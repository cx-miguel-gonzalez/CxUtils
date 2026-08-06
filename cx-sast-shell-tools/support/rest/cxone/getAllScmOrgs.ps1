param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session,
    [int]$pageSize = 50,
    [switch]$UsePagination = $true
)

. "support/rest_util.ps1"

# Check if pagination is disabled for backward compatibility
if (-not $UsePagination) {
    Write-Debug "Pagination disabled. Using legacy single request with high limit."
    $rest_url = [String]::Format("{0}/repos-manager/organizations?limit=12000&offset=0", $session.base_url)
    $request_url = New-Object System.Uri $rest_url
    Write-Debug "Get Orgs across all SCM API URL: $request_url"
    $headers = GetRestHeadersForJsonRequest($session)
    $response = Invoke-RestMethod -Method 'Get' -Uri $request_url -Headers $headers
    return $response
}

# Initialize variables for pagination
$allOrgs = @()
$offset = 0
$hasMoreData = $true

Write-Debug "Starting pagination through all SCM organizations with page size: $pageSize"

while ($hasMoreData) {
    $rest_url = [String]::Format("{0}/repos-manager/organizations?limit={1}&offset={2}", $session.base_url, $pageSize, $offset)
    $request_url = New-Object System.Uri $rest_url

    Write-Debug "Get Orgs across all SCM API URL: $request_url (offset: $offset)"

    $headers = GetRestHeadersForJsonRequest($session)

    try {
        $response = Invoke-RestMethod -Method 'Get' -Uri $request_url -Headers $headers

        # Response wraps organizations in an "orgItems" array alongside totalCount/offset/limit
        $orgs = if ($response.orgItems) { $response.orgItems } else { @($response) }

        if ($orgs -and $orgs.Count -gt 0) {
            $allOrgs += $orgs
            Write-Debug "Retrieved $($orgs.Count) organizations in this batch. Total so far: $($allOrgs.Count)"

            # Check if we have more data to fetch
            if ($orgs.Count -lt $pageSize) {
                # If we got fewer results than requested, we've reached the end
                $hasMoreData = $false
                Write-Debug "Received fewer organizations than page size. End of data reached."
            } else {
                # Move to next page
                $offset += $pageSize
            }
        } else {
            # No organizations returned, end pagination
            $hasMoreData = $false
            Write-Debug "No organizations returned in this batch. End of data reached."
        }

        # Optional: Check totalCount if available in response for more accurate pagination
        if ($response.totalCount -and $allOrgs.Count -ge $response.totalCount) {
            $hasMoreData = $false
            Write-Debug "Retrieved all $($response.totalCount) organizations based on totalCount."
        }

    } catch {
        Write-Error "Failed to retrieve organizations at offset $offset`: $($_.Exception.Message)"
        throw
    }
}

Write-Debug "Pagination complete. Total organizations retrieved: $($allOrgs.Count)"

# Return the same structure as the original but with all organizations
$result = @{
    orgItems = $allOrgs
    totalCount = $allOrgs.Count
}

return $result
