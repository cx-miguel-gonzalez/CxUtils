param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session,
    [Parameter(Mandatory=$true)]
    [PSCustomObject]$user
)

. "support/rest_util.ps1"

$rest_url = [String]::Format("/cxrestapi/auth/Users")
$request_url = New-Object System.Uri $session.base_url, $rest_url

Write-Debug $user

$Body = ConvertTo-Json $user
Write-Debug $Body

$headers = GetRestHeadersForJsonRequest($session)
Write-Debug $request_url


try {
    $response = Invoke-RestMethod -Method "POST" -Uri $request_url -Headers $headers -ContentType "application/json" -Body $Body
    return $response
}
catch {
    Write-Output "StatusCode:" $_.Exception.Response.StatusCode.value__
    Write-Output "StatusDescription:" $_.Exception.Response.StatusDescription
    throw "Error on: $method $endpoint"
}
