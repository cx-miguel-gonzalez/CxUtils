param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session,
    [Parameter(Mandatory=$true)]
    [hashtable]$reportRequest
)

. "support/rest_util.ps1"

$rest_url = [String]::Format("/api/reports")
$request_url = New-Object System.Uri $session.reporting_url, $rest_url

#generate Body
$Body = $reportRequest | ConvertTO-JSON -Depth 10

Write-Output $Body

Write-Debug "CxReporting API URL: $request_url"

$headers = GetRestHeadersForJsonRequest($session)

try {
    $response = Invoke-RestMethod -Method 'POST' -Uri $request_url -Headers $headers -ContentType "application/json" -Body $Body
    
    return $response
}
catch {
    Write-Output $response
    Write-Output "StatusCode:" $_.Exception.Response.StatusCode.value__
    Write-Output "StatusDescription:" $_.Exception.Response.StatusDescription
    throw "Error on: $method $endpoint"
}