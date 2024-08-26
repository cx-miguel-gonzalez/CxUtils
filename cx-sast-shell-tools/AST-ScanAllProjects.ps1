param(
    [Switch]$dbg
)

####CxOne Variable######
$cx1Tenant="ps_na_miguel_gonzalez"
$PAT="eyJhbGciOiJIUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICIzZGMzMzdlOS03YWY1LTQyMTUtOTY0OC04MWU1MmJmMTNlOTYifQ.eyJpYXQiOjE3MDQ0NzY4NzcsImp0aSI6Ijk4OWM3MGQ5LWJlMDMtNDJkZC04ODBmLWY1NDRjNDllOWJmNSIsImlzcyI6Imh0dHBzOi8vaWFtLmNoZWNrbWFyeC5uZXQvYXV0aC9yZWFsbXMvcHNfbmFfbWlndWVsX2dvbnphbGV6IiwiYXVkIjoiaHR0cHM6Ly9pYW0uY2hlY2ttYXJ4Lm5ldC9hdXRoL3JlYWxtcy9wc19uYV9taWd1ZWxfZ29uemFsZXoiLCJzdWIiOiI4NmJlOGEzMC1mZTRiLTQ0ZTQtODBkZi0wY2Y5YWQzYjg3M2IiLCJ0eXAiOiJPZmZsaW5lIiwiYXpwIjoiYXN0LWFwcCIsInNlc3Npb25fc3RhdGUiOiI5YjVlMzQ2OS03NmFjLTRhNWMtYjViMi0xZTFjNTI0NjUzMTYiLCJzY29wZSI6IiBvZmZsaW5lX2FjY2VzcyIsInNpZCI6IjliNWUzNDY5LTc2YWMtNGE1Yy1iNWIyLTFlMWM1MjQ2NTMxNiJ9.5K1xdsNMzrHYogTsZr4sSUQipDabIwnnV5z9reBpFPk"
$cx1URL="https://ast.checkmarx.net/api"
$cx1TokenURL="https://iam.checkmarx.net/auth/realms/$cx1Tenant"
$cx1IamURL="https://iam.checkmarx.net/auth/admin/realms/$cx1Tenant"
$cliPath="/Users/miguelg/Documents/cx"

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

        $command = [String]::Format("{0} scan create --project-name {1} -s {2} --branch {3}", $exportToolPath, $projectName, $repoUrl, $branch)
        Write-Output "$command" > $exportLog
        &"$exportToolPath" scan create --project-name $projectName -s $repoUrl --branch $branch > $exportLog
        
        #initiate scan for the project if we have git settings
#        $gitScanRequest = @{
#            repoOrigin = "github"
#            project = @{
#                repoIdentity = $repoName
#                repoUrl = $scmSettings.url
#                projectId = $projectId
#                repoId = $repoId
#                scannerTypes = @("sast","sca")
#                isIncrementalScan = $false
#                sshRepoUrl = $scmSettings.sshRepoUrl
#            }
#            orgSSHKey = $null
#        }
#        write-output $gitScanRequest | ConvertTo-Json -Depth 10
#        #Write-Output $gitScanRequest.handler
#        $response = &"support/rest/cxone/createSCMscan.ps1" $cx1Session $scmId $orgName $projectId $gitScanRequest
        exit
    }
}