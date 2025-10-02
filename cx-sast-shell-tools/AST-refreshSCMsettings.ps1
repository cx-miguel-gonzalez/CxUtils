param(
    [Switch]$dbg,
    [String]$csv_path
)

####CxOne Variables######
#Please update with the values for your environment and respective region
#update the url based on your login page. ex: https://ast.checkmarx.net, https://us.ast.checkmarx.net
#add an API key as the $PAT value
$cx1Tenant=""
$PAT=""
$cx1URL="https://ast.checkmarx.net/api"
$cx1TokenURL="https://iam.checkmarx.net/auth/realms/$cx1Tenant"
$cx1IamURL="https://iam.checkmarx.net/auth/admin/realms/$cx1Tenant"
$scmType="cloud"
$scmInstanceName="github" #only if scmType is self-hosted
$scmOrg=""
$scmAuthCode=""
$csv_path=""


. "support/debug.ps1"

setupDebug($dbg.IsPresent)

Add-Type -AssemblyName System.Web

#Generate token for CxOne
$cx1Session = &"support/rest/cxone/apiTokenLogin.ps1" $cx1TokenURL $cx1URL "$cx1IamURL" $cx1Tenant $PAT

#Get list of SCMs 
$cx1ScmList = &"support/rest/cxone/getScms.ps1" $cx1Session
$targetScm = $cx1ScmList | Where-Object {$_.type -eq $scmInstanceName}

#Get list of CxOne projects
$cx1ProjectsResponse = &"support/rest/cxone/getprojects.ps1" $cx1Session
$cx1Projects = $cx1ProjectsResponse.projects

#Get list of repositories that have been imported
$scmProjectsResponse= &"support/rest/cxone/getProjectsFromSCM.ps1" $cx1Session $scmAuthCode $targetScm.id $scmOrg "1"
$allRepos = $scmProjectsResponse.repoWebDtoList

#Determine target projects
if($csv_path -ne $null){
    $targetRepos = @()
    Import-Csv $csv_path | ForEach-Object {
    $projectName = $_.ProjectName
    $target = $allRepos | Where-Object {$_.fullName -eq $projectName}
    $targetRepos += $target
    }
}
else{
    $targetRepos = $allRepos | Where-Object {$_.repoId -ne $null}
}


#1. get project id for each of the repos
#2. update refresh the repository settings
#3. build out the scan request
#       - need scm id, repo origin, project name, scanner types
$validationLine = 0

$targetRepos | %{
    $validationLine++
    $repoId = $_.repoId
    $sleepCheck = $validationLine % 50
    if($sleepCheck -eq 0){
        start-sleep -Seconds 300
        $cx1Session = &"support/rest/cxone/apiTokenLogin.ps1" $cx1TokenURL $cx1URL "$cx1IamURL" $cx1Tenant $PAT
    }

    $targetProject = $cx1Projects | Where-Object {$_.repoId -eq $repoId}
    $targetScmSettings = &"support/rest/cxone/getProjectSCMsettings.ps1" $cx1Session $repoId

    #Create SCM Settings body
    $scanEngines = @()

    #pull enabled scanners
    if ($targetScmSettings.sastScannerEnabled -eq $true){
        $scanEngines += "sast"
    }
    if ($targetScmSettings.scaScannerEnabled -eq $true){
        $scanEngines += "sca"
    }
    if ($targetScmSettings.kicsScannerEnabled -eq $true){
        $scanEngines += "kics"
    }
    if ($targetScmSettings.apiSecScannerEnabled -eq $true){
        $scanEngines += "apisec"
    }
    if ($targetScmSettings.containerScannerEnabled -eq $true){
        $scanEngines += "containers"
    }
    if ($targetScmSettings.ossfSecoreCardScannerEnabled -eq $true){
        $scanEngines += "scorecard"
    }
    if ($targetScmSettings.secretsDerectionScannerEnabled -eq $true){
        $scanEngines += "2ms"
    }

    $scmSettings = @{
        astProjectId = $targetProject.id
        astProjectName = $targetProject.name
        importedProjectName = $targetProject.imported_proj_name
        repoId = $repoId
        scanEngines = $scanEngines
    }
    
    
    #Refresh Repository Setting
    &"support/rest/cxone/refreshRepositorySettings.ps1" $cx1Session $targetScm.id $scmAuthCode $targetProject.id $scmSettings

}