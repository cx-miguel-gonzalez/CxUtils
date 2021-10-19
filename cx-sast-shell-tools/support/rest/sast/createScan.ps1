param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session,
    [Parameter(Mandatory=$true)]
    [hashtable]$scanRequest
)

. "support/rest_util.ps1"

$request_url = New-Object System.Uri $session.base_url, "/cxrestapi/sast/scans"

$Body = ConvertTo-Json $scanRequest
Write-Debug $Body


Write-Debug "Scans API URL: $request_url"

$headers = GetRestHeadersForJsonRequest($session)

try {
    $response = Invoke-RestMethod -Method "POST" -Uri $request_url -ContentType "application/json" -Headers $headers -Body $Body
    
    return $response
}
catch {
    Write-Output $response
    Write-Output "StatusCode:" $_.Exception.Response.StatusCode.value__
    Write-Output "StatusDescription:" $_.Exception.Response.StatusDescription
    throw "Error on: $method $endpoint"
}