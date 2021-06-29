param(
    [Parameter(Mandatory = $true)]
    [System.Uri]$sast_url,
    [Parameter(Mandatory = $true)]
    [String]$username,
    [Parameter(Mandatory = $true)]
    [String]$password,
    [Parameter(Mandatory = $true)]
    [String]$teamName,
#    [String]$Role,
#    [Parameter(Mandatory = $false)]
#    [Boolean]$ReplaceRole,
    [Switch]$dbg
)

. "support/debug.ps1"

setupDebug($dbg.IsPresent)

#Login and generate token
$session = &"support/rest/sast/login.ps1" $sast_url $username $password -dbg:$dbg.IsPresent

$teams = &"support/rest/sast/teams.ps1" $session
#Write-Output $teams
#find teams
$targetTeams = $teams | Where-Object {$_ -like "*$teamName*"}

Write-Output $targetTeams
#Get all users that belong to one of the teams/subteams
$allUsers = &"support/rest/sast/getusers.ps1" $session
$user_index = @()

$allUsers | % {
    $withinTeam = $false
    $_.teamIds | % {
        #Write-Debug $_
        if($targetTeams.id.Contains($_)){
            $withinTeam = $true
        }   
    }

    $_.teamsIds | %{
        if($targetTeams.id.Contains($_)){
            $withinTeam = $false
        }
    }

    if($withinTeam){
        $user_index += $_
    }
}

Write-Output $user_index.username