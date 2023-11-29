##################################################################
# To use this script you will need to update lines 27, 28, and 29 with the following
#   teamPath        | full team path (CxServer/SP/ParentTeam)
#   cliPath         | full path to the CLI executable (C:\CLI\CxRunConsole.cmd)
#   targetDirector  | full path of the folder that you want to scan. This script will scan all sub folders (C:\TargetFolder)
#
#   Example for running script after updating script:
#       .\SAST-CLI-ScanSubFolders.ps1 -sast_url https://my.checkmarx.com
##################################################################
param(
    [Parameter(Mandatory = $true)]
    [System.Uri]$sast_url,
    [string]$cliPath,
    [string]$targetDirectory,
    [string]$projectName,
    [string]$teamPath,
    [Switch]$dbg
)

Add-Type -AssemblyName System.Web

if(!$username){
    $credentials = Get-Credential -Credential $null
    $username = $credentials.UserName
    $password = $credentials.GetNetworkCredential().Password
}

$teamPath = ""
$cliPath = ""
$targetDirectory = ""

#$subFolders = Get-ChildItem -Path $targetDirectory -Recurse -Directory -Force -ErrorAction SilentlyContinue | Select-Object Name
$subFolders = Get-ChildItem -Path $targetDirectory -Directory -Force -ErrorAction SilentlyContinue 
Write-Output $subFolders.Name
$counter = 0
$subFolders | %{
    $counter++
    $sleepCheck = $counter % 5
    if($sleepCheck -eq 0){
        start-sleep -Seconds 300
    }
    $newProjectName = $teamPath + "/" + $projectName + "-" + $_.Name
    $sourcePath = $_.FullName

    Write-Debug "$cliPath scan  -v -CxServer $sast_url -projectName $projectName -CxUser $username -CxPassword ***** -LocationType folder -LocationPath $sourcePath"

    &$cliPath Scan -v -CxServer $sast_url -projectName $newProjectName -CxUser $username -CxPassword $password -Locationtype "folder"  -Locationpath $sourcePath 
}