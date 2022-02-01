param(
    [Parameter(Mandatory = $true)]
    [System.Uri]$sast_url,
    [String]$username,
    [String]$password,
    [Parameter(Mandatory = $true)]
    [String]$teamName,
    [Parameter(Mandatory = $true)]
    [String]$cutoff,
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

$teams = &"support/rest/sast/teams.ps1" $session
$projects = &"support/rest/sast/projects.ps1" $session
$users = &"support/rest/sast/getusers.ps1" $session

$culture = [Globalization.CultureInfo]::InvariantCulture
$pattern = "dd\/MM\/yyyy"
$cutOffDate = [DateTime]::ParseExact($cutoff, $pattern, $culture)
Write-Debug $cutOffDate
#Get all users that belong to one of the teams/subteams
$parentTeam = $teams | Where-Object {$_.Name -eq "$teamName"}
if($parentTeam.count -eq 0){
    Write-Output "No team found with name $teamName"
    Exit
}
$targetTeams = $teams | Where-Object {$_.parentId -eq $parentTeam.id}

$deleteProjects = @()
#Gather list of projects that will be deleted
$targetTeams | %{
    $teamId = $_.id
    $targetProjects = $projects | Where-Object {$_.teamId -eq $teamId}
    
    $targetProjects | %{
        try{
            $lastScan = &"support/rest/sast/scans.ps1" $session $_.id

            Write-Debug $lastScan.dateAndTime.finishedOn
            $scanDate = Get-Date($lastScan.dateAndTime.finishedOn)
    
            if($scanDate -lt $cutOffDate){
                $deleteProjects += $_
            }
        }
        catch{
            Write-Debug "No scans for this project. Don't delete this one"
        }
    }
}

if($deleteProjects.count -eq 0){
    Write-Output "No projects found to be deleted under parent team $TeamName"
    Exit
}
#Delete Projects
Write-Output "The projects that will be deleted can be found in the TargetProjects.csv file"
#Write-Output $deleteProjects.Name
$deleteProjects | Export-Csv -Path './TargetProject.csv' -Delimiter ',' -Append -NoTypeInformation
$output = [string]::Format("Totoal number of projects to be affected: {0}", $deleteProjects.count)
Write-Output $output
$verification = Read-Host -Prompt "Are you sure you want to update all projects (y/n)"

if($verification -eq "y"){
    $deleteProjects | %{
        &"support/rest/sast/deleteproject.ps1" $session $_.id
    }
}
else{
    Write-Output "Process aborted"
    Exit
}

#Find all Teams that will be targeted for deletion
$projects = &"support/rest/sast/projects.ps1" $session
$deleteTeams=@();

$targetTeams | %{
    $teamId = $_.id
    $targetProjects = $projects | Where-Object {$_.teamId -eq $teamId}
    
    if($targetProjects.count -lt 1){
        $deleteTeams += $_
    }
}

#Find all users that will be deleted
$oneTeamUsers = $users | Where-Object {$_.teamIds.count -eq 1}
$deleteUsers = @()

$deleteTeams | %{
    $teamId = $_.id
    $deleteUsers += $oneTeamUsers | Where-Object{$_.teamIds -eq $teamId}
}

#Delete users first
Write-Output "The users that will be deleted can be found in the TargetUsers.csv file"
#Write-Output $deleteUsers.userName
$deleteUsers | Export-Csv -Path './TargetUsers.csv' -Delimiter ',' -Append -NoTypeInformation
$output = [string]::Format("Totoal number of users to be affected: {0}", $deleteusers.count)
Write-Output $output
$verification = Read-Host -Prompt "Are you sure you want to delete all projects? (y/n)"

if($verification -eq "y"){
    $deleteUsers | %{
        &"support/rest/sast/deleteuser.ps1" $session $_.id
    }
}
else{
    Write-Output "Process aborted"
    Exit
}

#Delete all teams that have no projects
Write-Output "The teams that will be deleted can be found in the TargetTeams.csv file"
#Write-Output $deleteTeams.Name
$targetTeams | Export-Csv -Path './TargetTeams.csv' -Delimiter ',' -Append -NoTypeInformation
$output = [string]::Format("Totoal number of teams to be affected: {0}", $deleteTeams.count)
Write-Output $output
$verification = Read-Host -Prompt "Are you sure you want to delete all teams? (y/n)"

if($verification -eq "y"){
    $deleteTeams | %{
        &"support/rest/sast/deleteTeam.ps1" $session $_.id
    }
}
else{
    Write-Output "Process aborted"
    Exit
}

#Summary
$output = [string]::Format("Totoal number of projects to deleted: {0}", $deleteProjects.count)
Write-Output $output
$output = [string]::Format("Totoal number of teams deleted: {0}", $deleteTeams.count)
Write-Output $output
$output = [string]::Format("Totoal number of users deleted: {0}", $deleteusers.count)
Write-Output $output
Write-Output "Clean up completed successfully"