param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session,
    [string]$engine
)

. "support/rest_util.ps1"

$request_url = [String]::Format("{0}/preset-manager/{1}/query-families", $session.base_url, $engine)
$request_url = New-Object System.Uri $request_url
Write-Debug "Preset Manager Query Families API URL: $request_url"

$headers = GetRestHeadersForJsonRequest($session)


$response = Invoke-RestMethod -Method 'Get' -Uri $request_url -Headers $headers
return $response