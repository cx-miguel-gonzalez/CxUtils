param(
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
$cx1Session = &"support/rest/cxone/apiTokenLogin.ps1" $cx1TokenURL $cx1URL "$cx1IamURL" $cx1Tenant $PAT

#Get list of CxOne projects
$cx1ProjectsResponse = &"support/rest/cxone/getprojects.ps1" $cx1Session
$cx1Projects = $cx1ProjectsResponse.projects

$cx1Projects | %{
    $projectScans = &"support/rest/cxone/getscansforproject.ps1" $cx1Session $_.id
    if($projectScans.filteredTotalCount -eq 0){
        $message = [String]::Format("This project will be deleted {0}", $_.name)
        Write-Output $message
        try{
            &"support/rest/cxone/deleteproject.ps1" $cx1Session $_.id
        }
        catch{
            $message = [String]::Format("Failed to delete project: {0}", $_.name)
            Write-Output $message
        }
    }
}