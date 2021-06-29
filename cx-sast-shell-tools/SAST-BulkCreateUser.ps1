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
        Throw "Error processing $_ - a username field does not exist on line ${validationLine}."
    }
    if ($null -eq $_.password) {
        Throw "Error processing $_ - a password field does not exist on line ${validationLine}."
    }
    if ($null -eq $_.roles) {
        Throw "Error processing $_ - a roles field does not exist on line ${validationLine}."
    }
    if ($null -eq $_.teams) {
        Throw "Error processing $_ - a teams field does not exist on line ${validationLine}."
    }
    if ($null -eq $_.firstName) {
        Throw "Error processing $_ - a firstName field does not exist on line ${validationLine}."
    }
    if ($null -eq $_.lastName) {
        Throw "Error processing $_ - a lastName field does not exist on line ${validationLine}."
    }
    if ($null -eq $_.email) {
        Throw "Error processing $_ - a roles field does not exist on line ${validationLine}."
    }
}

Write-Output "CSV file was validated. Ready to start the update for $validationLine records"

#Login and generate token
$session = &"support/rest/sast/login.ps1" $sast_url $username $password -dbg:$dbg.IsPresent
#Get team and role information
$teams = &"support/rest/sast/teams.ps1" $session
$roles = &"support/rest/sast/getroles.ps1" $session

$validationLine = 0
$creationTally = 0
$failureTally= 0
$failures = @()

#start creating the users
Import-Csv $csv_path | ForEach-Object {
    $validationLine++
    #set teams list
    $teamids = @()
    $_.teams.split(",") | %{
        $teamName = $_
        Write-Debug $teamName
        $teamInfo = $teams | Where-Object {$_.name -eq $teamName}
        if(!$teaminfo) {
            $output = [String]::Format("Unable to find team with the name: {0}", $teamName)
            Write-Output $output
        }
        else{
            $teamids += $teaminfo.id
        }
    }
    
    #Get all of the role ids and set the list 
    $roleids = @()
    $_.roles.split(",") | %{
        $roleName = $_
        Write-Debug $roleName
        $roleInfo = $roles | Where-Object {$_.name -eq $roleName}
        if(!$roleInfo) {
            $output = [String]::Format("Unable to find role with the name: {0}", $roleName)
            Write-Output $output
        }
        else{
            $roleids += $roleInfo.id
        }
    }
    
    if($_.username -ne $null -and $_.password -ne $null -and $teamIds.Count -ne 0 -and $roleids.Count -ne 0 -and $_.firstName -ne $null -and $_.lastName -ne $null -and $_.email -ne $null){
        #build the body
            $newUser = @{
                username                   =   $_.username;
                password                   =   $_.password;
                RoleIds                    =   $roleIds;
                TeamIds                    =   $teamIds;
                authenticationProviderId   =   1;
                firstName                  =   $_.firstName;
                lastName                   =   $_.lastName;
                email                      =   $_.email;
                phoneNumber                =   $_.phoneNumber;
                cellPhoneNumber            =   $_.cellPhoneNumber;
                jobTitle                   =   $_.jobTitle;
                other                      =   $_.other;
                active                     =   $true;
                expirationDate             =   (Get-Date).AddYears(3);
                allowedIpList              =   $null;
                localeId                   =   1;
            }
            #create the user
            try{
                &"support\rest\sast\createuser.ps1" $session $newUser
                $output = [string]::Format("Successfully created user: {0}", $_.username)
                Write-Output $output
                $creationTally++
            }
            catch{
                $output = [string]::Format("Failed to creat user: {0}", $newUser.username)
                Write-Output $output
                $failureTally++
                $failures += $newUser
            }

    }
    else{
        $output = [string]::Format("Row {0} - Missing required information for username: {1}", $validationLine, $_.username)
        Write-Output $output
        $failureTally++
        $failures += $_
    }
}

#Report totals
Write-Output "Successfully created $creationTally users"
if($failures){
    Write-Output "Failed to create $failureTally users"

    $failures.GetEnumerator() | Select-Object -property firstName,lastName,userName,email | Export-Csv -NoTypeInformation -path .\ImportFailures.csv
    
}