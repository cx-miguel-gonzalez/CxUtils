param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session,
    [string]$repoId,
    [string]$projectId,
    [string]$scmSettings
)

. "support/rest_util.ps1"

$rest_url = [String]::Format("{0}/repos-manager/repo/{1}?projectId={2}", $session.base_url, $repoId, $projectId)
$request_url = New-Object System.Uri $rest_url

Write-Debug "Update Projects SCM API URL: $request_url"

$headers = GetRestHeadersForJsonRequest($session)
#$body = $scmSettings | ConvertTo-Json -Depth 10


$response = Invoke-RestMethod -Method 'PUT' -Uri $request_url -ContentType 'application/json' -Headers $headers -Body $scmSettings
return $response