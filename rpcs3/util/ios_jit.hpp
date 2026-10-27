#pragma once // No BOM and only basic ASCII in this header

#include <TargetConditionals.h>

#if TARGET_OS_IPHONE
#include <pthread.h>

// iOS apps can't toggle MAP_JIT write protection: pthread_jit_write_protect_np() is unavailable there.
// RPCS3 calls it with bool arguments on every Apple platform, so this overload is picked over the
// unavailable int version. It does nothing for now: it marks where the iOS JIT memory strategy
// (JIT enabled through a debugger such as StikDebug) has to plug in.
inline void pthread_jit_write_protect_np(bool) noexcept
{
}
#endif
