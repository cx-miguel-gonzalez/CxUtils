param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session,
    [Parameter(Mandatory=$true)]
    [string]$projectId,
    [Parameter(Mandatory=$true)]
    [hashtable]$gitSettings
)

. "support/rest_util.ps1"

$rest_url = [String]::Format("/cxrestapi/projects/{0}/sourceCode/remoteSettings/git", $projectId)
$request_url = New-Object System.Uri $session.base_url, $rest_url

$Body = ConvertTo-Json $gitSettings
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