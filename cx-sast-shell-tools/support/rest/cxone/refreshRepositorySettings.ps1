param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session,
    [string]$scmId,
    [string]$authCode,
    [string]$projectId,
    [hashtable]$scmSettings
)

. "support/rest_util.ps1"

$rest_url = [String]::Format("{0}/repos-manager/scms/{1}/reimport?authCode={2}&projectId={3}", $session.base_url, $scmId, $authCode, $projectId)
$request_url = New-Object System.Uri $rest_url

Write-Debug "Get Projects SCM API URL: $request_url"

$headers = GetRestHeadersForJsonRequest($session)
$body = $scmSettings | ConvertTo-Json -Depth 10
Write-Debug $body


$response = Invoke-RestMethod -Method 'Post' -Uri $request_url -Headers $headers -Body $body -ContentType 'application/json'
return $response
