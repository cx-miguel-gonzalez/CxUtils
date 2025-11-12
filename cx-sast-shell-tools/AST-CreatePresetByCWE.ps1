param(
    [string]$presetName,
    [string]$presetDescription,
    [string]$csv_path,
    [Switch]$dbg
)

####CxOne Variable######
$cx1Tenant=""
$PAT=""
$cx1URL="https://ast.checkmarx.net/api"
$cx1TokenURL="https://iam.checkmarx.net/auth/realms/$cx1Tenant"
$cx1IamURL="https://iam.checkmarx.net/auth/admin/realms/$cx1Tenant"
$csv_path=""

. "support/debug.ps1"

setupDebug($dbg.IsPresent)

Add-Type -AssemblyName System.Web

#Generate token for CxOne
$cx1Session = &"support/rest/cxone/apiTokenLogin.ps1" $cx1TokenURL $cx1URL "$cx1IamURL" $cx1Tenant $PAT

#Get list of CxOne Query Families
$engine="sast"
$cx1SastQueryFamilies = &"support/rest/cxone/getQueryFamilyForEngine.ps1" $cx1Session $engine

#Loop through the cwes in the csv and get the list of all the queries
Write-Debug $csv_path
$validationLine = 0
$cweList = @()

#Get list of CWEs from CSV
Import-Csv $csv_path | ForEach-Object {
    $validationLine++
    $cweList += $_.Id
    
}
$queriesBody = @()
#Loop through each CWE and get the queries from each family
$cx1SastQueryFamilies | %{
    $familyName = $_
    $queriesList = @()
    
    #pull list of queries for the family
    $familyQueriesResponse = &"support/rest/cxone/getListOfQueriesInFamily.ps1" $cx1Session $engine $familyName
    
    #filter queries for the cwe
    $familyQueriesCategories = $familyQueriesResponse.children
    $familyQueriesCategories | ForEach-Object {
        $_.children | ForEach-Object {
            if($_ -ne $null -and $_.data.cwe -in $cweList){
                $queriesList += $_.key
            }
        }
    }
    Write-Debug "Family: $familyName, CWE: $cweId, Queries Found: $($queriesList.Count)"
    if(-not $queriesList){
        Write-Debug "No queries found for CWE-$cweId in family $familyName"
    }
    else {
        $queryData = @{
            familyName = $familyName
            queryIds = $queriesList
        }
        $queriesBody += $queryData
    }
}


$newPresetBody = @{
    name = "$presetName"
    description = "$presetDescription"
    queries = $queriesBody
}
Write-Output $newPresetBody | ConvertTo-Json -Depth 10
#Create Preset
try {
    $response = &"support/rest/cxone/createPresetForEngine.ps1" $cx1Session $engine $newPresetBody
    Write-Debug $response
}
catch {
    <#Do this if a terminating exception happens#>
    Write-Host "Error creating preset: $($_.Exception.Message)"
}