function [sheetIDs, sheetTitles] = GetSheetIDs(docid, mouseNames, dataSheetsOnly) %#ok<INUSD>
%GETSHEETIDS  Sheet ids from a Google spreadsheet, via a service account.
%
%   SHEETIDS = GETSHEETIDS(DOCID, MOUSENAMES, DATASHEETSONLY)
%
%   MOUSENAMES empty returns every data sheet; otherwise only the sheets
%   whose titles match, ignoring capitalization.  SHEETTITLES gives the
%   titles as they are actually spelled in the spreadsheet.
%
%   Self contained - no other new files needed.
%
%   Written for R2017b.

% ==================================================================
%  SETTINGS
% ==================================================================
KEY_FILE = 'C:\Users\IAM\Documents\MVR\config\gcp_key.json';

% Must match what is authorized for this service account's client id in the
% Workspace admin console, character for character.
SCOPE = 'https://www.googleapis.com/auth/spreadsheets';

% Domain-wide delegation: the service account acts as this user.
IMPERSONATE = 'script-runner@iam.science';
% ==================================================================

accessToken = getServiceToken(KEY_FILE, SCOPE, IMPERSONATE);

% ---- read the sheet list -----------------------------------------
% The query goes on the URL itself.  WEBOPTIONS gained a
% 'QueryParameters' option in a later release, so it cannot be used here.
dataURL = sprintf( ...
    'https://sheets.googleapis.com/v4/spreadsheets/%s?fields=sheets.properties', ...
    docid);

readOptions = weboptions( ...
    'HeaderFields', {'Authorization', ['Bearer ' accessToken]}, ...
    'ContentType',  'json', ...
    'Timeout',      30);

parsed = webread(dataURL, readOptions);

% ---- pick out the ids we want ------------------------------------
sheets      = parsed.sheets;
sheetIDs    = [];
sheetTitles = {};

for i = 1:length(sheets)
    if iscell(sheets)
        props = sheets{i}.properties;
    else
        props = sheets(i).properties;
    end
    sheetTitle = props.title;

    if isempty(sheetTitle)
        continue
    end

    % Skip underscore-prefixed sheets - those are not mouse data sheets.
    if sheetTitle(1) ~= '_'
        if isempty(mouseNames)
            sheetIDs(end+1)    = props.sheetId; %#ok<AGROW>
            sheetTitles{end+1} = sheetTitle;    %#ok<AGROW>
        else
            for j = 1:length(mouseNames)
                % Case-insensitive: trainers type "real", the sheet says
                % "Real", and that should still match.
                if strcmpi(sheetTitle, mouseNames{j})
                    sheetIDs(end+1)    = props.sheetId; %#ok<AGROW>
                    sheetTitles{end+1} = sheetTitle;    %#ok<AGROW>
                end
            end
        end
    end
end
end

% ======================================================================
function token = getServiceToken(keyFile, scope, impersonate)
%GETSERVICETOKEN  Sign a JWT with the service account key, swap it for an
%   access token.  Cached until shortly before it expires.

persistent cachedToken cachedExpiry

nowSecs = floor(double(java.lang.System.currentTimeMillis()) / 1000);
if ~isempty(cachedToken) && ~isempty(cachedExpiry) && nowSecs < cachedExpiry
    token = cachedToken;
    return
end

if exist(keyFile, 'file') ~= 2
    error('GoogleAuth:noKey', 'Missing key file: %s', keyFile);
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

body = fetchToken(tokenURL, assertion);

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
function resp = fetchToken(tokenURL, assertion)
%FETCHTOKEN  POST the signed JWT and return the decoded reply.
%
%   Tries three ways, because the compiled application does not behave like
%   MATLAB here.  In the runtime the CA certificate bundle sits inside the
%   MCR cache, and MATLAB.NET.HTTP can fail to read it - which surfaces as
%   "Permission denied" against the token URL even though the network is
%   fine.  WEBWRITE is more forgiving, so it goes first.

problems = {};

% --- 1. plain WEBWRITE ---------------------------------------------
try
    opts = weboptions('RequestMethod', 'post', 'ContentType', 'json', ...
        'Timeout', 30);
    resp = webwrite(tokenURL, ...
        'grant_type', 'urn:ietf:params:oauth:grant-type:jwt-bearer', ...
        'assertion', assertion, opts);
    if isstruct(resp) && isfield(resp, 'access_token')
        return
    end
    problems{end+1} = 'webwrite: no access_token in the reply';
catch err
    problems{end+1} = sprintf('webwrite: %s', err.message);
end

% --- 2. WEBWRITE without certificate checking ----------------------
try
    opts = weboptions('RequestMethod', 'post', 'ContentType', 'json', ...
        'Timeout', 30, 'CertificateFilename', '');
    resp = webwrite(tokenURL, ...
        'grant_type', 'urn:ietf:params:oauth:grant-type:jwt-bearer', ...
        'assertion', assertion, opts);
    if isstruct(resp) && isfield(resp, 'access_token')
        return
    end
    problems{end+1} = 'webwrite (no cert check): no access_token in the reply';
catch err
    problems{end+1} = sprintf('webwrite (no cert check): %s', err.message);
end

% --- 3. MATLAB.NET.HTTP, which can show what Google actually said ---
try
    req = matlab.net.http.RequestMessage('POST', ...
        matlab.net.http.HeaderField('Content-Type', ...
            'application/x-www-form-urlencoded'), ...
        ['grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer' ...
         '&assertion=' assertion]);

    r = req.send(tokenURL, matlab.net.http.HTTPOptions( ...
        'ConnectTimeout', 30, 'CertificateFilename', ''));

    b = r.Body.Data;
    if ischar(b)
        b = jsondecode(b);
    end

    if r.StatusCode == matlab.net.http.StatusCode.OK ...
            && isstruct(b) && isfield(b, 'access_token')
        resp = b;
        return
    end

    if isstruct(b)
        detail = jsonencode(b);
    else
        detail = char(string(b));
    end
    problems{end+1} = sprintf('http: %d %s', double(r.StatusCode), detail);
catch err
    problems{end+1} = sprintf('http: %s', err.message);
end

error('GoogleAuth:tokenFailed', ...
    ['Could not get an access token.\n  %s\nIf every attempt says ' ...
     'Permission denied, the program is being blocked from the network - ' ...
     'allow it through Windows Firewall and any endpoint security.'], ...
    strjoin(problems, sprintf('\n  ')));
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