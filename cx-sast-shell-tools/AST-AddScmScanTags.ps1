param(
    [Switch]$dbg,
    [string]$csvPath,
    [string]$errorLogPath = "AddScmScanTags_errors.csv"
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
#   projectName        - exact name of the CxOne project
#   protectedBranches  - branch(es) to protect, in the format:
#                           BRANCH_NAME | tag, tag2:tagValue ; BRANCH_NAME2 | tag3:tagValue3
#                         where ";" separates branches, "|" separates the branch name from its
#                         tags, "," separates individual tags, and ":" separates a tag's
#                         name from its value (a tag with no ":" gets an empty value)

. "support/debug.ps1"
setupDebug($dbg.IsPresent)

function ConvertTo-ProtectedBranchBody {
    param(
        [Parameter(Mandatory=$true)]
        [string]$protectedBranchesValue
    )

    $branchBodies = @()

    foreach ($branchEntry in ($protectedBranchesValue -split ";")) {
        if ([string]::IsNullOrWhiteSpace($branchEntry)) {
            continue
        }

        $branchParts = $branchEntry -split "\|", 2
        $branchName  = $branchParts[0].Trim()
        $tagsPart    = if ($branchParts.Count -gt 1) { $branchParts[1] } else { "" }

        $tags = @{}
        foreach ($tagEntry in ($tagsPart -split ",")) {
            $tagEntry = $tagEntry.Trim()
            if ([string]::IsNullOrWhiteSpace($tagEntry)) {
                continue
            }

            $tagParts = $tagEntry -split ":", 2
            $tagKey   = $tagParts[0].Trim()
            $tagValue = if ($tagParts.Count -gt 1) { $tagParts[1].Trim() } else { "" }

            $tags[$tagKey] = $tagValue
        }

        $branchBodies += @{
            pattern         = $branchName
            isDefaultBranch = $false
            tags            = $tags
        }
    }

    return $branchBodies
}

function Merge-ProtectedBranches {
    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyCollection()]
        [System.Object[]]$currentProtectedBranches,
        [Parameter(Mandatory=$true)]
        [System.Object[]]$desiredProtectedBranches
    )

    $branchesByPattern = @{}

    foreach ($branch in $currentProtectedBranches) {
        $existingTags = @{}
        if ($branch.tags) {
            foreach ($tagProperty in $branch.tags.PSObject.Properties) {
                $existingTags[$tagProperty.Name] = $tagProperty.Value
            }
        }

        $branchesByPattern[$branch.pattern] = @{
            pattern         = $branch.pattern
            isDefaultBranch = $branch.isDefaultBranch
            tags            = $existingTags
        }
    }

    foreach ($branch in $desiredProtectedBranches) {
        if ($branchesByPattern.ContainsKey($branch.pattern)) {
            foreach ($tagKey in $branch.tags.Keys) {
                $branchesByPattern[$branch.pattern].tags[$tagKey] = $branch.tags[$tagKey]
            }
        } else {
            $branchesByPattern[$branch.pattern] = $branch
        }
    }

    return @($branchesByPattern.Values)
}

if (-not $csvPath -or -not (Test-Path $csvPath)) {
    Write-Error "CSV file not found: $csvPath."
    exit 1
}

#Generate token for CxOne
$cx1Session = &"support/rest/cxone/apiTokenLogin.ps1" $cx1TokenURL $cx1URL $cx1IamURL $cx1Tenant $PAT

#Get full list of CxOne projects (paginated)
Write-Output "Retrieving all projects..."
$cx1ProjectsResponse = &"support/rest/cxone/getprojects.ps1" $cx1Session
$cx1Projects = $cx1ProjectsResponse.projects

$csvRows = Import-Csv -Path $csvPath

$errorLog          = @()
$matchedProjects   = @()

foreach ($row in $csvRows) {
    $projectName       = $row.projectName
    $protectedBranches = $row.protectedBranches

    $matchedProject = $cx1Projects | Where-Object { $_.name -eq $projectName } | Select-Object -First 1

    if (-not $matchedProject) {
        Write-Warning "No matching project found for: $projectName"
        $errorLog += [PSCustomObject]@{
            ProjectName = $projectName
            Error       = "No matching project found in CxOne"
        }
        continue
    }

    Write-Output "Retrieving current protected branches for project: $projectName"

    try {
        $currentProtectedBranches = @(&"support/rest/cxone/getProtectedBranches.ps1" $cx1Session $projectName)

        $desiredProtectedBranches = ConvertTo-ProtectedBranchBody -protectedBranchesValue $protectedBranches
        $mergedProtectedBranches  = Merge-ProtectedBranches -currentProtectedBranches $currentProtectedBranches -desiredProtectedBranches $desiredProtectedBranches

        &"support/rest/cxone/replaceProtectedBranches.ps1" $cx1Session $projectName $mergedProtectedBranches | Out-Null
        Write-Output "  Updated protected branches for: $projectName"

        $matchedProjects += [PSCustomObject]@{
            ProjectName       = $projectName
            ProjectId         = $matchedProject.id
            RepoId            = $matchedProject.repoId
            ProtectedBranches = $mergedProtectedBranches
        }
    } catch {
        Write-Warning "  Failed to update protected branches for $projectName`: $($_.Exception.Message)"
        $errorLog += [PSCustomObject]@{
            ProjectName = $projectName
            Error       = "Failed to update protected branches: $($_.Exception.Message)"
        }
    }
}

Write-Output "Matched $($matchedProjects.Count) of $($csvRows.Count) project(s)."

if ($errorLog.Count -gt 0) {
    $errorLog | Export-Csv -Path $errorLogPath -NoTypeInformation
    Write-Output "Errors logged to: $errorLogPath"
}
