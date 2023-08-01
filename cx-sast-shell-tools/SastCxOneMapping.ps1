param(
    [Switch]$dbg
)
####SAST Variables######
$sastUrl="https://cxprivatecloud.checkmarx.net"
$sastUser="mgonzalez"
$sastPassword="_NitdZ_xKKn4y6"

if(!$sastUser){
    $credentials = Get-Credential -Credential $null
    $sastUser = $credentials.UserName
    $sastPassword = $credentials.GetNetworkCredential().Password
}

####CxOne Variable######
$cx1Tenant="ps_na_miguel_gonzalez"
$PAT="eyJhbGciOiJIUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICIzZGMzMzdlOS03YWY1LTQyMTUtOTY0OC04MWU1MmJmMTNlOTYifQ.eyJpYXQiOjE2ODkxODE2MzksImp0aSI6IjM0N2M5MTczLTQ2YmItNGJjOS05MDJiLTdkYTdlOTUzYTNjNSIsImlzcyI6Imh0dHBzOi8vaWFtLmNoZWNrbWFyeC5uZXQvYXV0aC9yZWFsbXMvcHNfbmFfbWlndWVsX2dvbnphbGV6IiwiYXVkIjoiaHR0cHM6Ly9pYW0uY2hlY2ttYXJ4Lm5ldC9hdXRoL3JlYWxtcy9wc19uYV9taWd1ZWxfZ29uemFsZXoiLCJzdWIiOiI4NmJlOGEzMC1mZTRiLTQ0ZTQtODBkZi0wY2Y5YWQzYjg3M2IiLCJ0eXAiOiJPZmZsaW5lIiwiYXpwIjoiYXN0LWFwcCIsInNlc3Npb25fc3RhdGUiOiJlZmM3NWIzYS0xMzJjLTRhOTItOTBiZS1hMjFmZTUwNDdmODYiLCJzY29wZSI6IiBvZmZsaW5lX2FjY2VzcyIsInNpZCI6ImVmYzc1YjNhLTEzMmMtNGE5Mi05MGJlLWEyMWZlNTA0N2Y4NiJ9.qkKgUWBYn2UyNDaIO8mhzBfZ_dkLzW7VteA8aALXSBU"
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
$projectMatches=@()

$cx1Projects | %{
    $cx1ProjectName = $_.Name
    $cx1ProjectId = $_.id

    $sastProject = $sastProjects | Where-Object {$_.name -eq $cx1ProjectName}
    
    $csvEntry = New-Object -TypeName psobject -Property ([Ordered]@{
        ProjectName = $cx1ProjectName;
        SastId = $sastProject.id;
        CxOneId = $cx1ProjectId;
    })
    
    $projectMatches += $csvEntry
}

#Generate the csv file
$projectMatches | Export-Csv -Path './SAST_CX1_Mapping.csv' -Delimiter ',' -Append -NoTypeInformation