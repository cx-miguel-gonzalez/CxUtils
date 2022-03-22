param(
    [Parameter(Mandatory = $true)]
    [System.Uri]$sast_url,
    [Parameter(Mandatory = $true)]
    [String]$username,
    [Parameter(Mandatory = $true)]
    [String]$password,
    [Parameter(Mandatory = $true)]
    [String]$projectName,
    [Parameter(Mandatory = $true)]
    [String]$BranchedProjectName,
    [Parameter(Mandatory = $true)]
    [String]$gitBranch,
    [Parameter(Mandatory = $true)]
    [String]$gitPAT,
    [Switch]$dbg
)


if(!$username){
    $credentials = Get-Credential -Credential $null
    $username = $credentials.UserName
    $password = $credentials.GetNetworkCredential().Password
}

. "support/debug.ps1"

setupDebug($dbg.IsPresent)

# login
# branch project
# add git settings

$session = &"support/rest/sast/login.ps1" $sast_url $username $password -dbg:$dbg.IsPresent

$projects = &"support/rest/sast/projects.ps1" $session

#branch the project
$targetProject = $projects | Where-Object {$_.name -eq $projectName}
$branchRequest = @{
    name = $BranchedProjectName;
}

$branchedProject = &"support/rest/sast/branchProject.ps1" $session $targetProject.id $branchRequest

#create git settings object
$scmSettings = &"support/rest/sast/getprojectgitdetails.ps1" $session $targetProject.id

$gitSettings = @{
    url = $scmSettings.url;
    branch = $gitBranch;
    gitPAT = $gitPAT;
    usessh = "false";
}

#update the git scm settings for the branched project
&"support/rest/sast/updateProjectGitSettings.ps1" $session $branchedProject.id $gitSettings

Write-Output "Finished Branching project"