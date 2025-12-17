param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session,
    [string]$authCode,
    [string]$scmId,
    [string]$scmOrg,
    [string]$pageSize
)

. "support/rest_util.ps1"

if($pageSize -eq $null){
    $pageSize = 100
}
$headers = GetRestHeadersForJsonRequest($session)
$pageLink = "1"
$allRepos = @()
$hasMoreData = $true

while($hasMoreData){
    $rest_url = [String]::Format("{0}/repos-manager/v2/scms/{1}/orgs/{2}/repos?authCode={3}&isUser=false&pageSize={4}&pageLink={5}", $session.base_url, $scmId, $scmOrg, $authCode, $pageSize, $pageLink)
    $request_url = New-Object System.Uri $rest_url

    Write-Debug "Get Projects from Repos Manager API URL: $request_url"
    $response = Invoke-RestMethod -Method 'Get' -Uri $request_url -Headers $headers
    $allRepos += $response.repos
    if($response.nextPageLink -eq $null){
        $hasMoreData = $false
    }
    else{
        $pageLink = $response.nextPageLink
    }
}

$repos = @{
    repos = $allRepos
    totalCount = $allRepos.Count
}
return $repos
