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
$session = &"support/rest/sast/login.ps1" $sast_url $username $password -dbg:$dbg.IsPresent

$teams = &"support/rest/sast/teams.ps1" $session
$projects = &"support/rest/sast/projects.ps1" $session

$culture = [Globalization.CultureInfo]::InvariantCulture
$pattern = "dd\/MM\/yyyy"
$cutOffDate = [DateTime]::ParseExact($cutoff, $pattern, $culture)
Write-Debug $cutOffDate

$oldProjects = @()
$targetProjectCsv = @()    
#Gather list of projects that will be deleted
$teams | %{
    $teamId = $_.id
    
    $projects | %{
        try{
            $lastScan = &"support/rest/sast/scans.ps1" $session $_.id

            Write-Debug $lastScan.dateAndTime.finishedOn
            $scanDate = Get-Date($lastScan.dateAndTime.finishedOn)
    
            if($scanDate -lt $cutOffDate){
                $oldProjects += $_
                $projectTeam = $_.teamId
                $currTeam = $teams | Where-Object{$_.id -eq $projectTeam}

                $targetProject = New-Object -TypeName psobject -Property ([Ordered]@{
                    id = $_.id;
                    teamName = $currTeam.fullName
                    projectName = $_.name
                    lastScanDate = $scanDate
                })

                $targetProjectCsv += $targetProject
            }
        }
        catch{
            Write-Debug "No scans for this project."
        }
    }
}

if($oldProjects.count -eq 0){
    Write-Output "No projects found to have last scan date older than $cutoff"
}
else{

    #Delete Projects
    Write-Output "The projects that will fail to scan are listed in the TargetProject.csv file"
    
    $targetProjectCsv | Export-Csv -Path './TargetProject.csv' -Delimiter ',' -Append -NoTypeInformation
    $output = [string]::Format("Totoal number of projects to be affected: {0}", $oldProjects.count)
    Write-Output $output
    
}


#Summary
$output = [string]::Format("Totoal number of projects that are affected: {0}", $oldProjects.count)
Write-Output $output
