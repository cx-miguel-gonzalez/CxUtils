param(
    [Parameter(Mandatory = $true)]
    [System.Uri]$sast_url,
    [String]$username,
    [String]$password,
    [Parameter(Mandatory = $true)]
    [String]$cutOff,
    [Switch]$dbg
)

if(!$username){
    $credentials = Get-Credential -Credential $null
    $username = $credentials.UserName
    $password = $credentials.GetNetworkCredential().Password
}

. "support/debug.ps1"

setupDebug($dbg.IsPresent)

#Login and generate token
$session = &"support/rest/sast/login.ps1" $sast_url $username $password -dbg:$dbg.IsPresent

#Get list of all users
$CutOffDate = Get-Date($cutOff)
$allUsers = &"support/rest/sast/getusers.ps1" $session

#find any users that have not logged in
$targetUsers = $allUsers | Where-Object{$_.lastLoginDate -eq $null}
#find all users where last login date is less that cutoff date
$allUsers | Where-Object{$_.lastLoginDate -ne $null} | %{
    $lastLogin = Get-Date($_.lastLoginDate)
    if($lastLogin -lt $CutOffDate){
        $targetUsers += $_
    }
}

$output = [String]::Format("{0} users will be deleted. The following users will be deleted:", $targetUsers.count)
Write-Output $output
$targetUsers | %{
    $output = $_.firstName + " " + $_.lastName + " - " + $_.username
    Write-Output $output
}

$verification = Read-Host -Prompt "Are you sure you want to delete these users (y/n)"
#delete target users
if($verification -eq "y"){
    Write-Debug "You have confirmed your're going to delete the users"
    $targetUsers | %{
        &"support/rest/sast/deleteuser.ps1" $session $_.id
    }
}
