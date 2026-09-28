function build_mousecam(outDir, includeRuntime)
%BUILD_MOUSECAM  Compile MOUSECAMAPP into a standalone Windows application,
%   including the GenICam camera adaptor and the MATLAB Runtime installer, so
%   the result runs on a machine with no MATLAB on it.
%
%   BUILD_MOUSECAM                   builds into .\dist, runtime included
%   BUILD_MOUSECAM(OUTDIR)           builds into OUTDIR
%   BUILD_MOUSECAM(OUTDIR, false)    skips the runtime installer (much faster)
%
%   The runtime installer is roughly 1-2 GB, so the first build takes a few
%   minutes to copy it.  Pass FALSE while you are still iterating.
%
%   Run this from the folder holding mousecamApp.m, with logTrialMarks.m,
%   GetSheetIDs.m and GetGoogleSpreadsheet.m in the same folder or on the path.
%
%   The camera adaptor is not picked up automatically, because the compiler
%   only scans your code and cannot tell which camera hardware you use.  This
%   script locates the installed support package and hands it to the compiler
%   explicitly.
%
%   Tested against R2017b.

if nargin < 1 || isempty(outDir)
    outDir = fullfile(pwd, 'dist');
end
if nargin < 2 || isempty(includeRuntime)
    includeRuntime = true;
end
if exist(outDir, 'dir') ~= 7
    mkdir(outDir);
end

% ----------------------------------------------------------------------
% 1. Everything the compiler needs to be able to find
% ----------------------------------------------------------------------
required = {'mousecamApp', 'mousecamConfig', 'mousecamGetDay', ...
            'mousecamFileBase', 'mousecamPoolInit', 'mousecamSlaveStart', ...
            'mousecamSlaveStop', 'mousecamSlaveCleanup', ...
            'mousecamSaveSession', 'mousecamCheckAdaptor', 'mousecamCameraIdentity', ...
            'logTrialMarks', 'GetGoogleToken', ...
            'GetSheetIDs', 'GetGoogleSpreadsheet'};
missing = {};
for k = 1:numel(required)
    if isempty(which(required{k}))
        missing{end+1} = required{k}; %#ok<AGROW>
    end
end
if ~isempty(missing)
    error('build_mousecam:missingFiles', ...
        'Not on the path: %s', strjoin(missing, ', '));
end

% ----------------------------------------------------------------------
% 2. Locate the camera adaptor
% ----------------------------------------------------------------------
[spkgFolder, adaptorDll] = locateAdaptor();

if isempty(adaptorDll)
    fprintf('\n');
    fprintf('*** The GenICam adaptor was NOT found on this machine.        ***\n');
    fprintf('*** Install "Image Acquisition Toolbox Support Package for    ***\n');
    fprintf('*** GenICam Interface" here, then build again. Continuing,    ***\n');
    fprintf('*** but the result will not see any cameras.                  ***\n');
    fprintf('\n');
else
    fprintf('Adaptor found:  %s\n', adaptorDll);
    fprintf('Bundling:       %s\n', spkgFolder);
end

% ----------------------------------------------------------------------
% 3. Build
% ----------------------------------------------------------------------
args = {'-m', 'mousecamApp.m', ...
        '-o', 'MouseCam', ...
        '-d', outDir, ...
        '-a', which('logTrialMarks'), ...
        '-a', which('GetGoogleToken'), ...
        '-a', which('GetSheetIDs'), ...
        '-a', which('GetGoogleSpreadsheet')};

if ~isempty(spkgFolder)
    args = [args, {'-a', spkgFolder}];
end
if ~isempty(adaptorDll)
    % Also drop the adaptor in on its own, so mousecamCheckAdaptor can find
    % and register it if the runtime does not pick it up by itself.
    args = [args, {'-a', adaptorDll}];
end
args = [args, {'-v'}];

fprintf('\nBuilding into %s ...\n', outDir);
mcc(args{:});

% ----------------------------------------------------------------------
% 4. Drop the MATLAB Runtime installer alongside the program
% ----------------------------------------------------------------------
if includeRuntime
    copyRuntimeInstaller(outDir);
end

writeInstallNotes(outDir, includeRuntime);

fprintf('\nDone. Copy this whole folder to the rig machine:\n   %s\n', outDir);
fprintf('Remember: Basler pylon still has to be installed there too.\n');
end

% ======================================================================
function copyRuntimeInstaller(outDir)
%COPYRUNTIMEINSTALLER  Find MCRInstaller.exe and copy it into the output folder.
%
%   R2017b is the last release that ships this installer with MATLAB.  From
%   R2018a onwards you have to download it from mathworks.com instead.

fprintf('\nLocating the MATLAB Runtime installer...\n');

src = '';
try
    src = mcrinstaller;
catch err
    fprintf('  mcrinstaller failed: %s\n', err.message);
end

if isempty(src) || exist(src, 'file') ~= 2
    fprintf('\n');
    fprintf('*** MCRInstaller.exe was not found on this machine.           ***\n');
    fprintf('*** Download the R2017b runtime (64-bit) by hand from         ***\n');
    fprintf('*** mathworks.com and put it in the output folder yourself.   ***\n');
    fprintf('\n');
    return
end

d = dir(src);
fprintf('  Found: %s (%.0f MB)\n', src, d.bytes / 1e6);
fprintf('  Copying - this takes a few minutes...\n');

dest = fullfile(outDir, 'MCRInstaller.exe');
[ok, msg] = copyfile(src, dest);
if ok
    fprintf('  Copied to %s\n', dest);
else
    fprintf('  Copy FAILED: %s\n', msg);
end
end

% ======================================================================
function writeInstallNotes(outDir, includeRuntime)
%WRITEINSTALLNOTES  Leave a plain text crib sheet next to the program.

fid = fopen(fullfile(outDir, 'INSTALL.txt'), 'w');
if fid < 0
    return
end

fprintf(fid, 'MouseCam - installing on the rig machine\r\n');
fprintf(fid, '=======================================\r\n\r\n');

step = 1;
if includeRuntime
    fprintf(fid, '%d. Run MCRInstaller.exe. This is the MATLAB Runtime.\r\n', step);
    fprintf(fid, '   It is free, needs no licence, and only has to be done once\r\n');
    fprintf(fid, '   per machine. Takes a while.\r\n\r\n');
else
    fprintf(fid, '%d. Install the MATLAB Runtime for R2017b, 64-bit, from\r\n', step);
    fprintf(fid, '   mathworks.com. Free, no licence, once per machine.\r\n\r\n');
end
step = step + 1;

fprintf(fid, '%d. Install Basler pylon. Untick the DirectShow driver during\r\n', step);
fprintf(fid, '   setup, or the cameras may not show up.\r\n');
fprintf(fid, '   This part cannot be bundled - it is Basler software.\r\n\r\n');
step = step + 1;

fprintf(fid, '%d. Check that the GENICAM_GENTL64_PATH environment variable\r\n', step);
fprintf(fid, '   points at the folder holding pylon''s .cti file.\r\n\r\n');
step = step + 1;

fprintf(fid, '%d. Run MouseCam.exe. If anything above is missing, the log\r\n', step);
fprintf(fid, '   panel says which when you press Connect & Preview.\r\n\r\n');
step = step + 1;

fprintf(fid, '%d. First run only: use the two Browse buttons to point at\r\n', step);
fprintf(fid, '   vrGSdocid.txt and the folder where videos should be saved.\r\n');
fprintf(fid, '   Both are remembered afterwards.\r\n\r\n');

fprintf(fid, 'If the program starts but finds no cameras, try launching it\r\n');
fprintf(fid, 'once with right-click > Run as administrator.\r\n');

fclose(fid);
end

% ======================================================================
function [spkgFolder, adaptorDll] = locateAdaptor()
%LOCATEADAPTOR  Find the installed GenICam support package.

spkgFolder = '';
adaptorDll = '';

try
    root = matlabshared.supportpkg.getSupportPackageRoot;
catch
    root = '';
end
if isempty(root) || exist(root, 'dir') ~= 7
    return
end

try
    d = dir(fullfile(root, '**', 'mwgentlimaq.dll'));
catch
    d = [];
end
if ~isempty(d)
    adaptorDll = fullfile(d(1).folder, d(1).name);
end

% Ship the image acquisition part of the support package tree if we can
% pick it out, otherwise the whole thing.
candidate = fullfile(root, 'toolbox', 'imaq');
if exist(candidate, 'dir') == 7
    spkgFolder = candidate;
else
    spkgFolder = root;
end
end
