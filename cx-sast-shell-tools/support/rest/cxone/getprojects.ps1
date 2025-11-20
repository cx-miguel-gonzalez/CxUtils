param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session,
    [int]$pageSize = 100,
    [switch]$UsePagination = $true
)

. "support/rest_util.ps1"

# Check if pagination is disabled for backward compatibility
if (-not $UsePagination) {
    Write-Debug "Pagination disabled. Using legacy single request with high limit."
    $request_url = New-Object System.Uri $session.base_url, "/api/projects?limit=12000"
    Write-Debug "Projects API URL: $request_url"
    $headers = GetRestHeadersForJsonRequest($session)
    $response = Invoke-RestMethod -Method 'Get' -Uri $request_url -Headers $headers
    return $response
}

# Initialize variables for pagination
$allProjects = @()
$offset = 0
$hasMoreData = $true

Write-Debug "Starting pagination through all projects with page size: $pageSize"

while ($hasMoreData) {
    $request_url = New-Object System.Uri $session.base_url, "/api/projects?limit=$pageSize&offset=$offset"
    
    Write-Debug "Projects API URL: $request_url (offset: $offset)"
    
    $headers = GetRestHeadersForJsonRequest($session)
    
    try {
        $response = Invoke-RestMethod -Method 'Get' -Uri $request_url -Headers $headers
        
        # Add projects from this page to the collection
        if ($response.projects -and $response.projects.Count -gt 0) {
            $allProjects += $response.projects
            Write-Debug "Retrieved $($response.projects.Count) projects in this batch. Total so far: $($allProjects.Count)"
            
            # Check if we have more data to fetch
            if ($response.projects.Count -lt $pageSize) {
                # If we got fewer results than requested, we've reached the end
                $hasMoreData = $false
                Write-Debug "Received fewer projects than page size. End of data reached."
            } else {
                # Move to next page
                $offset += $pageSize
            }
        } else {
            # No projects returned, end pagination
            $hasMoreData = $false
            Write-Debug "No projects returned in this batch. End of data reached."
        }
        
        # Optional: Check totalCount if available in response for more accurate pagination
        if ($response.totalCount -and $allProjects.Count -ge $response.totalCount) {
            $hasMoreData = $false
            Write-Debug "Retrieved all $($response.totalCount) projects based on totalCount."
        }
        
    } catch {
        Write-Error "Failed to retrieve projects at offset $offset`: $($_.Exception.Message)"
        throw
    }
}

Write-Debug "Pagination complete. Total projects retrieved: $($allProjects.Count)"

# Return the same structure as the original but with all projects
$result = @{
    projects = $allProjects
    totalCount = $allProjects.Count
}

return $result