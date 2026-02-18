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
  float pitch;
  float volume;
  float reverb;
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
  float reverb;
#ifdef LOVR_USE_PHONON
  IPLContext phonon;
  IPLAudioSettings audioSettings;
  IPLReflectionEffectSettings reflectionSettings;
  IPLSimulationFlags simulationFlags;
  IPLSimulator simulator;
  IPLScene scene;
  bool sceneDirty;
  IPLHRTF hrtf;
  IPLSource listener;
  bool listenerAdded;
  IPLCoordinateSpace3 listenerBasis[2];
  IPLReflectionEffect reflectionEffect;
  IPLReflectionMixer reflectionMixer;
  IPLAudioBuffer reflectionBuffer;
  IPLAudioBuffer listenerReverbInput;
  IPLAmbisonicsDecodeEffect ambisonicsDecodeEffect;
  atomic_bool reverbFinished;
  float reverbTimer;
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

static bool phonon_init(void);
static void phonon_destroy(void);
static void phonon_update(float dt);
static bool phonon_set_hrtf(Blob* blob);
static void phonon_mix_begin(void);
static bool phonon_mix_source(Source* source, float* src, float* dst, float* tmp);
static void phonon_mix_tail(float* output, float* temp);
static bool phonon_source_init(Source* source);
static void phonon_source_destroy(Source* source);
static void phonon_source_add(Source* source);
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
  float tmp[BUFFER_SIZE * 2];
  float mix[BUFFER_SIZE * 2];
  float* dst = out;
  float* buf = NULL; // The "current" buffer

  phonon_mix_begin();

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
      // - No converter: just read frames into raw
      // - Converter: keep reading as many frames as possible/needed into raw and convert into tmp.
      // - If EOF is reached, rewind and continue for looping sources, otherwise pad end with zero.
      float* cursor = source->converter ? tmp : raw; // Edge of processed frames
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

      buf = source->converter ? tmp : raw;
    }

    bool tail = false;

    if (source->spatial) {
      tail = phonon_mix_source(source, buf, mix, buf == raw ? tmp : raw);
      buf = mix;
    }

    // Mix
    float volume = source->volume;
    for (uint32_t i = 0; i < 2 * BUFFER_SIZE; i++) {
      dst[i] += buf[i] * volume;
    }

    // Once we set this to false, the source could get destroyed (if it's not playing)
    source->hasTail = tail;
  }

  phonon_mix_tail(dst, tmp);

  if (state.sinks[AUDIO_PLAYBACK]) {
    uint64_t capacity = sizeof(tmp) / lovrSoundGetChannelCount(state.sinks[AUDIO_PLAYBACK]) / sizeof(float);
    while (count > 0) {
      ma_uint64 framesConsumed = count;
      ma_uint64 framesWritten = capacity;
      ma_data_converter_process_pcm_frames(&state.playbackConverter, dst, &framesConsumed, tmp, &framesWritten);
      lovrSoundWrite(state.sinks[AUDIO_PLAYBACK], 0, framesWritten, tmp, NULL);
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

  if (!phonon_init()) {
    lovrAudioDestroy();
    return false;
  }

  // SteamAudio's default frequency-dependent absorption coefficients for air
  state.absorption[0] = .0002f;
  state.absorption[1] = .0017f;
  state.absorption[2] = .0182f;

  state.reverb = 1.f;

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
  phonon_destroy();
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

void lovrAudioUpdate(float dt) {
  Source* source;
  FOREACH_SOURCE(state.activeSourceMask | state.pendingSourceMask, source) {
    if (!source->playing && source->playRequest != 1 && !source->hasTail) {
      phonon_source_remove(source);
      state.activeSources[source->slot] = NULL;
      state.activeSourceMask &= ~(1ull << source->slot);
      state.pendingSourceMask &= ~(1ull << source->slot);
      source->slot = ~0u;
      lovrRelease(source, lovrSourceDestroy);
    }
  }

  phonon_update(dt);

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
  return phonon_set_hrtf(blob);
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

float lovrAudioGetReverb(void) {
  return state.reverb;
}

void lovrAudioSetReverb(float reverb) {
  state.reverb = reverb;
}

// Source

Source* lovrSourceCreate(Sound* sound, bool pitchable, bool spatial, uint32_t effects) {
  lovrCheck(lovrSoundGetChannelLayout(sound) != CHANNEL_AMBISONIC, "Ambisonic Sources are not currently supported");

  Source* source = lovrCalloc(sizeof(Source));
  source->ref = 1;
  source->slot = ~0u;
  source->volume = 1.f;
  source->pitch = 1.f;
  source->reverb = 0.f;
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

  if (!phonon_source_init(source)) {
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

  if (!phonon_source_init(clone)) {
    lovrSourceDestroy(clone);
    return false;
  }

  clone->sound = source->sound;
  lovrRetain(clone->sound);
  return clone;
}

void lovrSourceDestroy(void* ref) {
  Source* source = ref;
  phonon_source_destroy(source);
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
    phonon_source_add(source);
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

float lovrSourceGetReverb(Source* source) {
  return source->reverb;
}

void lovrSourceSetReverb(Source* source, float reverb) {
  source->reverb = reverb;
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

static void convertPose(float* position, float* orientation, IPLCoordinateSpace3* basis) {
  float transform[16];
  mat4_fromQuat(transform, orientation);
  vec3_init(&basis->right.x, &transform[0]);
  vec3_init(&basis->up.x, &transform[4]);
  vec3_scale(vec3_init(&basis->ahead.x, &transform[8]), -1.f);
  vec3_init(&basis->origin.x, position);
}

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

static void simulateReflections(void* arg) {
  iplSimulatorRunReflections(state.simulator);
  atomic_store(&state.reverbFinished, true);
}

static bool phonon_init(void) {
  IPLContextSettings contextSettings = {
    .version = STEAMAUDIO_VERSION,
    .logCallback = onSpatializerLog,
    .simdLevel = IPL_SIMDLEVEL_AVX512
  };

  if (iplContextCreate(&contextSettings, &state.phonon)) {
    return lovrSetError("Failed to create SteamAudio context");
  }

  state.audioSettings.samplingRate = state.config.sampleRate;
  state.audioSettings.frameSize = BUFFER_SIZE;

  switch (state.config.reverb.mode) {
    case REVERB_CONVOLUTION: default: state.reflectionSettings.type = IPL_REFLECTIONEFFECTTYPE_CONVOLUTION; break;
    case REVERB_PARAMETRIC: state.reflectionSettings.type = IPL_REFLECTIONEFFECTTYPE_PARAMETRIC; break;
  }

  state.reflectionSettings.irSize = state.config.reverb.duration * state.config.sampleRate;
  state.reflectionSettings.numChannels = state.config.reverb.mode == REVERB_CONVOLUTION ? 4 : 1;

  state.simulationFlags = IPL_SIMULATIONFLAGS_DIRECT | IPL_SIMULATIONFLAGS_REFLECTIONS;

  IPLSimulationSettings simulationSettings = {
    .flags = state.simulationFlags,
    .sceneType = IPL_SCENETYPE_DEFAULT,
    .reflectionType = state.reflectionSettings.type,
    .maxNumOcclusionSamples = MAX_OCCLUSION_SAMPLES,
    .maxNumRays = state.config.reverb.rays,
    .numDiffuseSamples = 1024,
    .maxDuration = state.config.reverb.duration,
    .maxOrder = 1,
    .maxNumSources = MAX_SOURCES,
    .numThreads = 8,
    .samplingRate = state.audioSettings.samplingRate,
    .frameSize = state.audioSettings.frameSize
  };

  if (iplSimulatorCreate(state.phonon, &simulationSettings, &state.simulator)) {
    return phonon_destroy(), lovrSetError("Failed to create SteamAudio simulator");
  }

  IPLSceneSettings sceneSettings = { .type = IPL_SCENETYPE_DEFAULT };
  if (iplSceneCreate(state.phonon, &sceneSettings, &state.scene)) {
    return phonon_destroy(), lovrSetError("Failed to create SteamAudio scene");
  }

  iplSimulatorSetScene(state.simulator, state.scene);

  IPLSourceSettings sourceSettings = {
    .flags = IPL_SIMULATIONFLAGS_REFLECTIONS
  };

  if (iplSourceCreate(state.simulator, &sourceSettings, &state.listener)) {
    return phonon_destroy(), lovrSetError("Failed to create listener source");
  }

  if (iplReflectionEffectCreate(state.phonon, &state.audioSettings, &state.reflectionSettings, &state.reflectionEffect)) {
    return phonon_destroy(), lovrSetError("Failed to create reflection effect");
  }

  if (state.config.reverb.mode == REVERB_CONVOLUTION) {
    if (iplReflectionMixerCreate(state.phonon, &state.audioSettings, &state.reflectionSettings, &state.reflectionMixer)) {
      return phonon_destroy(), lovrSetError("Failed to create reverb mixer");
    }

    IPLAmbisonicsDecodeEffectSettings settings = {
      .speakerLayout.type = IPL_SPEAKERLAYOUTTYPE_STEREO,
      .hrtf = NULL,
      .maxOrder = 1
    };

    if (iplAmbisonicsDecodeEffectCreate(state.phonon, &state.audioSettings, &settings, &state.ambisonicsDecodeEffect)) {
      return phonon_destroy(), lovrSetError("Failed to create ambisonics decode effect");
    }
  }

  if (iplAudioBufferAllocate(state.phonon, state.reflectionSettings.numChannels, BUFFER_SIZE, &state.reflectionBuffer)) {
    return phonon_destroy(), lovrSetError("Failed to create reverb buffer");
  }

  if (iplAudioBufferAllocate(state.phonon, 1, BUFFER_SIZE, &state.listenerReverbInput)) {
    return phonon_destroy(), lovrSetError("Failed to create reverb buffer");
  }

  atomic_store(&state.reverbFinished, true);

  return true;
}

static void phonon_destroy(void) {
  while (!atomic_load(&state.reverbFinished)) {
    job_spin();
  }

  iplAmbisonicsDecodeEffectRelease(&state.ambisonicsDecodeEffect), state.ambisonicsDecodeEffect = NULL;
  iplAudioBufferFree(state.phonon, &state.listenerReverbInput), state.listenerReverbInput.data = NULL;
  iplAudioBufferFree(state.phonon, &state.reflectionBuffer), state.reflectionBuffer.data = NULL;
  iplReflectionMixerRelease(&state.reflectionMixer), state.reflectionMixer = NULL;
  iplReflectionEffectRelease(&state.reflectionEffect), state.reflectionEffect = NULL;
  iplSourceRelease(&state.listener), state.listener = NULL;
  iplHRTFRelease(&state.hrtf), state.hrtf = NULL;
  iplSceneRelease(&state.scene), state.scene = NULL;
  iplSimulatorRelease(&state.simulator), state.simulator = NULL;
  iplContextRelease(&state.phonon), state.phonon = NULL;
}

static void phonon_update(float dt) {
  if (state.sceneDirty) {
    iplSceneCommit(state.scene);
    state.sceneDirty = false;
  }

  // TODO maybe split into 2 simulators so we can have less latency on direct simulation commits
  if (atomic_load(&state.reverbFinished)) {
    if (!state.listenerAdded && state.reverb > 0.f) {
      iplSourceAdd(state.listener, state.simulator);
      state.listenerAdded = true;
    } else if (state.listenerAdded && state.reverb <= 0.f) {
      iplSourceRemove(state.listener, state.simulator);
      state.listenerAdded = false;
    }

    iplSimulatorCommit(state.simulator);
  }

  uint32_t backbuffer = state.backbuffer;
  bool hasReverb = false;

  IPLSimulationSharedInputs sharedInputs;
  convertPose(state.position, state.orientation, &sharedInputs.listener);
  sharedInputs.numRays = state.config.reverb.rays;
  sharedInputs.numBounces = state.config.reverb.bounces;
  sharedInputs.duration = state.config.reverb.duration;
  sharedInputs.order = 1;
  sharedInputs.irradianceMinDistance = .01f;

  iplSimulatorSetSharedInputs(state.simulator, IPL_SIMULATIONFLAGS_DIRECT, &sharedInputs);

  state.listenerBasis[backbuffer] = sharedInputs.listener;

  uint64_t mask = state.activeSourceMask | state.pendingSourceMask;
  Source* source;

  FOREACH_SOURCE(mask, source) {
    convertPose(source->position, source->orientation, &source->inputs.source);
    vec3_sub(vec3_init(&source->relativeDirection[backbuffer].x, source->position), state.position);

    static const IPLDirectSimulationFlags effects[] = {
      [EFFECT_ABSORPTION] = IPL_DIRECTSIMULATIONFLAGS_AIRABSORPTION,
      [EFFECT_ATTENUATION] = IPL_DIRECTSIMULATIONFLAGS_DISTANCEATTENUATION,
      [EFFECT_OCCLUSION] = IPL_DIRECTSIMULATIONFLAGS_OCCLUSION,
      [EFFECT_SPATIALIZATION] = 0,
      [EFFECT_TRANSMISSION] = IPL_DIRECTSIMULATIONFLAGS_TRANSMISSION
    };

    source->inputs.directFlags = 0;

    for (uint32_t i = 0; i < COUNTOF(effects); i++) {
      if (source->effects & (1 << i)) {
        source->inputs.directFlags |= effects[i];
      }
    }

    hasReverb |= source->reverb > 0.f;

    source->inputs.directivity.dipoleWeight = source->dipoleWeight;
    source->inputs.directivity.dipolePower = source->dipolePower;
    source->inputs.occlusionRadius = source->radius;
    source->inputs.occlusionType = source->radius > 0.f ? IPL_OCCLUSIONTYPE_VOLUMETRIC : IPL_OCCLUSIONTYPE_RAYCAST;
    memcpy(source->inputs.airAbsorptionModel.coefficients, state.absorption, 3 * sizeof(float));

    iplSourceSetInputs(source->handle, IPL_SIMULATIONFLAGS_DIRECT, &source->inputs);
  }

  iplSimulatorRunDirect(state.simulator);

  FOREACH_SOURCE(mask, source) {
    iplSourceGetOutputs(source->handle, IPL_SIMULATIONFLAGS_DIRECT, &source->outputs[backbuffer]);
    source->outputs[backbuffer].direct.flags = source->inputs.directFlags;
  }

  atomic_fetch_xor(&state.backbuffer, 0x1);

  if (hasReverb || state.reverb > 0.f) {
    state.reverbTimer -= dt;

    if (state.reverbTimer <= 0.f && atomic_load(&state.reverbFinished)) {
      atomic_store(&state.reverbFinished, false);
      state.reverbTimer = state.config.reverb.rate;

      if (state.reverb > 0.f) {
        IPLSimulationInputs inputs = { 0 };
        inputs.flags = IPL_SIMULATIONFLAGS_REFLECTIONS;
        inputs.source = sharedInputs.listener;
        inputs.reverbScale[0] = 1.f;
        inputs.reverbScale[1] = 1.f;
        inputs.reverbScale[2] = 1.f;
        iplSourceSetInputs(state.listener, IPL_SIMULATIONFLAGS_REFLECTIONS, &inputs);
      }

      Source* source;
      FOREACH_SOURCE(mask, source) {
        iplSourceSetInputs(source->handle, IPL_SIMULATIONFLAGS_REFLECTIONS, &source->inputs);
      }

      iplSimulatorSetSharedInputs(state.simulator, IPL_SIMULATIONFLAGS_REFLECTIONS, &sharedInputs);

      while (!job_start(simulateReflections, NULL)) {
        job_spin();
      }
    }
  }
}

static bool phonon_set_hrtf(Blob* blob) {
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

    if (iplHRTFCreate(state.phonon, &state.audioSettings, &settings, &state.hrtf)) {
      return lovrSetError("Failed to create HRTF");
    }

    // TODO recreate AmbisonicsDecodeEffect (may need to double buffer this, and/or maybe the hrtf)
  }

  return true;
}

static void phonon_mix_begin(void) {
  if (state.config.reverb.mode == REVERB_PARAMETRIC) {
    memset(state.reflectionBuffer.data[0], 0, BUFFER_SIZE * sizeof(float));
  }

  if (state.reverb > 0.f) {
    memset(state.listenerReverbInput.data[0], 0, BUFFER_SIZE * sizeof(float));
  }
}

static bool phonon_mix_source(Source* source, float* _src, float* dst, float* _tmp) {
  IPLAudioBuffer src = { .numChannels = 1, .numSamples = BUFFER_SIZE, .data = &_src };
  IPLAudioBuffer tmp1 = { .numChannels = 1, .numSamples = BUFFER_SIZE, .data = &_tmp };
  IPLAudioBuffer tmp2 = { .numChannels = 2, .numSamples = BUFFER_SIZE, .data = (float*[2]) { _tmp, _tmp + BUFFER_SIZE } };

  uint32_t index = !state.backbuffer;
  bool tail = false;

  if (!source->playing) {
    if ((source->effects & (1 << EFFECT_SPATIALIZATION)) && source->hrtf) {
      tail |= !iplBinauralEffectGetTail(source->binauralEffect, &tmp2);
      iplAudioBufferInterleave(state.phonon, &tmp2, dst);
    } else {
      memset(dst, 0, 2 * BUFFER_SIZE * sizeof(float));
    }

    if (source->reverb > 0.f && iplReflectionEffectGetTailSize(source->reflectionEffect) > 0) {
      if (state.config.reverb.mode == REVERB_CONVOLUTION) {
        tail |= !iplReflectionEffectGetTail(source->reflectionEffect, &tmp1, state.reflectionMixer);
      } else {
        tail |= !iplReflectionEffectGetTail(source->reflectionEffect, &tmp1, NULL);
        iplAudioBufferMix(state.phonon, &tmp1, &state.reflectionBuffer);
      }
    }

    return tail;
  }

  // Feed raw audio to reflection effect (use reflection mixer for convolution, or mix mono reverb
  // into reflectionBuffer for parametric)
  if (source->reverb > 0.f) {
    IPLSimulationOutputs outputs = { 0 };
    iplSourceGetOutputs(source->handle, IPL_SIMULATIONFLAGS_REFLECTIONS, &outputs);

    if (state.config.reverb.mode == REVERB_CONVOLUTION) {
      tail |= !iplReflectionEffectApply(source->reflectionEffect, &outputs.reflections, &src, &tmp1, state.reflectionMixer);
    } else {
      tail |= !iplReflectionEffectApply(source->reflectionEffect, &outputs.reflections, &src, &tmp1, NULL);
      iplAudioBufferMix(state.phonon, &tmp1, &state.reflectionBuffer);
    }
  }

  // Direct effects, applied in-place
  if (source->effects & ((1 << EFFECT_ABSORPTION) | (1 << EFFECT_ATTENUATION) | (1 << EFFECT_OCCLUSION) | (1 << EFFECT_TRANSMISSION))) {
    IPLDirectEffectParams* params = &source->outputs[index].direct;
    tail |= !iplDirectEffectApply(source->directEffect, params, &src, &src);
  }

  // Accumulate post-direct-effect mono audio for listener-centric reverb
  if (state.reverb > 0.f && source->reverb <= 0.f) {
    for (uint32_t i = 0; i < BUFFER_SIZE; i++) {
      state.listenerReverbInput.data[0][i] += _src[i];
    }
  }

  // Spatialize to stereo (either binaural, panning, or upmix)
  if (source->effects & (1 << EFFECT_SPATIALIZATION)) {
    if (source->hrtf) {
      IPLBinauralEffectParams params = {
        .direction = source->relativeDirection[index],
        .interpolation = IPL_HRTFINTERPOLATION_BILINEAR,
        .spatialBlend = 1.f,
        .hrtf = source->hrtf
      };

      tail |= !iplBinauralEffectApply(source->binauralEffect, &params, &src, &tmp2);
    } else {
      IPLPanningEffectParams params = {
        .direction = source->relativeDirection[index]
      };

      iplPanningEffectApply(source->panningEffect, &params, &src, &tmp2);
    }

    iplAudioBufferInterleave(state.phonon, &tmp2, dst);
  } else {
    for (uint32_t i = 0; i < BUFFER_SIZE; i++) {
      dst[2 * i + 0] = _src[i];
      dst[2 * i + 1] = _src[i];
    }
  }

  return tail;
}

static void phonon_mix_tail(float* dst, float* _tmp) {
  IPLAudioBuffer tmp1 = { .numChannels = 1, .numSamples = BUFFER_SIZE, .data = &_tmp };
  IPLAudioBuffer tmp2 = { .numChannels = 2, .numSamples = BUFFER_SIZE, .data = (float*[2]) { _tmp, _tmp + BUFFER_SIZE } };

  Source* source;
  bool hasReverb = false;
  FOREACH_SOURCE(state.activeSourceMask, source) {
    if (source->reverb > 0.f || iplReflectionEffectGetTailSize(source->reflectionEffect) > 0) {
      hasReverb = true;
      break;
    }
  }

  // Listener-centric reverb
  if (state.reverb > 0.f) {
    IPLSimulationOutputs outputs = { 0 };
    iplSourceGetOutputs(state.listener, IPL_SIMULATIONFLAGS_REFLECTIONS, &outputs);

    if (state.config.reverb.mode == REVERB_CONVOLUTION) {
      iplReflectionEffectApply(state.reflectionEffect, &outputs.reflections, &state.listenerReverbInput, &tmp1, state.reflectionMixer);
    } else {
      iplReflectionEffectApply(state.reflectionEffect, &outputs.reflections, &state.listenerReverbInput, &tmp1, NULL);
      iplAudioBufferMix(state.phonon, &tmp1, &state.reflectionBuffer);
    }

    hasReverb = true;
  } else if (iplReflectionEffectGetTailSize(state.reflectionEffect) > 0) {
    if (state.config.reverb.mode == REVERB_CONVOLUTION) {
      iplReflectionEffectGetTail(state.reflectionEffect, &tmp1, state.reflectionMixer);
    } else {
      iplReflectionEffectGetTail(state.reflectionEffect, &tmp1, NULL);
      iplAudioBufferMix(state.phonon, &tmp1, &state.reflectionBuffer);
    }

    hasReverb = true;
  }

  // Final reverb mix
  if (state.config.reverb.mode == REVERB_CONVOLUTION) {
    if (hasReverb) {
      IPLReflectionEffectParams reflectionMixerParams = {
        .numChannels = 4
      };

      iplReflectionMixerApply(state.reflectionMixer, &reflectionMixerParams, &state.reflectionBuffer);

      IPLAmbisonicsDecodeEffectParams ambisonicsDecodeParams = {
        .order = 1,
        .hrtf = state.hrtf,
        .orientation = state.listenerBasis[!state.backbuffer],
        .binaural = !!state.hrtf
      };

      iplAmbisonicsDecodeEffectApply(state.ambisonicsDecodeEffect, &ambisonicsDecodeParams, &state.reflectionBuffer, &tmp2);
    } else if (iplAmbisonicsDecodeEffectGetTailSize(state.ambisonicsDecodeEffect) > 0) {
      iplAmbisonicsDecodeEffectGetTail(state.ambisonicsDecodeEffect, &tmp2);
    }

    // Interleave and mix
    for (uint32_t i = 0; i < BUFFER_SIZE; i++) {
      dst[2 * i + 0] += tmp2.data[0][i];
      dst[2 * i + 1] += tmp2.data[1][i];
    }
  } else if (hasReverb) {
    // Parametric reverb: just upmix mono reflection buffer to stereo and mix into dst
    for (uint32_t i = 0; i < BUFFER_SIZE; i++) {
      dst[2 * i + 0] += state.reflectionBuffer.data[0][i];
      dst[2 * i + 1] += state.reflectionBuffer.data[0][i];
    }
  }
}

static bool phonon_source_init(Source* source) {
  IPLSourceSettings settings = {
    .flags = IPL_SIMULATIONFLAGS_DIRECT | IPL_SIMULATIONFLAGS_REFLECTIONS
  };

  if (iplSourceCreate(state.simulator, &settings, &source->handle)) {
    return lovrSetError("Failed to add source to spatializer");
  }

  source->inputs.flags = state.simulationFlags;
  source->inputs.distanceAttenuationModel.type = IPL_DISTANCEATTENUATIONTYPE_DEFAULT;
  source->inputs.distanceAttenuationModel.minDistance = 1.f;
  source->inputs.airAbsorptionModel.type = IPL_AIRABSORPTIONTYPE_DEFAULT;
  source->inputs.numOcclusionSamples = MAX_OCCLUSION_SAMPLES;
  source->inputs.numTransmissionRays = 2;
  vec3_set(source->inputs.reverbScale, 1.f, 1.f, 1.f);

  IPLDirectEffectSettings directEffectSettings = {
    .numChannels = 1
  };

  if (iplDirectEffectCreate(state.phonon, &state.audioSettings, &directEffectSettings, &source->directEffect)) {
    lovrSetError("Failed to create direct effect");
    phonon_source_destroy(source);
    return false;
  }

  IPLPanningEffectSettings panningEffectSettings = {
    .speakerLayout.type = IPL_SPEAKERLAYOUTTYPE_STEREO
  };

  if (iplPanningEffectCreate(state.phonon, &state.audioSettings, &panningEffectSettings, &source->panningEffect)) {
    lovrSetError("Failed to create panning effect");
    phonon_source_destroy(source);
    return false;
  }

  if (iplReflectionEffectCreate(state.phonon, &state.audioSettings, &state.reflectionSettings, &source->reflectionEffect)) {
    lovrSetError("Failed to create reflection effect");
    phonon_source_destroy(source);
    return false;
  }

  return true;
}

static void phonon_source_destroy(Source* source) {
  iplHRTFRelease(&source->hrtf), source->hrtf = NULL;
  iplReflectionEffectRelease(&source->reflectionEffect), source->reflectionEffect = NULL;
  iplBinauralEffectRelease(&source->binauralEffect), source->binauralEffect = NULL;
  iplPanningEffectRelease(&source->panningEffect), source->panningEffect = NULL;
  iplDirectEffectRelease(&source->directEffect), source->directEffect = NULL;
  iplSourceRelease(&source->handle), source->handle = NULL;
}

static void phonon_source_add(Source* source) {
  iplSourceAdd(source->handle, state.simulator);

  if (source->hrtf) lovrUnreachable();
  source->hrtf = state.hrtf;
  iplHRTFRetain(source->hrtf);

  if (source->hrtf && !source->binauralEffect) {
    IPLBinauralEffectSettings settings = { .hrtf = source->hrtf };
    iplBinauralEffectCreate(state.phonon, &state.audioSettings, &settings, &source->binauralEffect);
  }
}

static void phonon_source_remove(Source* source) {
  iplSourceRemove(source->handle, state.simulator);
  iplHRTFRelease(&source->hrtf);
  source->hrtf = NULL;
}

static IPLMaterial materialData[] = {
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

static bool phonon_mesh_init(AudioMesh* mesh, float* vertices, uint32_t* indices, uint32_t vertexCount, uint32_t indexCount, AudioMaterial* materials, AudioMaterial material) {
  lovrCheck(indexCount % 3 == 0, "AudioMesh index count must be a multiple of 3");

  // Scene

  IPLSceneSettings sceneSettings = {
    .type = IPL_SCENETYPE_DEFAULT
  };

  if (iplSceneCreate(state.phonon, &sceneSettings, &mesh->scene)) {
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

  if (iplInstancedMeshCreate(state.scene, &instancedMeshSettings, &mesh->instancedMesh)) {
    lovrSetError("Failed to add AudioMesh to scene");
    iplStaticMeshRelease(&mesh->staticMesh);
    iplSceneRelease(&mesh->scene);
    return false;
  }

  iplInstancedMeshAdd(mesh->instancedMesh, state.scene);
  state.sceneDirty = true;

  return true;
}

static bool phonon_mesh_init_clone(AudioMesh* mesh) {
  IPLInstancedMeshSettings settings = {
    .subScene = mesh->parent->scene
  };

  mat4_transpose(mat4_init(&settings.transform.elements[0][0], mesh->transform));

  if (iplInstancedMeshCreate(state.scene, &settings, &mesh->instancedMesh)) {
    lovrSetError("Failed to create instanced audio mesh");
    return false;
  }

  iplInstancedMeshAdd(mesh->instancedMesh, state.scene);
  state.sceneDirty = true;

  mesh->staticMesh = mesh->parent->staticMesh;
  mesh->scene = mesh->parent->scene;
  return true;
}

static void phonon_mesh_destroy(AudioMesh* mesh) {
  if (mesh->enabled) {
    iplInstancedMeshRemove(mesh->instancedMesh, state.scene);
    state.sceneDirty = true;
  }
  iplInstancedMeshRelease(&mesh->instancedMesh);
  iplStaticMeshRelease(&mesh->staticMesh);
  iplSceneRelease(&mesh->scene);
}

static void phonon_mesh_set_enabled(AudioMesh* mesh, bool enable) {
  if (mesh->enabled != enable) {
    if (enable) {
      iplInstancedMeshAdd(mesh->instancedMesh, state.scene);
    } else {
      iplInstancedMeshRemove(mesh->instancedMesh, state.scene);
    }
    state.sceneDirty = true;
  }
}

static void phonon_mesh_set_transform(AudioMesh* mesh, float* transform) {
  IPLMatrix4x4 matrix;
  mat4_transpose(mat4_init(&matrix.elements[0][0], transform));
  iplInstancedMeshUpdateTransform(mesh->instancedMesh, state.scene, matrix);
  state.sceneDirty = true;
}

#else
static bool phonon_init(void) { return true; }
static void phonon_destroy(void) {}
static void phonon_update(float dt) {}
static bool phonon_set_hrtf(Blob* blob) { return true; }
static void phonon_mix_begin(void) {}
static bool phonon_mix_source(Source* source, float* src, float* dst, float* tmp) {}
static void phonon_mix_tail(float* output, float* temp) {}
static bool phonon_source_init(Source* source) { return true; }
static void phonon_source_destroy(Source* source) {}
static void phonon_source_add(Source* source) {}
static void phonon_source_remove(Source* source) {}
static bool phonon_mesh_init(AudioMesh* mesh, float* vertices, uint32_t* indices, uint32_t vertexCount, uint32_t indexCount, AudioMaterial* materials, AudioMaterial material) { return true; }
static bool phonon_mesh_init_clone(AudioMesh* clone) { return true; }
static void phonon_mesh_destroy(AudioMesh* mesh) {}
static void phonon_mesh_set_enabled(AudioMesh* mesh, bool enable) {}
static void phonon_mesh_set_transform(AudioMesh* mesh, float* transform) {}
#endif
