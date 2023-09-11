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

#Login and generate token for SAST
$sastSession = &"support/rest/sast/loginV2.ps1" $sast_url $username $password -dbg:$dbg.IsPresent

#Get list of all SAST projects
$sastProjects = &"support/rest/sast/projects.ps1" $sastSession
$teams = &"support/rest/sast/teams.ps1" $sastSession


#Match the projects based on the name
$duplicateProjects=@()

$sastProjects | %{
    $projectName = $_.Name
    $projectId = $_.id
    $teamId = $_.teamId
    $teamInfo = $teams | Where-Object {$_.id -eq $teamId};


    $duplicateProject = $sastProjects | Where-Object {$_.name -eq $projectName}
    if ($duplicateProject.count -gt 1){

        $csvEntry = New-Object -TypeName psobject -Property ([Ordered]@{
            ProjectName = $projectName;
            SastId = $projectId;
            parentTeam = $teamInfo.fullName;
        })
        $duplicateProjects += $csvEntry
    }
    
}

#Generate the csv file
$duplicateProjects | Export-Csv -Path './SAST_Duplicate_Projects.csv' -Delimiter ',' -Append -NoTypeInformation