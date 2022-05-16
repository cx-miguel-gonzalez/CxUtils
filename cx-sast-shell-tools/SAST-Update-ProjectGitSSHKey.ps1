param(
    [Parameter(Mandatory = $true)]
    [System.Uri]$sast_url,
    [String]$username,
    [String]$password,
    [String]$sshKey,
    [String]$sshKeyFile,
    [String]$projectNameFilter,
    [Switch]$exec,
    [Switch]$dbg
)

if(!$username){
    $credentials = Get-Credential -Credential $null
    $username = $credentials.UserName
    $password = $credentials.GetNetworkCredential().Password
}


. "support/debug.ps1"

setupDebug($dbg.IsPresent)

if (!$exec.IsPresent) {
    Write-Output "DRY-RUN MODE. Will NOT update project settings."
}

# Ensure SSH key file can be read
if ($sshKeyFile) {
    $sshKeyFilePath = (Get-Item -Path $sshKeyFile).FullName
    Write-Output "Reading SSH Key from $sshKeyFilePath"
    $sshKey = Get-Content -Path $sshKeyFilePath -Raw
}

if (!$sshKey) {
    Write-Output "SSH key was empty."
    exit 1
}

#Login and generate token
$session = &"support/rest/sast/login.ps1" $sast_url $username $password -dbg:$dbg.IsPresent

# $teams = &"support/rest/sast/teams.ps1" $session
$projects = &"support/rest/sast/projects.ps1" $session
$projectsUpdated = @()
$failedUpdates = @()

#Gather list of projects that will be deleted
$projects | %{
    $prjId = $_.id
    $currProject = $_
    try{
        $scmSettings = &"support/rest/sast/getprojectgitdetails.ps1" $session $_.id
        
        $gitSettings = @{
            url = $scmSettings.url;
            branch = $scmSettings.branch;
            privateKey = $sshKey
        }

        if($currProject.Name -like "*$projectNameFilter*"){
            try{
                # Execute API if not in dry-run mode
                if ($exec.IsPresent) {
                    &"support/rest/sast/updateProjectGitSettings.ps1" $session $prjId $gitSettings
                }
                $projectsUpdated += $currProject.Name
            }
            catch{
                Write-Debug "This project does not meet update requirements $_"
                $failedUpdates += $currProject.Name
            }
        }

    }
    catch{
        Write-Debug "This project does not have git settings"
    }
}

#Print out the results
if($projectsUpdated.count -gt 0){
    Write-Output "The following projects were updated:" 
    $projectsUpdated | Format-Table
}
else{
    Write-Output "No projects were updated"
}

if($failedUpdates.count -gt 0){
    Write-Output "The following projects could NOT be updated:"    
    $failedUpdates | Format-Table
}