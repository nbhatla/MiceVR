function result = GetGoogleSpreadsheet(docid, gid)
% result = GetGoogleSpreadsheet(DOCID, GID)
% Read one sheet of a google spreadsheet into a Matlab cell array.
%
% [DOCID] the spreadsheet id, from its url
% [GID]   the sheet id, as returned by GetSheetIDs
%
% [result] cell array of the values in the spreadsheet, padded to a
%          rectangle with empty strings (at least MIN_COLS wide)
%
% Reads through the Sheets API as the service account.
%
% Rate limits: Google allows roughly 60 read requests per minute per user.
% To stay under it, the sheet-id -> title lookup is done once and cached,
% so each call normally costs a single request.  If Google still answers
% 429 Too Many Requests (or a temporary 5xx), the request is retried with
% exponential backoff instead of failing.
%
% Written for R2017b.

% ==================================================================
%  SETTINGS
% ==================================================================
%KEY_FILE    = 'C:\Users\nikhi\IAM\RESEARCH\GAME\config\gcp_key.json';
KEY_FILE    = char(fullfile(getPathConfigFolder(), 'gcp_key.json'));
SCOPE       = 'https://www.googleapis.com/auth/spreadsheets';
IMPERSONATE = 'script-runner@iam.science';
MIN_COLS    = 28;   % scanSheetsToAnalyze reads column AB (28)
% ==================================================================

result = {};

token = getToken(KEY_FILE, SCOPE, IMPERSONATE);

% ---- gid -> sheet title (cached) ---------------------------------
title = sheetTitle(docid, gid, token, false);

% ---- read the cells ----------------------------------------------
try
    data = webreadRetry(valuesURL(docid, title), authOpts(token));
catch ME
    % A tab renamed since the title was cached gives 400 "Unable to parse
    % range".  Refresh the titles once and try again.
    if ~isempty(strfind(ME.message, '400')) %#ok<STREMP>
        title = sheetTitle(docid, gid, token, true);
        data  = webreadRetry(valuesURL(docid, title), authOpts(token));
    else
        rethrow(ME);
    end
end

if isfield(data, 'values') && ~isempty(data.values)
    result = toCellGrid(data.values);
end

% Trailing empty columns are not returned by the API; pad so fixed column
% positions always exist.
if isempty(result)
    result = repmat({''}, 1, MIN_COLS);
elseif size(result, 2) < MIN_COLS
    result(:, end+1:MIN_COLS) = {''};
end
end

% ======================================================================
function url = valuesURL(docid, title)
url = sprintf( ...
    'https://sheets.googleapis.com/v4/spreadsheets/%s/values/%s?majorDimension=ROWS', ...
    docid, pctEncode(quoteRange(title)));
end

% ======================================================================
function title = sheetTitle(docid, gid, token, forceRefresh)
%SHEETTITLE  Title of the sheet with this gid, from a per-spreadsheet cache.
%   The cache holds every sheet's title after one metadata request, so the
%   lookup costs nothing for the remaining sheets.

persistent cache    % containers.Map: docid -> containers.Map(gid string -> title)

if isempty(cache)
    cache = containers.Map('KeyType', 'char', 'ValueType', 'any');
end

key = sprintf('%d', round(double(gid)));

if ~forceRefresh && isKey(cache, docid)
    titles = cache(docid);
    if isKey(titles, key)
        title = titles(key);
        return
    end
end

% Fetch all sheet titles in one request
meta = webreadRetry(sprintf( ...
    'https://sheets.googleapis.com/v4/spreadsheets/%s?fields=sheets.properties', ...
    docid), authOpts(token));

titles = containers.Map('KeyType', 'char', 'ValueType', 'char');
sheets = meta.sheets;
for i = 1:numel(sheets)
    if iscell(sheets)
        props = sheets{i}.properties;
    else
        props = sheets(i).properties;
    end
    if isfield(props, 'sheetId') && isfield(props, 'title')
        titles(sprintf('%d', round(double(props.sheetId)))) = props.title;
    end
end
cache(docid) = titles;

if ~isKey(titles, key)
    error('GetGoogleSpreadsheet:noSuchSheet', ...
        'No sheet with id %s in that spreadsheet.', key);
end
title = titles(key);
end

% ======================================================================
function data = webreadRetry(url, opts)
%WEBREADRETRY  WEBREAD that waits and retries when Google is rate limiting
%   (429) or briefly unavailable (500, 502, 503, 504).
%   Waits 2, 4, 8, 16, 32, 64 s (plus a little jitter) - about two minutes
%   in total - which is more than enough for the per-minute quota to reset.

waits = [2 4 8 16 32 64];
for attempt = 1:numel(waits) + 1
    try
        data = webread(url, opts);
        return
    catch ME
        msg = ME.message;
        retryable = ~isempty(regexp(msg, 'status (429|500|502|503|504)', 'once')) || ...
                    ~isempty(strfind(msg, 'Too Many Requests')); %#ok<STREMP>
        if ~retryable || attempt > numel(waits)
            rethrow(ME);
        end
        w = waits(attempt) + rand();
        fprintf('Google Sheets busy (%s). Retrying in %.0f s...\n', ...
            firstLine(msg), w);
        pause(w);
    end
end
end

function s = firstLine(msg)
s = strtok(msg, sprintf('\n'));
if numel(s) > 80
    s = [s(1:77) '...'];
end
end

% ======================================================================
function opts = authOpts(token)
opts = weboptions( ...
    'HeaderFields', {'Authorization', ['Bearer ' token]}, ...
    'ContentType',  'json', ...
    'Timeout',      30);
end

% ======================================================================
function token = getToken(keyFile, scope, impersonate)
%GETTOKEN  Sign a JWT with the service account key and swap it for a token.

persistent cachedToken cachedExpiry

nowSecs = floor(double(java.lang.System.currentTimeMillis()) / 1000);
if ~isempty(cachedToken) && ~isempty(cachedExpiry) && nowSecs < cachedExpiry
    token = cachedToken;
    return
end

if exist(keyFile, 'file') ~= 2
    error('GetGoogleSpreadsheet:noKey', 'Missing key file: %s', keyFile);
end

k           = jsondecode(fileread(keyFile));
clientEmail = k.client_email;
tokenURL    = k.token_uri;

% Epoch seconds in UTC.  NOW is local time, which puts iat hours out on any
% machine not set to UTC, and Google then rejects the JWT.
iatSecs = nowSecs - 30;
expSecs = iatSecs + 3600;

% Built by hand - JSONENCODE escapes forward slashes and breaks the signature.
hdr = '{"alg":"RS256","typ":"JWT"}';
if isempty(impersonate)
    pay = sprintf('{"iss":"%s","scope":"%s","aud":"%s","exp":%d,"iat":%d}', ...
        clientEmail, scope, tokenURL, expSecs, iatSecs);
else
    pay = sprintf(['{"iss":"%s","scope":"%s","aud":"%s","exp":%d,"iat":%d,' ...
        '"sub":"%s"}'], clientEmail, scope, tokenURL, expSecs, iatSecs, impersonate);
end

signingInput = [b64url(hdr) '.' b64url(pay)];

pem = strrep(k.private_key, '-----BEGIN PRIVATE KEY-----', '');
pem = strrep(pem, '-----END PRIVATE KEY-----', '');
pem = regexprep(pem, '\s', '');

keySpec    = java.security.spec.PKCS8EncodedKeySpec( ...
                typecast(matlab.net.base64decode(pem), 'int8'));
keyFactory = java.security.KeyFactory.getInstance('RSA');
privKey    = keyFactory.generatePrivate(keySpec);

sig = java.security.Signature.getInstance('SHA256withRSA');
sig.initSign(privKey);
sig.update(uint8(signingInput));
assertion = [signingInput '.' b64url(typecast(sig.sign(), 'uint8'))];

% MATLAB.NET.HTTP rather than WEBWRITE, because WEBWRITE throws away the
% response body - which is where Google explains any rejection.
req = matlab.net.http.RequestMessage('POST', ...
    matlab.net.http.HeaderField('Content-Type', ...
        'application/x-www-form-urlencoded'), ...
    ['grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer' ...
     '&assertion=' assertion]);

resp = req.send(tokenURL, matlab.net.http.HTTPOptions('ConnectTimeout', 30));

if resp.StatusCode ~= matlab.net.http.StatusCode.OK
    error('GetGoogleSpreadsheet:tokenRejected', ...
        'Google rejected the token request (HTTP %d).\n%s', ...
        double(resp.StatusCode), bodyText(resp));
end

body = resp.Body.Data;
if ischar(body)
    body = jsondecode(body);
end
if ~isfield(body, 'access_token')
    error('GetGoogleSpreadsheet:noToken', 'No access token: %s', bodyText(resp));
end

token = body.access_token;
if isfield(body, 'expires_in')
    life = double(body.expires_in);
else
    life = 3600;
end
cachedToken  = token;
cachedExpiry = nowSecs + life - 120;
end

% ======================================================================
function txt = bodyText(resp)
try
    d = resp.Body.Data;
    if ischar(d)
        txt = d;
    elseif isstruct(d)
        txt = jsonencode(d);
    else
        txt = char(string(d));
    end
catch
    txt = '(no response body)';
end
end

% ======================================================================
function out = b64url(x)
if ischar(x)
    x = strtrim(x);
end
b = matlab.net.base64encode(x);
b = strrep(b, '+', '-');
b = strrep(b, '/', '_');
out = strrep(b, '=', '');
end

% ======================================================================
function r = quoteRange(title)
%QUOTERANGE  A1 notation needs the sheet name quoted unless it is a plain word.
if isempty(regexp(title, '^\w+$', 'once'))
    r = ['''' strrep(title, '''', '''''') ''''];
else
    r = title;
end
end

% ======================================================================
function out = pctEncode(str)
%PCTENCODE  For a url path segment.  URLENCODE turns spaces into '+', which
%   is wrong here, so do it by hand.
out = '';
for k = 1:numel(str)
    c = str(k);
    if isstrprop(c, 'alphanum') || any(c == '-_.~')
        out(end+1) = c; %#ok<AGROW>
    else
        out = [out sprintf('%%%02X', double(c))]; %#ok<AGROW>
    end
end
end

% ======================================================================
function C = toCellGrid(v)
%TOCELLGRID  Whatever JSONDECODE returned, as a rectangular cell array of
%   character strings.  Rows can be ragged, and blank rows come back as []
%   (an empty double, not a cell), so normalise every row first.
if isempty(v)
    C = {};
    return
end
if ~iscell(v)
    v = {v};
end

rows = cell(numel(v), 1);
for i = 1:numel(v)
    r = v{i};
    if iscell(r)
        rows{i} = cellfun(@toChar, r(:)', 'UniformOutput', false);
    elseif ischar(r)
        rows{i} = {r};                     % row with a single cell of text
    elseif isempty(r)
        rows{i} = {};                      % blank row
    elseif isnumeric(r) || islogical(r)
        rows{i} = arrayfun(@toChar, r(:)', 'UniformOutput', false);
    else
        rows{i} = {''};
    end
end

nCols = max([1; cellfun(@numel, rows)]);
C = repmat({''}, numel(rows), nCols);
for i = 1:numel(rows)
    C(i, 1:numel(rows{i})) = rows{i};
end
end

% ======================================================================
function s = toChar(x)
if ischar(x)
    s = x;
elseif isnumeric(x) && isscalar(x)
    s = num2str(x);
elseif islogical(x) && isscalar(x)
    if x
        s = 'TRUE';
    else
        s = 'FALSE';
    end
else
    s = '';
end
end