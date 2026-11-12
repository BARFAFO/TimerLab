## 1.0.13 (resource/package-size optimization)

- Kept the full seven-size `TimerLab.ico` as the native executable/shell icon.
- Added `TimerLabWindow.ico` for the WPF window with the original 16, 24, 32, 48, 64, and 128 px frames; the 256 px frame remains in the executable icon and is no longer embedded a second time as a WPF resource.
- Every retained frame is copied byte-for-byte from the 1.0.12 icon. No image was resampled or re-encoded.
- This removes 114,003 bytes from the WPF icon resource file while preserving the full-resolution executable icon.
- No timer API, benchmark sequencing, sample timing, verification, calculations, UI layout, or export semantics were changed.
- This is a packaging/resource optimization candidate; verify the window/taskbar/Alt-Tab icon on Windows before adopting it as the new official baseline.

## 1.0.12 (configuration highlights)

- Added three automatic results highlights: lowest mean `Sleep(1)`, mean `Sleep(1)` closest to 1.000 ms (smallest absolute mean delta), and lowest sample standard deviation.
- Only verified points with accepted samples are eligible. Verified partial-run points remain eligible, with accepted/expected sample counts shown so the smaller sample is visible; rejected and unverified points are never ranked.
- Added a `BEST` ring and label to the graph for the strongest verified point under the currently selected plot metric. Mean delta is ranked by absolute distance from zero; the other metrics favor the lower value.
- Added hover explanations and deterministic tie-breaking by requested resolution. These are within-run comparisons, not universal recommendations or claims about FPS or system-wide latency.
- No timer API calls, benchmark sequencing, verification rules, sample calculations, or export data semantics were changed.

## 1.0.11 (results column alignment)

- Center-aligned numeric result values within each column, directly beneath the already-centered column headers. Removed the former right-side text inset so headings and their values share the same horizontal centerline.
- Column widths, responsive sizing, table typography, verification display, and all benchmark/timer behavior remain unchanged.

## 1.0.10 (results alignment refinement)

- Inset right-aligned numeric result values by 10 px within their existing columns. This keeps decimal values consistently right-aligned while moving the visible numbers away from the far-right cell edge for a more balanced table.
- Column widths, header alignment, status placement, table typography, and all benchmark/timer behavior remain unchanged.

# Changelog

## 1.0.9 (results table refinement)

- Removed the verbose verification-details column from the visible results table; full status and detail text remain available on hover and in the raw/verification exports.
- Replaced long status strings with compact PASS, PARTIAL, FAIL, and N/A indicators. This is a display-only mapping; verification decisions and sample acceptance are unchanged.
- Moved the status column to the far right so Requested and System current sit together, followed by the measured statistics.
- Replaced fixed column widths with proportional widths and minimums, wrapped long headers onto two lines, and right-aligned numeric values to make the table easier to scan.
- Increased result text to 18 and row height to 54 px, while adjusting padding to preserve column space.
- No timer API calls, benchmark sequencing, verification rules, sample calculations, or export data semantics were changed.

## 1.0.8 (results readability refinement)

- Increased results-table body text from 14 to 17 WPF units and row height from 40 to 50 px; table values use a medium weight for clearer reading.
- Increased table column-header text from 14 to 16 and increased cell/header padding for improved legibility.
- Kept the results chart panel at 300 px to preserve table space, while enlarging axis labels and slightly increasing the plotted line and point markers.
- Increased results-section labels and chart guidance text.
- No timer API calls, benchmark sequencing, verification rules, sample calculations, or export data semantics were changed.

## 1.0.7 (UI readability refresh)

- Increased the default window size and minimum dimensions to give the interface more working space.
- Widened the sidebar and increased navigation text sizing so every workspace label, including Automatic benchmark, remains visible without truncation.
- Increased typography and control sizing across timer control, automatic benchmark, results, tooltips, and the statistics table.
- Increased the results chart panel height, axis-label sizes, plotted line weight, point markers, and hover target.
- No timer API calls, benchmark sequencing, verification rules, sample calculations, or export data semantics were changed.

## 1.0.6 (requested-resolution draft isolation)

- The requested-resolution textbox is explicitly treated as a pending draft, separate from the TimerLab request currently held by the native API wrapper.
- Editing the field updates only a UI status line; its text-change handler does not call `NtSetTimerResolution`, `NtQueryTimerResolution`, `Request`, or `Release`.
- The status line shows whether the draft matches the active request, differs from it while the previous request remains held, or is invalid.
- Apply remains the only manual action that commits a new requested value; Release remains the manual action that clears the active request. Benchmark behavior and verification logic are unchanged.

## 1.0.5 (idempotent same-value timer request)

- Reapplying the exact timer-resolution value already held by TimerLab now reuses the existing request without issuing another `NtSetTimerResolution(SetResolution=TRUE)` call.
- Applying a different value still updates the active TimerLab request directly; Release still makes one `SetResolution=FALSE` call.
- The benchmark records whether each interval/sample actually made a native Set call. When a requested value is already active (including a benchmark that begins on the same value as the saved manual request), it records request reuse explicitly and leaves the Set API output blank instead of presenting a stale value as a fresh API result.
- Error diagnostics now name `STATUS_TIMER_RESOLUTION_NOT_SET` (`0xC0000245`) and `STATUS_IP_ADDRESS_CONFLICT1` (`0xC0000254`) distinctly.

## 1.0.4 (benchmark verification gate)

- Every benchmark interval now records the system-current timer value before the request, the native Set API output, and the system-current values after settling and after the warm-up.
- Every timed `Sleep(1)` is bracketed by `NtQueryTimerResolution` checks immediately before and after the sleep. Its measurement is accepted only if both checks exactly match the requested value.
- If any round for a requested value fails verification, all measurements for that value are excluded from summary statistics and the chart, while raw timed measurements remain available with rejection reasons.
- Added per-round verification records to JSON and a separate verification CSV export; raw CSV now records before/after current values, immediate check outcome, final statistical acceptance, and rejection reasons.
- Added TimerLab's process ID to run metadata and both CSV exports so request events can be correlated with WDK PwrTest logs.
- Raw sample records distinguish passing the immediate before/after checks from final inclusion in statistics; a later interval failure can invalidate the entire timer-value point without erasing that distinction.
- Verification documentation notes that per-sample queries are outside the Stopwatch window but add small workload between samples, and that point-in-time checks cannot detect a brief change entirely between queries. Added a repeatable manual and PwrTest cross-check procedure to the README.
- Verification failure messages distinguish a finer-than-target current-system period from a coarser-than-target period, which helps identify competing requests.
- Results table identifies verified, partially verified, and rejected values; the graph plots only verified values.
- Documentation clarifies that `NtQueryTimerResolution` reports system current state and cannot identify the owning process. PwrTest `/timer` is documented as an independent process/request-event diagnostic.

## 1.0.3 (release-control UX)

- The Release button is disabled whenever TimerLab has no active timer-resolution request.
- The disabled button displays a tooltip explaining that there is no active request to release.
- The Release handler has a defensive no-request guard and does not call the native release API unnecessarily.
- Release-button availability is refreshed from TimerLab's tracked native-request state, including after benchmark cleanup.

## 1.0.2 (timer request replacement fix)

- Manual Apply now updates TimerLab's existing per-process `NtSetTimerResolution` request directly instead of releasing it and immediately requesting another value.
- The benchmark also changes its request in place between scan points and restores the previous manual request in place when the run ends. It calls `SetResolution=FALSE` only when no manual request existed before the benchmark.
- Failed request changes reassert the previous value without first clearing the process request.
- This avoids an unnecessary release/reacquire gap and makes changing a value without pressing Release the normal supported workflow.

## 1.0.1 (reliability and distribution pass)

Packaging-script follow-up
- Packaging errors now remain visible when launched from File Explorer; the script displays a clear diagnostic and pauses before closing.
- The package is checked to contain exactly one file (`TimerLab.exe`).
- Missing metadata errors explain that an executable from the older 1.0.0 build must be rebuilt once with the current `build.ps1`.

- Timer requests are tracked by their exact 100 ns value, rather than by a separate UI-only flag.
- Benchmark cleanup now reports release/restoration failures and does not claim that the previous request was restored unless the native calls succeeded.
- A benchmark exception preserves any measurements already collected; the UI marks the run as failed, keeps available data, and reports the diagnostic.
- Stopped/failed benchmark results are no longer described as saved unless automatic saving actually succeeded.
- Automatic JSON/CSV result names use millisecond timestamps and exclusive file creation, with suffixes for rapid or concurrent runs.
- Benchmark progress updates during sample collection (throttled to avoid excessive UI dispatch).
- Long benchmark estimates now show hours/days and warn when the scan is expected to take four hours or more.
- Removed the unused in-memory `BenchmarkPoint.Samples` property; raw samples remain stored once in `BenchmarkRun.RawSamples`.
- `build.ps1` checks for the .NET 10 SDK and gives a direct installation instruction when it is missing.
- Build output records its version, architecture, and self-contained/framework-dependent mode. The packaging script verifies this metadata and refuses to create a shareable ZIP from a framework-dependent build.
- Publish and ZIP replacement now preserve the previous output if the final swap fails.

## 1.0.0 (cleanup pass)

Size
- Header image `TimerLab.png`: 1254 px (1.8 MB) -> 256 px (about 99 KB). It is drawn at 54 px, so this stays sharp up to roughly 470% display scaling. The artwork was fully opaque, so the alpha channel was dropped losslessly.
- `SatelliteResourceLanguages=en`: stops bundling WPF's localized resource sets for ~13 languages (the app is English-only).
- No debug symbols (`DebugType=none`); size-related publish settings moved from `build.ps1` into `TimerLab.csproj`.
- `build.ps1 -FrameworkDependent`: optional tiny build that needs the .NET 10 Desktop Runtime.
- Saved results JSON no longer writes every sample twice (they remain under `RawSamples`; `Points[].Samples` is no longer serialized). The raw CSV is unchanged.

Fixes
- Light theme: the "Important for valid results" banner on the benchmark page was dark text on a hard-coded dark box. It now follows the theme (dark-mode colors unchanged).
- Switching theme left the selected sidebar item stuck on the previous theme's background. It now tracks theme changes.
- The sidebar now highlights "Timer control" on launch.

Cleanup
- Removed unused brushes, a redundant `ItemsSource` binding, redundant null guards, a duplicate window-background assignment and an unused `using`.
- `TimerResolutionInfo` moved to `Models.cs`; chart tooltip delay moved into the XAML.
- Release notes, theme-fix notes and icon notes merged into this file; removed the stale `TimerLab.svg` (it did not match the final icon and was not part of the build).
- Scripts read the version from `TimerLab.csproj` instead of hard-coding `1.0.0`.

## 1.0.0 (initial)

- Manual timer control via `NtSetTimerResolution`, automatic `Sleep(1)` benchmark scan, chart and statistics table, raw CSV export, automatic JSON and CSV saving.
- Dark, light and system themes; theme-aware ComboBox and ToolTip templates; native title bar follows the theme through DWM attributes.
- Custom application icon (blue segmented gauge in a metallic timer bezel, microchip frame, stopwatch crown).
- `build.ps1` publishes a self-contained single-file exe, refreshes the Desktop shortcut and launches the app; `package-release.ps1` creates the shareable ZIP on demand.
