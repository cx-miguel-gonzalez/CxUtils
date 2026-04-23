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
$scmType="cloud" #cloud or slef-hosted
$scmInstanceName="" #github, bitbucket, azure, gitlab or self-hosted label
$scmOrg=""
$scmAuthCode="" #Personal Access Token for the SCM
#$csv_path=$null


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
$orgReposResponse= &"support/rest/cxone/getProjectsFromSCM.ps1" $cx1Session $scmAuthCode $targetScm.id $scmOrg "50"
$allRepos = $orgReposResponse.repos

#Determine target projects
if($csv_path -ne $null -and $csv_path -ne ""){
    $targetRepos = @()
    Import-Csv $csv_path | ForEach-Object {
    $projectName = $_.ProjectName
    $target = $cx1Projects | Where-Object {$_.name -eq $projectName}
    $targetRepos += $target
    }
}
else{
    if($scmInstanceName -eq "github"){
        $targetRepos = $cx1Projects | Where-Object {$_.imported_proj_name -in $allRepos.fullName}
    }
    elseif ($scmInstanceName -eq "azure") {
        $allRepoFullNames = $allRepos | ForEach-Object {
            "$($scmOrg)/$($_.name)"
        }
        $targetRepos = $cx1Projects | Where-Object {$_.imported_proj_name -in $allRepoFullNames}
    }
}


#1. get project id for each of the repos
#2. update refresh the repository settings
#3. build out the scan request
#       - need scm id, repo origin, project name, scanner types
$validationLine = 0
$refreshErrors = @()
$refreshSuccesses = @()
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
    if ($targetScmSettings.ossfScoreCardScannerEnabled -eq $true){
        $scanEngines += "scorecard"
    }
    if ($targetScmSettings.secretsDetectionScannerEnabled -eq $true){
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
    try{
        $response = &"support/rest/cxone/refreshRepositorySettings.ps1" $cx1Session $targetScm.id $scmAuthCode $targetProject.id $scmSettings
        Write-Output $response

        $refreshSuccesses += $targetProject
    }
    catch{
        $refreshErrors += $targetProject
        Write-Output "Error refreshing SCM settings for project: $($targetProject.name)"
    }
    Write-Output "Refreshed SCM settings for project: $($targetProject.name)"

    
}

# Export results to CSV files
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$successCsvPath = "refreshSuccesses-$timestamp.csv"
$errorsCsvPath = "repoErrors-$timestamp.csv"

if ($refreshSuccesses -and $refreshSuccesses.Count -gt 0) {
	$refreshSuccesses | Export-Csv -Path $successCsvPath -NoTypeInformation
	Write-Output "Wrote refresh successes to: $successCsvPath"
}
else {
	Write-Output "No refresh successes to write."
}

if ($refreshErrors -and $refreshErrors.Count -gt 0) {
	$refreshErrors | Export-Csv -Path $errorsCsvPath -NoTypeInformation
	Write-Output "Wrote repo errors to: $errorsCsvPath"
}
else {
	Write-Output "No repo errors to write."
}