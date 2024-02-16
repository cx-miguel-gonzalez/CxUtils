param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session,
    [string]$createdAt,
    [string]$limit
)

. "support/rest_util.ps1"
$rest_url = [String]::Format("{0}/scans/?offset=0&limit=100&statuses=Failed&statuses=Partial&sort=%2Bcreated_at&sort=%2Bstatus&field=scan-ids&from-date={1}", $session.base_url, $createdAt)
$request_url = New-Object System.Uri $rest_url

Write-Debug "Get scans API URL: $request_url"

$headers = GetRestHeadersForJsonRequest($session)


$response = Invoke-RestMethod -Method 'Get' -Uri $request_url -Headers $headers
return $response