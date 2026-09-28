function base = mousecamFileBase(mouseName, dayStr)
%MOUSECAMFILEBASE  Build the '<mouse>_<zero padded day>' file name stem.
%
%   If DAYSTR is empty the mouse name alone is returned, matching the
%   original behaviour when no spreadsheet was available.

base = strtrim(mouseName);

if nargin < 2 || isempty(dayStr)
    return
end

dayStr = strtrim(dayStr);
d = str2double(dayStr);

if isnan(d)
    return
end

if d < 10
    prefix = '00';
elseif d < 100
    prefix = '0';
else
    prefix = '';
end

base = [base '_' prefix dayStr];
end
