param(
    [Parameter(Mandatory = $true)]
    [System.Uri]$sast_url,
    [Parameter(Mandatory = $false)]
    [String]$username,
    [Parameter(Mandatory = $false)]
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
        Throw "Error processing $_ - a project_name field does not exist on line ${validationLine}."
    }
    if ($null -eq $_.roleName) {
        Throw "Error processing $_ - a scanID field does not exist on line ${validationLine}."
    }
}

Write-Output "CSV file was validated. Ready to start the update for $validationLine records"

#Login and generate token
$session = &"support/rest/sast/login.ps1" $sast_url $username $password -dbg:$dbg.IsPresent

#Get Role information 
Write-Output "Fetching Roles"
$roles = &"support/rest/sast/getroles.ps1" $session

#get User information
Write-Output "Fetching user information"
$allUsers = &"support/rest/sast/getusers.ps1" $session

#Update each user in list
Import-Csv $csv_path | ForEach-Object {
    #Validate Role information 
    $role = $null
    $roleName = $_.roleName
    $roles | % {
        Write-Debug $_
        if( $_.name -eq $roleName){
            $role = $_
        }
    }

    if(!$role){
        Write-Output "Could not find any Roles with the name of $roleName. Please correct name and try again."
    }
    else{
        Write-Output "Successfully found role information for $roleName"
        Write-Debug $role
    }

    #$newRoleIds = @($role.id)
    
    #get User information
    $user = $null
    $targetuser = $_.username
    $allUsers | % {
        Write-Debug $_
        if( $_.username -eq $targetuser){
            $user = $_
        }
    }

    if(!$user){
        Write-Output "Could not find any users with the name of $targetuser. Please correct name and try again."
    }
    else{
        Write-Output "Successfully found user information for $targetuser"
        Write-Debug $user
    }

    $user.roleIds = @($role.id)
    Write-Debug $user

    &"support/rest/sast/modifyuser.ps1" $session $user

    $output = [String]::Format("Updated user: {0} to the role: {1}", $targetuser, $roleName)
    Write-Output $output
    
}