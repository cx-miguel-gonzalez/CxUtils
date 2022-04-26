param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session,
    [string]$apiVersion
)

. "support/rest_util.ps1"

$request_url = New-Object System.Uri $session.base_url, "/cxrestapi/projects"

Write-Debug "Projects API URL: $request_url"

$headers = GetRestHeadersForJsonRequest($session)

if($apiVersion){
    $contentType = "application/json;v=$apiVersion"
    Invoke-RestMethod -Method 'Get' -Uri $request_url -Headers $headers -ContentType $contentType
}
else{
    Invoke-RestMethod -Method 'Get' -Uri $request_url -Headers $headers
}
