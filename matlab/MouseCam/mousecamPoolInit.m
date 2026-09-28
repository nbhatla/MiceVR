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

p = gcp('nocreate');
if ~isempty(p) && p.NumWorkers ~= numSlaves
    delete(p);
    p = [];
end
if isempty(p)
    c = parcluster('local');
    p = parpool(c, numSlaves);
end
n = p.NumWorkers;

spmd(numSlaves)
    imaqreset;
    delete(imaqfind);
end
end
