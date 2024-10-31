param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session,
    [String]$scmId,
    [String]$orgName,
    [String]$projectId,
    [hashtable]$scanRequest
)

. "support/rest_util.ps1"

$rest_url = [String]::Format("{0}/repos-manager/scms/{1}/orgs/{2}/repo/projectScan?projectId={3}", $session.base_url,$scmId,$orgName,$projectId)
$request_url = New-Object System.Uri $rest_url

Write-Debug "Create scan API URL: $request_url"

$headers = GetRestHeadersForJsonRequest($session)
$body = $scanRequest | ConvertTo-Json -Depth 10
Write-Debug $body

$response = Invoke-RestMethod -Method 'POST' -Uri $request_url -Headers $headers -Body $body -ContentType 'application/json'
return $response