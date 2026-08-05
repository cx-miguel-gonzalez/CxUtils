param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session,
    [string]$projectId
)

. "support/rest_util.ps1"

$rest_url = [String]::Format("{0}/repos-manager/projects/{1}/disconnect", $session.base_url, $projectId)
$request_url = New-Object System.Uri $rest_url

Write-Debug "Disconnect project SCM API URL: $request_url"

$headers = GetRestHeadersForJsonRequest($session)

$response = Invoke-RestMethod -Method 'POST' -Uri $request_url -Headers $headers -ContentType "application/json"
return $response
