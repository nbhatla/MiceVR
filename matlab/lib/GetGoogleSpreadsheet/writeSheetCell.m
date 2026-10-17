function writeSheetCell(docid, gid, row, col, text)
%WRITESHEETCELL  Write one cell of a Google spreadsheet.
%
%   WRITESHEETCELL(DOCID, GID, ROW, COL, TEXT)
%
%   [DOCID] the spreadsheet id, from its url
%   [GID]   the sheet id, as returned by GetSheetIDs
%   [ROW]   row number (1 = first row)
%   [COL]   column number (1 = column A)
%   [TEXT]  what to put in the cell; written exactly as given (RAW), so
%           something like '12/3/45' is never turned into a date
%
%   Uses the same service-account login as GetGoogleSpreadsheet, acting as
%   IMPERSONATE.  Retries automatically if Google rate-limits (429) or is
%   briefly unavailable (5xx).  Throws an error with Google's explanation
%   if the write is refused.
%
%   Written for R2017b; works compiled.

% ==================================================================
%  SETTINGS (same as GetGoogleSpreadsheet / GetSheetIDs)
% ==================================================================
KEY_FILE    = char(fullfile(getPathConfigFolder(), 'gcp_key.json'));
SCOPE       = 'https://www.googleapis.com/auth/spreadsheets';
IMPERSONATE = 'script-runner@iam.science';
% ==================================================================

if isstring(text)
    text = char(text);
end
if isnumeric(text)
    text = num2str(text);
end

token = getToken(KEY_FILE, SCOPE, IMPERSONATE);
title = sheetTitle(docid, gid, token);

a1    = [quoteRange(title) '!' colLetters(col) num2str(row)];
url   = sprintf( ...
    'https://sheets.googleapis.com/v4/spreadsheets/%s/values/%s?valueInputOption=RAW', ...
    docid, pctEncode(a1));

% No "range" field in the body: it is optional, and leaving it out means
% Google has nothing to compare against the range in the URL.
body.majorDimension = 'ROWS';
body.values         = {{text}};          % -> [["text"]]

% Send the JSON as raw UTF-8 bytes.  Given a char body with a JSON content
% type, R2017b encodes it a second time - turning the object into one big
% quoted string, which Google rejects ("Root element must be a message").
% Setting Payload directly sends the bytes exactly as they are.
msgBody = matlab.net.http.MessageBody();
msgBody.Payload = unicode2native(jsonencode(body), 'UTF-8');

req = matlab.net.http.RequestMessage('PUT', ...
    [bearerField(token), ...
     matlab.net.http.HeaderField('Content-Type', 'application/json; charset=UTF-8')], ...
    msgBody);

% 'literal' stops MATLAB re-encoding the already-encoded URL; otherwise the
% %21 for '!' goes out as %2521 and Google sees the range "BROWNIE%21Y171".
sendWithRetry(req, matlab.net.URI(url, 'literal'));
end

% ======================================================================
function resp = sendWithRetry(req, url)
%SENDWITHRETRY  Send, waiting 2, 4, 8 ... 64 s between tries on 429 / 5xx.
waits = [2 4 8 16 32 64];
opts  = matlab.net.http.HTTPOptions('ConnectTimeout', 30);
for attempt = 1:numel(waits) + 1
    resp = req.send(url, opts);
    code = double(resp.StatusCode);
    if code >= 200 && code < 300
        return
    end
    retryable = any(code == [429 500 502 503 504]);
    if ~retryable || attempt > numel(waits)
        error('writeSheetCell:failed', ...
            'Google refused the write (HTTP %d).\n%s', code, bodyText(resp));
    end
    w = waits(attempt) + rand();
    fprintf('Google Sheets busy (HTTP %d). Retrying write in %.0f s...\n', code, w);
    pause(w);
end
end

% ======================================================================
function title = sheetTitle(docid, gid, token)
%SHEETTITLE  gid -> sheet title, cached per spreadsheet.
persistent cache
if isempty(cache)
    cache = containers.Map('KeyType', 'char', 'ValueType', 'any');
end
key = sprintf('%d', round(double(gid)));

if isKey(cache, docid)
    titles = cache(docid);
    if isKey(titles, key)
        title = titles(key);
        return
    end
end

req  = matlab.net.http.RequestMessage('GET', bearerField(token));
resp = sendWithRetry(req, sprintf( ...
    'https://sheets.googleapis.com/v4/spreadsheets/%s?fields=sheets.properties', docid));

meta = resp.Body.Data;
if ischar(meta)
    meta = jsondecode(meta);
end

titles = containers.Map('KeyType', 'char', 'ValueType', 'char');
sheets = meta.sheets;
for i = 1:numel(sheets)
    if iscell(sheets)
        props = sheets{i}.properties;
    else
        props = sheets(i).properties;
    end
    titles(sprintf('%d', round(double(props.sheetId)))) = props.title;
end
cache(docid) = titles;

if ~isKey(titles, key)
    error('writeSheetCell:noSuchSheet', 'No sheet with id %s in that spreadsheet.', key);
end
title = titles(key);
end

% ======================================================================
function f = bearerField(token)
%BEARERFIELD  "Authorization: Bearer <token>" header.
%   HeaderField('Authorization', ...) makes MATLAB parse the value with its
%   own AuthorizationField rules, which in R2017b reject Google's tokens.
%   GenericField sends the text exactly as given.
f = matlab.net.http.field.GenericField('Authorization', ['Bearer ' token]);
end

% ======================================================================
function s = colLetters(col)
%COLLETTERS  1 -> A, 25 -> Y, 28 -> AB, ...
s = '';
while col > 0
    r = mod(col - 1, 26);
    s = [char('A' + r) s]; %#ok<AGROW>
    col = floor((col - 1) / 26);
end
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
    error('writeSheetCell:noKey', 'Missing key file: %s', keyFile);
end

k           = jsondecode(fileread(keyFile));
clientEmail = k.client_email;
tokenURL    = k.token_uri;

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

req = matlab.net.http.RequestMessage('POST', ...
    matlab.net.http.HeaderField('Content-Type', ...
        'application/x-www-form-urlencoded'), ...
    ['grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer' ...
     '&assertion=' assertion]);

resp = req.send(tokenURL, matlab.net.http.HTTPOptions('ConnectTimeout', 30));

if resp.StatusCode ~= matlab.net.http.StatusCode.OK
    error('writeSheetCell:tokenRejected', ...
        'Google rejected the token request (HTTP %d).\n%s', ...
        double(resp.StatusCode), bodyText(resp));
end

b = resp.Body.Data;
if ischar(b)
    b = jsondecode(b);
end
if ~isfield(b, 'access_token')
    error('writeSheetCell:noToken', 'No access token: %s', bodyText(resp));
end

token = b.access_token;
if isfield(b, 'expires_in')
    life = double(b.expires_in);
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
if isempty(regexp(title, '^\w+$', 'once'))
    r = ['''' strrep(title, '''', '''''') ''''];
else
    r = title;
end
end

% ======================================================================
function out = pctEncode(str)
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