param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session,
    [Parameter(Mandatory=$true)]
    [string]$reportID,
    [string]$projectName
)

. "support/rest_util.ps1"

$rest_url = [String]::Format("/api/reports/{0}", $reportID)
$request_url = New-Object System.Uri $session.reporting_url, $rest_url


Write-Debug "CxReporting API URL: $request_url"

$fullpath = [string]::Format("{0}_{1}.pdf", $projectName, $(get-date -f dd-MM-yyyyz))
Write-Debug $fullpath

$headers = GetRestHeadersForJsonRequest($session)

$response = Invoke-RestMethod -Method 'Get' -Uri $request_url -Headers $headers -OutFile $fullpath

return $fullpath