param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session,
    [string]$projectId,
    [hashtable]$project,
    [string]$apiVersion
)

. "support/rest_util.ps1"

$request_url = New-Object System.Uri $session.base_url, "/cxrestapi/projects/$projectId"

Write-Debug "Projects API URL: $request_url"

$headers = GetRestHeadersForJsonRequest($session)

$body = $project | ConvertTo-Json

if($apiVersion){
    $contentType = "application/json;v=$apiVersion"
    Invoke-RestMethod -Method 'Patch' -Uri $request_url -Headers $headers -ContentType $contentType -Body $project
}
else{
    $contentType = "application/json"
    Invoke-RestMethod -Method 'Patch' -Uri $request_url -Headers $headers -ContentType $contentType -Body $body
}
