param(
    [Switch]$dbg,
    [string]$ProjectNamePattern,
    [string]$outputPath = "ProjectSCMData_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv",
    [string]$errorLogPath = "ProjectSCMData_errors_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
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

. "support/debug.ps1"

setupDebug($dbg.IsPresent)

#Generate token for CxOne
$cx1Session = &"support/rest/cxone/apiTokenLogin.ps1" $cx1TokenURL $cx1URL "$cx1IamURL" $cx1Tenant $PAT

#Get list of CxOne projects
Write-Output "Retrieving all projects..."
$cx1ProjectsResponse = &"support/rest/cxone/getprojects.ps1" $cx1Session
$cx1Projects = $cx1ProjectsResponse.projects

$namePatterns = @()
if ($ProjectNamePattern) {
    $namePatterns = $ProjectNamePattern -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ }
}

$targetProjects = $cx1Projects | Where-Object {
    $project = $_
    if ($project.repoId -eq $null) {
        return $false
    }
    if ($namePatterns.Count -eq 0) {
        return $true
    }
    foreach ($pattern in $namePatterns) {
        if ($project.name -like $pattern) {
            return $true
        }
    }
    return $false
}

if ($namePatterns.Count -gt 0) {
    Write-Output "Filtering projects to those matching: $($namePatterns -join ', ')"
}
Write-Output "Found $($targetProjects.Count) project(s) connected to an SCM repository."

$csvRows = @()
$errorLog = @()
$counter = 0

foreach ($project in $targetProjects) {
    $counter++
    $sleepCheck = $counter % 50
    if ($sleepCheck -eq 0) {
        Start-Sleep -Seconds 300
        $cx1Session = &"support/rest/cxone/apiTokenLogin.ps1" $cx1TokenURL $cx1URL "$cx1IamURL" $cx1Tenant $PAT
    }

    Write-Output "  [$counter/$($targetProjects.Count)] $($project.name)"

    try {
        $scmSettings = &"support/rest/cxone/getProjectSCMsettings.ps1" $cx1Session $project.repoId

        $protectedBranches = ($scmSettings.branches | ForEach-Object { $_.pattern }) -join ","

        $csvRows += [PSCustomObject]@{
            ProjectId         = $project.id
            ProjectName       = $project.name
            RepoUrl           = $scmSettings.url
            ProtectedBranches = $protectedBranches
        }
    } catch {
        Write-Warning "  Failed to retrieve SCM settings for $($project.name): $($_.Exception.Message)"
        $errorLog += [PSCustomObject]@{
            ProjectName = $project.name
            ProjectId   = $project.id
            RepoId      = $project.repoId
            Error       = $_.Exception.Message
        }
    }
}

$csvRows | Export-Csv -Path $outputPath -NoTypeInformation
Write-Output "Wrote $($csvRows.Count) of $($targetProjects.Count) project(s) to: $outputPath"

if ($errorLog.Count -gt 0) {
    $errorLog | Export-Csv -Path $errorLogPath -NoTypeInformation
    Write-Output "Errors logged to: $errorLogPath"
}
