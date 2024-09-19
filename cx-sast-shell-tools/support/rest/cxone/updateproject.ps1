param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session,
    [string]$projectId,
    [System.Object[]]$projectUpdate
)

. "support/rest_util.ps1"

$rest_url = [String]::Format("{0}/projects/{1}", $session.base_url, $projectId)
$request_url = New-Object System.Uri $rest_url

Write-Debug "Update Projects API URL: $request_url"

$headers = GetRestHeadersForJsonRequest($session)
$body = $projectUpdate | ConvertTo-Json -Depth 10

$response = Invoke-RestMethod -Method 'PUT' -Uri $request_url -ContentType 'application/json' -Headers $headers -Body $body
return $response