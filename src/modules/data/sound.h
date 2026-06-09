#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>

#pragma once

#define MAX_CHANNELS 16

struct Blob;

typedef enum {
  SAMPLE_F32,
  SAMPLE_I16
} SampleFormat;

typedef enum {
  CHANNEL_MONO,
  CHANNEL_STEREO,
  CHANNEL_AMBISONIC
} ChannelLayout;

typedef struct Sound Sound;

Sound* lovrSoundCreate(uint32_t frames, SampleFormat format, uint32_t channels, uint32_t sampleRate);
Sound* lovrSoundLoad(struct Blob* blob, bool decode);
void lovrSoundDestroy(void* ref);
struct Blob* lovrSoundGetBlob(Sound* sound);
SampleFormat lovrSoundGetFormat(Sound* sound);
uint32_t lovrSoundGetChannelCount(Sound* sound);
uint32_t lovrSoundGetSampleRate(Sound* sound);
uint32_t lovrSoundGetFrameCount(Sound* sound);
size_t lovrSoundGetStride(Sound* sound);
bool lovrSoundIsCompressed(Sound* sound);
bool lovrSoundIsStream(Sound* sound);
uint32_t lovrSoundRead(Sound* sound, uint32_t offset, uint32_t count, void* data);
bool lovrSoundWrite(Sound* sound, uint32_t offset, uint32_t count, const void* data, uint32_t* framesWritten);
bool lovrSoundCopy(Sound* src, Sound* dst, uint32_t frames, uint32_t srcOffset, uint32_t dstOffset, uint32_t* framesCopied);

// AudioStream

typedef struct AudioStream AudioStream;

AudioStream* lovrAudioStreamCreate(uint32_t frames, SampleFormat format, uint32_t channels, uint32_t sampleRate);
void lovrAudioStreamDestroy(void* ref);
Sound* lovrAudioStreamGetSound(AudioStream* stream);
uint32_t lovrAudioStreamRead(AudioStream* stream, uint32_t frameCount, void* data);
uint32_t lovrAudioStreamWrite(AudioStream* stream, uint32_t frameCount, const void* data);
uint32_t lovrAudioStreamGetReadCapacity(AudioStream* stream);
uint32_t lovrAudioStreamGetWriteCapacity(AudioStream* stream);
