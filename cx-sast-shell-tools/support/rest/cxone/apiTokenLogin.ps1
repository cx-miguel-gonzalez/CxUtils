param(
    [System.Uri]$cx1TokenURL,
    [System.Uri]$cx1URL,
    [System.Uri]$cx1IamURL,
    [string]$cx1Tenant,
    [String]$PAT,
    [Switch]$dbg
)

. "support/rest_util.ps1"
$session = @{}

    Write-Debug "Executing new login"

$query_elems = @{
    grant_type    = "refresh_token";
    client_id = "ast-app";
    refresh_token = $PAT;
}

$api_path = "$cx1Tenant/protocol/openid-connect/token"

$api_uri_base = New-Object System.Uri $cx1TokenURL, $api_path
$api_uri = New-Object System.UriBuilder $api_uri_base

$query = GetQueryStringFromHashtable $query_elems

$session.reauth_uri  = $api_uri.Uri;
$session.reauth_body = $query;
$session.base_url = $cx1URL;
$session.auth_url = $cx1IamURL;
$session.tenant = $cx1Tenant;

$resp = Invoke-RestMethod -Method 'Post' -Uri $session.reauth_uri -ContentType "application/x-www-form-urlencoded" -Body $session.reauth_body

$session.auth_header = [String]::Format("{0} {1}", $resp.token_type, $resp.access_token);
$session.expires_at  = $(Get-Date).AddSeconds($resp.expires_in);

return $session