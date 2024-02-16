param(
    [Switch]$dbg
)

####CxOne Variable######
$cx1Tenant=""
$PAT=""
$cx1URL="https://ast.checkmarx.net/api"
$cx1TokenURL="https://iam.checkmarx.net/auth/realms/$cx1Tenant"
$cx1IamURL="https://iam.checkmarx.net/auth/admin/realms/$cx1Tenant"
$cliPath=""
$exportLog="scanProjectsCLI.log"

. "support/debug.ps1"

setupDebug($dbg.IsPresent)

Add-Type -AssemblyName System.Web

#Generate token for CxOne
$cx1Session = &"support/rest/cxone/apiTokenLogin.ps1" $cx1TokenURL $cx1URL "$cx1IamURL" $cx1Tenant $PAT

#Get list of CxOne projects
$cx1ProjectsResponse = &"support/rest/cxone/getprojects.ps1" $cx1Session
$cx1Projects = $cx1ProjectsResponse.projects
$targetProjects = $cx1Projects | Where-Object { $_.tags.SystemId -eq "Miguel"}

$validationLine = 0

$targetProjects | %{
    $validationLine++
    $sleepCheck = $validationLine % 10
    if($sleepCheck -eq 0){
        start-sleep -Seconds 300
        $cx1ProjectsResponse = &"support/rest/cxone/getprojects.ps1" $cx1Session
    }
    $projectName = $_.Name
    $repoId = $_.repoId
    #get the scm settings for the project
    if($repoId){
        $scmSettings = &"support/rest/cxone/getProjectSCMsettings.ps1" $cx1Session $repoId
        #$scmId = $scmSettings.scmId
        $repoUrl = $scmSettings.url
        $branch = $scmSettings.branches.name
        Write-Output $scmSettings

        $command = [String]::Format("{0} scan create --project-name {1} -s {2} --branch {3}", $cliPath, $projectName, $repoUrl, $branch)
        Write-Output "$command" > $exportLog
        &"$cliPath" scan create --project-name $projectName -s $repoUrl --branch $branch > $exportLog
        

    }
}