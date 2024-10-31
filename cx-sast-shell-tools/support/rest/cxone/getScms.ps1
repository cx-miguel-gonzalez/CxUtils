param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session
)

. "support/rest_util.ps1"

$rest_url = [String]::Format("{0}/repos-manager/v2/scms", $session.base_url)
$request_url = New-Object System.Uri $rest_url

Write-Debug "Get Projects SCM API URL: $request_url"

$headers = GetRestHeadersForJsonRequest($session)


$response = Invoke-RestMethod -Method 'Get' -Uri $request_url -Headers $headers
return $response