param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session,
    [Parameter(Mandatory=$true)]
    [string]$projectId
)

. "support/rest_util.ps1"

$rest_url = [String]::Format("/cxrestapi/projects/{0}", $projectId)
$request_url = New-Object System.Uri $session.base_url, $rest_url

Write-Debug "Projects API URL: $request_url"

$headers = GetRestHeadersForJsonRequest($session)

Invoke-RestMethod -Method 'DELETE' -Uri $request_url -Headers $headers

