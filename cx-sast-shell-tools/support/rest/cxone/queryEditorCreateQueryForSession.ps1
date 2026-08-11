param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session,
    [Parameter(Mandatory=$true)]
    [string]$editorSessionId,
    [Parameter(Mandatory=$true)]
    [string]$name,
    [Parameter(Mandatory=$true)]
    [string]$language,
    [Parameter(Mandatory=$true)]
    [string]$group,
    [Parameter(Mandatory=$true)]
    [string]$severity,
    [Parameter(Mandatory=$true)]
    [string]$source,
    [bool]$executable = $true,
    [ValidateSet("Cx", "Tenant", "Project", "Application")]
    [string]$level
)

. "support/rest_util.ps1"

$rest_url = [String]::Format("{0}/query-editor/sessions/{1}/queries", $session.base_url, $editorSessionId)
$request_url = New-Object System.Uri $rest_url

Write-Debug "Create Query Editor Query API URL: $request_url"

$headers = GetRestHeadersForJsonRequest($session)
$queryRequest = @{
    name       = $name
    language   = $language
    group      = $group
    severity   = $severity
    source     = $source
    executable = $executable
}
if ($level) {
    $queryRequest.level = $level
}
$body = $queryRequest | ConvertTo-Json
Write-Debug $body

$response = Invoke-RestMethod -Method 'POST' -Uri $request_url -Headers $headers -Body $body -ContentType 'application/json'
return $response
