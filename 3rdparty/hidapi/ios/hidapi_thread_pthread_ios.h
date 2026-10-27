#pragma once

// Thread model for hidapi's libusb backend on iOS.
// iOS has no pthread_barrier, so provide a minimal one and then use hidapi's regular pthread thread model.

#include <errno.h>
#include <pthread.h>

typedef int pthread_barrierattr_t;

typedef struct pthread_barrier
{
	pthread_mutex_t mutex;
	pthread_cond_t cond;
	unsigned int count;
	unsigned int waiting;
	unsigned int generation;
} pthread_barrier_t;

static int pthread_barrier_init(pthread_barrier_t* barrier, const pthread_barrierattr_t* attr, unsigned int count)
{
	(void)attr;

	if (count == 0)
	{
		return EINVAL;
	}

	if (pthread_mutex_init(&barrier->mutex, NULL) != 0)
	{
		return -1;
	}

	if (pthread_cond_init(&barrier->cond, NULL) != 0)
	{
		pthread_mutex_destroy(&barrier->mutex);
		return -1;
	}

	barrier->count = count;
	barrier->waiting = 0;
	barrier->generation = 0;
	return 0;
}

static int pthread_barrier_destroy(pthread_barrier_t* barrier)
{
	pthread_cond_destroy(&barrier->cond);
	pthread_mutex_destroy(&barrier->mutex);
	return 0;
}

static int pthread_barrier_wait(pthread_barrier_t* barrier)
{
	pthread_mutex_lock(&barrier->mutex);

	const unsigned int generation = barrier->generation;

	if (++barrier->waiting == barrier->count)
	{
		// Last thread to arrive releases the others
		barrier->waiting = 0;
		barrier->generation++;
		pthread_cond_broadcast(&barrier->cond);
		pthread_mutex_unlock(&barrier->mutex);
		return 1;
	}

	while (generation == barrier->generation)
	{
		pthread_cond_wait(&barrier->cond, &barrier->mutex);
	}

	pthread_mutex_unlock(&barrier->mutex);
	return 0;
}

#include "hidapi_thread_pthread.h"
