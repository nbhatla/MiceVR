function [vComposite, usedSerial] = mousecamSlaveStart(cfg, isBasler, roi, exposure, outDir, base, targetSerial)
%MOUSECAMSLAVESTART  Open the right eye camera on the worker and start it.
%
%   [VCOMPOSITE, USEDSERIAL] = MOUSECAMSLAVESTART(CFG, ISBASLER, ROI, ...
%       EXPOSURE, OUTDIR, BASE, TARGETSERIAL)
%
%   Writes BASE_2.mp4 - the right eye.  The left eye is recorded by the main
%   process as BASE_1.mp4.
%
%   The worker does not trust enumeration order.  The main process is
%   already holding the left eye camera open, so only the right eye is free;
%   the worker tries each camera number in turn, and checks the serial of
%   whichever one opens against TARGETSERIAL.  Pass '' to skip the check.
%
%   Returns a Composite holding the worker's VIDEOINPUT object.  Keep it -
%   the worker side object lives only as long as that Composite does.

numSlaves  = cfg.numCams - 1;
vComposite = [];
usedSerial = '';
if numSlaves < 1
    return
end

adaptor   = cfg.adaptor;
fmt       = cfg.format;
frameRate = cfg.frameRate;
numCams   = cfg.numCams;
if isBasler
    trigSrc = cfg.triggerSourceBasler;
else
    trigSrc = cfg.triggerSourceOther;
end

spmd(numSlaves)
    v      = [];
    serial = '';

    for camTry = 1:numCams
        try
            candidate = videoinput(adaptor, camTry, fmt);
        catch
            continue            % that one belongs to the main process
        end

        cs = getselectedsource(candidate);
        thisSerial = mousecamCameraIdentity(cs, camTry);

        if isempty(targetSerial) || strcmp(thisSerial, targetSerial)
            v      = candidate;
            serial = thisSerial;
            break
        end

        delete(candidate);
    end

    if isempty(v)
        error('mousecam:noSlaveCamera', ...
            'The worker could not open the right eye camera (wanted %s).', ...
            targetSerial);
    end

    s = getselectedsource(v);

    v.FramesPerTrigger   = 1;
    v.LoggingMode        = 'disk';
    v.ReturnedColorspace = 'grayscale';
    v.TriggerRepeat      = Inf;
    v.ROIPosition        = roi;

    s.ExposureTime = exposure;
    % Leave AcquisitionFrameRateMode alone - turning it on drops frames.

    % _2 is always the right eye.
    vw = VideoWriter(fullfile(outDir, sprintf('%s_2.mp4', base)), 'MPEG-4');
    vw.FrameRate = frameRate;
    v.DiskLogger = vw;

    triggerconfig(v, 'hardware');
    s.TriggerMode       = 'On';
    s.TriggerActivation = 'RisingEdge';
    s.TriggerDelay      = 0;
    s.TriggerSelector   = 'FrameStart';
    s.TriggerSource     = trigSrc;

    start(v);
end

vComposite = v;
try
    usedSerial = serial{1};
catch
    usedSerial = '';
end
end
