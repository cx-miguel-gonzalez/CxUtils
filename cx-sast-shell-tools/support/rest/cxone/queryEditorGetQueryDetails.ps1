param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session,
    [Parameter(Mandatory=$true)]
    [string]$editorSessionId,
    [Parameter(Mandatory=$true)]
    [string]$queryId
)

. "support/rest_util.ps1"

$rest_url = [String]::Format("{0}/query-editor/sessions/{1}/queries/{2}", $session.base_url, $editorSessionId, $queryId)
$request_url = New-Object System.Uri $rest_url

Write-Debug "Get Query Editor Query Details API URL: $request_url"

$headers = GetRestHeadersForJsonRequest($session)

$response = Invoke-RestMethod -Method 'Get' -Uri $request_url -Headers $headers
return $response
