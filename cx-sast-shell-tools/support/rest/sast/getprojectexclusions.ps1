param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session,
    [Parameter(Mandatory=$true)]
    [string]$projectId
)

. "support/rest_util.ps1"

$rest_url = [String]::Format("/cxrestapi/projects/{0}/sourceCode/excludeSettings", $projectId)
$request_url = New-Object System.Uri $session.base_url, $rest_url


Write-Debug "Project SCM Details URL: $request_url"

$headers = GetRestHeadersForJsonRequest($session)

Invoke-RestMethod -Method 'Get' -Uri $request_url -Headers $headers

