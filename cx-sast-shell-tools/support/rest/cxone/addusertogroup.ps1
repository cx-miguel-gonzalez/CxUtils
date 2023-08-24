param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session,
    [Parameter(Mandatory=$true)]
    [string]$userId,
    [Parameter(Mandatory=$true)]
    [string]$groupId
)

. "support/rest_util.ps1"

$rest_url = [String]::Format("{0}/users/{1}/groups/{2}", $session.auth_url, $userId, $groupId)
$request_url = New-Object System.Uri $rest_url

Write-Debug $request_url
Write-Debug "Users API URL: $request_url"

$headers = GetRestHeadersForJsonRequest($session)
$body = @{
    id = $groupId
}
$jsonBody = $body | ConvertTo-Json
write-debug $jsonBody

$response = Invoke-RestMethod -Method 'Put' -Uri $request_url -Headers $headers -ContentType 'application/json' -Body $jsonBody
return $response