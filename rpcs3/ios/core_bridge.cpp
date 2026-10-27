#include "stdafx.h"
#include "core_bridge.h"
#include "Emu/System.h"
#include "rpcs3_version.h"

std::string rpcs3_ios_core_status()
{
	// Reading Emu's state makes the linker pull in the emulator core, not just the version string
	const char* state = Emu.IsRunning() ? "running" : Emu.IsPaused() ? "paused" : Emu.IsReady() ? "ready" : "stopped";

	return fmt::format("%s\nEmulator: %s", rpcs3::get_verbose_version(), state);
}
