param(
    [Parameter(Mandatory = $true)]
    [System.Uri]$sast_url,
    [String]$username,
    [String]$password,
    [Parameter(Mandatory = $true)]
    [String]$cutoff,
    [Switch]$dbg
)

if(!$username){
    $credentials = Get-Credential -Credential $null
    $username = $credentials.UserName
    $password = $credentials.GetNetworkCredential().Password
}

. "support/debug.ps1"

setupDebug($dbg.IsPresent)

#convert cutoff date
$culture = [Globalization.CultureInfo]::InvariantCulture
$pattern = "MM\/dd\/yyyy"
$cutOffDate = [DateTime]::ParseExact($cutoff, $pattern, $culture)

#Login and generate token
$session = &"support/rest/sast/login.ps1" $sast_url $username $password -dbg:$dbg.IsPresent

#Get the list of projects that have git configured for source control
$allprojects = &"support/rest/sast/projects.ps1" $session "2.2"
$teams = &"support/rest/sast/teams.ps1" $session


$targetProjects = @()

#branched projects
$branchedProjects = $allprojects | Where-Object {$_.isBranched -eq 1}

#build list of project information and scm configuration
$branchedProjects | %{
    #set project details
    $prjId = $_.id
    $prjName = $_.Name
    $prjTeamId = $_.teamId
    $prjTeam = $teams | Where-Object {$_.id -eq $prjTeamId}

    #parent project details
    $parentProjectId = $_.originalProjectId
    $parentProject = $allprojects | Where-Object {$_.id -eq $parentProjectId}
    $parentTeam = $teams | Where-Object {$_.id -eq $parentProject.teamId}

    try {
        $lastScan = &"support/rest/sast/scans.ps1" $session $prjId
        $scanDate = Get-Date($lastScan.dateAndTime.finishedOn)
        Write-Debug $scanDate
        
        if($scanDate -lt $cutOffDate){        
            try{
                $scmSettings = &"support/rest/sast/getprojectgitdetails.ps1" $session $prjId
            }
            catch{
                Write-Debug "This project: $prjName , does not have git configuration"
                $scmSettings = @{
                    url = "None"
                    Branch = "None"
                }
            }
        }
    }
    catch {
        Write-Debug "This project has not been scanned"
        $scmSettings = @{
            url = "None"
            branch = "None"
        }
        $scanDate = "Never Scanned"
    }
    
    
    $csvEntry = New-Object -TypeName psobject -Property ([Ordered]@{
        projectId = $prjId;
        projectName = $prjName;
        lastScanDate = $scanDate
        owningTeam = $prjTeam.Name;
        projectUrl = $scmSettings.url;
        projectGitBranch = $scmSettings.branch;
        parentProject = $parentProject.Name
        parentTeam = $parentTeam.Name
    })
    
    
    #Write-Debug $csvEntry
    $targetProjects +=$csvEntry
       
}

$targetProjects | Export-Csv -Path './TargetBranchedProjectDetails.csv' -Delimiter ',' -Append -NoTypeInformation

Write-Output "Please review the csv and verify that you wish to delete all projects found in the TargetBranchedProjectDetails.csv"
$verification = Read-Host -Prompt "Do you wish to delete all of the listed projects (y/n)"

$failedProjects = @()
if($verification -eq 'y'){
    $targetProjects | %{
        try{
            &"support/rest/sast/deleteproject.ps1" $session $_.projectId
        }
        catch{
            Write-Debug "this one failed"
            $failedProjects += $_
        }
    }
    $failedProjects | Export-Csv -Path './FailedToDeleteProjects.csv' -Delimiter ',' -Append -NoTypeInformation
}
else{
    Write-Output "This process has been aborted"
    Exit
}