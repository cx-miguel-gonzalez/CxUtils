param(
    [Switch]$dbg
)

####CxOne Variable######
$cx1Tenant=""
$PAT=""
$cx1URL="https://ast.checkmarx.net/api"
$cx1TokenURL="https://iam.checkmarx.net/auth/realms/$cx1Tenant"
$cx1IamURL="https://iam.checkmarx.net/auth/admin/realms/$cx1Tenant"
$csv_path="SAST_CX1_MapTest.csv"

. "support/debug.ps1"

setupDebug($dbg.IsPresent)


#Generate token for CxOne
$cx1Session = &"support/rest/cxone/apiTokenLogin.ps1" $cx1TokenURL $cx1URL "$cx1IamURL" $cx1Tenant $PAT

#get SCM Orgs
#$scmOrgs= &"support/rest/cxone/getScmOrgs.ps1" $cx1Session
$scmRepos= &"support/rest/cxone/getScmRepos.ps1" $cx1Session "MGLcx"
Write-Output $scmRepos.repoWebDtoList

