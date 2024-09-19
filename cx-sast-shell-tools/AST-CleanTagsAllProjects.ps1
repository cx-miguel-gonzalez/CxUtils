param(
    [Switch]$dbg
)

####CxOne Variable######
$cx1Tenant=""
$PAT=""
$cx1URL="https://ast.checkmarx.net/api"
$cx1TokenURL="https://iam.checkmarx.net/auth/realms/$cx1Tenant"
$cx1IamURL="https://iam.checkmarx.net/auth/admin/realms/$cx1Tenant"
#$cliPath=/Repos/Bins/ast-cli-2.2.5/bin/cx.exe"

. "support/debug.ps1"

setupDebug($dbg.IsPresent)

Add-Type -AssemblyName System.Web

#Generate token for CxOne
$cx1Session = &"support/rest/cxone/apiTokenLogin.ps1" $cx1TokenURL $cx1URL "$cx1IamURL" $cx1Tenant $PAT

#Get list of CxOne projects
$cx1ProjectsResponse = &"support/rest/cxone/getprojects.ps1" $cx1Session
$cx1Projects = $cx1ProjectsResponse.projects
$tagedProjects = $cx1Projects | Where-Object {-not [string]::IsNullOrEmpty($_.tags)}

# $validationLine = 0

$tagedProjects | ForEach-Object {
    $project = $_
    
    # Initialize a new hashtable for updated tags
    $updatedTags = @{}
    $count = 0
    
    # Iterate through each property in the tags object
    $project.tags | Get-Member -MemberType Properties | ForEach-Object {
        $key = $_.Name
        $value = $project.tags.$key
        # Check if the value contains a comma
        if ($value -match ",") {
            # Replace commas in the tag value
            $updatedTags[$key] = $value -replace ",", ""
            $count++
        } else {
            # Keep the original value if no comma is found
            $updatedTags[$key] = $value
        }
    }

    # Debugging 
    #Write-Host "Original Tags: $($project.tags)"
    #Write-Host "Updated Tags: $updatedTagsJson"
        
    # Rebuild the project object with the updated tags
    $projectUpdate = @{
        name              = $project.name
        groups            = $project.groups
        tags              = $updatedTags
        repoUrl           = $project.repoUrl
        mainBranch        = $project.mainBranch
    }
    
    # Update the project
    $response = &"support/rest/cxone/updateproject.ps1" $cx1Session $_.id $projectUpdate
    Write-Host "Project $($project.name) had $count tags modified"
}
