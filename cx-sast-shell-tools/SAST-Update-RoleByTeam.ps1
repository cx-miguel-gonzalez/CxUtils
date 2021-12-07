param(
    [Parameter(Mandatory = $true)]
    [System.Uri]$sast_url,
    [String]$username,
    [String]$password,
    [Parameter(Mandatory = $true)]
    [String]$teamName,
    [Parameter(Mandatory = $true)]
    [String]$roleName,
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

#Get all users that belong to one of the teams/subteams
$targetTeams = $teams | Where-Object {$_ -like "*$teamName*"}
Write-Output $targetTeams

#Find all users that belong to any of the target teams
$allUsers = &"support/rest/sast/getusers.ps1" $session
$user_index = @()

$allUsers | % {
    $withinTeam = $false
    $currentUser = $_
    $currentUser.teamIds | % {
        #Write-Debug $_
        if($targetTeams.id.Count -eq 1){
            if($targetTeams.id -eq ($_)){
                $withinTeam = $true
            }
        }
        else{
            if($targetTeams.id.Contains($_)){
                $withinTeam = $true
            }   
        }
    }
    if($withinTeam){
        $user_index += $currentUser
    }
}

#Remove the users that belong to teams outside of the target teams
#Write-Output "these are the target users now"
$targetUsers = @()
$user_index | %{
    $teamsExclusive = $true
    $_.teamids | %{
        #Write-Output $_
        if($targetTeams.id.Count -eq 1){
            if(-not($targetTeams.id -eq $_)){
                $teamsExclusive = $false
            }
        }
        else{
            if(-not($targetTeams.id.contains($_))){
                $teamsExclusive = $false
            }
        }
    }
    if($teamsExclusive -eq $true){
        $targetUsers += $_
    }
}

#Get the role id for the desired role
$allroles = &"support\rest\sast\getroles.ps1" $session

$targetRole = $allroles | Where-Object {$_.name -eq $roleName}

if(!$targetRole){
    Write-Output "Could not find any Roles with the name of $roleName. Please correct name and try again."
    throw "Invalid Role Name: $roleName"
}
else{
    Write-Output "Successfully found role information for $roleName"
    Write-Debug $targetRole
}

$output = [string]::Format("Preparing to update users under the {0} team and set their role to {1}", $teamName, $roleName)
Write-Output $output

$output = [string]::Format("Totoal number of users to be affected: {0}", $targetUsers.count)
Write-Output $output
#add the prompt
$verification = Read-Host -Prompt "Are you sure you want to update all these users (y/n)"

if($verification -eq "y"){
    #start updating all the users
    $userCount = 0
    $targetUsers | %{
        $userUpdate = $_
        $userUpdate.roleids = @($targetRole.id)
    
        &"support\rest\sast\modifyuser.ps1" $session $_
        $userCount++
    }
    
    Write-Output "Successfully updated roles for $userCount users"
}
else{
    Write-Output "Role updater has been cancelled"
}