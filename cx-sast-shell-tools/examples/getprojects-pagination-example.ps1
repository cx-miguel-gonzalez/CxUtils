# Example: How to use the updated getprojects.ps1 with pagination

# Load the session (this would be your actual session creation code)
# $cx1Session = &"support/rest/cxone/apiTokenLogin.ps1" $cx1TokenURL $cx1URL $cx1IamURL $cx1Tenant $PAT

# Method 1: Use pagination (default behavior)
# This will automatically page through ALL projects, regardless of count
$allProjectsResponse = &"support/rest/cxone/getprojects.ps1" $cx1Session
Write-Output "Total projects retrieved with pagination: $($allProjectsResponse.projects.Count)"

# Method 2: Use pagination with custom page size
# Smaller page sizes = more API calls but less memory per call
$allProjectsResponseSmallPages = &"support/rest/cxone/getprojects.ps1" $cx1Session -pageSize 50
Write-Output "Total projects with smaller page size: $($allProjectsResponseSmallPages.projects.Count)"

# Method 3: Disable pagination (legacy behavior)
# This uses the original single API call with limit=12000
$legacyProjectsResponse = &"support/rest/cxone/getprojects.ps1" $cx1Session -UsePagination:$false
Write-Output "Projects retrieved with legacy method: $($legacyProjectsResponse.projects.Count)"

# Access the projects array (same as before)
$projects = $allProjectsResponse.projects

# Example: Process each project
$projects | ForEach-Object {
    Write-Output "Project: $($_.name) (ID: $($_.id))"
}

# Example: Filter projects
$filteredProjects = $projects | Where-Object { $_.name -like "*test*" }
Write-Output "Test projects found: $($filteredProjects.Count)"