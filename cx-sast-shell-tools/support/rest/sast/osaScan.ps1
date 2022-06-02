param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session,
    [string]$projectId,
    [string]$zipLocation
)

. "support/rest_util.ps1"

$request_url = New-Object System.Uri $session.base_url, "/cxrestapi/osa/scans"
$request_url = New-Object System.UriBuilder $request_url

Write-Debug "Scans API URL: $request_url"

$zipName = Split-Path $zipLocation -leaf

$multipartContent = [System.Net.Http.MultipartFormDataContent]::new()
$multipartFile = $zipLocation
$FileStream = [System.IO.FileStream]::new($multipartFile, [System.IO.FileMode]::Open)
$fileHeader = [System.Net.Http.Headers.ContentDispositionHeaderValue]::new("form-data")
$fileHeader.Name = "zippedSource"
$fileHeader.FileName = $zipName
$fileContent = [System.Net.Http.StreamContent]::new($FileStream)
$fileContent.Headers.ContentDisposition = $fileHeader
$multipartContent.Add($fileContent)

$stringHeader = [System.Net.Http.Headers.ContentDispositionHeaderValue]::new("form-data")
$stringHeader.Name = "projectId"
$stringContent = [System.Net.Http.StringContent]::new($projectId)
$stringContent.Headers.ContentDisposition = $stringHeader
$multipartContent.Add($stringContent)

$body = $multipartContent

$headers = GetRestHeadersForJsonRequest($session)

$response = Invoke-RestMethod $request_url.Uri -Method 'POST' -Headers $headers -Body $body

return $response