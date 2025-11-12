param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session,
    [string]$engine,
    [hashtable]$presetBody
)

. "support/rest_util.ps1"

$request_url = [String]::Format("{0}/preset-manager/{1}/presets", $session.base_url, $engine)
$request_url = New-Object System.Uri $request_url
Write-Debug "Preset Manager - Create Preset API URL: $request_url"

$body = $presetBody | ConvertTo-Json -Depth 10

$headers = GetRestHeadersForJsonRequest($session)

$response = Invoke-RestMethod -Method 'Post' -Uri $request_url -Headers $headers -Body $body -ContentType "application/json"
return $response