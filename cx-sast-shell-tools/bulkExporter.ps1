param(
    [Parameter(Mandatory = $true)]
    [System.Uri]$sast_url,
    [String]$username,
    [String]$password,
    [String]$exportToolPath,
    [Switch]$dbg
)

if(!$username){
    $credentials = Get-Credential -Credential $null
    $username = $credentials.UserName
    $password = $credentials.GetNetworkCredential().Password
}

. "support/debug.ps1"
Add-Type -AssemblyName System.Web

setupDebug($dbg.IsPresent)

#Login and generate token
$session = &"support/rest/sast/loginV2.ps1" $sast_url $username $password -dbg:$dbg.IsPresent

#Get the list of projects that have git configured for source control
$allTeams = &"support/rest/sast/teams.ps1" $session


$spTeam = $allTeams | Where-Object{$_.name -eq "SP"}

$targetTeams = $allTeams | Where-Object{$_.parentId -eq $spTeam.id}

$targetTeams | %{
    &"$exportToolPath" -url $sast_url -user $username -pass $password -export "triage,projects" -project-team $team -projects-active-since 5000
}