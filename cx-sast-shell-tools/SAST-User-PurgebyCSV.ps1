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

setupDebug($dbg.IsPresent)

#Login and generate token
$session = &"support/rest/sast/login.ps1" $sast_url $username $password -dbg:$dbg.IsPresent

#Get list of all users
$allUsers = &"support/rest/sast/getusers.ps1" $session

# Validate the CSV file exists
if (!(Test-Path -Path $csv_path -PathType Leaf)) {
    Throw "A file was not found at ${csv_path}."
}

Write-Output "Csv file was found"

# Validate the CSV File first and exit with any error. 
$validationLine = 0
Import-Csv $csv_path | ForEach-Object {
    $validationLine++

    if ($null -eq $_.username) {
        Throw "Error processing $_ - a username field does not exist on line ${validationLine}."
    }
    if ($null -eq $_.email) {
        Throw "Error processing $_ - a email field does not exist on line ${validationLine}."
    }
}

Write-Output "CSV file was validated. Ready to start the update. Will keep only $validationLine users. All Others will be deleted"

#Gather list of users to save
$saveUsers = @()
$validationLine = 0
Import-Csv $csv_path | ForEach-Object {
    $validationLine++

    $curEmail = $_.email
    
    $curUser = $allUsers | Where-Object {$_.email -eq $curEmail}

    if($curUser -ne $null){
        $saveUsers += $curUser
    }
    else{
        Write-Output "Could not find user with the email: $curEmail"
    }
}

Write-Output "The following users will be saved"
Write-Output $saveUsers

$targetUsers = $allUsers | Where-Object {$_.email -notin $saveUsers.email}

$output = [String]::Format("{0} users will be deleted", $targetUsers.count)
Write-Output $output

$verification = Read-Host -Prompt "Are you sure you want to delete all these users (y/n)"
#delete target users
if($verification -eq "y"){
    Write-Debug "You have confirmed your're going to delete the users"
    $targetUsers | %{
        &"support/rest/sast/deleteuser.ps1" $session $_.id
    }

    $output = [String]::Format("{0} users have been successfully deleted", $targetUsers.count)
    Write-Output $output

}

