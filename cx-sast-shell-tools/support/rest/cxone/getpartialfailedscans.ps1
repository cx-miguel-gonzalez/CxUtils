param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session,
    [string]$createdAt,
    [int]$pageSize = 100
)

. "support/rest_util.ps1"

$headers = GetRestHeadersForJsonRequest($session)

$allScans = @()
$offset = 0
$hasMoreData = $true

Write-Debug "Starting pagination through all Failed/Partial scans with page size: $pageSize"

while ($hasMoreData) {
    $rest_url = [String]::Format("{0}/scans/?offset={1}&limit={2}&statuses=Failed&statuses=Partial&sort=%2Bcreated_at&sort=%2Bstatus&field=scan-ids&from-date={3}", $session.base_url, $offset, $pageSize, $createdAt)
    $request_url = New-Object System.Uri $rest_url

    Write-Debug "Get scans API URL: $request_url (offset: $offset)"

    try {
        $response = Invoke-RestMethod -Method 'Get' -Uri $request_url -Headers $headers

        if ($response.scans -and $response.scans.Count -gt 0) {
            $allScans += $response.scans
            Write-Debug "Retrieved $($response.scans.Count) scans in this batch. Total so far: $($allScans.Count)"

            if ($response.scans.Count -lt $pageSize) {
                $hasMoreData = $false
                Write-Debug "Received fewer scans than page size. End of data reached."
            } else {
                $offset += $pageSize
            }
        } else {
            $hasMoreData = $false
            Write-Debug "No scans returned in this batch. End of data reached."
        }

        if ($response.totalCount -and $allScans.Count -ge $response.totalCount) {
            $hasMoreData = $false
            Write-Debug "Retrieved all $($response.totalCount) scans based on totalCount."
        }

    } catch {
        Write-Error "Failed to retrieve scans at offset $offset`: $($_.Exception.Message)"
        throw
    }
}

Write-Debug "Pagination complete. Total scans retrieved: $($allScans.Count)"

$result = @{
    scans      = $allScans
    totalCount = $allScans.Count
}

return $result
