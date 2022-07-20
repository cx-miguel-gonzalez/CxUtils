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


#Login and generate token
$session = &"support/rest/sast/loginV2.ps1" $sast_url $username $password -dbg:$dbg.IsPresent

$teams = &"support/rest/sast/teams.ps1" $session
$projects = &"support/rest/sast/projects.ps1" $session

$culture = [Globalization.CultureInfo]::InvariantCulture
$pattern = "dd\/MM\/yyyy"
$cutOffDate = [DateTime]::ParseExact($cutoff, $pattern, $culture)
Write-Debug $cutOffDate

$targetProjectCsv = @()    

#Gather list of projects that will be deleted
$projects | %{

    $id = $_.id
    $projectTeam = $_.teamId
    $currTeam = $teams | Where-Object{$_.id -eq $projectTeam}
    $projectName = $_.name

    try{
        $lastScan = &"support/rest/sast/scans.ps1" $session $_.id

        Write-Debug $lastScan.dateAndTime.finishedOn
        $scanDate = Get-Date($lastScan.dateAndTime.finishedOn)

        if($scanDate -lt $cutOffDate){

            $targetProject = New-Object -TypeName psobject -Property ([Ordered]@{
                id = $id
                teamName = $currTeam.fullName
                projectName = $projectName
                lastScanDate = $scanDate
            })

            $targetProjectCsv += $targetProject
        }
    }
    catch{
        Write-Debug "No scans for this project."
        #If project does not have any scans add it to the list to be deleted
        $targetProject = New-Object -TypeName psobject -Property ([Ordered]@{
            id = $id
            teamName = $currTeam.fullName
            projectName = $projectName
            lastScanDate = $scanDate
        })

        $targetProjectCsv += $targetProject
    }
}

if($targetProjectCsv.count -eq 0){
    Write-Output "No projects found to have last scan date older than $cutoff"
}
else{

    #Delete Projects
    Write-Output "The following projects that will be deleted can be found in the TargetProjectsForDeletion.csv file"
    
    $targetProjectCsv | Export-Csv -Path './TargetProjectsForDeletion.csv' -Delimiter ',' -Append -NoTypeInformation
    $output = [string]::Format("Totoal number of projects to be affected: {0}", $targetProjectCsv.count)
    Write-Output $output

    $verification = Read-Host -Prompt "Are you sure you want to delete all projects listed in the csv (y/n)"
    #delete target projects
    if($verification -eq "y"){
        Write-Debug "You have confirmed your're going to delete the projects"
        $targetProjectCsv | %{
            &"support/rest/sast/deleteproject.ps1" $session $_.id
        }

        #Summary
        $output = [String]::Format("{0} projects have been successfully deleted", $targetProjects.count)
        Write-Output $output

    }
    else{
        Write-Output "Process Aborted"
        exit
    }
}



