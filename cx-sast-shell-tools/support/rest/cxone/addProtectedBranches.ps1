param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session,
    [Parameter(Mandatory=$true)]
    [string]$cxProjectName,
    [Parameter(Mandatory=$true)]
    [System.Object[]]$protectedBranches
)

. "support/rest_util.ps1"

$rest_url = [String]::Format("{0}/repos-manager/protected-branches?cxProjectName={1}", $session.base_url, $cxProjectName)
$request_url = New-Object System.Uri $rest_url

Write-Debug "Add Protected Branches API URL: $request_url"

$headers = GetRestHeadersForJsonRequest($session)
$body = ConvertTo-Json -InputObject $protectedBranches -Depth 10
Write-Debug $body

$response = Invoke-RestMethod -Method 'POST' -Uri $request_url -Headers $headers -Body $body -ContentType 'application/json'
return $response
