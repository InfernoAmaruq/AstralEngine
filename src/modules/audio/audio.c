#include "audio/audio.h"
#include "data/blob.h"
#include "data/sound.h"
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

#define FOREACH_SOURCE(s) for (uint64_t m = state.sourceMask; s = m ? state.sources[CTZL(m)] : NULL, m; m ^= (m & -m))
#define OUTPUT_FORMAT SAMPLE_F32
#define OUTPUT_CHANNELS 2
#define BUFFER_SIZE 256
#define MAX_SOURCES 64

struct Source {
  atomic_uint ref;
  uint32_t index;
  Sound* sound;
  ma_data_converter* converter;
  uint32_t offset;
  float pitch;
  float volume;
  float position[3];
  float orientation[4];
  float radius;
  float dipoleWeight;
  float dipolePower;
  uint8_t effects;
  bool playing;
  bool looping;
  bool pitchable;
  bool spatial;
#ifdef LOVR_USE_PHONON
  IPLSource handle;
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
  bool debug;
  ma_log log;
  ma_mutex lock;
  ma_context context;
  ma_device devices[2];
  ma_device_info* deviceInfo[2];
  Sound* sinks[2];
  Source* sources[MAX_SOURCES];
  uint64_t sourceMask;
  float position[3];
  float orientation[4];
  float absorption[3];
  ma_data_converter playbackConverter;
  uint32_t sampleRate;
#ifdef LOVR_USE_PHONON
  IPLContext spatializer;
  IPLAudioSettings audioSettings;
  IPLSimulator simulator;
  IPLScene scene;
  bool sceneDirty;
  IPLHRTF hrtf;
#endif
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

// Device callbacks

static void onPlayback(ma_device* device, void* out, const void* in, uint32_t count) {
  if (count != BUFFER_SIZE) {
    return;
  }

  float raw[BUFFER_SIZE * 2];
  float aux[BUFFER_SIZE * 2];
  float mix[BUFFER_SIZE * 2];
  float* dst = out;
  float* buf = NULL; // The "current" buffer (used for fast paths)

  ma_mutex_lock(&state.lock);

  Source* source;
  FOREACH_SOURCE(source) {
    if (!source->playing) {
      state.sources[source->index] = NULL;
      state.sourceMask &= ~(1ull << source->index);
      source->index = ~0u;
      lovrRelease(source, lovrSourceDestroy);
      continue;
    }

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

    // Spatialize
    if (source->spatial) {
      // lovrSpatializerApply(source, buf, mix, BUFFER_SIZE);
      buf = mix;
    }

    // Mix
    float volume = source->volume;
    for (uint32_t i = 0; i < OUTPUT_CHANNELS * BUFFER_SIZE; i++) {
      dst[i] += buf[i] * volume;
    }
  }

  // Tail
  // uint32_t tailCount = lovrSpatializerApplyTail(aux, mix, BUFFER_SIZE);
  // for (uint32_t i = 0; i < tailCount * OUTPUT_CHANNELS; i++) {
    // dst[i] += mix[i];
  // }

  ma_mutex_unlock(&state.lock);

  if (state.sinks[AUDIO_PLAYBACK]) {
    uint64_t capacity = sizeof(aux) / lovrSoundGetChannelCount(state.sinks[AUDIO_PLAYBACK]) / sizeof(float);
    while (count > 0) {
      ma_uint64 framesConsumed = count;
      ma_uint64 framesWritten = capacity;
      ma_data_converter_process_pcm_frames(&state.playbackConverter, dst, &framesConsumed, aux, &framesWritten);
      lovrSoundWrite(state.sinks[AUDIO_PLAYBACK], 0, framesWritten, aux, NULL);
      dst += framesConsumed * OUTPUT_CHANNELS;
      count -= framesConsumed;
    }
  }
}

static void onCapture(ma_device* device, void* output, const void* input, uint32_t count) {
  lovrSoundWrite(state.sinks[AUDIO_CAPTURE], 0, count, input, NULL);
}

static const ma_device_data_proc callbacks[] = { onPlayback, onCapture };

static void onLog(void* userdata, ma_uint32 level, const char* message) {
  lovrLog(level, "MA", message);
}

static void onSpatializerLog(IPLLogLevel iplLevel, const char* message) {
  int level;
  switch (iplLevel) {
    case IPL_LOGLEVEL_INFO: level = LOG_INFO;
    case IPL_LOGLEVEL_WARNING: level = LOG_WARN;
    case IPL_LOGLEVEL_ERROR: level = LOG_ERROR;
    case IPL_LOGLEVEL_DEBUG: level = LOG_DEBUG;
  }
  lovrLog(level, "SA", message);
}

// Entry

bool lovrAudioInit(bool debug, uint32_t sampleRate) {
  if (!lovrModuleAcquire(&ref)) return true;

  state.debug = debug;
  state.sampleRate = sampleRate;

  ma_context_config config = ma_context_config_init();

  if (debug) {
    ma_log_init(NULL, &state.log);
    ma_log_register_callback(&state.log, ma_log_callback_init(onLog, NULL));
    config.pLog = &state.log;
  }

  ma_result result = ma_context_init(NULL, 0, &config, &state.context);
  if (result != MA_SUCCESS) {
    lovrModuleReset(&ref);
    return lovrSetError("Failed to initialize miniaudio context: %s", ma_result_description(result));
  }

  result = ma_mutex_init(&state.lock);

  if (result != MA_SUCCESS) {
    ma_context_uninit(&state.context);
    lovrModuleReset(&ref);
    return lovrSetError("Failed to create audio mutex: %s", ma_result_description(result));
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

  state.audioSettings.samplingRate = state.sampleRate;
  state.audioSettings.frameSize = BUFFER_SIZE;

  IPLSimulationSettings simulationSettings = {
    .flags = IPL_SIMULATIONFLAGS_DIRECT | IPL_SIMULATIONFLAGS_REFLECTIONS,
    .sceneType = IPL_SCENETYPE_DEFAULT,
    .reflectionType = IPL_REFLECTIONEFFECTTYPE_CONVOLUTION,
    .maxNumOcclusionSamples = 16,
    .maxNumRays = 4096,
    .numDiffuseSamples = 1024,
    .maxDuration = 1.f,
    .maxOrder = 1,
    .maxNumSources = MAX_SOURCES,
    .numThreads = 4,
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
  FOREACH_SOURCE(source) lovrRelease(source, lovrSourceDestroy);
  ma_mutex_uninit(&state.lock);
  ma_context_uninit(&state.context);
  lovrRelease(state.sinks[AUDIO_PLAYBACK], lovrSoundDestroy);
  lovrRelease(state.sinks[AUDIO_CAPTURE], lovrSoundDestroy);
  ma_data_converter_uninit(&state.playbackConverter, NULL);
#ifdef LOVR_USE_PHONON
  iplHRTFRelease(&state.hrtf), state.hrtf = NULL;
  iplSceneRelease(&state.scene), state.scene = NULL;
  iplSimulatorRelease(&state.simulator), state.simulator = NULL;
  iplContextRelease(&state.spatializer), state.spatializer = NULL;
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
    sink = lovrSoundCreateStream(state.sampleRate * 1., SAMPLE_F32, CHANNEL_MONO, state.sampleRate);
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
    config.playback.channels = OUTPUT_CHANNELS;
    config.sampleRate = state.sampleRate;
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
  }

  config.periodSizeInFrames = BUFFER_SIZE;
  config.dataCallback = callbacks[type];

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

bool lovrAudioSetHRTF(Blob* hrtf) {
#if LOVR_USE_PHONON
  iplHRTFRelease(&state.hrtf);

  IPLHRTFSettings settings = {
    .type = IPL_HRTFTYPE_SOFA,
    .sofaData = hrtf->data,
    .sofaDataSize = hrtf->size,
    .volume = 1.f,
    .normType = IPL_HRTFNORMTYPE_NONE
  };

  if (iplHRTFCreate(state.spatializer, &state.audioSettings, &settings, &state.hrtf)) {
    return lovrSetError("Failed to create HRTF");
  }
#endif
  return true;
}

uint32_t lovrAudioGetSampleRate(void) {
  return state.sampleRate;
}

void lovrAudioGetAbsorption(float absorption[3]) {
  memcpy(absorption, state.absorption, 3 * sizeof(float));
}

void lovrAudioSetAbsorption(float absorption[3]) {
  ma_mutex_lock(&state.lock);
  memcpy(state.absorption, absorption, 3 * sizeof(float));
  ma_mutex_unlock(&state.lock);
}

// Source

static bool lovrSourceInit(Source* source) {
#ifdef LOVR_USE_PHONON
  IPLSourceSettings settings = { .flags = IPL_SIMULATIONFLAGS_DIRECT | IPL_SIMULATIONFLAGS_REFLECTIONS };
  if (iplSourceCreate(state.simulator, &settings, &source->handle)) {
    return lovrSetError("Failed to add source to spatializer");
  }
#endif

  return true;
}

Source* lovrSourceCreate(Sound* sound, bool pitchable, bool spatial, uint32_t effects) {
  lovrCheck(lovrSoundGetChannelLayout(sound) != CHANNEL_AMBISONIC, "Ambisonic Sources are not currently supported");

  Source* source = lovrCalloc(sizeof(Source));
  source->ref = 1;
  source->index = ~0u;
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
  config.sampleRateOut = state.sampleRate;
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
  clone->index = ~0u;
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
  // If too many sources already running, refuse to play
  if (state.sourceMask == ~0ull) {
    return false;
  }

  ma_mutex_lock(&state.lock);

  source->playing = true;

  // If the source isn't tracked, set its index to the right-most zero bit in the mask
  if (source->index == ~0u) {
    uint32_t index = state.sourceMask ? CTZL(~state.sourceMask) : 0;
    state.sourceMask |= (1ull << index);
    state.sources[index] = source;
    source->index = index;
    lovrRetain(source);
  }

  ma_mutex_unlock(&state.lock);
  return true;
}

void lovrSourcePause(Source* source) {
  source->playing = false;
}

void lovrSourceStop(Source* source) {
  lovrSourcePause(source);
  lovrSourceSeek(source, 0, UNIT_FRAMES);
}

bool lovrSourceIsPlaying(Source* source) {
  return source->playing;
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

  if (source->pitch != pitch) {
    source->pitch = pitch;
    ma_mutex_lock(&state.lock);
    float ratio = (float) lovrSoundGetSampleRate(source->sound) / state.sampleRate;
    ma_data_converter_set_rate_ratio(source->converter, pitch * ratio);
    ma_mutex_unlock(&state.lock);
  }

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
  ma_mutex_lock(&state.lock);
  source->offset = units == UNIT_SECONDS ? (uint32_t) (time * lovrSoundGetSampleRate(source->sound) + .5) : (uint32_t) time;
  ma_mutex_unlock(&state.lock);
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
  ma_mutex_lock(&state.lock);
  if (position) vec3_init(source->position, position);
  if (orientation) quat_init(source->orientation, orientation);
  ma_mutex_unlock(&state.lock);
}

float lovrSourceGetRadius(Source* source) {
  return source->radius;
}

void lovrSourceSetRadius(Source* source, float radius) {
  source->radius = radius;
}

void lovrSourceGetDirectivity(Source* source, float* weight, float* power) {
  *weight = source->dipoleWeight;
  *power = source->dipolePower;
}

void lovrSourceSetDirectivity(Source* source, float weight, float power) {
  source->dipoleWeight = weight;
  source->dipolePower = power;
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

  return true;
}

// AudioMesh

static IPLMaterial materialData[] = {
  [MATERIAL_GENERIC] = { .10f, .20f, .30f, .05f, .100f, .050f, .030f },
  [MATERIAL_BRICK] = { .03f, .04f, .07f, .05f, .015f, .015f, .015f },
  [MATERIAL_CARPET] = { .24f, .69f, .73f, .05f, .020f, .005f, .003f },
  [MATERIAL_CERAMIC] = { .01f, .02f, .02f, .05f, .060f, .044f, .011f },
  [MATERIAL_CONCRETE] = { .05f, .07f, .08f, .05f, .015f, .002f, .001f },
  [MATERIAL_GLASS] = { .06f, .03f, .02f, .05f, .060f, .044f, .011f },
  [MATERIAL_GRAVEL] = { .60f, .70f, .80f, .05f, .031f, .012f, .008f },
  [MATERIAL_METAL] = { .20f, .07f, .06f, .05f, .200f, .025f, .010f },
  [MATERIAL_PLASTER] = { .12f, .06f, .04f, .05f, .056f, .056f, .004f },
  [MATERIAL_ROCK] = { .13f, .20f, .24f, .05f, .015f, .002f, .001f },
  [MATERIAL_WOOD] = { .11f, .07f, .06f, .05f, .070f, .014f, .005f }
};

AudioMesh* lovrAudioMeshCreate(float* vertices, uint32_t* indices, uint32_t vertexCount, uint32_t indexCount, AudioMaterial* materials, AudioMaterial material) {
  AudioMesh* mesh = lovrCalloc(sizeof(AudioMesh));
  mesh->ref = 1;
  mesh->enabled = true;
  mat4_identity(mesh->transform);

#ifdef LOVR_USE_PHONON
  // Scene

  IPLSceneSettings sceneSettings = {
    .type = IPL_SCENETYPE_DEFAULT
  };

  if (iplSceneCreate(state.spatializer, &sceneSettings, &mesh->scene)) {
    lovrSetError("Failed to create AudioMesh scene");
    return NULL;
  }

  // StaticMesh

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
    iplSceneRelease(&mesh->scene);
    lovrSetError("Failed to create AudioMesh");
    return NULL;
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

  if (iplInstancedMeshCreate(state.scene, &instancedMeshSettings, &mesh->instancedMesh)) {
    lovrSetError("Failed to clone AudioMesh");
    lovrFree(mesh);
    return NULL;
  }

  iplInstancedMeshAdd(mesh->instancedMesh, state.scene);
  state.sceneDirty = true;
#endif

  return mesh;
}

AudioMesh* lovrAudioMeshClone(AudioMesh* parent) {
  AudioMesh* mesh = lovrCalloc(sizeof(AudioMesh));
  mesh->ref = 1;
  mesh->enabled = true;
  mat4_init(mesh->transform, parent->transform);

#ifdef LOVR_USE_PHONON
  IPLInstancedMeshSettings settings = {
    .subScene = parent->scene
  };

  mat4_transpose(mat4_init(&settings.transform.elements[0][0], mesh->transform));

  if (iplInstancedMeshCreate(state.scene, &settings, &mesh->instancedMesh)) {
    lovrSetError("Failed to clone AudioMesh");
    lovrFree(mesh);
    return NULL;
  }

  iplInstancedMeshAdd(mesh->instancedMesh, state.scene);
  state.sceneDirty = true;

  mesh->staticMesh = parent->staticMesh;
  mesh->scene = parent->scene;
#endif
  lovrRetain(parent);
  return mesh;
}

void lovrAudioMeshDestroy(void* ref) {
  AudioMesh* mesh = ref;
#ifdef LOVR_USE_PHONON
  if (mesh->enabled) {
    iplInstancedMeshRemove(mesh->instancedMesh, state.scene);
    state.sceneDirty = true;
  }
  iplInstancedMeshRelease(&mesh->instancedMesh);
  iplSceneRelease(&mesh->scene);
  iplStaticMeshRelease(&mesh->staticMesh);
#endif
  lovrRelease(mesh->parent, lovrAudioMeshDestroy);
  lovrFree(mesh);
}

bool lovrAudioMeshIsEnabled(AudioMesh* mesh) {
  return mesh->enabled;
}

void lovrAudioMeshSetEnabled(AudioMesh* mesh, bool enable) {
#ifdef LOVR_USE_PHONON
  if (enable != mesh->enabled) {
    if (enable) {
      iplInstancedMeshAdd(mesh->instancedMesh, state.scene);
    } else {
      iplInstancedMeshRemove(mesh->instancedMesh, state.scene);
    }
    state.sceneDirty = true;
  }
#endif
  mesh->enabled = enable;
}

void lovrAudioMeshGetTransform(AudioMesh* mesh, float* transform) {
  mat4_init(transform, mesh->transform);
}

void lovrAudioMeshSetTransform(AudioMesh* mesh, float* transform) {
#ifdef LOVR_USE_PHONON
  IPLMatrix4x4 iplTransform;
  mat4_transpose(mat4_init(&iplTransform.elements[0][0], mesh->transform));
  iplInstancedMeshUpdateTransform(mesh->instancedMesh, state.scene, iplTransform);
  state.sceneDirty = true;
#endif

  mat4_init(mesh->transform, transform);
}
