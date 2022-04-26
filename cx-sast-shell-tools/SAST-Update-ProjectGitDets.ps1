param(
    [Parameter(Mandatory = $true)]
    [System.Uri]$sast_url,
    [String]$username,
    [String]$password,
    [String]$privateKey,
    [String]$urlFilter,
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
            privateKey = $privateKey;
        }

        if($scmSettings.url -like "*$urlFilter*"){
            try{
                &"support/rest/sast/updateProjectGitSettings.ps1" $session $prjId $gitSettings
                $projectsUpdated += $currProject
            }
            catch{
                Write-Debug "Failed to update this project $_"
                $failedUpdates += $currProject
            }
        }

    }
    catch{
        Write-Debug "This project does not have git settings"
    }
}

#Print out the results
$projectsUpdated | Export-Csv -Path './UpdatedProjectDetails.csv' -Delimiter ',' -Append -NoTypeInformation
if($failedUpdates.count -gt 0){
    $failedUpdates | Export-Csv -Path './FailedProjectDetails.csv' -Delimiter ',' -Append -NoTypeInformation
}