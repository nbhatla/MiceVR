function mousecamApp()
%MOUSECAMAPP  Two-camera mouse eye recorder.
%
%   Live previews start by themselves when the window opens.  Type the mouse
%   name and press Enter to pull the day from the Google Sheet, check the two
%   eyes are in focus, then press Start Recording.
%
%   Closing the window ends the recording, finishes the video files and
%   writes the MAT file.  There is deliberately no Stop button - closing is
%   the stop.
%
%   Exposure, ROI, binning and trigger lines all live in MOUSECAMCONFIG.
%
%   Built for R2017b with plain UICONTROL objects so it compiles cleanly.

% ==================================================================
%  EDIT THESE BEFORE COMPILING IF THE FOLDERS EVER MOVE
% ==================================================================
DOCID_FILE = 'C:\Users\IAM\Documents\MVR\config\vrGSdocid.txt';
OUTPUT_DIR = 'C:\Users\IAM\Documents\MVR\eyevideos';
% Folder holding GetSheetIDs.m and GetGoogleSpreadsheet.m.  Only used
% when running from MATLAB - once compiled they are inside the program.
HELPER_DIR = 'C:\Users\IAM\Documents\MVR';
% ==================================================================

cfg       = mousecamConfig();
numSlaves = cfg.numCams - 1;

% Globals used by the trigger callback LOGTRIALMARKS.
global trialStarts trialEnds lastEventTime fps
trialStarts   = struct([]);
trialEnds     = struct([]);
lastEventTime = 0;
fps           = cfg.frameRate;

% ------------------------------------------------------------------
% State.  st.vid is indexed by CAMERA NUMBER, not by eye.
% ------------------------------------------------------------------
st.vid        = cell(cfg.numCams, 1);
st.himg       = cell(cfg.numCams, 1);
st.vComposite = [];
st.state      = 'starting';      % starting | preview | recording | closing
st.isBasler   = false;
st.base       = '';
st.lookedUp   = '';        % name whose day has already been fetched
st.tmr        = [];
st.outDir     = OUTPUT_DIR;
st.docidFile  = DOCID_FILE;

% Which camera is which eye.  Stored by the camera's own serial number so
% the choice survives the devices being enumerated in a different order.
st.camID    = cell(cfg.numCams, 1);   % unique id per camera
st.camLabel = cell(cfg.numCams, 1);   % what the dropdown shows
st.leftCam  = 1;
st.rightCam = otherCamera(1, cfg.numCams);
st.savedLeftID = getpref('mousecam', 'leftCameraID', '');

% ------------------------------------------------------------------
% Layout.  One band of controls across the top with the log beside the
% button, and the two previews filling everything below.
% ------------------------------------------------------------------
figW = 980;
topH = 96;               % controls + log band
vidH = 440;              % preview band

figH   = topH + vidH + 24;
innerW = figW - 16;

fig = figure( ...
    'Name',            'Mouse Eye Camera Recorder', ...
    'NumberTitle',     'off', ...
    'MenuBar',         'none', ...
    'ToolBar',         'none', ...
    'Resize',          'off', ...
    'Units',           'pixels', ...
    'Position',        [100 100 figW figH], ...
    'Color',           [0.94 0.94 0.94], ...
    'CloseRequestFcn', @onClose, ...
    'Visible',         'off');

% Sit a fifth of the way down the screen, centred horizontally.  Raise or
% lower TOP_GAP to taste - 0 puts it against the top edge.
TOP_GAP = 0.20;
scr  = get(0, 'ScreenSize');            % [x y width height]
xPos = scr(1) + round((scr(3) - figW) / 2);
yPos = scr(2) + scr(4) - round(TOP_GAP * scr(4)) - figH;
yPos = max(yPos, scr(2) + 40);          % never off the bottom
set(fig, 'Position', [xPos yPos figW figH]);

pCtrl = uipanel('Parent', fig, 'Units', 'pixels', ...
    'Position', [8 vidH+16 innerW topH], 'Title', 'Session');
pVid = uipanel('Parent', fig, 'Units', 'pixels', ...
    'Position', [8 8 innerW vidH], 'Title', 'Live preview');

% ---- left of the band: name, day, the one button, status ----------
uicontrol(pCtrl, 'Style', 'text', 'String', 'Mouse name  (press Enter)', ...
    'HorizontalAlignment', 'left', 'Position', [10 58 160 14]);
hMouse = uicontrol(pCtrl, 'Style', 'edit', 'String', '', ...
    'HorizontalAlignment', 'left', 'BackgroundColor', 'w', ...
    'Position', [10 32 140 26], 'Callback', @onMouseNameEntered);

uicontrol(pCtrl, 'Style', 'text', 'String', 'Day', ...
    'HorizontalAlignment', 'left', 'Position', [158 58 50 14]);
hDay = uicontrol(pCtrl, 'Style', 'edit', 'String', '', ...
    'HorizontalAlignment', 'left', 'BackgroundColor', 'w', ...
    'Position', [158 32 55 26], 'Callback', @onDayEdited);

hRecord = uicontrol(pCtrl, 'Style', 'pushbutton', 'String', 'Start Recording', ...
    'FontWeight', 'bold', 'Position', [10 4 140 26], ...
    'Callback', @onStartRecording, 'Enable', 'off');

hStatus = uicontrol(pCtrl, 'Style', 'text', 'String', 'Starting...', ...
    'HorizontalAlignment', 'left', 'FontWeight', 'bold', ...
    'Position', [158 8 190 18]);

% ---- right of the band: the log, three lines tall -----------------
hLog = uicontrol(pCtrl, 'Style', 'listbox', 'String', {}, ...
    'BackgroundColor', 'w', 'Position', [360 28 594 52], ...
    'TooltipString', 'Double-click a line to read it in full', ...
    'Callback', @onLogClick);

hFileTxt = uicontrol(pCtrl, 'Style', 'text', 'String', 'Files: (none)', ...
    'HorizontalAlignment', 'left', 'FontAngle', 'italic', ...
    'Position', [360 8 330 18]);
hCounts = uicontrol(pCtrl, 'Style', 'text', 'String', '', ...
    'HorizontalAlignment', 'left', 'Position', [696 8 150 18]);
uicontrol(pCtrl, 'Style', 'pushbutton', 'String', 'Copy log', ...
    'Position', [852 4 100 24], 'Callback', @onCopyLog);

% ---- previews -----------------------------------------------------
% One axes per CAMERA, parked in whichever slot its eye occupies.  The
% previews are started once and never restarted: swapping the eyes just
% moves the axes between slots, which is what keeps the live image alive.
eyeName = {'Left eye', 'Right eye'};
ax      = gobjects(cfg.numCams, 1);
hPick   = gobjects(2, 1);
axW     = 0.46;
axGap   = (1 - 2*axW) / 3;

for k = 1:cfg.numCams
    ax(k) = axes('Parent', pVid, 'Units', 'normalized', ...
        'Position', slotPos(min(k, 2)), 'Visible', 'off');
    set(ax(k), 'XTick', [], 'YTick', [], 'Box', 'on');
end

for e = 1:2
    xc = (axGap + (e-1)*(axW + axGap) + axW/2) * innerW;
    hPick(e) = uicontrol(pVid, 'Style', 'popupmenu', 'String', {'Detecting...'}, ...
        'Position', [xc-120 8 240 24], 'Callback', @onPickCamera, ...
        'UserData', e, 'Enable', 'off', ...
        'TooltipString', 'Which physical camera is showing this eye');
end
colormap(fig, gray(256));

set(fig, 'Visible', 'on');
drawnow;

% ------------------------------------------------------------------
% Bring the cameras up straight away.
% ------------------------------------------------------------------
autoStart();

% ==================================================================
%  Startup
% ==================================================================

    function autoStart()
        setBusy(true, 'Starting cameras...');
        try
            logmsg('Resetting image acquisition hardware...');
            imaqreset;
            delete(imaqfind);

            [adaptorOK, adaptorMsgs] = mousecamCheckAdaptor(cfg.adaptor);
            for k = 1:numel(adaptorMsgs)
                logmsg('%s', adaptorMsgs{k});
            end
            if ~adaptorOK
                error('mousecam:noAdaptor', ...
                    'Cameras are not reachable - see the messages above.');
            end

            ensureHelpers(HELPER_DIR);

            if exist(st.outDir, 'dir') ~= 7
                [made, mkMsg] = mkdir(st.outDir);
                if made
                    logmsg('Created output folder %s', st.outDir);
                else
                    error('mousecam:noOutDir', ...
                        'Cannot create output folder %s (%s)', st.outDir, mkMsg);
                end
            end
            logmsg('Saving to: %s', st.outDir);

            if exist(st.docidFile, 'file') == 2
                logmsg('Spreadsheet config: %s', st.docidFile);
            else
                logmsg('Spreadsheet config NOT FOUND at %s', st.docidFile);
                logmsg('Day lookup will not work - type the day in by hand.');
            end

            if numSlaves > 0
                logmsg('Starting parallel pool (%d worker)...', numSlaves);
                n = mousecamPoolInit(numSlaves);
                logmsg('Pool ready with %d worker(s).', n);
            end

            createCameras();
            resolveCameraChoice();
            startPreviews();

            st.state = 'preview';
            logmsg('Ready. Type the mouse name and press Enter.');
            focusMouseName();
        catch err
            logmsg('ERROR: %s', err.message);
            safeCleanup();
            st.state = 'idle';
        end
        setBusy(false);
        updateUI();
    end

% ==================================================================
%  Controls
% ==================================================================

    function ensureHelpers(helperDir)
        % GetSheetIDs and GetGoogleSpreadsheet are yours, not part of this
        % app.  Running from MATLAB they have to be on the path; compiled,
        % they are packaged inside the program and this check is skipped.
        if isdeployed
            return
        end

        needed  = {'GetSheetIDs', 'GetGoogleSpreadsheet'};
        missing = needed(cellfun(@(f) isempty(which(f)), needed));
        if isempty(missing)
            % Say which copy is being used - a stale one elsewhere on the
            % path is a common cause of odd failures.
            for k = 1:numel(needed)
                logmsg('Using %s', which(needed{k}));
            end
            return
        end

        if exist(helperDir, 'dir') == 7
            addpath(genpath(helperDir));
            missing = needed(cellfun(@(f) isempty(which(f)), needed));
            if isempty(missing)
                logmsg('Added %s to the path for the spreadsheet helpers.', helperDir);
                return
            end
        end

        logmsg('Cannot find: %s', strjoin(missing, ', '));
        logmsg('Set HELPER_DIR at the top of mousecamApp.m to the folder holding them.');
        logmsg('Until then, type the day in by hand.');
    end

    function onMouseNameEntered(~, ~)
        % First Enter looks the day up on the Google Sheet.  A second Enter
        % on the same name starts the recording, so the whole thing is
        % name, Enter, Enter without reaching for the mouse.
        mouseName = strtrim(get(hMouse, 'String'));
        refreshFileLabel();
        if isempty(mouseName)
            return
        end

        if strcmp(mouseName, st.lookedUp)
            onStartRecording();
            return
        end

        setBusy(true, 'Reading Google Sheet...');
        [dayStr, msg] = mousecamGetDay(st.docidFile, mouseName, cfg.dayColumn);
        if ~isempty(dayStr)
            set(hDay, 'String', dayStr);
        end
        logmsg('%s', msg);

        st.lookedUp = mouseName;
        refreshFileLabel();
        setBusy(false);
        updateUI();
        logmsg('Press Enter again to start recording.');
        focusMouseName();
    end

    function onDayEdited(~, ~)
        refreshFileLabel();
        updateUI();
    end

    function onPickCamera(src, ~)
        % The two eyes always hold different cameras, so changing one
        % flips the other.
        if ~strcmp(st.state, 'preview')
            set(hPick(1), 'Value', st.leftCam);
            set(hPick(2), 'Value', st.rightCam);
            return
        end

        which = get(src, 'UserData');
        if isequal(which, 1)
            st.leftCam  = get(hPick(1), 'Value');
            st.rightCam = otherCamera(st.leftCam, cfg.numCams);
        else
            st.rightCam = get(hPick(2), 'Value');
            st.leftCam  = otherCamera(st.rightCam, cfg.numCams);
        end
        set(hPick(1), 'Value', st.leftCam);
        set(hPick(2), 'Value', st.rightCam);

        st.savedLeftID = st.camID{st.leftCam};
        setpref('mousecam', 'leftCameraID', st.savedLeftID);

        logmsg('Left eye = %s', st.camLabel{st.leftCam});
        logmsg('Right eye = %s', st.camLabel{st.rightCam});
        layoutPreviews();
    end

% ==================================================================
%  Recording
% ==================================================================

    function onStartRecording(~, ~)
        if ~strcmp(st.state, 'preview')
            return
        end
        mouseName = strtrim(get(hMouse, 'String'));
        if isempty(mouseName)
            logmsg('Enter a mouse name first.');
            focusMouseName();
            return
        end

        base = mousecamFileBase(mouseName, strtrim(get(hDay, 'String')));
        if fileClash(base)
            btn = questdlg(sprintf(['Files starting "%s" already exist in the ' ...
                'output folder. Overwrite?'], base), 'Overwrite?', ...
                'Overwrite', 'Cancel', 'Cancel');
            if ~strcmp(btn, 'Overwrite')
                return
            end
        end

        setBusy(true, 'Arming cameras...');
        try
            st.base = base;

            stopPreviews();

            % The left eye stays in this process and writes _1.
            % The right eye goes to the worker and writes _2.
            for k = 1:cfg.numCams
                if k ~= st.leftCam && ~isempty(st.vid{k}) && isvalid(st.vid{k})
                    delete(st.vid{k});
                    st.vid{k} = [];
                end
            end

            v = st.vid{st.leftCam};
            vw = VideoWriter(fullfile(st.outDir, [base '_1.mp4']), 'MPEG-4');
            vw.FrameRate = cfg.frameRate;
            fps          = vw.FrameRate;
            v.DiskLogger = vw;
            v.TriggerFcn = @logTrialMarks;

            triggerconfig(v, 'hardware');
            s = getselectedsource(v);
            s.TriggerMode       = 'On';
            s.TriggerActivation = 'RisingEdge';
            s.TriggerDelay      = 0;
            s.TriggerSelector   = 'FrameStart';
            s.TriggerSource     = triggerSource();

            trialStarts   = struct([]);
            trialEnds     = struct([]);
            lastEventTime = 0;

            start(v);
            logmsg('LEFT eye  = %s  ->  %s_1.mp4', st.camLabel{st.leftCam}, base);

            if numSlaves > 0
                wantSerial = st.camID{st.rightCam};
                [st.vComposite, gotSerial] = mousecamSlaveStart(cfg, st.isBasler, ...
                    roiFor(st.isBasler), cfg.exposureTime, st.outDir, base, wantSerial);
                logmsg('RIGHT eye = %s  ->  %s_2.mp4', st.camLabel{st.rightCam}, base);
                if ~isempty(gotSerial) && ~strcmp(gotSerial, wantSerial)
                    logmsg('*** WARNING: worker opened S/N %s, expected %s ***', ...
                        gotSerial, wantSerial);
                end
            end

            st.state = 'recording';
            startTicker();
            logmsg('WAITING FOR HARDWARE TRIGGER.');
            logmsg('Close this window when the session is over.');
        catch err
            logmsg('ERROR: %s', err.message);
            safeCleanup();
            st.state = 'idle';
        end
        setBusy(false);
        updateUI();
    end

    function finalizeRecording()
        % Stop everything, wait for the files to finish writing, save the
        % MAT file.  Called when the window is closed.
        stopTicker();
        setBusy(true, 'Finishing video files...');

        framesAcquiredLogged = zeros(cfg.numCams, 2);
        try
            v = st.vid{st.leftCam};
            stop(v);

            t0 = tic;
            while strcmp(get(v, 'Logging'), 'on') && toc(t0) < cfg.flushTimeout
                set(hCounts, 'String', sprintf('Finishing %d / %d', ...
                    get(v, 'FramesAcquired'), get(v, 'DiskLoggerFrameCount')));
                pause(0.5); drawnow;
            end
            while (get(v, 'FramesAcquired') ~= get(v, 'DiskLoggerFrameCount')) ...
                    && toc(t0) < cfg.flushTimeout
                pause(0.5); drawnow;
            end
            framesAcquiredLogged(1, :) = [get(v, 'FramesAcquired') ...
                                          get(v, 'DiskLoggerFrameCount')];

            if numSlaves > 0
                logmsg('Waiting for the right eye to finish...');
                counts = mousecamSlaveStop(st.vComposite, numSlaves, cfg.flushTimeout);
                framesAcquiredLogged(2:end, :) = counts;
            end

            matFile = fullfile(st.outDir, [st.base '.mat']);
            mousecamSaveSession(matFile, trialStarts, trialEnds, framesAcquiredLogged);

            eyes = {'left', 'right'};
            for i = 1:size(framesAcquiredLogged, 1)
                dropped = framesAcquiredLogged(i, 1) - framesAcquiredLogged(i, 2);
                logmsg('  %s eye: %d acquired / %d written%s', eyes{min(i, 2)}, ...
                    framesAcquiredLogged(i, 1), framesAcquiredLogged(i, 2), ...
                    dropStr(dropped));
            end
            logmsg('Trial marks: %d start(s), %d end(s).', ...
                numel(trialStarts), numel(trialEnds));
            logmsg('Saved %s', matFile);
            drawnow;
        catch err
            logmsg('ERROR while finishing: %s', err.message);
            drawnow;
        end
    end

% ==================================================================
%  Closing
% ==================================================================

    function onClose(~, ~)
        if strcmp(st.state, 'closing')
            return
        end
        wasRecording = strcmp(st.state, 'recording');
        st.state = 'closing';
        updateUI();

        if wasRecording
            finalizeRecording();
        end

        stopTicker();
        safeCleanup();

        p = gcp('nocreate');
        if ~isempty(p)
            delete(p);
        end
        delete(fig);
    end

% ==================================================================
%  Hardware
% ==================================================================

    function createCameras()
        % Pass 1: the reboot workaround.  On the first run after a reboot
        % the video comes back larger than the ROI, making huge files at
        % two different resolutions.  Setting binning, then the ROI, then
        % deleting the object fixes it.  DO NOT REMOVE.
        for i = 1:cfg.numCams
            v = videoinput(cfg.adaptor, i, cfg.format);
            s = getselectedsource(v);
            if strcmp(get(s, 'DeviceVendorName'), 'Basler')
                s.BinningHorizontal = cfg.binSize;
                s.BinningVertical   = cfg.binSize;
            end
            v.ROIPosition = roiFor(strcmp(get(s, 'DeviceVendorName'), 'Basler'));
            delete(v);
        end

        % Pass 2: the objects we keep.
        for i = 1:cfg.numCams
            v = videoinput(cfg.adaptor, i, cfg.format);
            s = getselectedsource(v);

            v.FramesPerTrigger   = 1;
            v.LoggingMode        = 'disk';
            v.ReturnedColorspace = 'grayscale';
            v.TriggerRepeat      = Inf;

            isB = strcmp(get(s, 'DeviceVendorName'), 'Basler');
            v.ROIPosition  = roiFor(isB);
            s.ExposureTime = cfg.exposureTime;

            st.vid{i} = v;
            if i == 1
                st.isBasler = isB;
            end

            [st.camID{i}, st.camLabel{i}] = mousecamCameraIdentity(s, i);

            roi = get(v, 'ROIPosition');
            logmsg('%s, ROI [%d %d %d %d].', st.camLabel{i}, ...
                roi(1), roi(2), roi(3), roi(4));
        end
    end

    function resolveCameraChoice()
        % Match the remembered serial number against the cameras that are
        % actually here.  If it is not among them (camera swapped out, or
        % first ever run) fall back to the first one.
        idx = [];
        if ~isempty(st.savedLeftID)
            idx = find(strcmp(st.camID, st.savedLeftID), 1);
        end

        if isempty(idx)
            if ~isempty(st.savedLeftID)
                logmsg('Remembered left camera (%s) is not connected.', st.savedLeftID);
            end
            st.leftCam = 1;
        else
            st.leftCam = idx;
        end
        st.rightCam = otherCamera(st.leftCam, cfg.numCams);

        set(hPick(1), 'String', st.camLabel, 'Value', st.leftCam);
        set(hPick(2), 'String', st.camLabel, 'Value', st.rightCam);

        logmsg('Left eye = %s', st.camLabel{st.leftCam});
        logmsg('Right eye = %s', st.camLabel{st.rightCam});
    end

    function startPreviews()
        % Create one image per camera in that camera's own axes and start
        % the live feed.  Called once, at startup.
        for k = 1:cfg.numCams
            if isempty(st.vid{k}) || ~isvalid(st.vid{k})
                continue
            end
            v   = st.vid{k};
            roi = get(v, 'ROIPosition');
            st.himg{k} = image(zeros(roi(4), roi(3), 'uint8'), 'Parent', ax(k));
            axis(ax(k), 'image');
            set(ax(k), 'XTick', [], 'YTick', [], 'Box', 'on', 'Visible', 'on');
            preview(v, st.himg{k});
        end
        layoutPreviews();
        drawnow;
    end

    function layoutPreviews()
        % Park each camera's axes in the slot for the eye it is assigned
        % to.  No preview is stopped or restarted here - that is exactly
        % what used to kill the live image when the eyes were swapped.
        camForEye = [st.leftCam st.rightCam];
        for e = 1:2
            k = camForEye(e);
            if k < 1 || k > cfg.numCams || ~ishandle(ax(k))
                continue
            end
            set(ax(k), 'Position', slotPos(e));
            ttl = title(ax(k), eyeName{e});
            set(ttl, 'FontSize', 11, 'FontWeight', 'bold', 'Visible', 'on');
        end
    end

    function pos = slotPos(e)
        pos = [axGap + (e-1)*(axW + axGap), 0.17, axW, 0.72];
    end

    function stopPreviews()
        for k = 1:cfg.numCams
            if ~isempty(st.vid{k}) && isvalid(st.vid{k})
                try
                    stoppreview(st.vid{k});
                catch
                end
            end
        end
    end

    function roi = roiFor(isB)
        if isB
            roi = [cfg.roiOriginBasler cfg.roiWidth cfg.roiHeight];
        else
            roi = [cfg.roiOriginOther cfg.roiWidth cfg.roiHeight];
        end
    end

    function src = triggerSource()
        if st.isBasler
            src = cfg.triggerSourceBasler;
        else
            src = cfg.triggerSourceOther;
        end
    end

    function safeCleanup()
        try
            for k = 1:cfg.numCams
                if ~isempty(st.vid{k}) && isvalid(st.vid{k})
                    v = st.vid{k};
                    try
                        stoppreview(v);
                    catch
                    end
                    try
                        if strcmp(get(v, 'Running'), 'on')
                            stop(v);
                        end
                    catch
                    end
                    delete(v);
                end
                st.vid{k} = [];
            end
        catch
        end

        if numSlaves > 0
            mousecamSlaveCleanup(st.vComposite, numSlaves);
            st.vComposite = [];
        end

        try
            imaqreset;
        catch
        end
    end

% ==================================================================
%  Interface helpers
% ==================================================================

    function focusMouseName()
        try
            uicontrol(hMouse);
        catch
        end
    end

    function startTicker()
        stopTicker();
        st.tmr = timer('ExecutionMode', 'fixedSpacing', 'Period', 1, ...
            'BusyMode', 'drop', 'TimerFcn', @onTick);
        start(st.tmr);
    end

    function stopTicker()
        if ~isempty(st.tmr) && isvalid(st.tmr)
            try
                stop(st.tmr);
            catch
            end
            delete(st.tmr);
        end
        st.tmr = [];
    end

    function onTick(~, ~)
        try
            k = st.leftCam;
            if ~isempty(st.vid{k}) && isvalid(st.vid{k})
                v = st.vid{k};
                set(hCounts, 'String', sprintf('%d / %d frames', ...
                    get(v, 'FramesAcquired'), get(v, 'DiskLoggerFrameCount')));
            end
        catch
        end
    end

    function onLogClick(~, ~)
        if strcmp(get(fig, 'SelectionType'), 'open')
            onShowLogLine();
        end
    end

    function onShowLogLine(~, ~) %#ok<DEFNU>
        entries = get(hLog, 'String');
        if isempty(entries)
            return
        end
        idx = get(hLog, 'Value');
        if isempty(idx) || idx < 1 || idx > numel(entries)
            return
        end
        msgbox(entries{idx}, 'Log message', 'none', 'modal');
    end

    function onCopyLog(~, ~)
        entries = get(hLog, 'String');
        if isempty(entries)
            return
        end
        try
            clipboard('copy', sprintf('%s\n', entries{:}));
            logmsg('Log copied to the clipboard.');
        catch err
            logmsg('Could not copy: %s', err.message);
        end
    end

    function refreshFileLabel()
        base = mousecamFileBase(strtrim(get(hMouse, 'String')), ...
                                strtrim(get(hDay, 'String')));
        if isempty(base)
            set(hFileTxt, 'String', 'Files: (none)');
        else
            set(hFileTxt, 'String', sprintf(...
                'Files: %s_1.mp4 (left), %s_2.mp4 (right), %s.mat', base, base, base));
        end
    end

    function tf = fileClash(base)
        tf = exist(fullfile(st.outDir, [base '_1.mp4']), 'file') == 2 || ...
             exist(fullfile(st.outDir, [base '_2.mp4']), 'file') == 2;
    end

    function updateUI()
        isPrev = strcmp(st.state, 'preview');
        isRec  = strcmp(st.state, 'recording');
        isShut = strcmp(st.state, 'closing');

        haveName = ~isempty(strtrim(get(hMouse, 'String')));

        set(hRecord,  'Enable', onoff(isPrev && haveName));
        set(hMouse,   'Enable', onoff(isPrev));
        set(hDay,     'Enable', onoff(isPrev));
        set(hPick(1), 'Enable', onoff(isPrev));
        set(hPick(2), 'Enable', onoff(isPrev));

        if isShut
            set(hStatus, 'String', 'Closing...', 'ForegroundColor', [0 0 0.6]);
        elseif isRec
            set(hStatus, 'String', 'RECORDING', 'ForegroundColor', [0.7 0 0]);
            set(hRecord, 'String', 'Recording...');
        elseif isPrev
            set(hStatus, 'String', 'Preview', 'ForegroundColor', [0 0.4 0]);
        else
            set(hStatus, 'String', 'Not running', 'ForegroundColor', [0.6 0 0]);
        end
        drawnow;
    end

    function setBusy(tf, msg)
        if tf
            set(fig, 'Pointer', 'watch');
            if nargin > 1
                set(hStatus, 'String', msg, 'ForegroundColor', [0 0 0.6]);
            end
        else
            set(fig, 'Pointer', 'arrow');
        end
        drawnow;
    end

    function logmsg(fmt, varargin)
        line = sprintf(['[%s] ' fmt], datestr(now, 'HH:MM:SS'), varargin{:});
        entries = get(hLog, 'String');
        if ~iscell(entries)
            entries = {};
        end
        entries{end+1} = line; %#ok<AGROW>
        if numel(entries) > 500
            entries = entries(end-499:end);
        end
        % Only three lines show; the rest are still there to scroll back to.
        set(hLog, 'String', entries, 'Value', numel(entries), ...
            'ListboxTop', max(1, numel(entries) - 2));
        drawnow;
    end
end

% ======================================================================
%  Local helpers
% ======================================================================

function k = otherCamera(k, numCams)
%OTHERCAMERA  With two cameras, the one that is not K.
if k == 1
    k = min(2, numCams);
else
    k = 1;
end
end

function s = onoff(tf)
if tf
    s = 'on';
else
    s = 'off';
end
end

function s = dropStr(dropped)
if dropped > 0
    s = sprintf('   *** %d NOT WRITTEN ***', dropped);
else
    s = '';
end
end
