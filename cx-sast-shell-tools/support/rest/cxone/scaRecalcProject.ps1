param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session,
    [String]$projectId,
    [String]$branch
)

. "support/rest_util.ps1"

$rest_url = [String]::Format("{0}/scans/recalculate", $session.base_url)
$request_url = New-Object System.Uri $rest_url

Write-Debug "Create recalc scan API URL: $request_url"

$headers = GetRestHeadersForJsonRequest($session)

#build request body
$engines = @("sca")
$scan = @{
    type = "sca"
    value = @{
        enableContainersScan = $false
    }
}
$config = @($scan)

$scanRequest = @{
    project_id = $projectId
    branch = $branch
    engines = $engines
    config = $config
}
$body = $scanRequest | ConvertTo-Json -Depth 10
Write-Debug $body

$response = Invoke-RestMethod -Method 'POST' -Uri $request_url -Headers $headers -Body $body -ContentType 'application/json'
return $response