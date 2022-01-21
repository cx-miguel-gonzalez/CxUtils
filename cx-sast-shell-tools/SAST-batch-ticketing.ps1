param(
    [Switch]$dbg
)
#Credentials and scan parameters
$sast_url = "http://workpc"
$username = "admin"
$password = "admin"
$cxflowPath = "C:\cxflow\cx-flow-1.6.28.jar"
$cxflowyml = "C:\cxflow\cxflow.yml"
. "support/debug.ps1"

setupDebug($dbg.IsPresent)


#Login and generate token
$session = &"support/rest/sast/login.ps1" $sast_url $username $password -dbg:$dbg.IsPresent

$projects = &"support/rest/sast/projects.ps1" $session
$teams = &"support/rest/sast/teams.ps1" $session

#loop through projects and initiate scan for each
$projects | %{
    $teamid = $_.teamid
    $team = $teams | Where-Object {$_.id -eq $teamid}
    $projectName = $_.name
    $teamName = $team.fullname

    $command = [string]::Format("-jar {0} --project --spring.config.location={1} --bug-tracker=JIRA --cx-project={2} --cx-team={3} --app={2}", $cxflowPath, $cxflowyml, $projectName, $teamName)
    write-debug $command
    $processOptions = @{
        FilePath = "java"
        ArgumentList = $command
        RedirectStandardOutput = ".\$projectName.log"
    }
    Start-Process @processOptions -NoNewWindow -Wait

}

