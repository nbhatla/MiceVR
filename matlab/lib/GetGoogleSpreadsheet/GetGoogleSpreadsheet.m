function result = GetGoogleSpreadsheet(docid, gid)
% result = GetGoogleSpreadsheet(DOCID, GID)
% Read one sheet of a google spreadsheet into a Matlab cell array.
%
% [DOCID] the spreadsheet id, from its url
% [GID]   the sheet id, as returned by GetSheetIDs
%
% [result] cell array of the values in the spreadsheet, padded to a
%          rectangle with empty strings
%
% The original version downloaded the public CSV export url, which needs
% the spreadsheet shared with "anyone with the link".  That is no longer
% allowed here, so this reads through the Sheets API as the service
% account instead.  Self contained - nothing else changes.
%
% Written for R2017b.

% ==================================================================
%  SETTINGS
% ==================================================================
KEY_FILE    = 'C:\Users\IAM\Documents\MVR\config\gcp_key.json';
SCOPE       = 'https://www.googleapis.com/auth/spreadsheets';
IMPERSONATE = 'script-runner@iam.science';
% ==================================================================

result = {};

token = getToken(KEY_FILE, SCOPE, IMPERSONATE);

% ---- gid -> sheet title ------------------------------------------
% The values endpoint addresses sheets by name, not by gid.
meta = webread(sprintf( ...
    'https://sheets.googleapis.com/v4/spreadsheets/%s?fields=sheets.properties', ...
    docid), authOpts(token));

title  = '';
sheets = meta.sheets;
for i = 1:numel(sheets)
    if iscell(sheets)
        props = sheets{i}.properties;
    else
        props = sheets(i).properties;
    end
    if isfield(props, 'sheetId') && double(props.sheetId) == double(gid)
        title = props.title;
        break
    end
end
if isempty(title)
    error('GetGoogleSpreadsheet:noSuchSheet', ...
        'No sheet with id %s in that spreadsheet.', num2str(gid));
end

% ---- read the cells ----------------------------------------------
data = webread(sprintf( ...
    'https://sheets.googleapis.com/v4/spreadsheets/%s/values/%s?majorDimension=ROWS', ...
    docid, pctEncode(quoteRange(title))), authOpts(token));

if ~isfield(data, 'values') || isempty(data.values)
    return
end

result = toCellGrid(data.values);
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
%   character strings.  Sheet rows can be ragged, so pad them.
if isempty(v) || ~iscell(v)
    C = {};
    return
end

if all(cellfun(@iscell, v(:)))
    nRows = numel(v);
    nCols = max(cellfun(@numel, v(:)));
    C = repmat({''}, nRows, max(nCols, 1));
    for i = 1:nRows
        row = v{i};
        for j = 1:numel(row)
            C{i, j} = toChar(row{j});
        end
    end
else
    C = cell(size(v));
    for i = 1:numel(v)
        C{i} = toChar(v{i});
    end
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