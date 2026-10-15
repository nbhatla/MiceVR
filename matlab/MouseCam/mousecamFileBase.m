function base = mousecamFileBase(mouseName, dayStr)
%MOUSECAMFILEBASE  Build the '<mouse>_<zero padded day>' file name stem.
%
%   If DAYSTR is empty the mouse name alone is returned, matching the
%   original behaviour when no spreadsheet was available.

% File names use a single consistent capitalization - first letter up, the
% rest down - so "real", "Real" and "REAL" all land on Real_027_1.mp4 and
% a season of recordings sorts and globs as one mouse.
base = capitalize(strtrim(mouseName));

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

% ======================================================================
function s = capitalize(s)
%CAPITALIZE  First character upper case, everything after it lower case.
if isempty(s)
    return
end
s = [upper(s(1)) lower(s(2:end))];
end
