param(
    [Parameter(Mandatory = $true)]
    [System.Uri]$sast_url,
    [String]$username,
    [String]$password,
    [String]$pat,
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
    Write-Output $_.Name
    try{
        $scmSettings = &"support/rest/sast/getprojectgitdetails.ps1" $session $_.id
        
        $newGitUrl = $scmSettings.url.substring(0,8) + $pat + "@" + $scmSettings.url.substring($scmSettings.url.length-($scmSettings.url.length-8))

        $gitSettings = @{
            url = $newGitUrl;
            branch = $scmSettings.branch;
        }
        Write-Debug $newGitUrl

        if($scmSettings.url -like "*$urlFilter*"){
            try{
                &"support/rest/sast/updateProjectGitSettings.ps1" $session $prjId $gitSettings
                $projectsUpdated += $currProject
            }
            catch{
                Write-Debug "This project does not meet update requirements $_"
                $failedUpdates += $currProject
            }
        }

    }
    catch{
        Write-Debug "This project does not have git settings"
    }
}

#Print out the results
if($projectsUpdated.count -gt 0){
    $projectsUpdated | Export-Csv -Path './UpdatedProjectDetails.csv' -Delimiter ',' -Append -NoTypeInformation
}
else{
    Write-Output "No projects were updated"
}

if($failedUpdates.count -gt 0){
    $failedUpdates | Export-Csv -Path './FailedProjectDetails.csv' -Delimiter ',' -Append -NoTypeInformation
}