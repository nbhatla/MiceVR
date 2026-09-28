function cfg = mousecamConfig()
%MOUSECAMCONFIG  All tunable settings for the mouse eye camera recorder.
%
%   Edit this file (and rebuild) to change acquisition parameters.  Keeping
%   them here rather than sprinkled through the code makes the compiled
%   application easier to maintain.

cfg.numCams       = 2;          % total number of cameras
cfg.adaptor       = 'gentl';    % image acquisition adaptor
cfg.format        = 'Mono8';    % video format
cfg.binSize       = 2;          % Basler binning -> video shrunk to 640x512
cfg.roiWidth      = 208;        % ROI saved to disk
cfg.roiHeight     = 150;
cfg.roiOriginBasler = [220 181];  % [x y] origin for Basler cameras
cfg.roiOriginOther  = [540 437];  % [x y] origin for everything else
cfg.exposureTime  = 14000;      % microseconds (15000 may be too slow/fast)
cfg.frameRate     = 60;         % VideoWriter frame rate

% Camera index that the parallel worker opens.  The original script used
% LABINDEX (i.e. 1), which works because the master process already holds
% the first camera open, so the worker only enumerates the free one.  If
% your enumeration order differs, change this.
cfg.slaveCameraID = 1;

% Trigger lines
cfg.triggerSourceBasler = 'Line3';
cfg.triggerSourceOther  = 'Line0';

% Google Sheet
cfg.dayColumn     = 1;          % column of the sheet holding the day number
cfg.docidFileName = 'vrGSdocid.txt';

% How long (s) to wait for the disk logger to flush after STOP
cfg.flushTimeout  = 180;
end
