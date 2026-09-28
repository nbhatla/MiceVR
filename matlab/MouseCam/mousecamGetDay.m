function [dayStr, msg] = mousecamGetDay(docidFile, mouseName, dayColumn)
%MOUSECAMGETDAY  Read the last completed day for a mouse from the Google Sheet.
%
%   [DAYSTR, MSG] = MOUSECAMGETDAY(DOCIDFILE, MOUSENAME, DAYCOLUMN)
%
%   Returns the day as a character string ('' if it could not be found) and a
%   human readable status message.  This function never throws: the GUI shows
%   MSG and lets the trainer type the day in by hand instead.

dayStr = '';
msg    = '';

if nargin < 3 || isempty(dayColumn)
    dayColumn = 1;
end

if strcmpi(mouseName, 'test') || ~isempty(strfind(mouseName, '_')) %#ok<STREMP>
    msg = 'Test/manual name - skipping spreadsheet lookup.';
    return
end

if isempty(docidFile) || exist(docidFile, 'file') ~= 2
    msg = 'Spreadsheet config (docid) file not found - set it with Browse.';
    return
end

fid = -1;
try
    fid = fopen(docidFile, 'r');
    if fid < 0
        msg = sprintf('Could not open %s', docidFile);
        return
    end
    docid = strtrim(fgetl(fid));
    fclose(fid);
    fid = -1;

    if isempty(docid) || ~ischar(docid)
        msg = 'Docid file is empty.';
        return
    end

    if isempty(which('GetSheetIDs')) || isempty(which('GetGoogleSpreadsheet'))
        msg = ['GetSheetIDs / GetGoogleSpreadsheet are not on the path. ' ...
               'Type the day in by hand.'];
        return
    end

    sheetID = GetSheetIDs(docid, {mouseName}, 1);   % data sheets only
    sheet   = GetGoogleSpreadsheet(docid, sheetID);

    lastDay = '';
    for row = 1:size(sheet, 1)
        d = sheet{row, dayColumn};
        if ischar(d) && ~isempty(d) && all(isstrprop(d, 'digit'))
            lastDay = d;    % keep overwriting -> ends up with the last one
        end
    end

    if isempty(lastDay)
        msg = 'No numeric day found in the sheet.';
        return
    end

    dayStr = lastDay;
    msg    = sprintf('Day %s read from Google Sheet.', dayStr);

catch err
    if fid >= 0
        fclose(fid);
    end
    % Google's refusals arrive as a wall of Java stack trace.  Pull out
    % the HTTP code and say what it means.  Anything else is reported
    % verbatim with its file and line - never paraphrased.
    code = regexp(err.message, 'response code: (\d+)', 'tokens', 'once');

    if ~isempty(code)
        switch code{1}
            case '403'
                msg = ['Google refused the request (403). Usually the sheet ' ...
                       'is no longer shared publicly, or the API key has been ' ...
                       'restricted or disabled.'];
            case '404'
                msg = ['Google could not find that spreadsheet (404). Check ' ...
                       'the id in the docid file.'];
            case '400'
                msg = 'Google rejected the request (400). The API key looks wrong.';
            case '429'
                msg = 'Google is rate limiting this key (429). Try again shortly.';
            otherwise
                msg = sprintf('Google returned HTTP %s.', code{1});
        end
        return
    end

    where = '';
    if ~isempty(err.stack)
        where = sprintf('  [in %s line %d]', err.stack(1).name, err.stack(1).line);
    end
    msg = sprintf('Lookup failed: %s%s', err.message, where);
end
end
