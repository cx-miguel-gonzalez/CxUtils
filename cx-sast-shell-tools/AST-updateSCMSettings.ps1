param(
    [Switch]$dbg,
    [string]$successLogPath = "updateSCMSettings_success_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv",
    [string]$errorLogPath = "updateSCMSettings_errors_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
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

Add-Type -AssemblyName System.Web

#Generate token for CxOne
$cx1Session = &"support/rest/cxone/apiTokenLogin.ps1" $cx1TokenURL $cx1URL "$cx1IamURL" $cx1Tenant $PAT

#Get list of CxOne projects
$cx1ProjectsResponse = &"support/rest/cxone/getprojects.ps1" $cx1Session
$cx1Projects = $cx1ProjectsResponse.projects
$targetProjects = $cx1Projects | Where-Object { $_.repoId -ne $null}

$validationLine = 0
$successLog = @()
$errorLog = @()

$targetProjects | %{
    $validationLine++
    $sleepCheck = $validationLine % 50
    if($sleepCheck -eq 0){
        start-sleep -Seconds 300
        $cx1Session = &"support/rest/cxone/apiTokenLogin.ps1" $cx1TokenURL $cx1URL "$cx1IamURL" $cx1Tenant $PAT
    }
    $projectName = $_.Name
    $projectId = $_.id
    $repoId = $_.repoId
    
    #get the scm settings for the project
    if($repoId){
        #enable/disable scanners as needed. In this example, we are enabling all scanners and related settings for all projects with a repoId. You can modify as needed based on your requirements.
        $scmSettings = @{
#            webhookEnabled                 = $true
#            kicsScannerEnabled             = $true
#            sastScannerEnabled             = $true
#            ossfScoreCardScannerEnabled    = $true
            secretsDetectionScannerEnabled = $true
#            sastIncrementalScan            = $false
#            scaScannerEnabled              = $true
#            apiSecScannerEnabled           = $true
#            containerScannerEnabled        = $true
#            prDecorationEnabled            = $true
#            commitIdScanTagEnabled         = $true
        }

        #update the scm settings
        $scmSettingsBody = $scmSettings | ConvertTo-Json -Depth 10
        try {
            &"support/rest/cxone/updateScmSettings.ps1" $cx1Session $repoId $projectId $scmSettingsBody | Out-Null

            $scmSettings = &"support/rest/cxone/getProjectSCMsettings.ps1" $cx1Session $repoId

            $successLog += [PSCustomObject]@{
                ProjectName = $projectName
                ProjectId   = $projectId
                RepoId      = $repoId
            }
        }
        catch {
            $statusCode = $null
            if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
                $statusCode = [int]$_.Exception.Response.StatusCode
            }
            $responseBody = Get-ErrorResponseBody -ErrorRecord $_

            Write-Warning "  Failed to update SCM settings for $projectName`: $($_.Exception.Message)"
            if ($responseBody) {
                Write-Warning "    Response body: $responseBody"
            }

            $errorLog += [PSCustomObject]@{
                ProjectName  = $projectName
                ProjectId    = $projectId
                RepoId       = $repoId
                StatusCode   = $statusCode
                Error        = $_.Exception.Message
                ResponseBody = $responseBody
            }
        }
    }
}

Write-Output "Updated $($successLog.Count) of $($targetProjects.Count) project(s)."

if ($successLog.Count -gt 0) {
    $successLog | Export-Csv -Path $successLogPath -NoTypeInformation
    Write-Output "Successful updates logged to: $successLogPath"
}

if ($errorLog.Count -gt 0) {
    $errorLog | Export-Csv -Path $errorLogPath -NoTypeInformation
    Write-Output "Errors logged to: $errorLogPath"
}