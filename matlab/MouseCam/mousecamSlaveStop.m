function counts = mousecamSlaveStop(vComposite, numSlaves, timeoutSec)
%MOUSECAMSLAVESTOP  Stop the worker cameras and wait for the disk logger.
%
%   COUNTS = MOUSECAMSLAVESTOP(VCOMPOSITE, NUMSLAVES, TIMEOUTSEC) returns an
%   NUMSLAVES-by-2 matrix of [FramesAcquired DiskLoggerFrameCount].
%
%   A timeout is used so that a camera which never flushes cannot hang the
%   application - the original unbounded WHILE loops would lock up the GUI.

counts = zeros(0, 2);
if numSlaves < 1 || isempty(vComposite)
    return
end
if nargin < 3 || isempty(timeoutSec)
    timeoutSec = 180;
end

v = vComposite;

spmd(numSlaves)
    stop(v);

    t0 = tic;
    while strcmp(v.Logging, 'on') && toc(t0) < timeoutSec
        pause(0.5);
    end
    while (v.FramesAcquired ~= v.DiskLoggerFrameCount) && toc(t0) < timeoutSec
        pause(0.5);
    end

    workerCounts = [v.FramesAcquired v.DiskLoggerFrameCount];
end

counts = zeros(numSlaves, 2);
for k = 1:numSlaves
    counts(k, :) = workerCounts{k};
end
end
