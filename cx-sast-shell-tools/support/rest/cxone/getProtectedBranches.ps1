param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session,
    [Parameter(Mandatory=$true)]
    [string]$cxProjectName
)

. "support/rest_util.ps1"

$rest_url = [String]::Format("{0}/repos-manager/protected-branches?cxProjectName={1}", $session.base_url, $cxProjectName)
$request_url = New-Object System.Uri $rest_url

Write-Debug "Get Protected Branches API URL: $request_url"

$headers = GetRestHeadersForJsonRequest($session)

$response = Invoke-RestMethod -Method 'Get' -Uri $request_url -Headers $headers
return $response
