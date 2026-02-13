#include "job.h"
#include <stdatomic.h>
#include <threads.h>
#include <string.h>

#define MAX_WORKERS 64
#define MAX_JOBS 4096
#define JOB_MASK (MAX_JOBS - 1)

typedef struct {
  fn_job* fn;
  void* arg;
} job;

static struct {
  atomic_uint head;
  atomic_uint tail;
  job jobs[MAX_JOBS];
  void (*setupWorker)(uint32_t id);
  thrd_t workers[MAX_WORKERS];
  uint32_t workerCount;
  cnd_t hasJob;
  mtx_t lock;
  bool quit;
} state;

// Must hold lock
static void runJob(void) {
  job job = state.jobs[state.head++ & JOB_MASK];
  mtx_unlock(&state.lock);
  job.fn(job.arg);
}

static int workerLoop(void* arg) {
  if (state.setupWorker) {
    state.setupWorker((uint32_t) (uintptr_t) arg);
  }

  for (;;) {
    mtx_lock(&state.lock);

    while (state.head == state.tail && !state.quit) {
      cnd_wait(&state.hasJob, &state.lock);
    }

    if (state.quit) {
      break;
    }

    runJob();
  }

  mtx_unlock(&state.lock);
  return 0;
}

bool job_init(uint32_t count, void (*setupWorker)(uint32_t id)) {
  mtx_init(&state.lock, mtx_plain);
  cnd_init(&state.hasJob);

  state.setupWorker = setupWorker;
  if (count > MAX_WORKERS) count = MAX_WORKERS;
  for (uint32_t i = 0; i < count; i++, state.workerCount++) {
    if (thrd_create(&state.workers[i], workerLoop, (void*) (uintptr_t) i) != thrd_success) {
      return false;
    }
  }

  return true;
}

void job_destroy(void) {
  state.quit = true;
  cnd_broadcast(&state.hasJob);
  for (uint32_t i = 0; i < state.workerCount; i++) {
    thrd_join(state.workers[i], NULL);
  }
  cnd_destroy(&state.hasJob);
  mtx_destroy(&state.lock);
  memset(&state, 0, sizeof(state));
}

bool job_start(fn_job* fn, void* arg) {
  mtx_lock(&state.lock);

  if (state.tail - state.head >= MAX_JOBS) {
    mtx_unlock(&state.lock);
    return false;
  }

  bool empty = state.head == state.tail;
  state.jobs[(state.tail++) & JOB_MASK] = (job) { fn, arg };
  if (empty) cnd_broadcast(&state.hasJob);
  mtx_unlock(&state.lock);
  return true;
}

void job_spin(void) {
  mtx_lock(&state.lock);

  if (state.head == state.tail) {
    mtx_unlock(&state.lock);
    thrd_yield();
  } else {
    runJob();
  }
}
