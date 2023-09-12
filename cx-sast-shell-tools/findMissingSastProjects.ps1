param(
    [Switch]$dbg
)
####SAST Variables######
$sastUrl=""
$sastUser=""
$sastPassword=""

if(!$sastUser){
    $credentials = Get-Credential -Credential $null
    $sastUser = $credentials.UserName
    $sastPassword = $credentials.GetNetworkCredential().Password
}

####CxOne Variable######
$cx1Tenant=""
$PAT=""
$cx1URL="https://ast.checkmarx.net/api"
$cx1TokenURL="https://iam.checkmarx.net/auth/realms/$cx1Tenant"
$cx1IamURL="https://iam.checkmarx.net/auth/admin/realms/$cx1Tenant"

. "support/debug.ps1"

setupDebug($dbg.IsPresent)

#Login and generate token for SAST
$sastSession = &"support/rest/sast/loginV2.ps1" $sastUrl $sastUser $sastPassword -dbg:$dbg.IsPresent

#Get list of all SAST projects
$sastProjects = &"support/rest/sast/projects.ps1" $sastSession

#Generate token for CxOne
$cx1Session = &"support/rest/cxone/apiTokenLogin.ps1" $cx1TokenURL $cx1URL $cx1IamURL $cx1Tenant $PAT

#Get list of CxOne projects
$cx1ProjectsResponse = &"support/rest/cxone/getprojects.ps1" $cx1Session
$cx1Projects = $cx1ProjectsResponse.projects

#Match the projects based on the name
$missingProjects=@()

$sastProjects | %{
    $sastProjectName = $_.Name
    $sastProjectId = $_.id

    Clear-Variable $sastProject
    $sastProject = $cx1Projects| Where-Object {$_.name -eq $sastProjectName}
    
    if(!$sastProject){

        $csvEntry = New-Object -TypeName psobject -Property ([Ordered]@{
            ProjectName = $sastProjectName;
            SastId = $sastProjectId;
            CxOneId = "Missing";
        })
        
        $missingProjects += $csvEntry
        
    }
}

#Generate the csv file
$missingProjects | Export-Csv -Path './SAST_CX1_MissingProjects.csv' -Delimiter ',' -Append -NoTypeInformation