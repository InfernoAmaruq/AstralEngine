#include "audio/audio.h"
#include "data/blob.h"
#include "data/sound.h"
#include "core/job.h"
#include "core/maf.h"
#include "util.h"
#include "lib/miniaudio/miniaudio.h"
#ifdef LOVR_USE_PHONON
#include <phonon.h>
#endif
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#ifdef _MSC_VER
#include <intrin.h>
#define CTZL _tzcnt_u64
#else
#define CTZL __builtin_ctzl
#endif

#define FOREACH_SOURCE(mask, s) for (uint64_t m = mask; s = m ? state.activeSources[CTZL(m)] : NULL, m; m ^= (m & -m))
#define OUTPUT_FORMAT SAMPLE_F32
#define MAX_OCCLUSION_SAMPLES 16
#define BUFFER_SIZE 256
#define MAX_SOURCES 64

struct Source {
  atomic_uint ref;
  uint32_t slot;
  Sound* sound;
  ma_data_converter* converter;
  float volume;
  float pitch;
  float position[3];
  float radius;
  float orientation[4];
  float dipoleWeight;
  float dipolePower;
  uint8_t effects;
  bool looping;
  bool pitchable;
  bool spatial;
  atomic_bool playing;
  atomic_bool hasTail;
  atomic_uint offset;
  atomic_uint playRequest;
  atomic_uint seekRequest;
#ifdef LOVR_USE_PHONON
  IPLSource handle;
  IPLHRTF hrtf;
  IPLAudioBuffer stereoBuffer;
  IPLSimulationInputs inputs;
  IPLSimulationOutputs outputs[2];
  IPLVector3 relativeDirection[2];
  IPLDirectEffect directEffect;
  IPLPanningEffect panningEffect;
  IPLBinauralEffect binauralEffect;
  IPLReflectionEffect reflectionEffect;
#endif
};

struct AudioMesh {
  uint32_t ref;
  bool enabled;
  AudioMesh* parent;
  float transform[16];
#ifdef LOVR_USE_PHONON
  IPLInstancedMesh instancedMesh;
  IPLStaticMesh staticMesh;
  IPLScene scene;
#endif
};

static atomic_uint ref;

static struct {
  AudioConfig config;
  ma_log log;
  ma_context context;
  ma_device devices[2];
  ma_device_info* deviceInfo[2];
  ma_data_converter playbackConverter;
  Sound* sinks[2];
  Source* activeSources[64];
  atomic_ullong activeSourceMask;
  uint64_t pendingSourceMask;
  atomic_uint backbuffer;
  float position[3];
  float orientation[4];
  float absorption[3];
} state;

static const ma_format miniaudioFormats[] = {
  [SAMPLE_I16] = ma_format_s16,
  [SAMPLE_F32] = ma_format_f32
};

static float dbToLinear(float db) {
  return powf(10.f, db / 20.f);
}

static float linearToDb(float linear) {
  return 20.f * log10f(linear);
}

static bool phonon_init(void);
static void phonon_destroy(void);
static bool phonon_update(float dt);
static bool phonon_set_hrtf(Blob* blob);
static void phonon_mix_source(Source* source, float* input, float* output, float* temp);
static void phonon_mix_tail(float* output, float* temp);
static bool phonon_source_init(Source* source);
static void phonon_source_destroy(Source* source);
static bool phonon_source_add(Source* source);
static void phonon_source_remove(Source* source);
static bool phonon_mesh_init(AudioMesh* mesh, float* vertices, uint32_t* indices, uint32_t vertexCount, uint32_t indexCount, AudioMaterial* materials, AudioMaterial material);
static bool phonon_mesh_init_clone(AudioMesh* clone);
static void phonon_mesh_destroy(AudioMesh* mesh);
static void phonon_mesh_set_enabled(AudioMesh* mesh, bool enable);
static void phonon_mesh_set_transform(AudioMesh* mesh, float* transform);

// Device callbacks

static void onPlayback(ma_device* device, void* out, const void* in, uint32_t count) {
  Source* source;
  float raw[BUFFER_SIZE * 2];
  float aux[BUFFER_SIZE * 2];
  float mix[BUFFER_SIZE * 2];
  float* dst = out;
  float* buf = NULL; // The "current" buffer (used for fast paths)

#ifdef LOVR_USE_PHONON
  uint32_t frontbuffer = !state.backbuffer;
  bool hasReverb = false;

  if (state.config.reverb.mode == REVERB_PARAMETRIC) {
    memset(state.reflectionBuffer.data[0], 0, BUFFER_SIZE * sizeof(float));
  }
#endif

  FOREACH_SOURCE(state.activeSourceMask, source) {
    uint32_t play = atomic_exchange(&source->playRequest, ~0u);
    if (play != ~0u) source->playing = !!play;

    uint32_t seek = atomic_exchange(&source->seekRequest, ~0u);
    if (seek != ~0u) source->offset = seek;

    if (source->pitchable) {
      float ratio = source->pitch * lovrSoundGetSampleRate(source->sound) / state.config.sampleRate;
      ma_data_converter_set_rate_ratio(source->converter, ratio);
    }

    bool hasTail = false;

    if (source->playing) {
      // Read and convert raw frames until there's BUFFER_SIZE converted frames
      // - No converter: just read frames into raw (it has enough space for BUFFER_SIZE frames).
      // - Converter: keep reading as many frames as possible/needed into raw and convert into aux.
      // - If EOF is reached, rewind and continue for looping sources, otherwise pad end with zero.
      buf = source->converter ? aux : raw;
      float* cursor = buf; // Edge of processed frames
      uint32_t channelsOut = source->spatial ? 1 : 2; // If spatializer isn't converting to stereo, converter must do it
      uint32_t framesRemaining = BUFFER_SIZE;

      while (framesRemaining > 0) {
        uint32_t framesRead;

        if (source->converter) {
          uint32_t channelsIn = lovrSoundGetChannelCount(source->sound);
          uint32_t capacity = sizeof(raw) / (channelsIn * sizeof(float));
          ma_uint64 chunk;
          ma_data_converter_get_required_input_frame_count(source->converter, framesRemaining, &chunk);
          framesRead = lovrSoundRead(source->sound, source->offset, MIN(chunk, capacity), raw);
        } else {
          framesRead = lovrSoundRead(source->sound, source->offset, framesRemaining, cursor);
        }

        if (framesRead == 0) {
          if (source->looping) {
            source->offset = 0;
            continue;
          } else {
            source->offset = 0;
            source->playing = false;
            memset(cursor, 0, framesRemaining * channelsOut * sizeof(float));
            break;
          }
        } else {
          source->offset += framesRead;
        }

        if (source->converter) {
          ma_uint64 framesIn = framesRead;
          ma_uint64 framesOut = framesRemaining;
          ma_data_converter_process_pcm_frames(source->converter, raw, &framesIn, cursor, &framesOut);
          cursor += framesOut * channelsOut;
          framesRemaining -= framesOut;
        } else {
          cursor += framesRead * channelsOut;
          framesRemaining -= framesRead;
        }
      }

#ifdef LOVR_USE_PHONON
      // Spatializer
      if (source->spatial) {
        IPLAudioBuffer monoBuffer = { .numChannels = 1, .numSamples = BUFFER_SIZE, .data = &buf };

        // Feed raw audio to reflection effect
        // Note that the reflection mixer is only used for convolution reverb
        // Parametric reverb uses `mix` as a temp buffer and mixes mono reverb into state.reflectionBuffer
        if (source->effects & (1 << EFFECT_REVERB)) {
          IPLSimulationOutputs outputs = { 0 };
          iplSourceGetOutputs(source->handle, IPL_SIMULATIONFLAGS_REFLECTIONS, &outputs);

          if (state.config.reverb.mode == REVERB_CONVOLUTION) {
            hasTail |= iplReflectionEffectApply(source->reflectionEffect, &outputs.reflections, &monoBuffer, &state.reflectionBuffer, state.reflectionMixer) == IPL_AUDIOEFFECTSTATE_TAILREMAINING;
          } else {
            IPLAudioBuffer output = { .numChannels = 1, .numSamples = BUFFER_SIZE, .data = (float**) &mix };
            hasTail |= iplReflectionEffectApply(source->reflectionEffect, &outputs.reflections, &monoBuffer, &output, NULL) == IPL_AUDIOEFFECTSTATE_TAILREMAINING;
            iplAudioBufferMix(state.spatializer, &output, &state.reflectionBuffer);
          }

          hasReverb = true;
        }

        // Apply direct effects to raw audio, in-place
        if (source->effects & ((1 << EFFECT_ABSORPTION) | (1 << EFFECT_ATTENUATION) | (1 << EFFECT_OCCLUSION) | (1 << EFFECT_TRANSMISSION))) {
          IPLDirectEffectParams* params = &source->outputs[frontbuffer].direct;
          hasTail |= iplDirectEffectApply(source->directEffect, params, &monoBuffer, &monoBuffer) == IPL_AUDIOEFFECTSTATE_TAILREMAINING;
        }

        // Convert to stereo (either binaural/panning spatialization, or upmix)
        if (source->effects & (1 << EFFECT_SPATIALIZATION)) {
          if (source->hrtf) {
            IPLBinauralEffectParams params = {
              .direction = source->relativeDirection[frontbuffer],
              .interpolation = IPL_HRTFINTERPOLATION_BILINEAR,
              .spatialBlend = 1.f,
              .hrtf = source->hrtf
            };

            hasTail |= iplBinauralEffectApply(source->binauralEffect, &params, &monoBuffer, &source->stereoBuffer) == IPL_AUDIOEFFECTSTATE_TAILREMAINING;
          } else {
            IPLPanningEffectParams params = {
              .direction = source->relativeDirection[frontbuffer]
            };

            iplPanningEffectApply(source->panningEffect, &params, &monoBuffer, &source->stereoBuffer);
          }

          iplAudioBufferInterleave(state.spatializer, &source->stereoBuffer, mix);
        } else {
          for (uint32_t i = 0; i < BUFFER_SIZE; i++) {
            mix[2 * i + 0] = buf[i];
            mix[2 * i + 1] = buf[i];
          }
        }

        buf = mix;
      }
#endif
    } else if (source->spatial) {
#ifdef LOVR_USE_PHONON
      uint32_t directTailSize = iplDirectEffectGetTailSize(source->directEffect);

      // Get mono tail from direct effect and convert to stereo, storing in raw
      if (directTailSize > 0) {
        IPLAudioBuffer buffer = { .numChannels = 1, .numSamples = BUFFER_SIZE, .data = (float**) raw };
        hasTail |= iplDirectEffectGetTail(source->directEffect, &buffer) == IPL_AUDIOEFFECTSTATE_TAILREMAINING;
      }

      // Get stereo tail from binaural effect and mix with other tails, if any
      if (source->hrtf && iplBinauralEffectGetTailSize(source->binauralEffect) > 0) {
        hasTail |= iplBinauralEffectGetTail(source->binauralEffect, &source->stereoBuffer) == IPL_AUDIOEFFECTSTATE_TAILREMAINING;
        if (directTailSize > 0) {
          iplAudioBufferInterleave(state.spatializer, &source->stereoBuffer, aux);
          for (uint32_t i = 0; i < BUFFER_SIZE; i++) {
            mix[2 * i + 0] = raw[i] + aux[2 * i + 0];
            mix[2 * i + 1] = raw[i] + aux[2 * i + 1];
          }
        } else {
          iplAudioBufferInterleave(state.spatializer, &source->stereoBuffer, mix);
        }
      } else if (directTailSize > 0) {
        for (uint32_t i = 0; i < BUFFER_SIZE; i++) {
          mix[2 * i + 0] = raw[i];
          mix[2 * i + 1] = raw[i];
        }
      } else {
        memset(mix, 0, BUFFER_SIZE * 2 * sizeof(float));
      }

      // Reverb tail
      if (iplReflectionEffectGetTailSize(source->reflectionEffect) > 0) {
        IPLAudioBuffer output = { .numChannels = 1, .numSamples = BUFFER_SIZE, .data = (float**) &raw };
        hasTail |= iplReflectionEffectGetTail(source->reflectionEffect, &output, state.reflectionMixer) == IPL_AUDIOEFFECTSTATE_TAILREMAINING;

        if (state.config.reverb.mode == REVERB_PARAMETRIC) {
          iplAudioBufferMix(state.spatializer, &output, &state.reflectionBuffer);
        }

        hasReverb = true;
      }

      buf = mix;
#endif
    }

    // Mix
    float volume = source->volume;
    for (uint32_t i = 0; i < 2 * BUFFER_SIZE; i++) {
      dst[i] += buf[i] * volume;
    }

    // Once we set this to false, the source could get destroyed (if it's not playing)
    source->hasTail = hasTail;
  }

#ifdef LOVR_USE_PHONON
  if (hasReverb) {
    // Convolution reverb: apply reflection mixer -> ambisonic buffer -> pan/spatialize to stereo
    if (state.config.reverb.mode == REVERB_CONVOLUTION) {
      IPLReflectionEffectParams reflectionMixerParams = { .numChannels = 4 };
      iplReflectionMixerApply(state.reflectionMixer, &reflectionMixerParams, &state.reflectionBuffer);

      IPLAmbisonicsDecodeEffectParams ambisonicsDecodeParams = {
        .order = 1,
        .hrtf = state.hrtf,
        .orientation = state.listenerBasis[frontbuffer],
        .binaural = !!state.hrtf
      };

      IPLAudioBuffer output = {
        .numChannels = 2,
        .numSamples = BUFFER_SIZE,
        .data = (float*[2]) {
          mix,
          mix + BUFFER_SIZE
        }
      };

      iplAmbisonicsDecodeEffectApply(state.ambisonicsDecodeEffect, &ambisonicsDecodeParams, &state.reflectionBuffer, &output);

      // Interleave and mix
      for (uint32_t i = 0; i < BUFFER_SIZE; i++) {
        dst[2 * i + 0] += output.data[0][i];
        dst[2 * i + 1] += output.data[1][i];
      }
    } else {
      // Parametric reverb: just upmix mono reflection buffer to stereo and mix into output
      for (uint32_t i = 0; i < BUFFER_SIZE; i++) {
        dst[2 * i + 0] += state.reflectionBuffer.data[0][i];
        dst[2 * i + 1] += state.reflectionBuffer.data[0][i];
      }
    }
  }

  if (!hasReverb && state.config.reverb.mode == REVERB_CONVOLUTION && iplAmbisonicsDecodeEffectGetTailSize(state.ambisonicsDecodeEffect) > 0) {
    IPLAudioBuffer output = {
      .numChannels = 2,
      .numSamples = BUFFER_SIZE,
      .data = (float*[2]) {
        mix,
        mix + BUFFER_SIZE
      }
    };

    iplAmbisonicsDecodeEffectGetTail(state.ambisonicsDecodeEffect, &output);

    // Interleave and mix
    for (uint32_t i = 0; i < BUFFER_SIZE; i++) {
      dst[2 * i + 0] += output.data[0][i];
      dst[2 * i + 1] += output.data[1][i];
    }
  }
#endif

  if (state.sinks[AUDIO_PLAYBACK]) {
    uint64_t capacity = sizeof(aux) / lovrSoundGetChannelCount(state.sinks[AUDIO_PLAYBACK]) / sizeof(float);
    while (count > 0) {
      ma_uint64 framesConsumed = count;
      ma_uint64 framesWritten = capacity;
      ma_data_converter_process_pcm_frames(&state.playbackConverter, dst, &framesConsumed, aux, &framesWritten);
      lovrSoundWrite(state.sinks[AUDIO_PLAYBACK], 0, framesWritten, aux, NULL);
      dst += framesConsumed * 2;
      count -= framesConsumed;
    }
  }
}

static void onCapture(ma_device* device, void* output, const void* input, uint32_t count) {
  lovrSoundWrite(state.sinks[AUDIO_CAPTURE], 0, count, input, NULL);
}

static void onLog(void* userdata, ma_uint32 maLevel, const char* message) {
  int level;
  switch (maLevel) {
    case MA_LOG_LEVEL_DEBUG: level = LOG_DEBUG; break;
    case MA_LOG_LEVEL_INFO: level = LOG_INFO; break;
    case MA_LOG_LEVEL_WARNING: level = LOG_WARN; break;
    case MA_LOG_LEVEL_ERROR: level = LOG_ERROR; break;
  }
  lovrLog(level, "MA", message);
}

#ifdef LOVR_USE_PHONON
static void onSpatializerLog(IPLLogLevel iplLevel, const char* message) {
  int level;
  switch (iplLevel) {
    case IPL_LOGLEVEL_INFO: level = LOG_INFO; break;
    case IPL_LOGLEVEL_WARNING: level = LOG_WARN; break;
    case IPL_LOGLEVEL_ERROR: level = LOG_ERROR; break;
    case IPL_LOGLEVEL_DEBUG: level = LOG_DEBUG; break;
  }
  lovrLog(level, "SA", message);
}
#endif

// Entry

bool lovrAudioInit(AudioConfig* config) {
  if (!lovrModuleAcquire(&ref)) return true;

  state.config = *config;

  ma_context_config contextConfig = ma_context_config_init();

  if (config->debug) {
    ma_log_init(NULL, &state.log);
    ma_log_register_callback(&state.log, ma_log_callback_init(onLog, NULL));
    contextConfig.pLog = &state.log;
  }

  ma_result result = ma_context_init(NULL, 0, &contextConfig, &state.context);
  if (result != MA_SUCCESS) {
    lovrModuleReset(&ref);
    return lovrSetError("Failed to initialize miniaudio context: %s", ma_result_description(result));
  }

#ifdef LOVR_USE_PHONON
  IPLContextSettings contextSettings = {
    .version = STEAMAUDIO_VERSION,
    .logCallback = onSpatializerLog,
    .simdLevel = IPL_SIMDLEVEL_AVX512
  };

  if (iplContextCreate(&contextSettings, &state.spatializer)) {
    return lovrAudioDestroy(), lovrSetError("Failed to create SteamAudio context");
  }

  state.audioSettings.samplingRate = config->sampleRate;
  state.audioSettings.frameSize = BUFFER_SIZE;

  switch (config->reverb.mode) {
    case REVERB_CONVOLUTION: default: state.reflectionSettings.type = IPL_REFLECTIONEFFECTTYPE_CONVOLUTION; break;
    case REVERB_PARAMETRIC: state.reflectionSettings.type = IPL_REFLECTIONEFFECTTYPE_PARAMETRIC; break;
  }

  state.reflectionSettings.irSize = config->reverb.duration * config->sampleRate;
  state.reflectionSettings.numChannels = config->reverb.mode == REVERB_CONVOLUTION ? 4 : 1;

  state.simulationFlags = IPL_SIMULATIONFLAGS_DIRECT | IPL_SIMULATIONFLAGS_REFLECTIONS;

  IPLSimulationSettings simulationSettings = {
    .flags = state.simulationFlags,
    .sceneType = IPL_SCENETYPE_DEFAULT,
    .reflectionType = state.reflectionSettings.type,
    .maxNumOcclusionSamples = MAX_OCCLUSION_SAMPLES,
    .maxNumRays = config->reverb.rays,
    .numDiffuseSamples = 1024,
    .maxDuration = config->reverb.duration,
    .maxOrder = 1,
    .maxNumSources = MAX_SOURCES,
    .numThreads = 8,
    .samplingRate = state.audioSettings.samplingRate,
    .frameSize = state.audioSettings.frameSize
  };

  if (iplSimulatorCreate(state.spatializer, &simulationSettings, &state.simulator)) {
    return lovrAudioDestroy(), lovrSetError("Failed to create SteamAudio simulator");
  }

  IPLSceneSettings sceneSettings = { .type = IPL_SCENETYPE_DEFAULT };
  if (iplSceneCreate(state.spatializer, &sceneSettings, &state.scene)) {
    return lovrAudioDestroy(), lovrSetError("Failed to create SteamAudio scene");
  }

  iplSimulatorSetScene(state.simulator, state.scene);

  if (config->reverb.mode == REVERB_CONVOLUTION) {
    if (iplReflectionMixerCreate(state.spatializer, &state.audioSettings, &state.reflectionSettings, &state.reflectionMixer)) {
      return lovrAudioDestroy(), lovrSetError("Failed to create reverb mixer");
    }

    IPLAmbisonicsDecodeEffectSettings settings = {
      .speakerLayout.type = IPL_SPEAKERLAYOUTTYPE_STEREO,
      .hrtf = NULL,
      .maxOrder = 1
    };

    if (iplAmbisonicsDecodeEffectCreate(state.spatializer, &state.audioSettings, &settings, &state.ambisonicsDecodeEffect)) {
      return lovrAudioDestroy(), lovrSetError("Failed to create ambisonics decode effect");
    }
  }

  if (iplAudioBufferAllocate(state.spatializer, state.reflectionSettings.numChannels, BUFFER_SIZE, &state.reflectionBuffer)) {
    return lovrAudioDestroy(), lovrSetError("Failed to create reverb buffer");
  }

  atomic_store(&state.reverbFinished, true);
#endif

  // SteamAudio's default frequency-dependent absorption coefficients for air
  state.absorption[0] = .0002f;
  state.absorption[1] = .0017f;
  state.absorption[2] = .0182f;

  quat_identity(state.orientation);
  lovrModuleReady(&ref);
  return true;
}

void lovrAudioDestroy(void) {
  if (!lovrModuleRelease(&ref)) return;
  for (size_t i = 0; i < 2; i++) {
    ma_device_uninit(&state.devices[i]);
    lovrFree(state.deviceInfo[i]);
  }
  Source* source;
  uint64_t mask = state.activeSourceMask | state.pendingSourceMask;
  FOREACH_SOURCE(mask, source) lovrRelease(source, lovrSourceDestroy);
  ma_context_uninit(&state.context);
  lovrRelease(state.sinks[AUDIO_PLAYBACK], lovrSoundDestroy);
  lovrRelease(state.sinks[AUDIO_CAPTURE], lovrSoundDestroy);
  ma_data_converter_uninit(&state.playbackConverter, NULL);
#ifdef LOVR_USE_PHONON
  iplAmbisonicsDecodeEffectRelease(&state.ambisonicsDecodeEffect);
  iplAudioBufferFree(state.spatializer, &state.reflectionBuffer);
  iplReflectionMixerRelease(&state.reflectionMixer);
  iplHRTFRelease(&state.hrtf);
  iplSceneRelease(&state.scene);
  iplSimulatorRelease(&state.simulator);
  iplContextRelease(&state.spatializer);
#endif
  memset(&state, 0, sizeof(state));
  lovrModuleReset(&ref);
}

static AudioDeviceCallback* enumerateCallback;

static ma_bool32 enumPlayback(ma_context* context, ma_device_type type, const ma_device_info* info, void* userdata) {
  AudioDevice device = { sizeof(info->id), &info->id, info->name, info->isDefault };
  if (type == ma_device_type_playback) enumerateCallback(&device, userdata);
  return MA_TRUE;
}

static ma_bool32 enumCapture(ma_context* context, ma_device_type type, const ma_device_info* info, void* userdata) {
  AudioDevice device = { sizeof(info->id), &info->id, info->name, info->isDefault };
  if (type == ma_device_type_capture) enumerateCallback(&device, userdata);
  return MA_TRUE;
}

void lovrAudioEnumerateDevices(AudioType type, AudioDeviceCallback* callback, void* userdata) {
  enumerateCallback = callback;
  ma_context_enumerate_devices(&state.context, type == AUDIO_PLAYBACK ? enumPlayback : enumCapture, userdata);
}

bool lovrAudioGetDevice(AudioType type, AudioDevice* device) {
  if (!state.devices[type].pContext) {
    return false;
  }

  if (!state.deviceInfo[type]) {
    state.deviceInfo[type] = lovrMalloc(sizeof(ma_device_info));
  }

  ma_device_info* info = state.deviceInfo[type];
  ma_device_type deviceType = type == AUDIO_PLAYBACK ? ma_device_type_playback : ma_device_type_capture;
  ma_result result = ma_device_get_info(&state.devices[type], deviceType, info);
  device->idSize = sizeof(ma_device_id);
  device->id = &info->id;
  device->name = info->name;
  device->isDefault = info->isDefault;
  return result == MA_SUCCESS;
}

bool lovrAudioSetDevice(AudioType type, void* id, size_t size, Sound* sink, AudioShareMode shareMode) {
  lovrAssert(!id || size == sizeof(ma_device_id), "Invalid device ID");
  lovrCheck(!sink || lovrSoundGetChannelLayout(sink) != CHANNEL_AMBISONIC, "Ambisonic Sounds cannot be used as sinks");
  lovrCheck(!sink || lovrSoundIsStream(sink), "Sinks must be streams");

  // If no sink is provided for a capture device, one is created internally
  if (type == AUDIO_CAPTURE && !sink) {
    sink = lovrSoundCreateStream(state.config.sampleRate * 1., SAMPLE_F32, CHANNEL_MONO, state.config.sampleRate);
  } else {
    lovrRetain(sink);
  }

  ma_device_uninit(&state.devices[type]);
  lovrRelease(state.sinks[type], lovrSoundDestroy);
  state.sinks[type] = sink;

#ifdef ANDROID
  // XXX<nevyn> miniaudio doesn't seem to be happy to set a specific device an android (fails with
  // error -2 on device init). Since there is only one playback and one capture device in OpenSL,
  // we can just set this to NULL and make this call a no-op.
  id = NULL;
#endif

  static const ma_share_mode shareModes[] = {
    [AUDIO_SHARED] = ma_share_mode_shared,
    [AUDIO_EXCLUSIVE] = ma_share_mode_exclusive
  };

  ma_result result;
  ma_device_config config;

  if (type == AUDIO_PLAYBACK) {
    config = ma_device_config_init(ma_device_type_playback);
    config.playback.pDeviceID = (ma_device_id*) id;
    config.playback.shareMode = shareModes[shareMode];
    config.playback.format = ma_format_f32;
    config.playback.channels = 2;
    config.sampleRate = state.config.sampleRate;
    config.periodSizeInFrames = BUFFER_SIZE;
    config.dataCallback = onPlayback;
    if (sink) {
      ma_data_converter_config converterConfig = ma_data_converter_config_init_default();
      converterConfig.formatIn = config.playback.format;
      converterConfig.formatOut = miniaudioFormats[lovrSoundGetFormat(sink)];
      converterConfig.channelsIn = config.playback.channels;
      converterConfig.channelsOut = lovrSoundGetChannelCount(sink);
      converterConfig.sampleRateIn = config.sampleRate;
      converterConfig.sampleRateOut = lovrSoundGetSampleRate(sink);
      ma_data_converter_uninit(&state.playbackConverter, NULL);
      result = ma_data_converter_init(&converterConfig, NULL, &state.playbackConverter);
      lovrAssertGoto(fail, result == MA_SUCCESS, "Failed to create sink data converter: %s", ma_result_description(result));
    }
  } else {
    config = ma_device_config_init(ma_device_type_capture);
    config.capture.pDeviceID = (ma_device_id*) id;
    config.capture.shareMode = shareModes[shareMode];
    config.capture.format = miniaudioFormats[lovrSoundGetFormat(sink)];
    config.capture.channels = lovrSoundGetChannelCount(sink);
    config.sampleRate = lovrSoundGetSampleRate(sink);
    config.periodSizeInFrames = BUFFER_SIZE;
    config.dataCallback = onCapture;
  }

  result = ma_device_init(&state.context, &config, &state.devices[type]);
  lovrAssertGoto(fail, result == MA_SUCCESS, "Failed to initialize device: %s", ma_result_description(result));
  return true;
fail:
  lovrRelease(sink, lovrSoundDestroy);
  state.sinks[type] = NULL;
  return false;
}

bool lovrAudioStart(AudioType type) {
  return ma_device_start(&state.devices[type]) == MA_SUCCESS;
}

bool lovrAudioStop(AudioType type) {
  return ma_device_stop(&state.devices[type]) == MA_SUCCESS;
}

bool lovrAudioIsStarted(AudioType type) {
  return ma_device_is_started(&state.devices[type]);
}

#ifdef LOVR_USE_PHONON
static void simulateIndirect(void* arg) {
  iplSimulatorRunReflections(state.simulator);
  atomic_store(&state.reverbFinished, true);
}
#endif

void lovrAudioUpdate(float dt) {
  Source* source;
  uint64_t mask = state.activeSourceMask | state.pendingSourceMask;

  FOREACH_SOURCE(mask, source) {
    if (!source->playing && source->playRequest != 1 && !source->hasTail) {
#ifdef LOVR_USE_PHONON
      phonon_source_remove();
      iplSourceRemove(source->handle, state.simulator);
      iplHRTFRelease(&source->hrtf);
      source->hrtf = NULL;
#endif
      state.activeSources[source->slot] = NULL;
      state.activeSourceMask &= ~(1ull << source->slot);
      state.pendingSourceMask &= ~(1ull << source->slot);
      mask &= ~(1ull << source->slot);
      source->slot = ~0u;
      lovrRelease(source, lovrSourceDestroy);
    }
  }

#ifdef LOVR_USE_PHONON
  if (state.sceneDirty) {
    iplSceneCommit(state.scene);
    state.sceneDirty = false;
  }

  // TODO maybe split into 2 simulators so we can have less latency on direct simulation commits
  if (atomic_load(&state.reverbFinished)) {
    iplSimulatorCommit(state.simulator);
  }

  uint32_t backbuffer = state.backbuffer;

  IPLSimulationSharedInputs sharedInputs;
  poseToPhonon(state.position, state.orientation, &sharedInputs.listener);
  sharedInputs.numRays = state.config.reverb.rays;
  sharedInputs.numBounces = state.config.reverb.bounces;
  sharedInputs.duration = state.config.reverb.duration;
  sharedInputs.order = 1;
  sharedInputs.irradianceMinDistance = .01f;

  iplSimulatorSetSharedInputs(state.simulator, IPL_SIMULATIONFLAGS_DIRECT, &sharedInputs);

  state.listenerBasis[backbuffer] = sharedInputs.listener;

  bool hasReverb = false;

  FOREACH_SOURCE(mask, source) {
    poseToPhonon(source->position, source->orientation, &source->inputs.source);
    vec3_sub(vec3_init(&source->relativeDirection[backbuffer].x, source->position), state.position);
    source->inputs.directivity.dipoleWeight = source->dipoleWeight;
    source->inputs.directivity.dipolePower = source->dipolePower;
    memcpy(source->inputs.airAbsorptionModel.coefficients, state.absorption, 3 * sizeof(float));
    iplSourceSetInputs(source->handle, IPL_SIMULATIONFLAGS_DIRECT, &source->inputs);
    hasReverb |= !!(source->effects & (1 << EFFECT_REVERB));
  }

  iplSimulatorRunDirect(state.simulator);

  FOREACH_SOURCE(mask, source) {
    iplSourceGetOutputs(source->handle, IPL_SIMULATIONFLAGS_DIRECT, &source->outputs[backbuffer]);
    source->outputs[backbuffer].direct.flags = source->inputs.directFlags;
  }

  atomic_fetch_xor(&state.backbuffer, 0x1);

  if (hasReverb) {
    state.reverbTimer -= dt;

    if (state.reverbTimer <= 0.f && atomic_load(&state.reverbFinished)) {
      atomic_store(&state.reverbFinished, false);
      state.reverbTimer = state.config.reverb.rate;

      Source* source;
      FOREACH_SOURCE(mask, source) {
        iplSourceSetInputs(source->handle, IPL_SIMULATIONFLAGS_REFLECTIONS, &source->inputs);
      }

      iplSimulatorSetSharedInputs(state.simulator, IPL_SIMULATIONFLAGS_REFLECTIONS, &sharedInputs);

      while (!job_start(simulateIndirect, NULL)) {
        job_spin();
      }
    }
  }
#endif

  atomic_fetch_or(&state.activeSourceMask, state.pendingSourceMask);
  state.pendingSourceMask = 0;
}

float lovrAudioGetVolume(VolumeUnit units) {
  float volume = 0.f;
  ma_device_get_master_volume(&state.devices[AUDIO_PLAYBACK], &volume);
  return units == UNIT_LINEAR ? volume : linearToDb(volume);
}

void lovrAudioSetVolume(float volume, VolumeUnit units) {
  if (units == UNIT_DECIBELS) volume = dbToLinear(volume);
  ma_device_set_master_volume(&state.devices[AUDIO_PLAYBACK], CLAMP(volume, 0.f, 1.f));
}

void lovrAudioGetPose(float position[3], float orientation[4]) {
  vec3_init(position, state.position);
  quat_init(orientation, state.orientation);
}

void lovrAudioSetPose(float position[3], float orientation[4]) {
  vec3_init(state.position, position);
  quat_init(state.orientation, orientation);
}

bool lovrAudioSetHRTF(Blob* blob) {
#ifdef LOVR_USE_PHONON
  iplHRTFRelease(&state.hrtf);
  state.hrtf = NULL;

  if (blob) {
    IPLHRTFSettings settings = {
      .type = IPL_HRTFTYPE_SOFA,
      .sofaData = blob->data,
      .sofaDataSize = blob->size,
      .volume = 1.f,
      .normType = IPL_HRTFNORMTYPE_NONE
    };

    if (iplHRTFCreate(state.spatializer, &state.audioSettings, &settings, &state.hrtf)) {
      return lovrSetError("Failed to create HRTF");
    }

    // TODO recreate AmbisonicsDecodeEffect (may need to double buffer this, and/or maybe the hrtf)
  }

#endif
  return true;
}

uint32_t lovrAudioGetSampleRate(void) {
  return state.config.sampleRate;
}

void lovrAudioGetAbsorption(float absorption[3]) {
  memcpy(absorption, state.absorption, 3 * sizeof(float));
}

void lovrAudioSetAbsorption(float absorption[3]) {
  memcpy(state.absorption, absorption, 3 * sizeof(float));
}

// Source

static bool lovrSourceInit(Source* source) {
#ifndef LOVR_USE_PHONON
  return true;
#else
  IPLSourceSettings settings = { .flags = IPL_SIMULATIONFLAGS_DIRECT | IPL_SIMULATIONFLAGS_REFLECTIONS };
  if (iplSourceCreate(state.simulator, &settings, &source->handle)) {
    return lovrSetError("Failed to add source to spatializer");
  }

  source->inputs.flags = state.simulationFlags;
  source->inputs.directFlags =
    IPL_DIRECTSIMULATIONFLAGS_AIRABSORPTION |
    IPL_DIRECTSIMULATIONFLAGS_DISTANCEATTENUATION |
    IPL_DIRECTSIMULATIONFLAGS_OCCLUSION |
    IPL_DIRECTSIMULATIONFLAGS_TRANSMISSION;
  source->inputs.distanceAttenuationModel.type = IPL_DISTANCEATTENUATIONTYPE_DEFAULT;
  source->inputs.distanceAttenuationModel.minDistance = 1.f;
  source->inputs.airAbsorptionModel.type = IPL_AIRABSORPTIONTYPE_DEFAULT;
  source->inputs.numOcclusionSamples = MAX_OCCLUSION_SAMPLES;
  source->inputs.numTransmissionRays = 2;
  vec3_set(source->inputs.reverbScale, 1.f, 1.f, 1.f);

  if (iplAudioBufferAllocate(state.spatializer, 2, BUFFER_SIZE, &source->stereoBuffer)) {
    lovrSetError("Failed to allocate audio buffer");
    goto fail;
  }

  IPLDirectEffectSettings directEffectSettings = {
    .numChannels = 1
  };

  if (iplDirectEffectCreate(state.spatializer, &state.audioSettings, &directEffectSettings, &source->directEffect)) {
    lovrSetError("Failed to create direct effect");
    goto fail;
  }

  IPLPanningEffectSettings panningEffectSettings = {
    .speakerLayout.type = IPL_SPEAKERLAYOUTTYPE_STEREO
  };

  if (iplPanningEffectCreate(state.spatializer, &state.audioSettings, &panningEffectSettings, &source->panningEffect)) {
    lovrSetError("Failed to create panning effect");
    goto fail;
  }

  if (iplReflectionEffectCreate(state.spatializer, &state.audioSettings, &state.reflectionSettings, &source->reflectionEffect)) {
    lovrSetError("Failed to create reflection effect");
    goto fail;
  }

  return true;
fail:
  iplReflectionEffectRelease(&source->reflectionEffect);
  iplPanningEffectRelease(&source->panningEffect);
  iplDirectEffectRelease(&source->directEffect);
  iplAudioBufferFree(state.spatializer, &source->stereoBuffer);
  iplSourceRelease(&source->handle);
  return false;
#endif
}

Source* lovrSourceCreate(Sound* sound, bool pitchable, bool spatial, uint32_t effects) {
  lovrCheck(lovrSoundGetChannelLayout(sound) != CHANNEL_AMBISONIC, "Ambisonic Sources are not currently supported");

  Source* source = lovrCalloc(sizeof(Source));
  source->ref = 1;
  source->slot = ~0u;
  source->pitch = 1.f;
  source->volume = 1.f;
  source->pitchable = pitchable;
  source->spatial = spatial;
  source->effects = spatial ? effects : 0;
  quat_identity(source->orientation);

  ma_data_converter_config config = ma_data_converter_config_init_default();
  config.formatIn = miniaudioFormats[lovrSoundGetFormat(sound)];
  config.formatOut = miniaudioFormats[OUTPUT_FORMAT];
  config.channelsIn = lovrSoundGetChannelCount(sound);
  config.channelsOut = spatial ? 1 : 2;
  config.sampleRateIn = lovrSoundGetSampleRate(sound);
  config.sampleRateOut = state.config.sampleRate;
  config.allowDynamicSampleRate = pitchable;

  if (pitchable || config.formatIn != config.formatOut || config.channelsIn != config.channelsOut || config.sampleRateIn != config.sampleRateOut) {
    ma_data_converter* converter = lovrMalloc(sizeof(ma_data_converter));
    ma_result status = ma_data_converter_init(&config, NULL, converter);

    if (status != MA_SUCCESS) {
      lovrSetError("Problem creating Source data converter: %s (%d)", ma_result_description(status), status);
      lovrSourceDestroy(source);
      return NULL;
    }

    source->converter = converter;
  }

  if (!lovrSourceInit(source)) {
    lovrSourceDestroy(source);
    return false;
  }

  source->sound = sound;
  lovrRetain(source->sound);
  return source;
}

Source* lovrSourceClone(Source* source) {
  Source* clone = lovrCalloc(sizeof(Source));
  clone->ref = 1;
  clone->slot = ~0u;
  clone->pitch = source->pitch;
  clone->volume = source->volume;
  vec3_init(clone->position, source->position);
  quat_init(clone->orientation, source->orientation);
  clone->radius = source->radius;
  clone->dipoleWeight = source->dipoleWeight;
  clone->dipolePower = source->dipolePower;
  clone->effects = source->effects;
  clone->looping = source->looping;
  clone->pitchable = source->pitchable;
  clone->spatial = source->spatial;

  if (source->converter) {
    ma_data_converter_config config = ma_data_converter_config_init_default();
    config.formatIn = source->converter->formatIn;
    config.formatOut = source->converter->formatOut;
    config.channelsIn = source->converter->channelsIn;
    config.channelsOut = source->converter->channelsOut;
    config.sampleRateIn = source->converter->sampleRateIn;
    config.sampleRateOut = source->converter->sampleRateOut;
    config.allowDynamicSampleRate = clone->pitchable;

    ma_data_converter* converter = lovrMalloc(sizeof(ma_data_converter));
    ma_result status = ma_data_converter_init(&config, NULL, converter);

    if (status != MA_SUCCESS) {
      lovrSetError("Problem creating Source data converter: %s (%d)", ma_result_description(status), status);
      lovrSourceDestroy(clone);
      return NULL;
    }

    clone->converter = converter;
  }

  if (!lovrSourceInit(clone)) {
    lovrSourceDestroy(clone);
    return false;
  }

  clone->sound = source->sound;
  lovrRetain(clone->sound);
  return clone;
}

void lovrSourceDestroy(void* ref) {
  Source* source = ref;
#ifdef LOVR_USE_PHONON
  iplHRTFRelease(&source->hrtf);
  iplReflectionEffectRelease(&source->reflectionEffect);
  iplBinauralEffectRelease(&source->binauralEffect);
  iplPanningEffectRelease(&source->panningEffect);
  iplDirectEffectRelease(&source->directEffect);
  iplAudioBufferFree(state.spatializer, &source->stereoBuffer);
  iplSourceRelease(&source->handle);
#endif
  lovrRelease(source->sound, lovrSoundDestroy);
  ma_data_converter_uninit(source->converter, NULL);
  lovrFree(source->converter);
  lovrFree(source);
}

Sound* lovrSourceGetSound(Source* source) {
  return source->sound;
}

bool lovrSourcePlay(Source* source) {
  if (source->slot == ~0u) {
    uint64_t mask = state.activeSourceMask | state.pendingSourceMask;
    if (mask == ~0ull) return false;
    uint32_t slot = mask ? CTZL(~mask) : 0;
    state.pendingSourceMask |= (1ull << slot);
    state.activeSources[slot] = source;
    source->slot = slot;
    lovrRetain(source);
#ifdef LOVR_USE_PHONON
    iplSourceAdd(source->handle, state.simulator);

    if (source->hrtf) lovrUnreachable();
    source->hrtf = state.hrtf;
    iplHRTFRetain(source->hrtf);

    if (source->hrtf && !source->binauralEffect) {
      IPLBinauralEffectSettings binauralEffectSettings = {
        .hrtf = source->hrtf
      };

      iplBinauralEffectCreate(state.spatializer, &state.audioSettings, &binauralEffectSettings, &source->binauralEffect);
    }
#endif
  }

  source->playRequest = 1;

  return true;
}

void lovrSourcePause(Source* source) {
  if (source->slot == ~0u) {
    source->playing = false;
  } else {
    source->playRequest = 0;
  }
}

void lovrSourceStop(Source* source) {
  lovrSourcePause(source);
  lovrSourceSeek(source, 0, UNIT_FRAMES);
}

bool lovrSourceIsPlaying(Source* source) {
  return source->playing || source->playRequest == 1;
}

bool lovrSourceIsLooping(Source* source) {
  return source->looping;
}

bool lovrSourceSetLooping(Source* source, bool loop) {
  lovrCheck(loop == false || lovrSoundIsStream(source->sound) == false, "Can't loop streams");
  source->looping = loop;
  return true;
}

float lovrSourceGetPitch(Source* source) {
  return source->pitch;
}

bool lovrSourceSetPitch(Source* source, float pitch) {
  lovrCheck(pitch > 0.f, "Source pitch must be positive");
  lovrCheck(source->pitchable, "Source must be created with the 'pitchable' flag to change its pitch");
  source->pitch = pitch;
  return true;
}

float lovrSourceGetVolume(Source* source, VolumeUnit units) {
  return units == UNIT_LINEAR ? source->volume : linearToDb(source->volume);
}

void lovrSourceSetVolume(Source* source, float volume, VolumeUnit units) {
  if (units == UNIT_DECIBELS) volume = dbToLinear(volume);
  source->volume = CLAMP(volume, 0.f, 1.f);
}

void lovrSourceSeek(Source* source, double time, TimeUnit units) {
  source->seekRequest = units == UNIT_SECONDS ? (uint32_t) (time * lovrSoundGetSampleRate(source->sound) + .5) : (uint32_t) time;
}

double lovrSourceTell(Source* source, TimeUnit units) {
  return units == UNIT_SECONDS ? (double) source->offset / lovrSoundGetSampleRate(source->sound) : source->offset;
}

double lovrSourceGetDuration(Source* source, TimeUnit units) {
  uint32_t frames = lovrSoundGetFrameCount(source->sound);
  return units == UNIT_SECONDS ? (double) frames / lovrSoundGetSampleRate(source->sound) : frames;
}

bool lovrSourceIsSpatial(Source* source) {
  return source->spatial;
}

void lovrSourceGetPose(Source* source, float position[3], float orientation[4]) {
  vec3_init(position, source->position);
  quat_init(orientation, source->orientation);
}

void lovrSourceSetPose(Source* source, float position[3], float orientation[4]) {
  if (position) vec3_init(source->position, position);
  if (orientation) quat_init(source->orientation, orientation);
}

float lovrSourceGetRadius(Source* source) {
  return source->radius;
}

void lovrSourceSetRadius(Source* source, float radius) {
  source->radius = radius;
#ifdef LOVR_USE_PHONON
  source->inputs.occlusionRadius = radius;
  source->inputs.occlusionType = radius > 0.f ? IPL_OCCLUSIONTYPE_VOLUMETRIC : IPL_OCCLUSIONTYPE_RAYCAST;
#endif
}

void lovrSourceGetDirectivity(Source* source, float* weight, float* power) {
  *weight = source->dipoleWeight;
  *power = source->dipolePower;
}

void lovrSourceSetDirectivity(Source* source, float weight, float power) {
  source->dipoleWeight = weight;
  source->dipolePower = power;
#ifdef LOVR_USE_PHONON
#endif
}

bool lovrSourceIsEffectEnabled(Source* source, Effect effect) {
  return source->effects & (1 << effect);
}

bool lovrSourceSetEffectEnabled(Source* source, Effect effect, bool enabled) {
  lovrCheck(source->spatial, "Sources must be created with the spatial flag to enable effects");

  if (enabled) {
    source->effects |= (1 << effect);
  } else {
    source->effects &= ~(1 << effect);
  }

#ifdef LOVR_USE_PHONON
  static const IPLDirectSimulationFlags phononEffectFlags[] = {
    [EFFECT_ABSORPTION] = IPL_DIRECTSIMULATIONFLAGS_AIRABSORPTION,
    [EFFECT_ATTENUATION] = IPL_DIRECTSIMULATIONFLAGS_DISTANCEATTENUATION,
    [EFFECT_OCCLUSION] = IPL_DIRECTSIMULATIONFLAGS_OCCLUSION,
    [EFFECT_REVERB] = 0,
    [EFFECT_SPATIALIZATION] = 0,
    [EFFECT_TRANSMISSION] = IPL_DIRECTSIMULATIONFLAGS_TRANSMISSION
  };

  if (enabled) {
    source->inputs.directFlags |= phononEffectFlags[effect];
  } else {
    source->inputs.directFlags &= ~phononEffectFlags[effect];
  }
#endif

  return true;
}

// AudioMesh

AudioMesh* lovrAudioMeshCreate(float* vertices, uint32_t* indices, uint32_t vertexCount, uint32_t indexCount, AudioMaterial* materials, AudioMaterial material) {
  AudioMesh* mesh = lovrCalloc(sizeof(AudioMesh));
  mesh->ref = 1;
  mesh->enabled = true;
  mat4_identity(mesh->transform);

  if (!phonon_mesh_init(mesh, vertices, indices, vertexCount, indexCount, materials, material)) {
    lovrFree(mesh);
    return NULL;
  }

  return mesh;
}

AudioMesh* lovrAudioMeshClone(AudioMesh* parent) {
  AudioMesh* mesh = lovrCalloc(sizeof(AudioMesh));
  mesh->ref = 1;
  mesh->enabled = true;
  mesh->parent = parent;
  mat4_init(mesh->transform, parent->transform);

  if (!phonon_mesh_init_clone(mesh)) {
    lovrFree(mesh);
    return NULL;
  }

  lovrRetain(parent);
  return mesh;
}

void lovrAudioMeshDestroy(void* ref) {
  AudioMesh* mesh = ref;
  phonon_mesh_destroy(mesh);
  lovrRelease(mesh->parent, lovrAudioMeshDestroy);
  lovrFree(mesh);
}

bool lovrAudioMeshIsEnabled(AudioMesh* mesh) {
  return mesh->enabled;
}

void lovrAudioMeshSetEnabled(AudioMesh* mesh, bool enable) {
  phonon_mesh_set_enabled(mesh, enable);
  mesh->enabled = enable;
}

void lovrAudioMeshGetTransform(AudioMesh* mesh, float* transform) {
  mat4_init(transform, mesh->transform);
}

void lovrAudioMeshSetTransform(AudioMesh* mesh, float* transform) {
  phonon_mesh_set_transform(mesh, transform);
  mat4_init(mesh->transform, transform);
}

// Phonon

#ifdef LOVR_USE_PHONON

static struct {
  IPLContext context;
  IPLAudioSettings audioSettings;
  IPLReflectionEffectSettings reflectionSettings;
  IPLSimulationFlags simulationFlags;
  IPLSimulator simulator;
  IPLScene scene;
  bool sceneDirty;
  IPLHRTF hrtf;
  IPLCoordinateSpace3 listenerBasis[2];
  IPLReflectionMixer reflectionMixer;
  IPLAudioBuffer reflectionBuffer;
  IPLAmbisonicsDecodeEffect ambisonicsDecodeEffect;
  atomic_bool reverbFinished;
  float reverbTimer;
} phonon;

static void convertPose(float* position, float* orientation, IPLCoordinateSpace3* basis) {
  float transform[16];
  mat4_fromQuat(transform, orientation);
  vec3_init(&basis->right.x, &transform[0]);
  vec3_init(&basis->up.x, &transform[4]);
  vec3_scale(vec3_init(&basis->ahead.x, &transform[8]), -1.f);
  vec3_init(&basis->origin.x, position);
}

static bool phonon_init(void) { return true; }
static void phonon_destroy(void) {}
static bool phonon_update(float dt) { return true; }
static bool phonon_set_hrtf(Blob* blob) { return true; }
static void phonon_mix_source(Source* source, float* input, float* output, float* temp) {}
static void phonon_mix_tail(float* output, float* temp) {}
static bool phonon_source_init(Source* source) { return true; }
static void phonon_source_destroy(Source* source) {}
static bool phonon_source_add(Source* source) { return true; }

static void phonon_source_remove(Source* source) {

}

static bool phonon_mesh_init(AudioMesh* mesh, float* vertices, uint32_t* indices, uint32_t vertexCount, uint32_t indexCount, AudioMaterial* materials, AudioMaterial material) {
  lovrCheck(indexCount % 3 == 0, "AudioMesh index count must be a multiple of 3");

  // Scene

  IPLSceneSettings sceneSettings = {
    .type = IPL_SCENETYPE_DEFAULT
  };

  if (iplSceneCreate(phonon.context, &sceneSettings, &mesh->scene)) {
    lovrSetError("Failed to create AudioMesh scene");
    return NULL;
  }

  // StaticMesh

  static const IPLMaterial materialData[] = {
    [MATERIAL_GENERIC] = { { .10f, .20f, .30f }, .05f, { .100f, .050f, .030f } },
    [MATERIAL_BRICK] = { { .03f, .04f, .07f }, .05f, { .015f, .015f, .015f } },
    [MATERIAL_CARPET] = { { .24f, .69f, .73f }, .05f, { .020f, .005f, .003f } },
    [MATERIAL_CERAMIC] = { { .01f, .02f, .02f }, .05f, { .060f, .044f, .011f } },
    [MATERIAL_CONCRETE] = { { .05f, .07f, .08f }, .05f, { .015f, .002f, .001f } },
    [MATERIAL_GLASS] = { { .06f, .03f, .02f }, .05f, { .060f, .044f, .011f } },
    [MATERIAL_GRAVEL] = { { .60f, .70f, .80f }, .05f, { .031f, .012f, .008f } },
    [MATERIAL_METAL] = { { .20f, .07f, .06f }, .05f, { .200f, .25f, .010f } },
    [MATERIAL_PLASTER] = { { .12f, .06f, .04f }, .05f, { .056f, .056f, .004f } },
    [MATERIAL_ROCK] = { { .13f, .20f, .24f }, .05f, { .015f, .002f, .001f } },
    [MATERIAL_WOOD] = { { .11f, .07f, .06f }, .05f, { .070f, .014f, .005f } }
  };

  IPLStaticMeshSettings settings = {
    .numVertices = vertexCount,
    .numTriangles = indexCount / 3,
    .numMaterials = COUNTOF(materialData),
    .vertices = (IPLVector3*) vertices,
    .materials = materialData
  };

  settings.triangles = lovrMalloc(settings.numTriangles * sizeof(IPLTriangle));

  for (uint32_t i = 0; i < settings.numTriangles; i++) {
    settings.triangles[i].indices[0] = indices[3 * i + 0];
    settings.triangles[i].indices[1] = indices[3 * i + 1];
    settings.triangles[i].indices[2] = indices[3 * i + 2];
  }

  if (materials) {
    settings.materialIndices = (IPLint32*) materials;
  } else {
    settings.materialIndices = lovrMalloc(settings.numTriangles * sizeof(IPLint32));
    for (uint32_t i = 0; i < settings.numTriangles; i++) {
      settings.materialIndices[i] = material;
    }
  }

  bool success = !iplStaticMeshCreate(mesh->scene, &settings, &mesh->staticMesh);
  if (!materials) lovrFree(settings.materialIndices);
  lovrFree(settings.triangles);

  if (!success) {
    lovrSetError("Failed to create AudioMesh");
    iplSceneRelease(&mesh->scene);
    return false;
  }

  iplStaticMeshAdd(mesh->staticMesh, mesh->scene);
  iplSceneCommit(mesh->scene);

  // InstancedMesh

  IPLInstancedMeshSettings instancedMeshSettings = {
    .subScene = mesh->scene,
    .transform.elements = {
      { 1.f, 0.f, 0.f, 0.f },
      { 0.f, 1.f, 0.f, 0.f },
      { 0.f, 0.f, 1.f, 0.f },
      { 0.f, 0.f, 0.f, 1.f }
    }
  };

  if (iplInstancedMeshCreate(phonon.scene, &instancedMeshSettings, &mesh->instancedMesh)) {
    lovrSetError("Failed to add AudioMesh to scene");
    iplStaticMeshRelease(&mesh->staticMesh);
    iplSceneRelease(&mesh->scene);
    return false;
  }

  iplInstancedMeshAdd(mesh->instancedMesh, phonon.scene);
  phonon.sceneDirty = true;

  return true;
}

static bool phonon_mesh_init_clone(AudioMesh* mesh) {
  IPLInstancedMeshSettings settings = {
    .subScene = mesh->parent->scene
  };

  mat4_transpose(mat4_init(&settings.transform.elements[0][0], mesh->transform));

  if (iplInstancedMeshCreate(phonon.scene, &settings, &mesh->instancedMesh)) {
    lovrSetError("Failed to create instanced audio mesh");
    return false;
  }

  iplInstancedMeshAdd(mesh->instancedMesh, phonon.scene);
  phonon.sceneDirty = true;

  mesh->staticMesh = mesh->parent->staticMesh;
  mesh->scene = mesh->parent->scene;
  return true;
}

static void phonon_mesh_destroy(AudioMesh* mesh) {
  if (mesh->enabled) {
    iplInstancedMeshRemove(mesh->instancedMesh, phonon.scene);
    phonon.sceneDirty = true;
  }
  iplInstancedMeshRelease(&mesh->instancedMesh);
  iplStaticMeshRelease(&mesh->staticMesh);
  iplSceneRelease(&mesh->scene);
}

static void phonon_mesh_set_enabled(AudioMesh* mesh, bool enable) {
  if (mesh->enabled == enable) {
    if (enable) {
      iplInstancedMeshAdd(mesh->instancedMesh, phonon.scene);
    } else {
      iplInstancedMeshRemove(mesh->instancedMesh, phonon.scene);
    }
    phonon.sceneDirty = true;
  }
}

static void phonon_mesh_set_transform(AudioMesh* mesh, float* transform) {
  IPLMatrix4x4 matrix;
  mat4_transpose(mat4_init(&matrix.elements[0][0], transform));
  iplInstancedMeshUpdateTransform(mesh->instancedMesh, phonon.scene, matrix);
  phonon.sceneDirty = true;
}

#else
static bool phonon_init(void) { return true; }
static void phonon_destroy(void) {}
static bool phonon_update(float dt) { return true; }
static bool phonon_set_hrtf(Blob* blob) { return true; }
static void phonon_mix_source(Source* source, float* input, float* output, float* temp) {}
static void phonon_mix_tail(float* output, float* temp) {}
static bool phonon_source_init(Source* source) { return true; }
static void phonon_source_destroy(Source* source) {}
static bool phonon_source_add(Source* source) { return true; }
static void phonon_source_remove(Source* source) {}
static bool phonon_mesh_init(AudioMesh* mesh, float* vertices, uint32_t* indices, uint32_t vertexCount, uint32_t indexCount, AudioMaterial* materials, AudioMaterial material) { return true; }
static bool phonon_mesh_init_clone(AudioMesh* clone) { return true; }
static void phonon_mesh_destroy(AudioMesh* mesh) {}
static void phonon_mesh_set_enabled(AudioMesh* mesh, bool enable) {}
static void phonon_mesh_set_transform(AudioMesh* mesh, float* transform) {}
#endif
