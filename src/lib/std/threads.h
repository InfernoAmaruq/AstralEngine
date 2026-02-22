#ifdef __STDC_NO_THREADS__

#include <time.h>

#pragma once

typedef int (*thrd_start_t)(void*);

enum { thrd_success, thrd_nomem, thrd_timedout, thrd_busy, thrd_error };
enum { mtx_plain };

#include <pthread.h>
typedef pthread_t thrd_t;
typedef pthread_mutex_t mtx_t;
typedef pthread_cond_t cnd_t;
#define thread_local _Thread_local

static inline int thrd_create(thrd_t* thread, thrd_start_t fn, void* arg);
static inline int thrd_detach(thrd_t thread);
static inline int thrd_join(thrd_t thread, int* result);
static inline void thrd_yield(void);

static inline int mtx_init(mtx_t* mutex, int type);
static inline void mtx_destroy(mtx_t* mutex);
static inline int mtx_lock(mtx_t* mutex);
static inline int mtx_unlock(mtx_t* mutex);

static inline int cnd_init(cnd_t* cond);
static inline void cnd_destroy(cnd_t* cond);
static inline int cnd_signal(cnd_t* cond);
static inline int cnd_broadcast(cnd_t* cond);
static inline int cnd_wait(cnd_t* cond, mtx_t* mutex);
static inline int cnd_timedwait(cnd_t* restrict cond, mtx_t* restrict mutex, const struct timespec* restrict until);

// Implementation

typedef struct {
  thrd_start_t fn;
  void* arg;
} thread_context;

#include <stdint.h>
#include <stdlib.h>
#include <errno.h>
#include <sched.h>

static inline void* thread_main(void* arg) {
  thread_context ctx = *(thread_context*) arg;
  return free(arg), (void*) (intptr_t) ctx.fn(ctx.arg);
}

static inline int thrd_create(thrd_t* thread, thrd_start_t fn, void* arg) {
  thread_context* ctx = malloc(sizeof(*ctx));
  if (!ctx) return thrd_nomem;

  ctx->fn = fn;
  ctx->arg = arg;

  if (pthread_create(thread, NULL, thread_main, ctx)) {
    free(ctx);
    return thrd_error;
  }

  return thrd_success;
}

static inline int thrd_detach(thrd_t thread) {
  return pthread_detach(thread) == 0 ? thrd_success : thrd_error;
}

static inline int thrd_join(thrd_t thread, int* result) {
  void* p;
  if (pthread_join(thread, &p)) return thrd_error;
  if (result) *result = (int) (intptr_t) p;
  return thrd_success;
}

static inline void thrd_yield(void) {
  sched_yield();
}

static inline int mtx_init(mtx_t* mutex, int type) {
  return pthread_mutex_init(mutex, NULL) == 0 ? thrd_success : thrd_error;
}

static inline void mtx_destroy(mtx_t* mutex) {
  pthread_mutex_destroy(mutex);
}

static inline int mtx_lock(mtx_t* mutex) {
  return pthread_mutex_lock(mutex) == 0 ? thrd_success : thrd_error;
}

static inline int mtx_unlock(mtx_t* mutex) {
  return pthread_mutex_unlock(mutex) == 0 ? thrd_success : thrd_error;
}

static inline int cnd_init(cnd_t* cond) {
  return pthread_cond_init(cond, NULL) == 0 ? thrd_success : thrd_error;
}

static inline void cnd_destroy(cnd_t* cond) {
  pthread_cond_destroy(cond);
}

static inline int cnd_signal(cnd_t* cond) {
  return pthread_cond_signal(cond) == 0 ? thrd_success : thrd_error;
}

static inline int cnd_broadcast(cnd_t* cond) {
  return pthread_cond_broadcast(cond) == 0 ? thrd_success : thrd_error;
}

static inline int cnd_wait(cnd_t* cond, mtx_t* mutex) {
  return pthread_cond_wait(cond, mutex) == 0 ? thrd_success : thrd_error;
}

static inline int cnd_timedwait(cnd_t* restrict cond, mtx_t* restrict mutex, const struct timespec* restrict until) {
  switch (pthread_cond_timedwait(cond, mutex, until)) {
    case ETIMEDOUT: return thrd_timedout;
    case 0: return thrd_success;
    default: return thrd_error;
  }
}
#else
#include <threads.h>
#endif
