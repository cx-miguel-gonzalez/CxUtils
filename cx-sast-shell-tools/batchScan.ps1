param(
    [Switch]$dbg
)
#Credentials and scan parameters
$sast_url = "http://workpc"
$username = "admin"
$password = "admin"
$isIncremental = $false
$forceScan = $true
$comment = 'batch scan test'

. "support/debug.ps1"

setupDebug($dbg.IsPresent)


#Login and generate token
$session = &"support/rest/sast/login.ps1" $sast_url $username $password -dbg:$dbg.IsPresent

$projects = &"support/rest/sast/projects.ps1" $session

#loop through projects and initiate scan for each
$projects | %{
    $scanRequest = @{
        projectId=$_.id;
        isIncremental=$isIncremental;
        isPublic=$true;
        forceScan=$forceScan;
        comment=$comment
    }
        &"support/rest/sast/createScan.ps1" $session $scanRequest        
}

