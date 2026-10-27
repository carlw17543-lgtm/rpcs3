#include "stdafx.h"
#include "Emu/System.h"
#include "Emu/Io/pad_config.h"
#include "Utilities/Thread.h"
#include "util/console.h"
#include "rpcs3_version.h"

#include <CoreFoundation/CoreFoundation.h>
#include <thread>

// Functions and globals the emulator core expects from its frontend.
// The desktop builds get them from the Qt UI (rpcs3qt, rpcs3.cpp), which iOS doesn't build.

// Defined in rpcs3qt/pad_settings_dialog.cpp on desktop
cfg_input_configurations g_cfg_input_configs;

// Same contract as the Qt version in rpcs3qt/main_window.cpp: call wrapped_op until it returns true.
// On the main thread, the iOS run loop keeps handling events between calls, like the Qt event loop does there.
void qt_events_aware_op(int repeat_duration_ms, std::function<bool()> wrapped_op)
{
	ensure(wrapped_op);

	while (!wrapped_op())
	{
		if (thread_ctrl::is_main())
		{
			CFRunLoopRunInMode(kCFRunLoopDefaultMode, repeat_duration_ms / 1000., true);
		}
		else if (repeat_duration_ms == 0)
		{
			std::this_thread::yield();
		}
		else
		{
			thread_ctrl::wait_for(repeat_duration_ms * 1000ull);
		}
	}
}

// The desktop version (rpcs3.cpp) shows a Qt dialog. Until the iOS app has its own, report the error
// the way RPCS3's headless mode does: write it to stderr and stop.
[[noreturn]] void report_fatal_error(std::string_view text, [[maybe_unused]] bool is_html, [[maybe_unused]] bool include_help_text)
{
	std::string buf(text);

	if (text.find("\nThread id = ") == std::string_view::npos && !thread_ctrl::is_main())
	{
		fmt::append(buf, "\n\nThread id = %u.", thread_ctrl::get_tid());
	}

	fmt::append(buf, "\nBuild: \"%s\"", rpcs3::get_verbose_version());

	utils::output_stderr(fmt::format("RPCS3: %s\n", buf));
	std::abort();
}
