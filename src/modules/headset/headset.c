#include "headset/headset.h"
#include "util.h"
#include <stdatomic.h>

static uint32_t ref;

bool lovrHeadsetInit(HeadsetConfig* config) {
  if (atomic_fetch_add(&ref, 1)) return true;
  return true;
}

void lovrHeadsetDestroy(void) {
  if (atomic_fetch_sub(&ref, 1) != 1) return;
  ref = 0;
}

void lovrLayerDestroy(void* ref) {
  //
}
