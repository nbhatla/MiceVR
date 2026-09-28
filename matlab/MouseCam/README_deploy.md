# MouseCam — deployable application

An interactive rewrite of `mousecam.m` so it can be compiled with MATLAB Compiler (R2017b) and run on a rig machine without a MATLAB licence.

## Files

| File | Role |
|---|---|
| `mousecamApp.m` | **Entry point.** The GUI and all client-side camera handling. |
| `mousecamConfig.m` | Every tunable number (ROI, binning, exposure, trigger lines, timeouts). |
| `mousecamGetDay.m` | Google Sheet day lookup, wrapped so it can never abort a session. |
| `mousecamFileBase.m` | Builds `mouse_007` style name stems. |
| `mousecamPoolInit.m` | Starts the local pool and clears imaq state on the workers. |
| `mousecamSlaveStart.m` | Worker camera setup + start. |
| `mousecamSlaveStop.m` | Worker stop, flush wait, frame-count gather. |
| `mousecamSlaveCleanup.m` | Worker teardown. |
| `mousecamSaveSession.m` | Writes the `.mat` file. |
| `mousecamCheckAdaptor.m` | Startup check: is the adaptor there, is the camera driver there. |
| `mousecamBuildInfo.m` | Prints the paths to paste into the Application Compiler dialogs. |
| `build_mousecam.m` | The `mcc` call. |

You supply `logTrialMarks.m`, `GetSheetIDs.m` and `GetGoogleSpreadsheet.m` unchanged.

## How it maps onto the original script

The two blocking `input()` prompts become buttons:

```
Connect & Preview  ->  imaqreset, pool start, two-pass camera creation, preview
Start Recording    ->  old "Press ENTER to stop preview & start PARALLEL recording"
Stop Recording     ->  old "Press ENTER to stop recording"
```

Everything else — the binning/ROI reboot workaround, `FramesPerTrigger = 1`, disk logging, `TriggerRepeat = Inf`, hardware trigger on rising edge of Line3/Line0, exposure 14000 µs, MPEG-4 at 60 fps, the `_1`/`_2` filename suffixes, and the `.mat` with `trialStarts`, `trialEnds`, `framesAcquiredLogged` — is byte-for-byte the same behaviour.

## Deliberate changes, and why

**No `close all` at the end.** It would have closed the GUI itself.

**`TriggerFcn = @logTrialMarks` instead of `{'logTrialMarks'}`.** The cell-string form is resolved by name at runtime, so `mcc`'s dependency analysis never sees it and the function gets stripped from the CTF. The function-handle form is found. (`build_mousecam` also passes it with `-a` as a belt-and-braces measure.)

**No `src` object crossing into the `spmd` block.** The original referenced the *client's* video source inside the worker code to test `DeviceVendorName`, which serialises a hardware object across processes. The vendor test and the ROI are now computed on the client and passed in as a logical and a numeric vector.

**Every `spmd` block lives in its own top-level function.** `spmd` bodies must be transparent, which conflicts with the shared-variable scoping of the GUI's nested callbacks. Do not move these blocks into `mousecamApp.m`.

**Flush loops are bounded** by `cfg.flushTimeout` (180 s). The original `while (v.FramesAcquired ~= v.DiskLoggerFrameCount)` loops had no exit and would hang the application if a camera never flushed.

**Paths are explicit.** A compiled executable's working directory is wherever the user launched it, so `'../config/vrGSdocid.txt'` is unreliable. The app takes the docid file and the output folder from Browse buttons and remembers them with `setpref`/`getpref` (which works fine in deployed apps — the prefs land in `prefdir`). The old relative path is still tried once at startup as a default.

**Frame counts update live** on a 1 Hz timer, and dropped frames are called out explicitly in the log.

## Building

The camera adaptor is not detected automatically. The compiler only reads your code, and nothing in your code says "Basler" or "GenICam" — it just says `videoinput`. So the compiler apps may show no support package section at all. Don't fight it; hand the adaptor over explicitly.

**Check the adaptor is installed on the build machine first:**

```matlab
root = matlabshared.supportpkg.getSupportPackageRoot
dir(fullfile(root, '**', 'mwgentlimaq.dll'))
```

Nothing found means the support package isn't installed *here*. Install "Image Acquisition Toolbox Support Package for GenICam Interface" on the build machine and try again.

**Then build:**

```matlab
build_mousecam            % includes the runtime installer
build_mousecam([], false) % skips it, much faster while iterating
```

The script finds the support package folder and passes it to the compiler with `-a`, which is MathWorks' documented method for exactly this case. It prints what it found before it starts, and warns loudly if it found nothing.

It then copies `MCRInstaller.exe` into the output folder and writes an `INSTALL.txt` next to it. R2017b is the last release that ships that installer with MATLAB, so this works now and wouldn't if you ever move to a newer release. `mcc` cannot fold the runtime into a single installer the way the compiler app can — you get a folder to copy across instead, which for one rig machine is the same amount of work.

The installer is 1–2 GB, so the first build takes a few minutes.

## Building a single self-installing package

`mcc` gives you a folder to copy. If you want one file that installs everything, you need the compiler app:

```matlab
mousecamBuildInfo        % prints every path you are about to paste
applicationCompiler
```

1. Main File: `mousecamApp.m`
2. **Files required for your application to run**: add all the `mousecam*.m` files plus `logTrialMarks.m`, `GetSheetIDs.m`, `GetGoogleSpreadsheet.m`
3. Same list: add the support package folder that `mousecamBuildInfo` printed. This is the manual version of the support package section that never appeared.
4. **Packaging Options**: untick *Runtime downloaded from web*, tick *Runtime included in package*
5. Application Information: name it MouseCam, and put the pylon requirement in the Installation Notes box
6. Package

Output lands in `for_redistribution` as a single `MyAppInstaller_mcr.exe`, around 2 GB. Build takes 10–20 minutes.

Save the project as `MouseCam.prj` on the way out. Rebuilds after that are one command, no clicking:

```matlab
deploytool -package MouseCam.prj
```

## The one thing you cannot put in the .exe

The adaptor is the MathWorks half. The other half is the file that actually talks to your Baslers — a `.cti` file that ships with Basler's own software (pylon). That belongs to Basler, not MathWorks, so nothing in the build can bundle it. It has to be installed on the rig machine, exactly the same way it is on your MATLAB machine:

1. Install Basler pylon on the rig machine, unticking the DirectShow driver during setup (a camera claimed by DirectShow may not show up).
2. Confirm the `GENICAM_GENTL64_PATH` environment variable points at the folder holding the `.cti` file.

`mousecamCheckAdaptor.m` runs on **Connect & Preview** and tells you in the log which of these two halves is missing, rather than failing with "no cameras found".

## Fallback if the support package won't package

If step 3 above isn't available in your R2017b install, you can carry the adaptor by hand:

1. Find `mwgentlimaq.dll` in the support package folder on your MATLAB machine (`matlabroot` → `toolbox/imaq/imaqadaptors/win64`, or wherever the support package landed).
2. Add it under **Files installed for your end user** in the Application Compiler.
3. `mousecamCheckAdaptor.m` already looks for that filename inside the installed application and registers it on first run.

First launch may need a right-click → **Run as administrator**, because registering an adaptor writes to a machine-level location. After that, normal launches are fine.

## Rest of the deployment checklist

1. **MATLAB Runtime R2017b, 64-bit.** Must match the build release exactly. Free, no licence.
2. **Parallel Computing Toolbox.** Deployed apps can only use the `local` profile, which `mousecamPoolInit` sets explicitly. The first pool start in a compiled app takes 10–30 seconds; that happens on Connect, not on Start Recording, so it doesn't eat into a session.
3. **First run**, use the two Browse buttons to point at `vrGSdocid.txt` and the data folder. Both are remembered afterwards.
4. **Firewall.** The worker talks to the main program over the local network loopback. An aggressive firewall will make the pool time out; allow `MouseCam.exe`.

## The one thing worth verifying on the rig

`cfg.slaveCameraID` is `1`, matching the original's `cameraID = labindex`. That works because the main program already holds the first camera open, so the worker only sees the free one. It depends on enumeration order. If camera 2 ever records the wrong eye or fails to open, set `cfg.slaveCameraID = 2` in `mousecamConfig.m` and rebuild.

Related: the handle to the worker's camera is held in the app's state between button presses. If a future change lets that handle go out of scope, the worker camera dies quietly at Stop.
