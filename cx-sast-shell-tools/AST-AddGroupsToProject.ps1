param(
    [Switch]$dbg
)

####CxOne Variable######
$cx1Tenant=""
$PAT=""
$cx1URL="https://ast.checkmarx.net/api"
$cx1TokenURL="https://iam.checkmarx.net/auth/realms/$cx1Tenant"
$cx1IamURL="https://iam.checkmarx.net/auth/admin/realms/$cx1Tenant"
$groupName = ""

. "support/debug.ps1"

setupDebug($dbg.IsPresent)

Add-Type -AssemblyName System.Web

#Generate token for CxOne
$cx1Session = &"support/rest/cxone/apiTokenLogin.ps1" $cx1TokenURL $cx1URL "$cx1IamURL" $cx1Tenant $PAT

#Get list of CxOne projects
$cx1ProjectsResponse = &"support/rest/cxone/getprojects.ps1" $cx1Session
$cx1Projects = $cx1ProjectsResponse.projects


#Get list of CxOne groups
$cx1Groups = &"support/rest/cxone/getgroups.ps1" $cx1Session
$targetGroup = $cx1Groups | Where-Object {$_.name -eq $groupName}

$validationLine = 0

$cx1Projects | %{
    
    $newGroups = @()
    $newGroups += $_.groups
    $newGroups += $targetGroup.id
    $projectUpdate = @{
        name        = $_.name
        groups      = $newGroups
        tags        = $_.tags
        repoUrl     = $_.repoUrl
        mainBranch  = $_.mainBranch
    }

    $response = $cx1ProjectsResponse = &"support/rest/cxone/updateproject.ps1" $cx1Session $_.id $projectUpdate
}

