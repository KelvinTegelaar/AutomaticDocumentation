#####################################################################
$APIKEy =  "APIKEYHERE"
$APIEndpoint = "https://api.eu.itglue.com"
$orgID = "ORGIDHERE"
#####################################################################
#Grabbing ITGlue Module and installing,etc
If(Get-Module -ListAvailable -Name "ITGlueAPI") {Import-module ITGlueAPI} Else { install-module ITGlueAPI -Force; import-module ITGlueAPI}
#Settings IT-Glue logon information
Add-ITGlueBaseURI -base_uri $APIEndpoint
Add-ITGlueAPIKey $APIKEy
#This is the data we'll be sending to IT-Glue. 
$BitlockVolumes = Get-BitLockerVolume
#The script uses the following line to find the correct asset by serialnumber, match it, and connect it if found. Don't want it to tag at all? Comment it out by adding #
$TaggedResource = (Get-ITGlueConfigurations -organization_id $orgID -filter_serial_number (get-ciminstance win32_bios).serialnumber).data
foreach($BitlockVolume in $BitlockVolumes) {
$PasswordObjectName = "$($Env:COMPUTERNAME) - $($BitlockVolume.MountPoint)"
$PasswordObject = @{
    type = 'passwords'
    attributes = @{
            name = $PasswordObjectName
            password = [string]$BitlockVolume.KeyProtector.recoverypassword
            notes = "Bitlocker key for $($Env:COMPUTERNAME)"

    }
}
if($TaggedResource){ 
    $Passwordobject.attributes.Add("resource_id",$TaggedResource.Id)
    $Passwordobject.attributes.Add("resource_type","Configuration")
}

#Now we'll check if it already exists, if not. We'll create a new one.
$ExistingPasswordAsset = (Get-ITGluePasswords -filter_organization_id $orgID -filter_name $PasswordObjectName).data
#If the Asset does not exist, we edit the body to be in the form of a new asset, if not, we just upload.
if(!$ExistingPasswordAsset){
Write-Host "Creating new Bitlocker Password" -ForegroundColor yellow
$ITGNewPassword = New-ITGluePasswords -organization_id $orgID -data $PasswordObject
} else {
Write-Host "Updating Bitlocker Password" -ForegroundColor Yellow
$ITGNewPassword = Set-ITGluePasswords -id $ExistingPasswordAsset.id -data $PasswordObject
}
}
