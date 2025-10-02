param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session,
    [string]$scanId,
    [string]$limit
)

. "support/rest_util.ps1"
$rest_url = [String]::Format("{0}/scans/{1}/workflow", $session.base_url, $scanId)
$request_url = New-Object System.Uri $rest_url

Write-Debug "Get scans API URL: $request_url"

$headers = GetRestHeadersForJsonRequest($session)


$response = Invoke-RestMethod -Method 'Get' -Uri $request_url -Headers $headers
return $response