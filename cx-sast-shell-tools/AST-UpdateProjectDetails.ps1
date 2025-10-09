param(
    [Switch]$dbg,
    [string]$csv_path
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

#Loop through projects in csv and update details
if($csv_path -eq $null){
    Write-Host "No CSV path provided. Please update valid csv path"
    Exit-PSHostProcess
}

# $validationLine = 0
Import-Csv $csv_path | ForEach-Object {
    $projectDetails = @{}

#    if($_.ProjectName -ne $null){
#        $projectDetails.name= $_.ProjectName
#    }
    if($_.RepoUrl -ne $null){
        $projectDetails.repoUrl= $_.RepoUrl
    }
    if($_.MainBranch -ne $null){
        $projectDetails.mainBranch= $_.MainBranch
    }
    if($_.Criticality -ne $null){
        $projectDetails.criticality= $_.Criticality
    }
    if($_.Tags -ne $null){
        $allTags= @{}
        $tagsList = $_.Tags.Split(',')
        $tagsList | %{
            $tag = $_
            $delimeterIndex = $tag.IndexOf(":")
            if($delimeterIndex -ne -1){
                $key = $tag.Substring(0, $delimeterIndex).Trim()
                $value = $tag.Substring($delimeterIndex+1).Trim()
                $allTags.$key = $value
            }
            else {
                $key = $tag
                $allTags.$key = ""
            }
        }

        $projectDetails.tags = $allTags
    }

    if($_.Groups -ne $null){
        $allGroups= @{}
        $groupsList = $_.Groups.Split(',')
        $groupsList | %{
            $allGroups += $_
        }

        $projectDetails.groups = $allGroups
    }
    

    Write-Output $projectDetails | ConvertTo-Json

    # Rebuild the project object with the updated tags
    
    $response = &"support/rest/cxone/patchprojectdetails.ps1" $cx1Session $_.ProjectID $projectDetails
    Write-Host "Project $($_.ProjectName) has been updated"
    
}
