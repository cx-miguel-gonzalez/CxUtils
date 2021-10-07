param(
    [Parameter(Mandatory = $true)]
    [System.Uri]$sast_url,
    [String]$username,
    [String]$password,
    [Parameter(Mandatory = $true)]
    [string]$samlIdP,
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

# Validate the SAML IdP name
$idps = &"support/rest/sast/getsamlproviders.ps1" $session
$idpID = $idps | Where-Object{$_.Name -eq $samlIdP}

if(!$idpID){
    Throw "An Identitiy provider with the name: ${samlIdP} could not be found. Please provide a valid Identity Provider name"
}
# Gather list of teams
$teams = &"support/rest/sast/teams.ps1" $session

# Validate the CSV file exists
if (!(Test-Path -Path $csv_path -PathType Leaf)) {
    Throw "A file was not found at ${csv_path}."
}

Write-Output "Csv file was found"

# Validate the CSV File first and exit with any error. 
$validationLine = 0
Import-Csv $csv_path | ForEach-Object {
    $validationLine++

    if ($null -eq $_.SAMLGroupName) {
        Throw "Error processing $_ - a project_name field does not exist on line ${validationLine}."
    }
    if ($null -eq $_.SAMLGroupID) {
        Throw "Error processing $_ - a scanID field does not exist on line ${validationLine}."
    }
    if ($null -eq $_.SASTteam) {
        Throw "Error processing $_ - a resultID field does not exist on line ${validationLine}."
    }
}

Write-Output "CSV file was validated. Ready to start the update for $validationLine records"
#Build the SAML idp team and group mapping
$samlmap = @()

Import-Csv $csv_path | ForEach-Object {
    $teamName = $_.SASTteam
    $samlValue = $_.SAMLGroupID
    $targetTeam = $teams | Where-Object{$_.name -eq $teamName}
        
    $mapping = New-Object -TypeName psobject -Property(@{
        teamfullpath = $targetTeam.fullName;
        SamlAttributeValue = $samlvalue;
    })
    
    $samlmap += $mapping
}

#need to test the saml map and the nreat the role map
Write-Output $samlmap
&"support/rest/sast/putSamlTeamMap.ps1" $session $samlmap $idpID