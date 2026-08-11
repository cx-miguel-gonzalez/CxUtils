param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session,
    [Parameter(Mandatory=$true)]
    [string]$scanner,
    [Parameter(Mandatory=$true)]
    [string]$filter
)

. "support/rest_util.ps1"

$rest_url = [String]::Format("{0}/query-editor/sessions", $session.base_url)
$request_url = New-Object System.Uri $rest_url

Write-Debug "Create Query Editor Session API URL: $request_url"

$headers = GetRestHeadersForJsonRequest($session)
$sessionRequest = @{
    scanner = $scanner
    filter  = $filter.ToLower()
}
$body = $sessionRequest | ConvertTo-Json
Write-Debug $body

$response = Invoke-RestMethod -Method 'POST' -Uri $request_url -Headers $headers -Body $body -ContentType 'application/json'
return $response
