param(
    [Parameter(Mandatory = $true)]
    [System.Uri]$sast_url,
    [String]$username,
    [String]$password,
    [Parameter(Mandatory = $true)]
    [Int]$monthsInactivity,
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

#List of teams that do not have any sub teams underneath them
$teams = &"support/rest/sast/teams.ps1" $session
$subTeams = $teams | Where-Object {$teams.parentid -notcontains $_.id}
#Get list of all projects
$projects = &"support/rest/sast/projects.ps1" $session
#Get list of all users
$allUsers = &"support/rest/sast/getusers.ps1" $session

$cutoffDate = Get-Date
#loop through teams to find all projects under that team
$teamPurgeList = @()
$saveList = @()

$subteams | %{
    $purge = $true
    $teamId = $_.id
    Write-Debug "looping through subteams $teamId"
    #loop through projects under the team
    $teamProjects = $projects | Where-Object {$_.teamId -eq $teamid}
    
    $teamProjects | %{
        Write-Debug $_.id
        #check to see if there are any scans for this project
        $lastScan = &"support/rest/sast/scans.ps1" $session $_.id
        $scanDate = Get-Date -Date $lastScan.dateAndTime.finishedOn

        Write-Output $scanDate
        if(([DateTime]$lastScan.dateAndTime.finishedOn) -gt $cutoffDate.AddMonths(-$monthsInactivity)){
            $purge = $false
            $output = [String]::Format("The scandate: {0} is greater than the cutoff date: {1}", $scanDate, $cutoffDate.AddMonths(-$monthsInactivity))
            Write-Debug $output
        }
    }

    if($purge){
        $teamPurgeList += $_
        $output = [String]::Format("The scandate: {0} is less than the cutoff date: {1}", $scanDate, $cutoffDate.AddMonths(-$monthsInactivity))
        Write-Debug $output
    }
    else{
        $saveList += $_
        $output = [String]::Format("The scandate: {0} is greater than the cutoff date: {1}", $scanDate, $cutoffDate.AddMonths(-$monthsInactivity))
        Write-Debug $output
    }
}

#List the items that will be deleted
$projectsPurge = @()
$teamPurgeList | %{
    $teamId = $_.id
    $projectsPurge += $projects | Where-Object {$_.teamId -eq $teamid}


}

Write-Output "The following Projects will be deleted:"
Write-Output $projectsPurge.Name
Write-Output "The following Teams will be deleted:"
Write-Output $teamPurgeList.FullName

#Verify that we do want to 
$confirmation = Read-Host "Are you sure you want to delete these projects and teams? (y) or (n)"

if($confirmation -eq "y"){
    #Time to delete all the teams in the purge list
    $teamPurgeList | %{
        $teamId = $_.id
        $teamProjects = $projects | Where-Object {$_.teamId -eq $teamid}
        #Delete all projects under this team
        $teamProjects | %{
            &"support/rest/sast/deleteproject.ps1" $session $_.id
        }
        #Delete the teams now that they have no projects left in them
        &"support/rest/sast/deleteteam.ps1" $session $teamId
    }
}
else{
    Write-Output "Teamp Cleanup has been aborted"
}

function UserCheck {
    param (
        [Parameter(Mandatory=$true)]
        [hashtable]$session,
        [Parameter(Mandatory=$true)]
        [string]$teamId,
        [Parameter(Mandatory=$true)]
        [hashtable]$users
    )

    $teamUsers = $users | Where-Object {$_.teamId -contains $teamId}

    $teamUsers | %{
        $totalTeams = $_.teamId.Count

        
    }
    
}