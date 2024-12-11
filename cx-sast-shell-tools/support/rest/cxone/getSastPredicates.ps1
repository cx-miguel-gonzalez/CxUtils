param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session,
    [string]$simId
)

. "support/rest_util.ps1"

if($resultLimit -eq $null){
    $resultLimit = 20
}
$rest_url = [String]::Format("{0}/sast-results-predicates/{1}", $session.base_url, $simId)
$request_url = New-Object System.Uri $rest_url

Write-Debug "Get predicate for sast result API URL: $request_url"

$headers = GetRestHeadersForJsonRequest($session)


$response = Invoke-RestMethod -Method 'Get' -Uri $request_url -Headers $headers
return $response