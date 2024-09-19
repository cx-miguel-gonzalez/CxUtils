param(
    [string]$csv_path,
    [Switch]$dbg
)

####CxOne Variable######
$cx1Tenant=""
$PAT=""
$cx1URL="https://ast.checkmarx.net/api"
$cx1TokenURL="https://iam.checkmarx.net/auth/realms/$cx1Tenant"
$cx1IamURL="https://iam.checkmarx.net/auth/admin/realms/$cx1Tenant"
$csv_path=""

. "support/debug.ps1"

setupDebug($dbg.IsPresent)

Add-Type -AssemblyName System.Web

#Generate token for CxOne
$cx1Session = &"support/rest/cxone/apiTokenLogin.ps1" $cx1TokenURL $cx1URL "$cx1IamURL" $cx1Tenant $PAT

#Get list of CxOne projects
$cx1ProjectsResponse = &"support/rest/cxone/getprojects.ps1" $cx1Session
$cx1Projects = $cx1ProjectsResponse.projects

Write-Output $csv_path
$validationLine = 0
Import-Csv $csv_path | ForEach-Object {
    $validationLine++
    $sleepCheck = $validationLine % 10
    if($sleepCheck -eq 0){
        start-sleep -Seconds 300
    }
    
    $projectName = $_.ProjectName
    $repoBranch = $_.PrimaryBranch.replace("/refs/heads/","")

    $projectData = $cx1Projects | Where-Object {$_.name -eq $projectName}

    $projectConfiguration = &"support/rest/cxone/getprojectconfig.ps1" $cx1Session $projectData.id

    #update project groups and primary branch
    $projectDetails = @{
        name = $projectName
        mainBranch = $repoBranch
    }

    $response = &"support/rest/cxone/updateproject.ps1" $cx1Session $projectData.id $projectDetails
    Write-Debug $response

}