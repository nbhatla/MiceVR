function n = mousecamPoolInit(numSlaves)
%MOUSECAMPOOLINIT  Make sure a local pool of NUMSLAVES workers exists and that
%   every worker starts with a clean image acquisition state.
%
%   Returns the number of workers in the pool (0 if none were requested).
%
%   SPMD blocks live in their own top level functions throughout this
%   application.  SPMD bodies must be "transparent", which they cannot be
%   inside nested functions that share variables with a parent workspace, so
%   never move these blocks into the GUI callbacks.

n = 0;
if nargin < 1 || numSlaves < 1
    return
end

% Deployed applications must be told explicitly to use the local scheduler.
parallel.defaultClusterProfile('local');

% A pool with the default 30 minute idle timeout is a hazard here.  The
% worker sits idle between mice, and during a recording it is idle too -
% it issues START and returns, while the camera acquires in the
% background.  If the pool times out the right eye camera goes with it.
IDLE_TIMEOUT = Inf;         % minutes; Inf means never shut down

p = gcp('nocreate');
if ~isempty(p) && (p.NumWorkers ~= numSlaves || ~isNoTimeout(p, IDLE_TIMEOUT))
    delete(p);
    p = [];
end

if isempty(p)
    c = parcluster('local');
    try
        p = parpool(c, numSlaves, 'IdleTimeout', IDLE_TIMEOUT);
    catch
        % Some releases will not take Inf - fall back to a long finite one.
        try
            p = parpool(c, numSlaves, 'IdleTimeout', 1440);   % 24 hours
        catch
            p = parpool(c, numSlaves);
            warning('mousecam:idleTimeout', ...
                ['Could not disable the pool idle timeout. Do not leave ' ...
                 'the app idle for long between recordings.']);
        end
    end
end
n = p.NumWorkers;

spmd(numSlaves)
    imaqreset;
    delete(imaqfind);
end
end
