function [id, label] = mousecamCameraIdentity(src, camNumber)
%MOUSECAMCAMERAIDENTITY  A stable unique id for a camera, plus a label.
%
%   [ID, LABEL] = MOUSECAMCAMERAIDENTITY(SRC, CAMNUMBER)
%
%   SRC is a video source object.  Tries the serial number first, since that
%   is the only thing that stays the same when cameras are unplugged,
%   swapped, or enumerated in a different order.  Falls back through the
%   other identifying properties, and finally to the position in the list.
%
%   This lives in its own file rather than inside the app because the
%   parallel worker needs it too, to confirm it has opened the right camera.

id    = '';
label = '';

if nargin < 2 || isempty(camNumber)
    camNumber = 0;
end

try
    props = fieldnames(get(src));
catch
    props = {};
end

wanted = {'DeviceSerialNumber', 'DeviceUserID', 'DeviceID', 'SerialNumber'};
for k = 1:numel(wanted)
    if any(strcmp(props, wanted{k}))
        try
            val = get(src, wanted{k});
        catch
            val = '';
        end
        if isnumeric(val)
            val = num2str(val);
        end
        if ischar(val) && ~isempty(strtrim(val))
            id = strtrim(val);
            break
        end
    end
end

model = '';
if any(strcmp(props, 'DeviceModelName'))
    try
        model = strtrim(get(src, 'DeviceModelName'));
    catch
        model = '';
    end
end

if isempty(id)
    id    = sprintf('position-%d', camNumber);
    label = sprintf('Cam %d  (no serial reported)', camNumber);
    return
end

if isempty(model)
    label = sprintf('Cam %d  -  S/N %s', camNumber, id);
else
    label = sprintf('Cam %d  -  %s  S/N %s', camNumber, model, id);
end
end
