param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session,
    [string]$projectId,
    [System.Object[]]$projectDetails
)

. "support/rest_util.ps1"

$rest_url = [String]::Format("{0}/projects/{1}", $session.base_url, $projectId)
$request_url = New-Object System.Uri $rest_url

Write-Debug "Patch Projects API URL: $request_url"

$headers = GetRestHeadersForJsonRequest($session)
$body = $projectDetails | ConvertTo-Json
write-debug $body

$response = Invoke-RestMethod -Method 'Patch' -Uri $request_url -Headers $headers -Body $body -ContentType 'application/json'
return $response