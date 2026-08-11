param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session,
    [Parameter(Mandatory=$true)]
    [string]$editorSessionId,
    [Parameter(Mandatory=$true)]
    [string]$requestId
)

. "support/rest_util.ps1"

$rest_url = [String]::Format("{0}/query-editor/sessions/{1}/requests/{2}", $session.base_url, $editorSessionId, $requestId)
$request_url = New-Object System.Uri $rest_url

Write-Debug "Get Query Editor Request Status API URL: $request_url"

$headers = GetAuthHeaders $session
$headers.Accept = 'application/json; version=1.0'

$response = Invoke-RestMethod -Method 'Get' -Uri $request_url -Headers $headers
return $response
