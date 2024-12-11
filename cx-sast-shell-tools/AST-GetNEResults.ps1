param(
    [Switch]$dbg
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

Add-Type -AssemblyName System.Web

#Generate token for CxOne
$cx1Session = &"support/rest/cxone/apiTokenLogin.ps1" $cx1TokenURL $cx1URL "$cx1IamURL" $cx1Tenant $PAT

#Get list of CxOne projects
$cx1ProjectsResponse = &"support/rest/cxone/getprojects.ps1" $cx1Session
$cx1Projects = $cx1ProjectsResponse.projects


$validationLine = 0

#1. Get list of projects
#2. Get all sast scans for project
#3. loop through NE results and grab its predicates
$NeResultsCsv = @()

$cx1Projects | %{
    #$branch = $null 
    $validationLine++
    $sleepCheck = $validationLine % 50
    if($sleepCheck -eq 0){
        start-sleep -Seconds 300
        $cx1Session = &"support/rest/cxone/apiTokenLogin.ps1" $cx1TokenURL $cx1URL "$cx1IamURL" $cx1Tenant $PAT
    }
    $projectName = $_.Name
    $projectId = $_.id
    
    Write-Debug $projectName
    
    #find all complted sast scans
    $response = &"support/rest/cxone/getscansforproject.ps1" $cx1Session $projectId
    $scansData = $response.scans
    $targetScans = $scansData | Where-Object {$_.status -eq "Completed" -and $_.engines -contains "sast"}
    
    if($targetScans -ne $null){
        #Get latest completed sast scan
        $targetScan = $targetScans[0]
        $response = &"support/rest/cxone/getSastResults.ps1" $cx1Session $targetScan.Id "1000"
        $sastResults = $response.results

        $sastResults | %{

            if($_.state -eq "NOT_EXPLOITABLE"){
                #get predicate history for result on this project
                $response = &"support/rest/cxone/getSastPredicates" $cx1Session $_.similarityId
                $allPredicates = $response.predicateHistoryPerProject.predicates
                $predicateComments = @()
                $allPredicates | %{
                    if($_.projectId -eq $projectId -and $_.comment -ne ""){
                        $predicateComments += $_.comment
                    }
                }
                
                #prepare CSV entry
                $csvEntry = New-Object -TypeName psobject -Property ([Ordered]@{
                    projectName = $projectName;
                    severity = $_.severity
                    queryName = $_.queryName
                    state = $_.state
                    detectionDate = $_.firstFoundAt
                    comment = [string]::Join("; ", $predicateComments)
        
                })
                #add to NE list
                $NeResultsCsv += $csvEntry
            }
        }
    }

}

$NeResultsCsv | Export-Csv -Path './NotExploitableResults.csv' -Delimiter ',' -Append -NoTypeInformation