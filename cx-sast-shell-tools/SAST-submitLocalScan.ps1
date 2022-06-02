param(
    [Parameter(Mandatory = $true)]
    [System.Uri]$sast_url,
    [String]$username,
    [String]$password,
    [String]$zipLocation,
    [string]$projectName,
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

$projects = &"support/rest/sast/projects.ps1" $session

$targetProject = $projects | where-object {$_.Name -eq $projectName}


$sastScanId = &"support/rest/sast/scanWithSettings.ps1" $session $targetProject.Id $zipLocation
$osaScanId = &"support/rest/sast/osaScan.ps1" $session $targetProject.id $zipLocation

write-output "Sast scan ID " $sastScanId
write-output "Osa scan ID " $osaScanId