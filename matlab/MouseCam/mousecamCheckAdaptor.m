function [ok, msgs] = mousecamCheckAdaptor(adaptorName)
%MOUSECAMCHECKADAPTOR  Make sure the camera adaptor is available, and say so plainly.
%
%   [OK, MSGS] = MOUSECAMCHECKADAPTOR('gentl')
%
%   Does three things, in order:
%     1. If an adaptor .dll was shipped inside this application, register it.
%     2. Report whether MATLAB Runtime can see the adaptor.
%     3. Report whether the camera maker's driver path is set.
%
%   Step 3 is the one that cannot be fixed by packaging.  The .cti file that
%   actually talks to the camera belongs to Basler (or whoever made the
%   camera) and has to be installed on the machine.

if nargin < 1 || isempty(adaptorName)
    adaptorName = 'gentl';
end

ok   = false;
msgs = {};

% --- 1. register a bundled adaptor, if we shipped one -------------------
dllPath = findBundledAdaptor();
if ~isempty(dllPath)
    try
        already = imaqregister;
        if ~iscell(already)
            already = {};
        end
        if ~any(strcmpi(already, dllPath))
            imaqregister(dllPath);
            imaqreset;
            msgs{end+1} = sprintf('Registered bundled adaptor: %s', dllPath);
        end
    catch err
        msgs{end+1} = sprintf(['Could not register %s - try starting the ' ...
            'program once with "Run as administrator". (%s)'], dllPath, err.message);
    end
end

% --- 2. can we see the adaptor? ----------------------------------------
try
    info = imaqhwinfo;
    ok = any(strcmpi(info.InstalledAdaptors, adaptorName));
    if ok
        msgs{end+1} = sprintf('Adaptor "%s" is available.', adaptorName);
    else
        msgs{end+1} = sprintf(['Adaptor "%s" NOT found. Available: %s. ' ...
            'The GenICam support package was probably not included in the build.'], ...
            adaptorName, strjoin(info.InstalledAdaptors, ', '));
    end
catch err
    msgs{end+1} = sprintf('Could not query image acquisition hardware: %s', err.message);
    return
end

% --- 3. is the camera maker's driver installed? ------------------------
ctiPath = getenv('GENICAM_GENTL64_PATH');
if isempty(ctiPath)
    msgs{end+1} = ['GENICAM_GENTL64_PATH is not set. Install the camera ' ...
        'maker''s software (e.g. Basler pylon) on this machine - it cannot ' ...
        'be packaged into this program.'];
    ok = false;
else
    n = 0;
    parts = strsplit(ctiPath, ';');
    for k = 1:numel(parts)
        if ~isempty(parts{k})
            n = n + numel(dir(fullfile(parts{k}, '*.cti')));
        end
    end
    if n == 0
        msgs{end+1} = sprintf(['GENICAM_GENTL64_PATH is set to "%s" but no ' ...
            'driver files were found there.'], ctiPath);
        ok = false;
    else
        msgs{end+1} = sprintf('Found %d camera driver file(s) on GENICAM_GENTL64_PATH.', n);
    end
end
end

% ----------------------------------------------------------------------
function p = findBundledAdaptor()
%FINDBUNDLEDADAPTOR  Look for an adaptor .dll shipped alongside this program.

p = '';
roots = {};
if isdeployed
    roots{end+1} = ctfroot;
end
roots{end+1} = pwd;

for k = 1:numel(roots)
    try
        d = dir(fullfile(roots{k}, '**', 'mwgentlimaq.dll'));
    catch
        d = [];
    end
    if ~isempty(d)
        p = fullfile(d(1).folder, d(1).name);
        return
    end
end
end
