param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session,
    [string]$processId
)

. "support/rest_util.ps1"

$rest_url = [String]::Format("{0}/repos-manager/project-conversion?processId={1}", $session.base_url, "$processId")
$request_url = New-Object System.Uri $rest_url

Write-Debug "Project Conversion Status API URL: $request_url"

$headers = GetRestHeadersForJsonRequest($session)


$response = Invoke-RestMethod -Method 'Get' -Uri $request_url -Headers $headers
return $response