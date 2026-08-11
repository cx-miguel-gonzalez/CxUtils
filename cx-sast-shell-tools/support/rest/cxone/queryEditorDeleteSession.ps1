param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session,
    [Parameter(Mandatory=$true)]
    [string]$editorSessionId
)

. "support/rest_util.ps1"

$rest_url = [String]::Format("{0}/query-editor/sessions/{1}", $session.base_url, $editorSessionId)
$request_url = New-Object System.Uri $rest_url

Write-Debug "Delete Query Editor Session API URL: $request_url"

$headers = GetRestHeadersForJsonRequest($session)

$response = Invoke-RestMethod -Method 'Delete' -Uri $request_url -Headers $headers
return $response
