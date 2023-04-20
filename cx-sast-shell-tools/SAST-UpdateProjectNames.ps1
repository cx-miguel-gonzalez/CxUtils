param(
    [Parameter(Mandatory = $true)]
    [System.Uri]$sast_url,
    [String]$username,
    [String]$password,
    [Parameter(Mandatory = $true)]
    [String]$parentTeamPath,
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
$session = &"support/rest/sast/loginV2.ps1" $sast_url $username $password -dbg:$dbg.IsPresent

#Get projects and teams list 
$teams = &"support/rest/sast/teams.ps1" $session
$projects = &"support/rest/sast/projects.ps1" $session

#Get all users that belong to one of the teams/subteams
$parentTeam = $teams | Where-Object {$_.fullname -eq "$parentTeamPath"}
if($parentTeam.count -eq 0){
    Write-Output "No team found with name $teamName"
    Exit
}
$targetTeams = $teams | Where-Object {$_.parentId -eq $parentTeam.id}

#Write-Output $targetTeams

$targetTeams |%{
    $teamId = $_.id
    $teamName = $_.name

    $targetProjects = $projects | Where-Object {$_.teamId -eq $teamId}

    $targetProjects | %{
        $projectName = $_.name
        $owningTeam = $_.teamId
    
        $newProjectName = "$teamName-$projectName"
        $projectBody = @{
            name = $newProjectName;
            owningTeam = $owningTeam
        }

        $result = &"support/rest/sast/updateProject.ps1" $session $_.id $projectBody
        Write-Output $result
    }

}
