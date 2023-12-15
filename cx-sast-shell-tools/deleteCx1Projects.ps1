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


#Generate token for CxOne
$cx1Session = &"support/rest/cxone/apiTokenLogin.ps1" $cx1TokenURL $cx1URL "$cx1IamURL" $cx1Tenant $PAT

#Get list of CxOne projects
$cx1ProjectsResponse = &"support/rest/cxone/getprojects.ps1" $cx1Session
$cx1Projects = $cx1ProjectsResponse.projects

#Get list of CxOne groups
$cx1Groups = &"support/rest/cxone/getgroups.ps1" $cx1Session

$validationLine = 0
Import-Csv $csv_path | ForEach-Object {
    $validationLine++
    $projectId = $_.Project_ID
    $projectName = $_.Project_Name

    if($projectData){
        try{
            &"support/rest/cxone/deleteproject.ps1" $cx1Session $projectId
            Write-Output "Found a Project Match $projectName"
        }
        catch{
            $message = [String]::Format("Failed to delete project: {0}", $projectData.name)
            Write-Output $message
        }
    }
    else{
        Write-Output "Project Not found $projectName"
    }
    
}