param(
    [Switch]$dbg,
    [string]$csvPath,
    [Switch]$autoScan,
    [Switch]$generateCsv,
    [string]$outputPath = "current_scm_project_information.csv",
    [int]$batchSize = 25
)

####CxOne Variables######
#Please update with the values for your environment and respective region
#update the url based on your login page. ex: https://ast.checkmarx.net, https://us.ast.checkmarx.net
#add an API key as the $PAT value
$cx1Tenant=""
$PAT=""
$cx1URL="https://ast.checkmarx.net/api"
$cx1TokenURL="https://iam.checkmarx.net/auth/realms/$cx1Tenant"
$cx1IamURL="https://iam.checkmarx.net/auth/admin/realms/$cx1Tenant"

# CSV columns expected:
#   ProjectId                - CxOne project ID
#   ProjectName              - exact name of the CxOne project
#   CurrentSCM               - (informational) name of the existing SCM integration
#   CurrentRepoUrl           - (informational) existing repo URL
#   CurrentProtectedBranches - (informational) existing protected branches, comma-separated
#   TargetScmType            - SCM type for new connection (github, bitbucket, azure, gitlab, githubApp)
#   TargetScmOnPremUrl       - base URL of the on-prem SCM instance (leave blank for cloud)
#   TargetOrgIdentity        - org/namespace identifier in the target SCM
#   TargetRepoUrl            - new repository URL to connect
#   TargetProtectedBranches  - branch name(s) to protect in the new repo
#   WebhookEnabled           - true or false
#   decoratePullRequests     - true or false

. "support/debug.ps1"
setupDebug($dbg.IsPresent)

if (-not $generateCsv.IsPresent) {
    if (-not $csvPath -or -not (Test-Path $csvPath)) {
        Write-Error "CSV file not found: $csvPath. Use -generateCsv to export current repo connections."
        exit 1
    }
}

$scanTypes = @("sast", "sca", "kics", "containers")

#Generate token for CxOne
$cx1Session = &"support/rest/cxone/apiTokenLogin.ps1" $cx1TokenURL $cx1URL $cx1IamURL $cx1Tenant $PAT

#Get full list of CxOne projects (paginated)
Write-Output "Retrieving all projects..."
$cx1ProjectsResponse = &"support/rest/cxone/getprojects.ps1" $cx1Session
$cx1Projects = $cx1ProjectsResponse.projects

$projectsWithRepo = $cx1Projects | Where-Object { $_.repoId -ne $null -and $_.repoId -ne "" }
Write-Output "Total projects: $($cx1Projects.Count) | Projects with repo connections: $($projectsWithRepo.Count)"

if ($generateCsv.IsPresent) {
    Write-Output "Generating CSV export to: $outputPath"

    Write-Output "Retrieving SCM integrations..."
    $scmsResponse = &"support/rest/cxone/getScms.ps1" $cx1Session
    $scmList = if ($scmsResponse.list) { $scmsResponse.list } else { @($scmsResponse) }

    $scmMap = @{}
    foreach ($scm in $scmList) {
        $scmMap[[int]$scm.id] = $scm
    }

    $csvRows = @()
    $counter = 0

    foreach ($project in $projectsWithRepo) {
        $counter++

        if ($counter % 50 -eq 0) {
            Write-Output "Rate limit pause..."
            Start-Sleep -Seconds 30
        }

        Write-Output "  [$counter/$($projectsWithRepo.Count)] $($project.name)"

        try {
            $scmSettings = &"support/rest/cxone/getProjectSCMsettings.ps1" $cx1Session $project.repoId

            $currentBranches = ($scmSettings.branches | ForEach-Object { $_.pattern }) -join ","

            $scmEntry       = $scmMap[[int]$scmSettings.scmId]
            $currentScmName = if ($scmEntry) { $scmEntry.name } else { $scmSettings.scm.typeName }

            $csvRows += [PSCustomObject]@{
                ProjectId                = $project.id
                ProjectName              = $project.name
                CurrentSCM               = $currentScmName
                CurrentRepoUrl           = $scmSettings.url
                CurrentProtectedBranches = $currentBranches
                TargetScmType            = ""
                TargetScmOnPremUrl       = ""
                TargetOrgIdentity        = ""
                TargetRepoUrl            = ""
                TargetProtectedBranches  = ""
                WebhookEnabled           = $scmSettings.webhookEnabled
                decoratePullRequests     = $scmSettings.prDecorationEnabled.value
            }
        } catch {
            Write-Warning "  Failed to retrieve SCM settings for $($project.name): $($_.Exception.Message)"
        }
    }

    $csvRows | Export-Csv -Path $outputPath -NoTypeInformation
    Write-Output "Export complete. $($csvRows.Count) project(s) written to $outputPath"
    exit 0
}

$logEntries   = @()
$logTimestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logPath      = [System.IO.Path]::Combine(
    [System.IO.Path]::GetDirectoryName((Resolve-Path $csvPath)),
    [System.IO.Path]::GetFileNameWithoutExtension($csvPath) + "_conversion_log_$logTimestamp.csv"
)

$allRows  = @(Import-Csv $csvPath)
$total    = $allRows.Count
$batchNum = 0

Write-Output "Total projects to process: $total | Batch size: $batchSize"

$terminalStatuses = @("OK", "PARTIAL", "FAILURE")

# Group rows by TargetScmType so each conversion API call contains a single SCM type
$scmGroups = $allRows | Group-Object -Property TargetScmType

foreach ($scmGroup in $scmGroups) {
    $groupScmType = $scmGroup.Name
    $groupRows    = @($scmGroup.Group)

    Write-Output "`n=== SCM Type: $groupScmType ($($groupRows.Count) project(s)) ==="

    for ($i = 0; $i -lt $groupRows.Count; $i += $batchSize) {
        $batchNum++
        $batch = $groupRows[$i .. ([Math]::Min($i + $batchSize - 1, $groupRows.Count - 1))]

        Write-Output "`n--- Batch $batchNum ($($batch.Count) project(s)) ---"

        if ($batchNum -gt 1) {
            Write-Output "Rate limit pause..."
            Start-Sleep -Seconds 30
        }

        $batchProjectDetails = @()
        $batchLogEntries     = @()
        $firstValidRow       = $null

        # Step 1: Validate + disconnect each project in the batch
        foreach ($row in $batch) {
            $projectId          = $row.ProjectId
            $projectName        = $row.ProjectName
            $targetRepoUrl      = $row.TargetRepoUrl
            $targetScmType      = $row.TargetScmType
            $targetScmOnPremUrl = $row.TargetScmOnPremUrl
            $orgIdentity        = $row.TargetOrgIdentity
            $protectedBranches  = $row.TargetProtectedBranches -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ }
            $webhookEnabled     = [System.Convert]::ToBoolean($row.WebhookEnabled)
            $decoratePR         = [System.Convert]::ToBoolean($row.decoratePullRequests)

            Write-Output "  [$projectName] ($projectId)"

            $logEntry = [PSCustomObject]@{
                Timestamp        = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                ProjectId        = $projectId
                ProjectName      = $projectName
                TargetRepoUrl    = $targetRepoUrl
                Status           = ""
                ProcessId        = ""
                ConversionStatus = ""
                ErrorMessage     = ""
            }

            if (-not $projectId -or -not $targetRepoUrl -or -not $targetScmType) {
                Write-Warning "    Missing required fields (ProjectId, TargetRepoUrl, or TargetScmType). Skipping."
                $logEntry.Status       = "Skipped"
                $logEntry.ErrorMessage = "Missing required fields"
                $batchLogEntries += $logEntry
                continue
            }

            Write-Output "    Disconnecting current SCM..."
            try {
                &"support/rest/cxone/disconnectProjectSCM.ps1" $cx1Session $projectId | Out-Null
                Write-Output "    Disconnected."
            } catch {
                Write-Warning "    Disconnect failed: $($_.Exception.Message). Continuing to conversion."
                $logEntry.ErrorMessage = "Disconnect failed: $($_.Exception.Message)"
            }

            Start-Sleep -Seconds 1

            $projectDetails = @{
                cxProjectId              = $projectId
                scmRepositoryUrl         = $targetRepoUrl
                protectedBranches        = @($protectedBranches)
                branchToScanUponCreation = $protectedBranches[0]
                types                    = $scanTypes
                webhookEnabled           = $webhookEnabled
                decoratePullRequests     = $decoratePR
            }

            $batchProjectDetails += $projectDetails
            $batchLogEntries     += $logEntry

            if ($null -eq $firstValidRow) { $firstValidRow = $row }
        }

        # Step 2: Submit batch to conversion API
        if ($batchProjectDetails.Count -eq 0) {
            Write-Warning "  No valid projects in batch. Skipping conversion call."
            $logEntries += $batchLogEntries
            continue
        }

        $conversionDetails = @{
            scmType                          = $firstValidRow.TargetScmType
            scmOnPremUrl                     = $firstValidRow.TargetScmOnPremUrl
            orgIdentity                      = $firstValidRow.TargetOrgIdentity
            token                            = ""
            types                            = $scanTypes
            webhookEnabled                   = [System.Convert]::ToBoolean($firstValidRow.WebhookEnabled)
            autoScanCxProjectAfterConversion = $autoScan.IsPresent
            projects                         = @($batchProjectDetails)
        }

        Write-Output "  Submitting $($batchProjectDetails.Count) project(s) to conversion API..."
        Write-Debug ($conversionDetails | ConvertTo-Json -Depth 10)

        try {
            $response  = &"support/rest/cxone/projectConversion.ps1" $cx1Session $conversionDetails
            $processId = $response.processId
            Write-Output "  Conversion started. ProcessId: $processId | $($response.message)"

            $migrationStatus = ""
            $pollCount       = 0

            do {
                Start-Sleep -Seconds 5
                $pollCount++
                $statusResponse  = &"support/rest/cxone/projectConversionStatus.ps1" $cx1Session $processId
                $migrationStatus = $statusResponse.migrationStatus
                Write-Output "  [$pollCount] Migration status: $migrationStatus"
            } while ($migrationStatus -notin $terminalStatuses)

            $finalStatus = switch ($migrationStatus) {
                "OK"      { "Success" }
                "PARTIAL" { "Partial" }
                "FAILURE" { "Failed"  }
            }

            Write-Output "  Final: $migrationStatus | $($statusResponse.summary) | Migrated $($statusResponse.migratedProjects)/$($statusResponse.totalProjects)"

            foreach ($entry in $batchLogEntries) {
                if ($entry.Status -ne "Skipped") {
                    $entry.ProcessId        = $processId
                    $entry.ConversionStatus = $migrationStatus
                    $entry.Status           = $finalStatus
                }
            }
        } catch {
            Write-Warning "  Conversion failed: $($_.Exception.Message)"
            foreach ($entry in $batchLogEntries) {
                if ($entry.Status -ne "Skipped") {
                    $entry.Status       = "Failed"
                    $entry.ErrorMessage = if ($entry.ErrorMessage) {
                        "$($entry.ErrorMessage); Conversion failed: $($_.Exception.Message)"
                    } else {
                        "Conversion failed: $($_.Exception.Message)"
                    }
                }
            }
        }

        $logEntries += $batchLogEntries
    }
}

$logEntries | Export-Csv -Path $logPath -NoTypeInformation
Write-Output "`nFinished. Processed $total project(s) across $batchNum batch(es)."
Write-Output "Conversion log written to: $logPath"
