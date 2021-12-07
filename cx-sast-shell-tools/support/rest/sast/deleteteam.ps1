param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session,
    [Parameter(Mandatory=$true)]
    [string]$teamId
)

. "support/rest_util.ps1"

$rest_url = [String]::Format("/cxrestapi/auth/Teams/{0}", $teamId)
$request_url = New-Object System.Uri $session.base_url, $rest_url

Write-Debug "Teams API URL: $request_url"

$headers = GetRestHeadersForJsonRequest($session)

Invoke-RestMethod -Method 'DELETE' -Uri $request_url -Headers $headers

