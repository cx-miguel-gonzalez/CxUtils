param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session,
    [System.Object[]]$projectConfiguration
)

. "support/rest_util.ps1"

$rest_url = [String]::Format("{0}/repos-manager/project-conversion", $session.base_url)
$request_url = New-Object System.Uri $rest_url

Write-Debug "Convert Projects API URL: $request_url"

$headers = GetRestHeadersForJsonRequest($session)
$body = $projectConfiguration | ConvertTo-Json -Depth 10
write-debug $body

$response = Invoke-RestMethod -Method 'Post' -Uri $request_url -Headers $headers -Body $body -ContentType "Application/JSON"
return $response