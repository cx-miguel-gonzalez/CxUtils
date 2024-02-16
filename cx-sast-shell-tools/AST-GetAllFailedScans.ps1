param(
    [Switch]$dbg
)

####CxOne Variable######
$cx1Tenant=""
$PAT=""
$cx1URL="https://ast.checkmarx.net/api"
$cx1TokenURL="https://iam.checkmarx.net/auth/realms/$cx1Tenant"
$cx1IamURL="https://iam.checkmarx.net/auth/admin/realms/$cx1Tenant"
$numberOfDays=-1

. "support/debug.ps1"

setupDebug($dbg.IsPresent)

Add-Type -AssemblyName System.Web

#Generate token for CxOne
$cx1Session = &"support/rest/cxone/apiTokenLogin.ps1" $cx1TokenURL $cx1URL "$cx1IamURL" $cx1Tenant $PAT


#Get list of CxOne projects
$cx1ProjectsResponse = &"support/rest/cxone/getprojects.ps1" $cx1Session
$cx1Projects = $cx1ProjectsResponse.projects
#Get a list of the scans in the last x amoutn of days

$today = Get-Date
$cutOffDate = $today.AddDays($numberOfDays).ToString('yyyy-MM-ddTHH:mm:ssZ')


$scansData = &"support/rest/cxone/getpartialfailedscans.ps1" $cx1Session $cutOffDate

#write-output $scansData.scans
$targetScans = @()

$scansData.scans | %{

    $csvEntry = New-Object -TypeName psobject -Property ([Ordered]@{
        ScanId = $_.id;
        ProjectName = $_.projectName;
        branch = $_.branch;
        status = $_.status;
        sourceType = $_.sourceType;
        initiator = $_.initiator
    })

    $targetScans += $csvEntry
}

#Generate the csv file
$targetScans | Export-Csv -Path './Cx1_FailedPartial_Scans.csv' -Delimiter ',' -Append -NoTypeInformation