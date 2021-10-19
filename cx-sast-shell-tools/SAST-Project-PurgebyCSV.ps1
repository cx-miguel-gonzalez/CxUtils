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
$session = &"support/rest/sast/login.ps1" $sast_url $username $password -dbg:$dbg.IsPresent

#Get list of all users
$teams = &"support/rest/sast/teams.ps1" $session
$projects = &"support/rest/sast/projects.ps1" $session

# Validate the CSV file exists
if (!(Test-Path -Path $csv_path -PathType Leaf)) {
    Throw "A file was not found at ${csv_path}."
}

Write-Output "Csv file was found"

# Validate the CSV File first and exit with any error. 
$validationLine = 0
Import-Csv $csv_path | ForEach-Object {
    $validationLine++

    if ($null -eq $_.FullTeamPath) {
        Throw "Error processing $_ - FullTeamPath field does not exist on line ${validationLine}."
    }
    if ($null -eq $_.ProjectName) {
        Throw "Error processing $_ - ProjectNamefield does not exist on line ${validationLine}."
    }
}

Write-Output "CSV file was validated. Ready to start the update. Will keep only $validationLine projects. All Others will be deleted"

#Gather list of projects to save
$saveProjects = @()
$validationLine = 0
Import-Csv $csv_path | ForEach-Object {
    $validationLine++

    $curProject = $_.ProjectName
    $curTeam = $_.FullTeamPath
    $parentTeam = $teams | Where-Object {$_.fullName -eq $curTeam}

    $target = $projects | Where-Object {$_.Name -eq $curProject -and $_.teamId -eq $parentTeam.id}

    if($target -ne $null){
        $saveProjects += $target
    }
    else{
        Write-Output "Could not find Project: $curProject"
    }
}

Write-Output "The following projects will be saved"
$saveProjects | %{
    $output = [String]::Format("Project name: {0} - TeamId: {1}", $_.name, $_.teamId)
    Write-Output $output
}

$targetProjects = $projects | Where-Object {$_.id -notin $saveProjects.id}

$output = [String]::Format("{0} projects will be deleted", $targetProjects.count)
Write-Output $output

$verification = Read-Host -Prompt "Are you sure you want to delete all these projects (y/n)"
#delete target users
if($verification -eq "y"){
    Write-Debug "You have confirmed your're going to delete the projects"
    $targetProjects | %{
        &"support/rest/sast/deleteproject.ps1" $session $_.id
    }

    $output = [String]::Format("{0} projects have been successfully deleted", $targetProjects.count)
    Write-Output $output

}

