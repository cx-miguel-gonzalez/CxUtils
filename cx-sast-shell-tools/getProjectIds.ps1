param(
    [Parameter(Mandatory = $true)]
    [System.Uri]$sast_url,
    [String]$username,
    [String]$password,
    [Parameter(Mandatory = $true)]
    [String]$csv_path,
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

# Validate the CSV file exists
if (!(Test-Path -Path $csv_path -PathType Leaf)) {
    Throw "A file was not found at ${csv_path}."
}

# Validate the CSV File first and exit with any error. 
$validationLine = 0
Import-Csv $csv_path | ForEach-Object {
    $validationLine++

    if ($null -eq $_.ProjectName) {
        Throw "Error processing $_ - a username field does not exist on line ${validationLine}."
    }
    if ($null -eq $_.LastScanDate) {
        Throw "Error processing $_ - a email field does not exist on line ${validationLine}."
    }
    if ($null -eq $_.Team) {
        Throw "Error processing $_ - a email field does not exist on line ${validationLine}."
    }
    if ($null -eq $_.LOC) {
        Throw "Error processing $_ - a email field does not exist on line ${validationLine}."
    }
}

$csvDetails = @()
$validationLine = 0

Import-Csv $csv_path | ForEach-Object {
    $validationLine++
    
    $teamPath = $_.Team
    $projectName = $_.ProjectName
    $team = $teams | Where-Object {$_.fullName -eq "$teamPath"}
    $teamId = $team.id

    $project = $projects | Where-Object {$_.Name -eq $projectName -And $_.teamId -eq $teamId}

    $csvEntry = New-Object -TypeName psobject -Property ([Ordered]@{
        projectId = $project.Id;
        projectName = $_.ProjectName;
        owningTeam = $_.Team;
        teamId = $teamId;
    })
    $csvDetails +=$csvEntry
}


$csvDetails | Export-Csv -Path './ProjectDetails4Import.csv' -Delimiter ',' -Append -NoTypeInformation
