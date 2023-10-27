param(
    [Parameter(Mandatory = $true)]
    [System.Uri]$sast_url,
    [Parameter(Mandatory = $true)]
    [String]$username,
    [Parameter(Mandatory = $true)]
    [String]$password,
    [Switch]$dbg
)

. "support/debug.ps1"

setupDebug($dbg.IsPresent)

Add-Type -AssemblyName System.Web

if(!$username){
    $credentials = Get-Credential -Credential $null
    $username = $credentials.UserName
    $password = $credentials.GetNetworkCredential().Password
}

# login
# use rest api to
# - Get projects
# - Get the last finished scan for each project
# Use soap api to create a report with the template
# Use rest api to
# - probe for report complete
# - download report

$session = &"support/rest/sast/loginV2.ps1" $sast_url $username $password -dbg:$dbg.IsPresent

$timer = $(Get-Date)
Write-Output "Fetching projects"
$projects = &"support/rest/sast/projects.ps1" $session
Write-Output "$($projects.Length) projects fetched - elapsed time $($(Get-Date).Subtract($timer))"
$projects | % { Write-Debug $_ } 


$timer = $(Get-Date)
Write-Output "Fetching teams"
$teams = &"support/rest/sast/teams.ps1" $session

Write-Output "Fetching Reports"
$projects | % {
    
    $scans = &"support/rest/sast/scans.ps1" $session $_.id
    $projectName = $_.name
    $teamId = $_.TeamId
    $teamInfo = $teams | Where-Object {$_.id -eq $teamId}
    $teamName = $teamInfo.fullName

    $reportRequest = @{
        reportType = "pdf"
        scanId = $scans.Id
    }

    #generate the report
    $report = &"support/rest/sast/createScanReport.ps1" $session $reportRequest
    $reportId = $report.reportId
    
    while ($reportstatus.status.value -ne "Created" -and $reportstatus.status.value -ne "Failed") {
        Start-Sleep -Seconds 5
        #get the status of the report
        $reportstatus = &"support/rest/sast/reportStatus.ps1" $session $reportId
        Write-Debug $reportstatus.status.value
    }
    if($reportstatus.status.value -eq "Created"){
        #download the report
        $status = [String]::Format("Report successfully created for id = {0}", $reportId)

        $outputPath = $PSScriptRoot + "\Output"
        write-output "teamName = $teamName"
        &"support/rest/sast/getreport.ps1" $session $reportId $teamName $projectName $outputPath
    }else{
        $status = [String]::Format("Report creation failed for id = {0}", $reportId)
    }
    Write-Output $status

}
