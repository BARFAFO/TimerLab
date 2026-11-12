# TimerLab

A native Windows x64 desktop application for manual timer-resolution control and repeatable `Sleep(1)` precision scans.

## Version 1.0.13

The executable retains its full multi-resolution Windows shell icon. The WPF window embeds a reduced icon containing the original 16, 24, 32, 48, 64, and 128 px frames; the 256 px frame remains in the executable icon and is not duplicated in WPF resources. All retained icon frames are byte-for-byte unchanged. Timer requests, benchmark logic, measurements, verification, and exports are unchanged.

Results include three automatic configuration highlights: lowest mean `Sleep(1)` duration, mean duration closest to 1.000 ms (smallest absolute mean delta), and lowest sample standard deviation. Highlights use verified values only and show accepted sample counts; verified partial points remain eligible but are visibly marked by their accepted/expected count. A `BEST` marker identifies the strongest point for the currently selected graph metric. These are comparisons within the current run, not universal recommendations or guarantees of gaming performance.

- **Timer control:** request a timer period with `NtSetTimerResolution`, inspect the system-reported current period and supported range, then release TimerLab's request.
- **Draft/active separation:** editing or focusing the requested-resolution field only changes the pending text. It makes no timer API calls and does not query or change the active request; Apply updates the request and Release clears it. The UI indicates whether the draft matches the active request.
- **Automatic benchmark:** scan a start/end range with a configurable increment and a configurable **Samples per increment** count.
- **Results:** plot mean delta, mean sleep, median, minimum, maximum, or standard deviation using verified points only; inspect the selected-metric `BEST` point and the three configuration highlights; export raw measurements and verification diagnostics separately. Full run metadata (including the TimerLab process ID), raw samples, and per-interval verification records are automatically saved as JSON plus two CSV files under `Documents\TimerLab\Results`.
- Dark, light, and Windows system theme selection.
- UI refresh: larger default window, wider navigation rail, larger text and controls, a readable results graph and statistics table, automatic configuration highlights, and a selected-metric graph marker. Timer-control and benchmark calculations are unchanged.
- Versioned as **1.0.13** in assembly metadata, the UI, and exported benchmark records.
- Timer requests are updated in place when changing values; benchmark cleanup restores a previous manual request in place, and restoration failures are surfaced instead of being silently treated as successful cleanup.
- Reapplying the exact same already-active value is a no-op; TimerLab does not send a duplicate native Set request, and the benchmark records when an existing request was reused.
- Automatic result filenames include milliseconds and use exclusive creation to prevent same-second overwrites.

## Benchmark semantics

The main-screen **Samples per increment** field is the target number of accepted timed `Sleep(1)` measurements for each requested timer value. It is not multiplied by the number of rounds. Samples are distributed across the configured shuffled passes (one by default). For example, 20 target samples over 3 rounds are allocated 7 + 7 + 6 measurement slots for every timer value. If a verification check fails for any round, the entire requested point is excluded from statistics; if the run is cancelled without a verification failure, already-verified partial samples can remain in the results.

Each pass first applies the requested timer value and waits for a 50 ms request-settle margin plus the user-configured settling period. TimerLab then checks `NtQueryTimerResolution` after settling and after the discarded warm-up `Sleep(1)`. Before and after every timed `Sleep(1)`, it queries the current system resolution again. A sample passes its immediate checks only when the pre-sleep and post-sleep system-current readings exactly match the requested value. A requested point contributes to summary statistics only if every round for that point verifies successfully; if any interval fails, all measurements for that point are excluded from its summary statistics and chart. Timed samples remain in the raw CSV/JSON for diagnosis. The raw CSV distinguishes `NativeSetCallMade`, `PassedImmediateResolutionChecks`, and final `AcceptedForStatistics`, so a sample can pass its own before/after checks but still be excluded because another round for the same point failed. The separate verification CSV records the process ID, before-request reading, whether a native Set call was actually made (or the same active request was reused), Set API result when a call occurred, after-settle and after-warm-up readings, planned/measured/accepted counts, and interval/point status. Reapplying an identical already-active value does not issue a duplicate native Set call. The Set API output is retained as a diagnostic field; statistical acceptance is gated by the subsequent `NtQueryTimerResolution` system-current checks, not by assuming the Set output must echo the input. These are point-in-time checks; they cannot rule out a very brief state change that starts and ends between the queries.

The timer query calls occur outside the `Stopwatch` timing window, so they do not form part of the reported `Sleep(1)` duration. Valid samples are spaced by 100 ms, matching the reference `MeasureSleep` measurement cadence. Each accepted measurement times only the `Thread.Sleep(1)` call using `Stopwatch` (Windows QueryPerformanceCounter). Standard deviation is shown as unavailable when fewer than two accepted samples exist.

The default scan (0.5000–0.5095 ms, 0.0005 ms increment) contains 20 requested values. With the default 20 samples per value, it plans up to 400 timed sleep measurements plus one discarded warm-up per value. The actual accepted count can be lower if a point fails verification. With the default 1-second settle delay, the estimated duration is approximately one minute; actual duration varies with scheduling and system load.

## Verifying a benchmark run

1. Close other timer-resolution utilities for the first controlled run. Keep TimerLab visible and do not change power, affinity, or timer settings while it runs.
2. Start with a small scan inside the system-supported range (for example, 0.5000–0.5050 ms in 0.0010 ms steps, 20 samples per value, 2 rounds, 1,000 ms settling).
3. In Results, look at the **Verification** and **Valid / expected** columns. A value marked `Verified` is included only after every interval matched the requested current-system value at all configured checks. Rejected values do not enter the graph or summary statistics.
4. Inspect the three automatically saved files: JSON for all metadata and verification intervals, `_raw.csv` for each timed sleep and its before/after checks, and `_verification.csv` for each request interval, including intervals that failed before any sleep measurement was taken.
5. For independent process-level evidence, run WDK `PwrTest.exe` from an elevated Command Prompt with `pwrtest /timer /t:5` while TimerLab is benchmarking. Match the `ProcessId` in TimerLab's JSON/CSV to the `ProcessID` in PwrTest's timer request records. The PwrTest log also records system timer-resolution update events. PwrTest is included with the Windows Driver Kit (WDK); see Microsoft's [PwrTest overview](https://learn.microsoft.com/en-us/windows-hardware/drivers/devtest/pwrtest) and [Timer Scenario reference](https://learn.microsoft.com/en-us/windows-hardware/drivers/devtest/pwrtest-timer-scenario).

A rejected point is not a failed benchmark run: it means TimerLab refused to claim that the requested target was the observed system-current period during that interval. Resolve competing requests or system conditions, then repeat the scan. Do not manually relabel rejected measurements as valid.

## Important measurement limitations

- This measures the elapsed duration of `Sleep(1)`, not game frametimes, input latency, DPC latency, or scheduler latency directly. A lower average is not automatically a better real-world gaming setting.
- Other timer-resolution requests, background load, power policy, visibility/occlusion, and scheduling noise can affect the observed result. A value is excluded when the system-current query differs from the exact requested value; this is deliberately conservative. A finer current-system period (numerically lower) may mean another process or kernel request is keeping the system at a shorter period. Close competing timer-resolution utilities and keep TimerLab visible during a run. Windows may not honor elevated timer resolution requests from a process that is minimized or fully occluded.
- `NtQueryTimerResolution` reports the current system timer resolution; it does not identify which process owns an outstanding request. A verified point means the TimerLab request call succeeded and the queried system-current value matched the target at every check, not that TimerLab was the only process requesting that value. The JSON and both CSV files now include TimerLab's process ID to help correlate the run with an independent trace. For stronger process/request-event verification, use `PwrTest.exe` from the Windows Driver Kit (WDK) with the `/timer` scenario: run `pwrtest /timer /t:5` from an elevated Command Prompt; its XML log records timer-resolution request rundown entries and `NtSetTimerResolution` events with application names, process IDs, and requested resolutions, alongside system-resolution update events (see Microsoft's [PwrTest Timer Scenario documentation](https://learn.microsoft.com/en-us/windows-hardware/drivers/devtest/pwrtest-timer-scenario)).
- The verification queries run immediately outside each timed `Sleep(1)` window. They are not included in the reported duration, but they add small work between samples and may slightly affect the surrounding scheduling/idle state. This is a deliberate trade-off for per-sample checks; interpret the measurement as `Sleep(1)` under TimerLab's verification workload, not as a query-free sleep benchmark.
- The benchmark intentionally does not modify registry settings, BCD, HPET configuration, power plans, or system-wide timer policy.
- The app attempts to release its benchmark timer-resolution request and restore the manual request that was active before the run, if any. A failed release or restoration is reported explicitly, and the request still tracked by TimerLab remains visible.
- TimerLab does not request real-time process priority. This is intentional: the benchmark should not elevate the entire desktop application to a priority class that can starve other work.
- The estimate is approximate. Real sample durations and interruptions vary with system state.

## Build on Windows

Requirements to build from source: Windows 10/11 x64 and the **.NET 10 SDK** (or Visual Studio with the .NET desktop development workload and .NET 10 targeting pack). The build script checks for an installed .NET 10 SDK and reports a direct installation link if it is missing.

From this folder, run:

```powershell
.\build.ps1
```

The default build is a self-contained single-file executable: it runs on a compatible Windows x64 machine without requiring the .NET Desktop Runtime or SDK to be installed. Size settings live in `TimerLab.csproj`: managed-assembly compression (costs a little startup decompression work), English-only satellite resources, and no debug symbols. Trimming and Native AOT are not supported by WPF and are not used.

Almost all of the executable is the bundled .NET and WPF runtime. To drop that, build the framework-dependent variant, which is a few hundred KB instead of tens of MB:

```powershell
.\build.ps1 -FrameworkDependent
```

It behaves identically but needs the **.NET 10 Desktop Runtime (x64)** on whichever machine runs it. Use the default build for anything you share.

The executable is published outside the source project to:

```text
dist\publish\TimerLab.exe
```

After a successful publish, `build.ps1` automatically creates or refreshes a `TimerLab` shortcut on the current user’s Desktop, then launches TimerLab immediately. You do not need to browse into the build folders, create a shortcut manually, or open the executable yourself.

The build script does **not** create or retain a release ZIP by default. It keeps one local runnable copy at `dist\publish\TimerLab.exe`, updates the Desktop shortcut, launches the app, and then deletes only the generated `src\TimerLab\bin` and `src\TimerLab\obj` directories. These compiler outputs are regenerated automatically by the next build; all source files and assets are retained. Not keeping the release ZIP by default avoids storing a second compressed copy of the executable in the project folder.

When you want to share TimerLab with someone who only needs to run it, run the separate packaging script. The script keeps its console open at the end so an error is not lost when launched from File Explorer; use `-NoPause` when running it from an existing terminal and you do not want the pause:

```powershell
.\package-release.ps1
```

From an already-open PowerShell terminal, you can use `.\package-release.ps1 -NoPause` instead if you do not want the final pause.

It creates `dist\TimerLab_v<version>_win-x64.zip`, containing **only** `TimerLab.exe`. The packaging script checks build metadata and refuses to package an older or framework-dependent build, so the shared ZIP does not silently depend on the recipient having the .NET 10 Desktop Runtime. If metadata is missing (for example, when reusing a `dist\publish` executable created by the previous 1.0.0 build), run `build.ps1` again from this source folder without `-FrameworkDependent` before packaging. The executable remains available in `dist\publish` for local use. The next successful run of `build.ps1` removes that generated release ZIP again, so the project returns to keeping only one local executable copy. The packaging script does not require the .NET SDK; it only needs the already-published executable and its build metadata.

Recipients who only want to use TimerLab should extract the ZIP and run `TimerLab.exe`; they do **not** need the source project, PowerShell build script, or .NET SDK. Windows SmartScreen or antivirus reputation warnings may still appear for an unsigned new application; those are a separate distribution-trust issue and are not solved by bundling the runtime.

You can also open `TimerLab.sln` in Visual Studio and build the `Release | Any CPU` configuration; the project itself targets x64 for publishing.

## Project layout

- `src/TimerLab/MainWindow.xaml` — WPF interface
- `src/TimerLab/MainWindow.xaml.cs` — control flow, graph, results export
- `src/TimerLab/TimerResolutionNative.cs` — `NtQueryTimerResolution` / `NtSetTimerResolution` interop
- `src/TimerLab/BenchmarkRunner.cs` — scan and raw measurement loop
- `src/TimerLab/Models.cs` — benchmark settings and result models
- `build.ps1` / `package-release.ps1` — publish and optional release ZIP (version is read from the `.csproj`)

## Validation status

The 1.0.4 benchmark-verification pass was prepared in an environment without the Windows/.NET SDK build toolchain. The project/XAML/manifest XML, XAML event-handler and named-control references, resource references, source delimiter structure, verification gating and CSV schema consistency were checked statically. The WPF application has **not** been compiled or executed in this environment. Build with `build.ps1` on Windows and validate both accepted and rejected benchmark points before relying on the results.

## Application icon

The final TimerLab icon combines the segmented blue performance gauge, a circular metallic timer bezel and needle, the microchip casing and pins, and a stopwatch crown with a side pusher. `TimerLab.png` (256 px, shown at 54 px in the in-app header) is a downscale of the original 1254 px artwork; the multi-resolution `TimerLab.ico` is embedded in the executable and used by the WPF window and Desktop shortcut.
