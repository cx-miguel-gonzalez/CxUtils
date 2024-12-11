param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session,
    [string]$scanId,
    [string]$resultLimit
)

. "support/rest_util.ps1"

if($resultLimit -eq $null){
    $resultLimit = 20
}
$rest_url = [String]::Format("{0}/sast-results/?scan-id={1}&limit={2}", $session.base_url, $scanId, $resultLimit)
$request_url = New-Object System.Uri $rest_url

Write-Debug "Get scans for Project API URL: $request_url"

$headers = GetRestHeadersForJsonRequest($session)


$response = Invoke-RestMethod -Method 'Get' -Uri $request_url -Headers $headers
return $response