param(
    [Parameter(Mandatory=$true)]
    [hashtable]$session,
    [Parameter(Mandatory=$true)]
    [string]$engine,
    [int]$pageSize = 100,
    [switch]$UsePagination = $true
)

. "support/rest_util.ps1"

# Check if pagination is disabled for backward compatibility
if (-not $UsePagination) {
    Write-Debug "Pagination disabled. Using legacy single request with high limit."
    $request_url = [String]::Format("{0}/preset-manager/{1}/presets?limit=12000", $session.base_url, $engine)
    $request_url = New-Object System.Uri $request_url
    Write-Debug "Preset Manager API URL: $request_url"
    $headers = GetRestHeadersForJsonRequest($session)
    $response = Invoke-RestMethod -Method 'Get' -Uri $request_url -Headers $headers
    return $response
}

# Initialize variables for pagination
$allPresets = @()
$offset = 0
$hasMoreData = $true

Write-Debug "Starting pagination through all presets for engine $engine with page size: $pageSize"

while ($hasMoreData) {
    $request_url = [String]::Format("{0}/preset-manager/{1}/presets?limit={2}&offset={3}", $session.base_url, $engine, $pageSize, $offset)
    $request_url = New-Object System.Uri $request_url

    Write-Debug "Preset Manager API URL: $request_url (offset: $offset)"

    $headers = GetRestHeadersForJsonRequest($session)

    try {
        $response = Invoke-RestMethod -Method 'Get' -Uri $request_url -Headers $headers

        # Support a wrapped "presets" property as well as a bare array response
        $presets = if ($response.presets) { $response.presets } else { @($response) }

        if ($presets -and $presets.Count -gt 0) {
            $allPresets += $presets
            Write-Debug "Retrieved $($presets.Count) preset(s) in this batch. Total so far: $($allPresets.Count)"

            if ($presets.Count -lt $pageSize) {
                $hasMoreData = $false
                Write-Debug "Received fewer presets than page size. End of data reached."
            } else {
                $offset += $pageSize
            }
        } else {
            $hasMoreData = $false
            Write-Debug "No presets returned in this batch. End of data reached."
        }

        if ($response.totalCount -and $allPresets.Count -ge $response.totalCount) {
            $hasMoreData = $false
            Write-Debug "Retrieved all $($response.totalCount) presets based on totalCount."
        }

    } catch {
        Write-Error "Failed to retrieve presets at offset $offset`: $($_.Exception.Message)"
        throw
    }
}

Write-Debug "Pagination complete. Total presets retrieved: $($allPresets.Count)"

$result = @{
    presets    = $allPresets
    totalCount = $allPresets.Count
}

return $result
