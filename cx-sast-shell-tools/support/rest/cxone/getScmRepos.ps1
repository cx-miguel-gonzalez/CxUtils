param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session,
    [Parameter(Mandatory=$true)]
    [string]$orgName
)

. "support/rest_util.ps1"

$rest_url = [String]::Format("{0}/repos-manager/scms/1/orgs/{1}/repos?authCode=d2e5714b965c732d57eb&isUser=false&page=1", $session.base_url, $orgName)
$request_url = New-Object System.Uri $rest_url

Write-Debug "SCM Repos for an org API URL: $request_url"

$headers = GetRestHeadersForJsonRequest($session)


$response = Invoke-RestMethod -Method 'Get' -Uri $request_url -Headers $headers
return $response