// On Apple platforms libusbi.h declares these instead of inlining them, because libusb's macOS backend
// implements them. iOS builds the null backend instead, so provide them here.

#include <time.h>

void usbi_get_monotonic_time(struct timespec* tp)
{
	clock_gettime(CLOCK_MONOTONIC, tp);
}

void usbi_get_real_time(struct timespec* tp)
{
	clock_gettime(CLOCK_REALTIME, tp);
}
