param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session,
    [string]$projectId
)

. "support/rest_util.ps1"

$rest_url = [String]::Format("{0}/projects/{1}", $session.base_url, $projectId)
$request_url = New-Object System.Uri $rest_url

Write-Debug "Delete Project API URL: $request_url"

$headers = GetRestHeadersForJsonRequest($session)


$response = Invoke-RestMethod -Method 'DELETE' -Uri $request_url -Headers $headers
return $response