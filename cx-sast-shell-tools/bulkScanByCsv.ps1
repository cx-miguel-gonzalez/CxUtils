param(
    [Parameter(Mandatory = $true)]
    [System.Uri]$sast_url,
    [String]$username,
    [String]$password,
    [Parameter(Mandatory = $true)]
    [String]$csv_path,
    [Switch]$dbg
)

if(!$username){
    $credentials = Get-Credential -Credential $null
    $username = $credentials.UserName
    $password = $credentials.GetNetworkCredential().Password
}

. "support/debug.ps1"

$cxCliPath="/Users/miguelg/Documents/CxConsolePlugin-1.1.26/runCxConsole.sh"

#Gather list of projects to save
$saveProjects = @()
$iteration = 0
Import-Csv $csv_path | ForEach-Object {

    $teamName = $_.team
    $projectName = $_.project
    $zipPath = $_.FilePath

    if($iteration -gt 0){
        $response = &"$cxCliPath" AsyncScan -CxServer $sast_url -CxUser $username -CxPassword $password -ProjectName "$teamName/$projectName" -LocationType folder -LocationPath $zipPath
        Write-Output $response
    }
    $iteration++
}

