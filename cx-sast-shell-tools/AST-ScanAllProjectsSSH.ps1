param(
    [Switch]$dbg
)

####CxOne Variables######
$cx1Tenant=""
$PAT=""
$cx1URL="https://ast.checkmarx.net/api"
$cx1TokenURL="https://iam.checkmarx.net/auth/realms/$cx1Tenant"
$cx1IamURL="https://iam.checkmarx.net/auth/admin/realms/$cx1Tenant"

. "support/debug.ps1"

setupDebug($dbg.IsPresent)

Add-Type -AssemblyName System.Web

#Generate token for CxOne
$cx1Session = &"support/rest/cxone/apiTokenLogin.ps1" $cx1TokenURL $cx1URL "$cx1IamURL" $cx1Tenant $PAT

#Get list of CxOne projects
$cx1ProjectsResponse = &"support/rest/cxone/getprojects.ps1" $cx1Session
$cx1Projects = $cx1ProjectsResponse.projects
$targetProjects = $cx1Projects | Where-Object { $_.tags.SystemId -eq "Rxsense"}

$validationLine = 0

$targetProjects | %{
    $validationLine++
    $sleepCheck = $validationLine % 10
    if($sleepCheck -eq 0){
        start-sleep -Seconds 300
    }
    $projectName = $_.Name
    $repoId = $_.repoId
    $projectId = $_.id
    write-output $projectName
    #get the scm settings for the project
    if($repoId){
        $scmSettings = &"support/rest/cxone/getProjectSCMsettings.ps1" $cx1Session $repoId
        Write-Output $scmSettings
        #initiate scan for the project if we have git settings
        $gitScanRequest = @{
            type = "git"
            handler = @{
                branch = $scmSettings.branches[0].name
                repoUrl = $scmSettings.sshRepoUrl
            }
            project = @{
                id = $projectId
                repoId = $repoId
            }
            config = @(
                @{
                    type = "sast"
                },
                @{
                    type = "sca"
                }
            )
        }
        write-output $gitScanRequest
        #Write-Output $gitScanRequest.handler
        $response = &"support/rest/cxone/creategitscan.ps1" $cx1Session $gitScanRequest
        exit
    }
}