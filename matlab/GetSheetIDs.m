function sheetIDs = GetSheetIDs(docid, mouseNames, dataSheetsOnly) %#ok<INUSD>
%GETSHEETIDS  Sheet ids from a Google spreadsheet, via a service account.
%
%   SHEETIDS = GETSHEETIDS(DOCID, MOUSENAMES, DATASHEETSONLY)
%
%   Authenticates with the service account in the key file below, then reads
%   the spreadsheet's sheet list.  MOUSENAMES empty returns every data sheet;
%   otherwise only the sheets whose titles match.
%
%   Written for R2017b.

% ==================================================================
%  SETTINGS
% ==================================================================
KEY_FILE = 'C:\Users\IAM\Documents\MVR\config\gcp_key.json';

% Real OAuth scope.  Must match what is authorized for the service account
% in the Workspace admin console, character for character.
SCOPE = 'https://www.googleapis.com/auth/spreadsheets';

% Domain-wide delegation: the service account acts as this user.  The
% client id of the service account must be authorized for SCOPE in the
% Workspace admin console, under Security > API controls > Domain-wide
% delegation.  If that is not in place Google answers unauthorized_client.
IMPERSONATE = 'script-runner@iam.science';
% ==================================================================

accessToken = getAccessToken(KEY_FILE, SCOPE, IMPERSONATE);

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
sheets   = parsed.sheets;
sheetIDs = [];

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

    % Skip underscore-prefixed and all-uppercase sheets - those are not
    % mouse data sheets.
    if sheetTitle(1) ~= '_' && ~strcmp(sheetTitle, upper(sheetTitle))
        if isempty(mouseNames)
            sheetIDs(end+1) = props.sheetId; %#ok<AGROW>
        else
            for j = 1:length(mouseNames)
                if strcmp(sheetTitle, mouseNames{j})
                    sheetIDs(end+1) = props.sheetId; %#ok<AGROW>
                end
            end
        end
    end
end
end

% ======================================================================
function accessToken = getAccessToken(keyFilePath, scope, impersonate)
%GETACCESSTOKEN  Sign a JWT with the service account key and swap it for a token.

if exist(keyFilePath, 'file') ~= 2
    error('GetSheetIDs:noKey', 'Missing key file: %s', keyFilePath);
end

keyData       = jsondecode(fileread(keyFilePath));
privateKeyPEM = keyData.private_key;
clientEmail   = keyData.client_email;
tokenURL      = keyData.token_uri;

% Epoch seconds in UTC.  NOW is local time, so using it directly puts iat
% hours out on any machine that is not on UTC and Google rejects the JWT.
nowSecs = floor(double(java.lang.System.currentTimeMillis()) / 1000);
iatSecs = nowSecs - 30;          % small backdate absorbs clock skew
expSecs = iatSecs + 3600;        % Google allows at most one hour

% Build the JSON by hand: JSONENCODE escapes forward slashes, which breaks
% the signature.
jsonHeader = '{"alg":"RS256","typ":"JWT"}';

if isempty(impersonate)
    jsonPayload = sprintf( ...
        '{"iss":"%s","scope":"%s","aud":"%s","exp":%d,"iat":%d}', ...
        clientEmail, scope, tokenURL, expSecs, iatSecs);
else
    jsonPayload = sprintf( ...
        '{"iss":"%s","scope":"%s","aud":"%s","exp":%d,"iat":%d,"sub":"%s"}', ...
        clientEmail, scope, tokenURL, expSecs, iatSecs, impersonate);
end

signingInput = [base64url(jsonHeader) '.' base64url(jsonPayload)];

% ---- sign with the private key -----------------------------------
keyPEM = strrep(privateKeyPEM, '-----BEGIN PRIVATE KEY-----', '');
keyPEM = strrep(keyPEM, '-----END PRIVATE KEY-----', '');
keyPEM = regexprep(keyPEM, '\s', '');        % newlines, spaces, stray CRs

keyBytes   = typecast(matlab.net.base64decode(keyPEM), 'int8');
keySpec    = java.security.spec.PKCS8EncodedKeySpec(keyBytes);
keyFactory = java.security.KeyFactory.getInstance('RSA');
privKey    = keyFactory.generatePrivate(keySpec);

sig = java.security.Signature.getInstance('SHA256withRSA');
sig.initSign(privKey);
sig.update(uint8(signingInput));
signatureBytes = sig.sign();

jwtAssertion = [signingInput '.' base64url(typecast(signatureBytes, 'uint8'))];

% ---- swap it for an access token ---------------------------------
% Sent with MATLAB.NET.HTTP rather than WEBWRITE so that a rejection can be
% read.  WEBWRITE throws away the response body, which is where Google puts
% the reason - that is why a failure here used to say only "Bad Request".
payload = ['grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer' ...
           '&assertion=' jwtAssertion];

req = matlab.net.http.RequestMessage( ...
    'POST', ...
    matlab.net.http.HeaderField('Content-Type', ...
        'application/x-www-form-urlencoded'), ...
    payload);

opts = matlab.net.http.HTTPOptions('ConnectTimeout', 30);
resp = req.send(tokenURL, opts);

if resp.StatusCode ~= matlab.net.http.StatusCode.OK
    error('GetSheetIDs:tokenRejected', ...
        'Google rejected the token request (HTTP %d).\n%s\n%s', ...
        double(resp.StatusCode), bodyText(resp), tokenHint(resp));
end

body = resp.Body.Data;
if ischar(body)
    body = jsondecode(body);
end
if ~isfield(body, 'access_token')
    error('GetSheetIDs:noToken', 'No access token came back: %s', bodyText(resp));
end
accessToken = body.access_token;
end

% ======================================================================
function txt = bodyText(resp)
%BODYTEXT  Whatever Google said, as readable text.
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
function hint = tokenHint(resp)
%TOKENHINT  Turn Google's error code into something actionable.
hint = '';
try
    t = lower(bodyText(resp));
catch
    return
end

if ~isempty(strfind(t, 'invalid_scope')) %#ok<STREMP>
    hint = 'SCOPE is not a real Google scope.';
elseif ~isempty(strfind(t, 'unauthorized_client')) %#ok<STREMP>
    hint = ['Domain-wide delegation is not authorized for this exact ' ...
            'scope. In the Workspace admin console add the service ' ...
            'account client id with SCOPE listed verbatim - the scope ' ...
            'string must match character for character.'];
elseif ~isempty(strfind(t, 'invalid_grant')) %#ok<STREMP>
    hint = ['Check the PC clock is correct, and that the impersonated ' ...
            'user exists and is active in the domain.'];
elseif ~isempty(strfind(t, 'invalid_client')) %#ok<STREMP>
    hint = 'The key file does not match a live service account.';
end
end

% ======================================================================
function out = base64url(inputData)
%BASE64URL  URL-safe base64 with the padding stripped (RFC 4648).
if ischar(inputData)
    inputData = strtrim(inputData);
end
b64 = matlab.net.base64encode(inputData);
b64 = strrep(b64, '+', '-');
b64 = strrep(b64, '/', '_');
out = strrep(b64, '=', '');
end