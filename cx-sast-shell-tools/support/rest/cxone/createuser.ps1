param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session,
    [Parameter(Mandatory=$true)]
    [hashtable]$userInput
)

. "support/rest_util.ps1"

$rest_url = [String]::Format("{0}/users", $session.auth_url)
$request_url = New-Object System.Uri $rest_url

Write-Debug $request_url
Write-Debug "Users API URL: $request_url"

$headers = GetRestHeadersForJsonRequest($session)
$body = $userInput | ConvertTo-Json
write-debug $body


$response = Invoke-RestMethod -Method 'POST' -Uri $request_url -Headers $headers -ContentType 'application/json' -Body $body
return $response