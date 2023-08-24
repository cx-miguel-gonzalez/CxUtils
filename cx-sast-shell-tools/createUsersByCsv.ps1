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

#Get list of CxOne groups
$cx1Groups = &"support/rest/cxone/getgroups.ps1" $cx1Session

#Create all of the users in the list
$validationLine = 0
Import-Csv $csv_path | ForEach-Object {
    $validationLine++
    
    #create the user
    $userInput=@{
        firstName = $_.firstName
        lastName = $_.lastName
        username = $_.username
        email = $_.email
    }

    try{
        $response = &"support/rest/cxone/createuser.ps1" $cx1Session $userInput
    }
    catch{        
        Write-Output $response
    }

    #add the user to all the correct groups
    $groupsDetails | %{

    }
}

#get a list of all users
$cx1Users = &"support/rest/cxone/getusers.ps1" $cx1Session

#add each user to the correct groups
$validationLine = 0
Import-Csv $csv_path | ForEach-Object {
    $validationLine++
    $username = $_.username
    $userInfo = $cx1Users | Where-Object{$_.username -eq $username}

    $groups = $_.groups.split(',')
    
    #generate list of groups 
    $groups | %{
        $groupName = $_
        $groupDetails=$cx1Groups | Where-Object{$_.name -eq $groupName}
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
