param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session,
    [Parameter(Mandatory=$true)]
    [string]$samlMap,
    [Parameter(Mandatory=$true)]
    [string]$IdpId
)

. "support/rest_util.ps1"

$rest_url = [String]::Format("/cxrestapi/auth/SamlIdentityProviders/{0}/TeamMappings", $IdPId)
$request_url = New-Object System.Uri $session.base_url, $rest_url

Write-Debug "SAML Group and Team Mapping API URL: $request_url"

#$Body = ConvertTo-Json $samlMap
Write-Debug $samlMap

$headers = GetRestHeadersForJsonRequest($session)
Write-Debug $request_url

try {
    $response = Invoke-RestMethod -Method "PUT" -Uri $request_url -Headers $headers -ContentType "application/json" -Body $samlMap
    return $response
}
catch {
    Write-Output "StatusCode:" $_.Exception.Response.StatusCode.value__
    Write-Output "StatusDescription:" $_.Exception.Response.StatusDescription
    throw "Error on: $method $endpoint"
}