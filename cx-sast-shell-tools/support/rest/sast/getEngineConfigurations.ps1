param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session
)

. "support/rest_util.ps1"

$request_url = New-Object System.Uri $session.base_url, "/cxrestapi/sast/engineconfigurations"

Write-Debug "Engine Configurations API URL: $request_url"

$headers = GetRestHeadersForJsonRequest($session)

if($apiVersion){
    $contentType = "application/json;v=$apiVersion"
    Invoke-RestMethod -Method 'Get' -Uri $request_url -Headers $headers -ContentType $contentType
}
else{
    Invoke-RestMethod -Method 'Get' -Uri $request_url -Headers $headers
}
