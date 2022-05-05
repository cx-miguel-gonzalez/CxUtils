param(
    [System.Uri]$sast_url,
    [String]$refreshToken,
    [Switch]$dbg
)

. "support/rest_util.ps1"

$session = @{}


Write-Debug "Executing new login"

$query_elems = @{
    grant_type    = "refresh_token";
    client_secret = "B9D84EA8-E476-4E83-A628-8A342D74D3BD";
    client_id     = "cli_client"
    refresh_token = $refreshToken
}

$api_path = "/cxrestapi/auth/identity/connect/token"

$api_uri_base = New-Object System.Uri $sast_url, $api_path
$api_uri = New-Object System.UriBuilder $api_uri_base

$query = GetQueryStringFromHashtable $query_elems

$session.reauth_uri  = $api_uri.Uri;
$session.reauth_body = $query
$session.base_url = $sast_url



$resp = Invoke-RestMethod -Method 'Post' -Uri $session.reauth_uri -ContentType "application/x-www-form-urlencoded" -Body $session.reauth_body

$session.auth_header = [String]::Format("{0} {1}", $resp.token_type, $resp.access_token);
$session.expires_at  = $(Get-Date).AddSeconds($resp.expires_in);

return $session
