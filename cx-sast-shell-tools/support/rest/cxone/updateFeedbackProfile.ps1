param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session,
    [hashtable]$profileUpdate
)

. "support/rest_util.ps1"

$rest_url = [String]::Format("{0}/feedback-app/profiles", $session.base_url)
$request_url = New-Object System.Uri $rest_url

Write-Debug "Feedback Profile API URL: $request_url"

$headers = GetRestHeadersForJsonRequest($session)
$body = $profileUpdate | ConvertTo-Json
Write-Output $profileUpdate

$response = Invoke-RestMethod -Method 'POST' -Uri $request_url -Headers $headers -Body $body -ContentType 'application/json'
return $response