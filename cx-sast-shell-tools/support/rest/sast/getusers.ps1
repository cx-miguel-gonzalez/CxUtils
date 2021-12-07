param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session
)

. "support/rest_util.ps1"

$request_url = New-Object System.Uri $session.base_url, "/cxrestapi/auth/Users"

Write-Debug "Users API URL: $request_url"

$headers = GetRestHeadersForJsonRequest($session)

Invoke-RestMethod -Method 'Get' -Uri $request_url -Headers $headers -ContentType "application/json"

