param(
    [Parameter(Mandatory = $true)]
    [System.Uri]$sast_url,
    [String]$username,
    [String]$password,
    [Switch]$dbg
)

if(!$username){
    $credentials = Get-Credential -Credential $null
    $username = $credentials.UserName
    $password = $credentials.GetNetworkCredential().Password
}

. "support/debug.ps1"

setupDebug($dbg.IsPresent)

#Login and generate token
$session = &"support/rest/sast/login.ps1" $sast_url $username $password -dbg:$dbg.IsPresent

#Get the list of projects that have git configured for source control
$allprojects = &"support/rest/sast/projects.ps1" $session
$teams = &"support/rest/sast/teams.ps1" $session

$csvDetails = @()

#build list of project information and scm configuration
$allProjects | %{
    $prjId = $_.id
    $prjName = $_.Name
    $prjTeamId = $_.teamID
    $prjTeam = $teams | Where-Object {$_.id -eq $prjTeamId}

    try{
        $scmSettings = &"support/rest/sast/getprojectgitdetails.ps1" $session $prjId
        
        $csvEntry = New-Object -TypeName psobject -Property ([Ordered]@{
            projectId = $prjId;
            projectName = $prjName;
            owningTeam = $prjTeam.fullName;
            projectUrl = $scmSettings.url;
            projectGitBranch = $scmSettings.branch;
        })
        
        Write-Debug $csvEntry
        $csvDetails +=$csvEntry
    }
    catch{
        Write-Debug "This project: $prjName , does not have git configuration"
    }
}

Write-Output $csvDetails
$csvDetails | Export-Csv -Path './ProjectDetails.csv' -Delimiter ',' -Append -NoTypeInformation
