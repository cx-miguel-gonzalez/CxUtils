param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session,
    [Parameter(Mandatory=$true)]
    [string]$orgName,
    [string]$authCode,
    [version]$version
)

. "support/rest_util.ps1"

if($version -eq "1"){
    $rest_url = [String]::Format("{0}/repos-manager/scms/{1}/orgs/{2}/repos?authCode={3}&isUser=false&page=1", $session.base_url, $scmId, $scmOrg, $authCode)
}
else{
    $rest_url = [String]::Format("{0}/repos-manager/v2/scms/{1}/orgs/{2}/repos?authCode={3}&isUser=false&page=1", $session.base_url, $scmId, $scmOrg, $authCode)
}
$request_url = New-Object System.Uri $rest_url

Write-Debug "SCM Repos for an org API URL: $request_url"

$headers = GetRestHeadersForJsonRequest($session)


$response = Invoke-RestMethod -Method 'Get' -Uri $request_url -Headers $headers
return $response