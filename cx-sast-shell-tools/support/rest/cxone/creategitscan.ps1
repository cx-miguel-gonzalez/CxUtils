param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session,
    [hashtable]$scanRequest
)

. "support/rest_util.ps1"

$rest_url = [String]::Format("{0}/scans", $session.base_url)
$request_url = New-Object System.Uri $rest_url

Write-Debug "Create scan API URL: $request_url"

$headers = GetRestHeadersForJsonRequest($session)
$body = $scanRequest | ConvertTo-Json

$response = Invoke-RestMethod -Method 'POST' -Uri $request_url -Headers $headers -Body $body
return $response