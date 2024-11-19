param(
    [string]$feedbackProfile,
    [Switch]$dbg
)

####CxOne Variable######
$cx1Tenant=""
$PAT=""
$cx1URL="https://ast.checkmarx.net/api"
$cx1TokenURL="https://iam.checkmarx.net/auth/realms/$cx1Tenant"
$cx1IamURL="https://iam.checkmarx.net/auth/admin/realms/$cx1Tenant"

. "support/debug.ps1"

setupDebug($dbg.IsPresent)

#Generate token for CxOne
$cx1Session = &"support/rest/cxone/apiTokenLogin.ps1" $cx1TokenURL $cx1URL $cx1IamURL $cx1Tenant $PAT

#Get list of CxOne projects
$cx1ProjectsResponse = &"support/rest/cxone/getprojects.ps1" $cx1Session
$cx1Projects = $cx1ProjectsResponse.projects

#Get feedback profiles
$allFeedbackProfiles = &"support/rest/cxone/getfeedbackprofiles.ps1" $cx1Session
$targetProfile=$allFeedbackProfiles | Where-Object {$_.name -eq $feedbackProfile}

$allFeedbackProfiles | %{
    if($_.name -eq $feedbackProfile){
        $targetProfile=$_
    }
}

$apps=@()
$apps+=$targetProfile.feedbackAppDtos.id
#create update
$profileUpdate=@{
    id = $targetProfile.Id
    name = $targetProfile.name
    appsIds=$apps
    description=""
    tags=""
    projectsIds=$cx1Projects.Id
}

$repsonse = &"support/rest/cxone/updateFeedbackProfile.ps1" $cx1Session $profileUpdate
