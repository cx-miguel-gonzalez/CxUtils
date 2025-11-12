param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session,
    [string]$engine,
    [string]$limit
)

. "support/rest_util.ps1"

if($limit -eq $null) {
    $limit = 100
}
$request_url = [String]::Format("{0}/preset-manager/{1}/presets?limit={2}", $session.base_url, $engine, $limit)
$request_url = New-Object System.Uri $request_url
Write-Debug "Preset Manager API URL: $request_url"

$headers = GetRestHeadersForJsonRequest($session)


$response = Invoke-RestMethod -Method 'Get' -Uri $request_url -Headers $headers
return $response