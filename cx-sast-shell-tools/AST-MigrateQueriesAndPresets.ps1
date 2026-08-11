param(
    [Switch]$dbg,
    [Switch]$generateSourceCustomizations,
    [Switch]$importTargetCustomizations
)

####CxOne Variables######
#Please update with the values for your environment and respective region
#update the url based on your login page. ex: https://ast.checkmarx.net, https://us.ast.checkmarx.net
#add an API key as the $PAT value
# Source Environment
$sourceCx1Tenant=""
$SourceAPIKey=""
$SourceCx1URL="https://ast.checkmarx.net/api"
$SourceCx1TokenURL="https://iam.checkmarx.net/auth/realms/$sourceCx1Tenant"
$SourceCx1IamURL="https://iam.checkmarx.net/auth/admin/realms/$sourceCx1Tenant"

#TargetEnvironment
$TargetCx1Tenant=""
$TargetAPIKey=""
$TargetCx1URL="https://ast.checkmarx.net/api"
$TargetCx1TokenURL="https://iam.checkmarx.net/auth/realms/$TargetCx1Tenant"
$TargetCx1IamURL="https://iam.checkmarx.net/auth/admin/realms/$TargetCx1Tenant"

. "support/debug.ps1"
setupDebug($dbg.IsPresent)

$queryCsvFolder = Join-Path "sourceCustomizations" "customQueries"
if (-not (Test-Path $queryCsvFolder)) {
    New-Item -ItemType Directory -Path $queryCsvFolder -Force | Out-Null
}
$customQueriesCsvPath = Join-Path $queryCsvFolder "source_custom_queries.csv"
$queryDetailsCsvPath  = Join-Path $queryCsvFolder "source_custom_query_details.csv"

$presetCsvFolder = Join-Path "sourceCustomizations" "customPresets"
if (-not (Test-Path $presetCsvFolder)) {
    New-Item -ItemType Directory -Path $presetCsvFolder -Force | Out-Null
}
$customPresetsCsvPath = Join-Path $presetCsvFolder "source_custom_presets.csv"

function Get-ErrorResponseBody {
    param($ErrorRecord)
    
    if ($ErrorRecord.ErrorDetails -and $ErrorRecord.ErrorDetails.Message) {
        return $ErrorRecord.ErrorDetails.Message
    }
    
    $response = $ErrorRecord.Exception.Response
    if ($response) {
        try {
            $stream = $response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($stream)
            return $reader.ReadToEnd()
        } catch {
            return $null
        }
    }
    
    return $null
}

function Find-TenantNodes {
    param(
        [Parameter(Mandatory=$true)]
        [System.Object[]]$nodes
        )
        
        $tenantNodes = @()
        
        foreach ($node in $nodes) {
            if ($node.title -eq "Tenant") {
                $tenantNodes += $node
            } elseif ($node.children -and $node.children.Count -gt 0) {
                $tenantNodes += Find-TenantNodes $node.children
            }
        }
        
        return $tenantNodes
    }
    
    function Wait-ForQueryEditorSessionReady {
        param(
            [Parameter(Mandatory=$true)]
            [hashtable]$session,
            [Parameter(Mandatory=$true)]
            [string]$editorSessionId,
            [Parameter(Mandatory=$true)]
            [string]$requestId
        )

        do {
            $statusResponse = &"support/rest/cxone/queryEditorRetrieveRequestStatus.ps1" $session $editorSessionId $requestId

            if (-not $statusResponse.completed) {
                Write-Debug "  Waiting for query editor session to be ready: $($statusResponse.value.message)"
                Start-Sleep -Seconds 5
            }
        } while (-not $statusResponse.completed)

        return $statusResponse
    }

    function Get-LeafQueries {
        param(
            [Parameter(Mandatory=$true)]
            [System.Object[]]$nodes
            )
            
            $leaves = @()
            
            foreach ($node in $nodes) {
                if ($node.isLeaf) {
                    $leaves += $node
                } elseif ($node.children -and $node.children.Count -gt 0) {
                    $leaves += Get-LeafQueries $node.children
                }
            }
            
            return $leaves
        }
        
if ($generateSourceCustomizations.IsPresent) {
            
    #Get source session token
    $sourceSession = &"support/rest/cxone/apiTokenLogin.ps1" $SourceCx1TokenURL $SourceCx1URL $SourceCx1IamURL $sourceCx1Tenant $SourceAPIKey

    #Get the full flat list of queries and filter down to Tenant-level (custom) queries
    Write-Output "Retrieving all queries..."
    $allQueries = &"support/rest/cxone/cxauditGetAllQueries.ps1" $sourceSession

    $allCustomQueries = $allQueries | Where-Object { $_.level -eq "Tenant" } | ForEach-Object {
        [PSCustomObject]@{
            Family       = $_.lang
            Category     = $_.group
            Name         = $_.name
            Key          = $_.Id
            Level        = $_.level
            Severity     = $_.severity
            IsExecutable = $_.isExecutable
        }
    }

    Write-Output "Total custom queries found: $($allCustomQueries.Count)"

    $allCustomQueries | Export-Csv -Path $customQueriesCsvPath -NoTypeInformation
    Write-Output "Custom queries exported to: $customQueriesCsvPath"

    #Identify the distinct languages that have custom queries
    $customQueryLanguages = $allCustomQueries | Select-Object -ExpandProperty Family -Unique
    Write-Output "Found $($customQueryLanguages.Count) language(s) with custom queries: $($customQueryLanguages -join ', ')"

    $queryDetailsList = @()

    # Query editor sessions are capped and take time to fully tear down after deletion
    $sessionWaitSeconds = 30

    foreach ($language in $customQueryLanguages) {
        Write-Output "Processing language: $language"

        $editorSessionId = $null
        $requestId       = $null

        while (-not $editorSessionId) {
            try {
                $editorSession   = &"support/rest/cxone/queryEditorCreateSession.ps1" $sourceSession "sast" $language
                $editorSessionId = $editorSession.id
                $requestId       = $editorSession.data.requestID
                Write-Debug "  Editor session ID for $language`: $editorSessionId"
            } catch {
                $errorBody = Get-ErrorResponseBody $_
                $errorCode = $null
                if ($errorBody) {
                    try { $errorCode = ($errorBody | ConvertFrom-Json).code } catch {}
                }

                if ($errorCode -eq "776") {
                    Write-Output "  No query editor sessions available. Waiting $sessionWaitSeconds second(s) before retrying $language..."
                    Start-Sleep -Seconds $sessionWaitSeconds
                } else {
                    Write-Warning "Failed to create query editor session for language $language`: $($_.Exception.Message)"
                    break
                }
            }
        }

        if (-not $editorSessionId) {
            continue
        }

        try {
            # Poll until the SAST engine backing this session reports as ready
            Wait-ForQueryEditorSessionReady $sourceSession $editorSessionId $requestId | Out-Null

            $queriesTree = &"support/rest/cxone/queryEditorGetQueriesForSession.ps1" $sourceSession $editorSessionId
            $tenantNodes = Find-TenantNodes $queriesTree
            Write-Debug "  Found $($tenantNodes.Count) Tenant node(s) for $language"

            $customLeafQueries = @()
            foreach ($tenantNode in $tenantNodes) {
                $customLeafQueries += Get-LeafQueries $tenantNode.children
            }
            Write-Debug "  Found $($customLeafQueries.Count) custom quer(y/ies) for $language"

            foreach ($leafQuery in $customLeafQueries) {
                Write-Debug "  Retrieving details for query: $($leafQuery.title) ($($leafQuery.key))"
                $queryDetails = &"support/rest/cxone/queryEditorGetQueryDetails.ps1" $sourceSession $editorSessionId $leafQuery.key
                $queryDetailsList += $queryDetails
            }
        } catch {
            Write-Warning "Failed to retrieve query details for language $language`: $($_.Exception.Message)"
        } finally {
            &"support/rest/cxone/queryEditorDeleteSession.ps1" $sourceSession $editorSessionId | Out-Null
            Write-Debug "  Waiting $sessionWaitSeconds second(s) for session $editorSessionId to fully tear down..."
            Start-Sleep -Seconds $sessionWaitSeconds
        }
    }

    Write-Output "Total query detail records retrieved: $($queryDetailsList.Count)"

    $queryDetailsExport = $queryDetailsList | ForEach-Object {
        [PSCustomObject]@{
            Language   = $_.metadata.language
            Group      = $_.metadata.group
            Name       = $_.name
            Id         = $_.id
            Level      = $_.level
            Severity   = $_.metadata.severity
            Cwe        = $_.metadata.cwe
            Executable = $_.metadata.executable
            Path       = $_.path
            Source     = $_.source
        }
    }

    $queryDetailsExport | Export-Csv -Path $queryDetailsCsvPath -NoTypeInformation
    Write-Output "Query details exported to: $queryDetailsCsvPath"

    #Get the full list of presets from the source environment
    Write-Output "Retrieving all presets..."
    $sourcePresets = (&"support/rest/cxone/getPresetsForEngine.ps1" $sourceSession "sast").presets
    Write-Output "Total presets found: $($sourcePresets.Count)"

    #Custom presets are identified by an ID of 100000 or higher
    $sourceCustomPresets = $sourcePresets | Where-Object { [int64]$_.id -ge 100000 }
    Write-Output "Total custom presets found: $($sourceCustomPresets.Count)"

    $sourceCustomPresets | Select-Object id, name | Export-Csv -Path $customPresetsCsvPath -NoTypeInformation
    Write-Output "Custom presets exported to: $customPresetsCsvPath"

    #Build a lookup of all queries by ID so preset query details can be pulled from $allQueries
    $allQueriesById = @{}
    foreach ($query in $allQueries) {
        $allQueriesById[[string]$query.Id] = $query
    }

    $invalidFileNameChars = [System.IO.Path]::GetInvalidFileNameChars()

    foreach ($preset in $sourceCustomPresets) {
        Write-Output "Processing preset: $($preset.name)"

        try {
            $presetDetails = &"support/rest/cxone/getQueriesForScannerPreset.ps1" $sourceSession "sast" $preset.id

            $presetQueryRows = foreach ($family in $presetDetails.queries) {
                foreach ($queryId in $family.queryIds) {
                    $matchedQuery = $allQueriesById[[string]$queryId]

                    if ($matchedQuery) {
                        [PSCustomObject]@{
                            Query    = $matchedQuery.name
                            QueryId  = $matchedQuery.Id
                            Group    = $matchedQuery.group
                            Language = $matchedQuery.lang
                            Level    = $matchedQuery.level
                        }
                    } else {
                        Write-Warning "  Query ID $queryId (family: $($family.familyName)) not found in `$allQueries"
                    }
                }
            }

            $presetFileName = $preset.name
            foreach ($invalidChar in $invalidFileNameChars) {
                $presetFileName = $presetFileName.Replace([string]$invalidChar, "_")
            }
            $presetCsvPath = Join-Path $presetCsvFolder "$presetFileName.csv"

            $presetQueryRows | Export-Csv -Path $presetCsvPath -NoTypeInformation
            Write-Output "  Exported $($presetQueryRows.Count) quer(y/ies) to: $presetCsvPath"
        } catch {
            Write-Warning "Failed to retrieve queries for preset $($preset.name): $($_.Exception.Message)"
        }
    }
}

if ($importTargetCustomizations.IsPresent) {
    #Get target session token
    $targetSession = &"support/rest/cxone/apiTokenLogin.ps1" $TargetCx1TokenURL $TargetCx1URL $TargetCx1IamURL $TargetCx1Tenant $TargetAPIKey

    #Get the full flat list of queries from the target environment
    Write-Output "Retrieving all target queries..."
    $targetQueries = &"support/rest/cxone/cxauditGetAllQueries.ps1" $targetSession
    Write-Output "Total target queries found: $($targetQueries.Count)"

    #Get the full list of presets from the target environment
    Write-Output "Retrieving all target presets..."
    $targetPresets = (&"support/rest/cxone/getPresetsForEngine.ps1" $targetSession "sast").presets
    Write-Output "Total target presets found: $($targetPresets.Count)"

    #Identify the target's custom (Tenant-level) queries, same as the source tenant
    $targetCustomQueries = $targetQueries | Where-Object { $_.level -eq "Tenant" } | ForEach-Object {
        [PSCustomObject]@{
            Family       = $_.lang
            Category     = $_.group
            Name         = $_.name
            Key          = $_.Id
            Level        = $_.level
            Severity     = $_.severity
            IsExecutable = $_.isExecutable
        }
    }
    Write-Output "Total target custom queries found: $($targetCustomQueries.Count)"

    #Compare the source tenant's custom queries against the target's, matching on language + name
    $targetCustomQueryKeys = @{}
    foreach ($targetQuery in $targetCustomQueries) {
        $targetCustomQueryKeys["$($targetQuery.Family)|$($targetQuery.Name)"] = $true
    }

    #Load the source tenant's custom queries (with source code) from the CSV generated by -generateSourceCustomizations
    $sourceCustomQueries = Import-Csv -Path $queryDetailsCsvPath

    $missingFromTarget  = @()
    $conflictingQueries = @()

    foreach ($sourceQuery in $sourceCustomQueries) {
        $matchKey = "$($sourceQuery.Language)|$($sourceQuery.Name)"

        if ([string]::IsNullOrWhiteSpace($sourceQuery.Source)) {
            Write-Warning "  Query $($sourceQuery.Name) ($($sourceQuery.Language)) has no source. Routing to conflicts instead of target_custom_queries.csv"
            $conflictingQueries += $sourceQuery
        } elseif ($targetCustomQueryKeys.ContainsKey($matchKey)) {
            $conflictingQueries += $sourceQuery
        } else {
            $missingFromTarget += $sourceQuery
        }
    }

    Write-Output "Source custom queries missing from target: $($missingFromTarget.Count)"
    Write-Output "Source custom queries already present in target (conflicts): $($conflictingQueries.Count)"

    $targetQueriesCsvFolder = Join-Path "targetCustomizations" "queries"
    if (-not (Test-Path $targetQueriesCsvFolder)) {
        New-Item -ItemType Directory -Path $targetQueriesCsvFolder -Force | Out-Null
    }

    $targetCustomQueriesCsvPath = Join-Path $targetQueriesCsvFolder "target_custom_queries.csv"
    $missingFromTarget | Export-Csv -Path $targetCustomQueriesCsvPath -NoTypeInformation
    $conflictingQueries | Export-Csv -Path (Join-Path $targetQueriesCsvFolder "target_queries_conflict.csv") -NoTypeInformation
    Write-Output "Query comparison CSVs exported to: $targetQueriesCsvFolder"

    #Create the missing custom queries in the target environment, grouped by language
    Write-Output "Creating missing custom queries in target..."

    $queryImportErrors = @()
    $importSessionWaitSeconds = 30

    $missingTargetQueries = Import-Csv -Path $targetCustomQueriesCsvPath
    $missingTargetQueriesByLanguage = $missingTargetQueries | Group-Object -Property Language

    foreach ($languageGroup in $missingTargetQueriesByLanguage) {
        $language = $languageGroup.Name
        Write-Output "  Creating queries for language: $language"

        $editorSessionId = $null
        $requestId       = $null

        while (-not $editorSessionId) {
            try {
                $editorSession   = &"support/rest/cxone/queryEditorCreateSession.ps1" $targetSession "sast" $language
                $editorSessionId = $editorSession.id
                $requestId       = $editorSession.data.requestID
                Write-Debug "  Editor session ID for $language`: $editorSessionId"
            } catch {
                $errorBody = Get-ErrorResponseBody $_
                $errorCode = $null
                if ($errorBody) {
                    try { $errorCode = ($errorBody | ConvertFrom-Json).code } catch {}
                }

                if ($errorCode -eq "776") {
                    Write-Output "    No query editor sessions available. Waiting $importSessionWaitSeconds second(s) before retrying $language..."
                    Start-Sleep -Seconds $importSessionWaitSeconds
                } else {
                    Write-Warning "Failed to create query editor session for language $language`: $($_.Exception.Message)"
                    break
                }
            }
        }

        if (-not $editorSessionId) {
            foreach ($query in $languageGroup.Group) {
                $queryImportErrors += [PSCustomObject]@{
                    Family   = $language
                    Category = $query.Group
                    Name     = $query.Name
                    Error    = "Failed to create a query editor session"
                }
            }
            continue
        }

        # Poll until the SAST engine backing this session reports as ready
        Wait-ForQueryEditorSessionReady $targetSession $editorSessionId $requestId | Out-Null

        try {
            foreach ($query in $languageGroup.Group) {
                $existingQuery = $targetQueries | Where-Object { $_.name -eq $query.Name -and $_.group -eq $query.Group }

                $createQueryParams = @{
                    session         = $targetSession
                    editorSessionId = $editorSessionId
                    name            = $query.Name
                    language        = $language
                    group           = $query.Group
                    severity        = $query.Severity
                    source          = $query.Source
                    executable      = [System.Convert]::ToBoolean($query.Executable)
                }

                if ($existingQuery) {
                    $createQueryParams.level = "Tenant"
                }

                $maxCreateQueryRetries = 3

                for ($createAttempt = 1; $createAttempt -le $maxCreateQueryRetries; $createAttempt++) {
                    try {
                        Start-Sleep -Seconds 5
                        $createQueryResponse = &"support/rest/cxone/queryEditorCreateQueryForSession.ps1" @createQueryParams
                        Write-Output "    Created query: $($query.Name)"
                        Write-Output "    Response: $($createQueryResponse | ConvertTo-Json -Depth 10 -Compress)"
                        break
                    } catch {
                        $statusCode = $null
                        if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
                            $statusCode = [int]$_.Exception.Response.StatusCode
                        }

                        if ($statusCode -eq 500 -and $createAttempt -lt $maxCreateQueryRetries) {
                            Write-Warning "    Received a 500 error creating query $($query.Name) (attempt $createAttempt/$maxCreateQueryRetries). Retrying..."
                        } else {
                            Write-Warning "    Failed to create query $($query.Name): $($_.Exception.Message)"
                            $queryImportErrors += [PSCustomObject]@{
                                Family   = $language
                                Category = $query.Group
                                Name     = $query.Name
                                Error    = $_.Exception.Message
                            }
                        }
                    }
                }
            }
        } finally {
            &"support/rest/cxone/queryEditorDeleteSession.ps1" $targetSession $editorSessionId | Out-Null
            Start-Sleep -Seconds $importSessionWaitSeconds
        }
    }

    if ($queryImportErrors.Count -gt 0) {
        $queryImportErrorsFolder = Join-Path "targetCustomizations" "Errors"
        if (-not (Test-Path $queryImportErrorsFolder)) {
            New-Item -ItemType Directory -Path $queryImportErrorsFolder -Force | Out-Null
        }
        $queryImportErrorsCsvPath = Join-Path $queryImportErrorsFolder "queryImportFailure.csv"
        $queryImportErrors | Export-Csv -Path $queryImportErrorsCsvPath -NoTypeInformation
        Write-Output "Query import failures logged to: $queryImportErrorsCsvPath"
    }

    #Identify the target's custom presets, same as the source tenant
    $targetCustomPresets = $targetPresets | Where-Object { [int64]$_.id -ge 100000 }
    Write-Output "Total target custom presets found: $($targetCustomPresets.Count)"

    #Compare the source tenant's custom presets against the target's, matching on preset name
    $targetCustomPresetNames = @{}
    foreach ($targetPreset in $targetCustomPresets) {
        $targetCustomPresetNames[$targetPreset.name] = $true
    }

    #Load the source tenant's custom presets from the CSV generated by -generateSourceCustomizations
    $sourceCustomPresets = Import-Csv -Path $customPresetsCsvPath

    $missingPresetsFromTarget  = @()
    $conflictingPresets        = @()
    $presetFileNameInvalidChars = [System.IO.Path]::GetInvalidFileNameChars()

    foreach ($sourcePreset in $sourceCustomPresets) {
        $presetFileName = $sourcePreset.name
        foreach ($invalidChar in $presetFileNameInvalidChars) {
            $presetFileName = $presetFileName.Replace([string]$invalidChar, "_")
        }
        $sourcePresetCsvPath = Join-Path $presetCsvFolder "$presetFileName.csv"
        $isSourcePresetEmpty = (-not (Test-Path $sourcePresetCsvPath)) -or ((Get-Item $sourcePresetCsvPath).Length -eq 0)

        if ($isSourcePresetEmpty) {
            Write-Warning "  Source preset CSV is empty or missing for $($sourcePreset.name). Routing to conflicts instead of target_custom_presets.csv"
            $conflictingPresets += $sourcePreset
        } elseif ($targetCustomPresetNames.ContainsKey($sourcePreset.name)) {
            $conflictingPresets += $sourcePreset
        } else {
            $missingPresetsFromTarget += $sourcePreset
        }
    }

    Write-Output "Source custom presets missing from target: $($missingPresetsFromTarget.Count)"
    Write-Output "Source custom presets already present in target (conflicts): $($conflictingPresets.Count)"

    $targetPresetsCsvFolder = Join-Path "targetCustomizations" "presets"
    if (-not (Test-Path $targetPresetsCsvFolder)) {
        New-Item -ItemType Directory -Path $targetPresetsCsvFolder -Force | Out-Null
    }

    $targetCustomPresetsCsvPath = Join-Path $targetPresetsCsvFolder "target_custom_presets.csv"
    $missingPresetsFromTarget | Export-Csv -Path $targetCustomPresetsCsvPath -NoTypeInformation
    $conflictingPresets | Export-Csv -Path (Join-Path $targetPresetsCsvFolder "target_presets_conflict.csv") -NoTypeInformation
    Write-Output "Preset comparison CSVs exported to: $targetPresetsCsvFolder"

    #Build the target's preset query lists, resolving each query's ID against the target environment
    Write-Output "Building target preset query lists..."

    $targetPresetImportsFolder = Join-Path $targetPresetsCsvFolder "imports"
    if (-not (Test-Path $targetPresetImportsFolder)) {
        New-Item -ItemType Directory -Path $targetPresetImportsFolder -Force | Out-Null
    }

    #Build a lookup of target queries by name+group+language for fast matching (avoids an O(n) scan per query row)
    $targetQueriesByKey = @{}
    foreach ($targetQuery in $targetQueries) {
        $targetQueriesByKey["$($targetQuery.name)|$($targetQuery.group)|$($targetQuery.lang)"] = $targetQuery
    }

    $presetImportErrors = @()

    $missingTargetPresets = Import-Csv -Path $targetCustomPresetsCsvPath

    foreach ($presetToImport in $missingTargetPresets) {
        Write-Output "  Processing preset: $($presetToImport.name)"

        $presetFileName = $presetToImport.name
        foreach ($invalidChar in $presetFileNameInvalidChars) {
            $presetFileName = $presetFileName.Replace([string]$invalidChar, "_")
        }
        $sourcePresetCsvPath = Join-Path $presetCsvFolder "$presetFileName.csv"

        if (-not (Test-Path $sourcePresetCsvPath)) {
            Write-Warning "    No matching source preset CSV found: $sourcePresetCsvPath"
            $presetImportErrors += [PSCustomObject]@{
                Preset = $presetToImport.name
                Query  = ""
                Error  = "Source preset CSV not found: $sourcePresetCsvPath"
            }
            continue
        }

        $sourcePresetQueries = Import-Csv -Path $sourcePresetCsvPath

        $targetPresetQueryRows = foreach ($sourceQuery in $sourcePresetQueries) {
            $matchedTargetQuery = $targetQueriesByKey["$($sourceQuery.Query)|$($sourceQuery.Group)|$($sourceQuery.Language)"]

            if ($matchedTargetQuery) {
                [PSCustomObject]@{
                    Query    = $sourceQuery.Query
                    QueryId  = $matchedTargetQuery.Id
                    Group    = $sourceQuery.Group
                    Language = $sourceQuery.Language
                    Level    = $sourceQuery.Level
                }
            } else {
                Write-Warning "    Query not found in target: $($sourceQuery.Query) ($($sourceQuery.Language)/$($sourceQuery.Group)/$($sourceQuery.Level))"
                $presetImportErrors += [PSCustomObject]@{
                    Preset = $presetToImport.name
                    Query  = $sourceQuery.Query
                    Error  = "Query not found in target environment"
                }
            }
        }

        $targetPresetCsvPath = Join-Path $targetPresetImportsFolder "$presetFileName.csv"
        $targetPresetQueryRows | Export-Csv -Path $targetPresetCsvPath -NoTypeInformation
        Write-Output "    Exported $($targetPresetQueryRows.Count) quer(y/ies) to: $targetPresetCsvPath"
    }

    if ($presetImportErrors.Count -gt 0) {
        $presetImportErrorsFolder = Join-Path "targetCustomizations" "Errors"
        if (-not (Test-Path $presetImportErrorsFolder)) {
            New-Item -ItemType Directory -Path $presetImportErrorsFolder -Force | Out-Null
        }
        $presetImportErrorsCsvPath = Join-Path $presetImportErrorsFolder "presetImportFailure.csv"
        $presetImportErrors | Export-Csv -Path $presetImportErrorsCsvPath -NoTypeInformation
        Write-Output "Preset import failures logged to: $presetImportErrorsCsvPath"
    }

    #Create the presets in the target environment from the resolved CSVs in the imports folder
    Write-Output "Creating presets in target..."

    $presetCreationErrors = @()
    $presetCreationErrorsFolder = Join-Path "targetCustomizations" "Errors"
    if (-not (Test-Path $presetCreationErrorsFolder)) {
        New-Item -ItemType Directory -Path $presetCreationErrorsFolder -Force | Out-Null
    }

    $targetPresetImportCsvFiles = Get-ChildItem -Path $targetPresetImportsFolder -Filter "*.csv"

    foreach ($presetCsvFile in $targetPresetImportCsvFiles) {
        $presetName = [System.IO.Path]::GetFileNameWithoutExtension($presetCsvFile.Name)
        Write-Output "  Creating preset: $presetName"

        $presetBody = $null

        try {
            $presetQueryRows = Import-Csv -Path $presetCsvFile.FullName

            $presetQueries = $presetQueryRows | Group-Object -Property Language | ForEach-Object {
                @{
                    familyName = $_.Name
                    queryIds   = @($_.Group | Select-Object -ExpandProperty QueryId)
                }
            }

            $presetBody = @{
                name        = $presetName
                description = ""
                queries     = @($presetQueries)
            }

            &"support/rest/cxone/createPresetForEngine.ps1" $targetSession "sast" $presetBody | Out-Null
            Write-Output "    Created preset: $presetName"
        } catch {
            Write-Warning "    Failed to create preset $presetName`: $($_.Exception.Message)"
            $presetCreationErrors += [PSCustomObject]@{
                Preset = $presetName
                Error  = $_.Exception.Message
            }

            if ($presetBody) {
                $presetBodyJsonPath = Join-Path $presetCreationErrorsFolder "$presetName.json"
                $presetBody | ConvertTo-Json -Depth 10 | Out-File -FilePath $presetBodyJsonPath -Encoding utf8
                Write-Output "    Preset body for failed import written to: $presetBodyJsonPath"
            }
        }
    }

    if ($presetCreationErrors.Count -gt 0) {
        $presetCreationErrorsCsvPath = Join-Path $presetCreationErrorsFolder "presetCreationFailure.csv"
        $presetCreationErrors | Export-Csv -Path $presetCreationErrorsCsvPath -NoTypeInformation
        Write-Output "Preset creation failures logged to: $presetCreationErrorsCsvPath"
    }
}

