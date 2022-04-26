param(
    [Parameter(Mandatory = $true)]
    [string]$recipient,
    [string]$xmlReport,
    [Switch]$dbg
)

#update the following with credentials
$sast_url  = "http://workpc"
$reporting_url = "http://workpc:8085"
$username = "admin"
$password = "P@ssw0rd01!"

. "support/debug.ps1"
setupDebug($dbg.IsPresent)

#Login and generate token
$session = &"support/rest/cxreporting/authenticate.ps1" $sast_url $reporting_url $username $password -dbg:$dbg.IsPresent

#Grab the scanId
[xml]$scanReport = Get-Content -Path $xmlReport

#Generate the report
#TemplateIds
#1 for Scan Template Vulnerability Type oriented
#2 for Scan Template Result State oriented
#3 for Project Template
#4 for Single Team Template
#5 for Multi Teams Template

#build the report request as Json
$templateId = 2
$entityId = $scanReport.CxXmlResults.Scanid
#Build out the request
$reportRequest = @{
    templateId = 2
    entityId   = @($entityId)
    filters    = @(
        @{
            type = 1
            excludedValues = @(
                'Medium',
                'Low',
                'Information'
                )
        },
        @{
            type = 2
            excludedValues = @(
                'Confirmed',
                'Urgent'
                )
        }
    )
    outputFormat = "pdf"
}


Write-Output $reportRequest | ConvertTo-Json -depth 10
#call apis
$reportId = &"support/rest/cxreporting/generateReport.ps1" $session $reportRequest

#Write-Output $reportId
$reportStatus = "NA"

while ($reportStatus -ne "Finished"){
    Start-Sleep -s 1.5
    $reportStatus = &"support/rest/cxreporting/getReportStatus.ps1"

}