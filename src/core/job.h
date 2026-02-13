#include <stdint.h>
#include <stdbool.h>

#pragma once

typedef void fn_job(void* arg);

bool job_init(uint32_t workerCount, void (*setupWorker)(uint32_t index));
void job_destroy(void);
bool job_start(fn_job* fn, void* arg);
void job_spin(void);
