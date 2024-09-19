param(
    [string]$csv_path,
    [Switch]$dbg
)

Add-Type -AssemblyName System.Web

####CxOne Variable######
$cx1Tenant=""
$PAT=""
$cx1URL="https://ast.checkmarx.net/api"
$cx1TokenURL="https://iam.checkmarx.net/auth/realms/$cx1Tenant"
$cx1IamURL="https://iam.checkmarx.net/auth/admin/realms/$cx1Tenant"
$csv_path=""

. "support/debug.ps1"

setupDebug($dbg.IsPresent)

#Generate token for CxOne
$cx1Session = &"support/rest/cxone/apiTokenLogin.ps1" $cx1TokenURL $cx1URL "$cx1IamURL" $cx1Tenant $PAT

#Get list of CxOne groups and users
$cx1Groups = &"support/rest/cxone/getgroups.ps1" $cx1Session
$cx1Users = &"support/rest/cxone/getusers.ps1" $cx1Session

#Create all of the users in the list

##add error handling for users that already exist 
$validationLine = 0
Import-Csv $csv_path | ForEach-Object {
    $validationLine++
    $firstName = $_.firstName
    $lastName = $_.lastName
    $username = $_.username
    $email = $_.email
    #check if user already exists
    $userExists = $cx1Users | Where-Object {$_.email -eq $email}
    if(!$userExists){
        #create the user
        $userInput=@{
            firstName = $firstName
            lastName = $lastName
            username = $username
            email = $email
        }
    
        try{
            #$response = &"support/rest/cxone/createuser.ps1" $cx1Session $userInput
        }
        catch{        
            Write-Output $response
        }
    }
}

#add each user to the correct groups
$cx1Users = &"support/rest/cxone/getusers.ps1" $cx1Session
$validationLine = 0
Import-Csv $csv_path | ForEach-Object {
    $validationLine++
    $email = $_.email.Trim()
    $userInfo = $cx1Users | Where-Object {$_.email -eq $email}
    $groups = $_.groups.split(',')
    #generate list of groups 
    $groups | %{
        $groupName = $_
        $groupDetails=$cx1Groups | Where-Object{$_.name -eq $groupName}
        #create group if it does not exist
        if(!$groupDetails){
            Write-output "Could not find $groupName"
            $groupInput = @{}
            $groupInput.Add("name",$groupName)
            $roleNames = @("Developer")
            $groupRoles = @{"ast-app"=$roleNames}
            $groupInput.Add("clientRoles",$groupRoles)

            #create group
            #$response = &"support/rest/cxone/createGroup.ps1" $cx1Session $groupInput
        }
        #add user to the group
        try{
            $response = &"support/rest/cxone/addusertogroup.ps1" $cx1Session $userInfo.id $groupDetails.id
            write-output $response
        }
        catch{        
            Write-Output $response
        }
    }
}
