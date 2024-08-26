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

    if ($null -eq $_.id) {
        Throw "Error processing $_ - id field does not exist on line ${validationLine}."
    }
    if ($null -eq $_.currentProjectName) {
        Throw "Error processing $_ - ProjectNamefield does not exist on line ${validationLine}."
    }
}

#Gather list of projects to save

$validationLine = 0
Import-Csv $csv_path | ForEach-Object {
    $validationLine++

    try{
        &"support/rest/sast/deleteproject.ps1" $session $_.id
    }
    catch{
        Write-Output "Could not delete project" + $_.currentProjectName + "id=" + $_.id
    }
}

