param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session,
    [Parameter(Mandatory=$true)]
    [string]$engine,
    [Parameter(Mandatory=$true)]
    [string]$presetId
)

. "support/rest_util.ps1"

$request_url = [String]::Format("{0}/preset-manager/{1}/presets/{2}", $session.base_url, $engine, $presetId)
$request_url = New-Object System.Uri $request_url
Write-Debug "Preset Manager Queries for Preset API URL: $request_url"

$headers = GetRestHeadersForJsonRequest($session)

$response = Invoke-RestMethod -Method 'Get' -Uri $request_url -Headers $headers
return $response
