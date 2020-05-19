#####################################################################
$APIKEy = "ITGLUEAPIKEYHERE"
$APIEndpoint = "https://api.eu.itglue.com"
$orgID = "ORGIDHERE"
$ChangeAdminUsername = $true
$NewAdminUsername = "Tits"
#####################################################################
#Grabbing ITGlue Module and installing.
If(Get-Module -ListAvailable -Name "ITGlueAPI") {Import-module ITGlueAPI} Else { install-module ITGlueAPI -Force; import-module ITGlueAPI}
#Settings IT-Glue logon information
Add-ITGlueBaseURI -base_uri $APIEndpoint
Add-ITGlueAPIKey $APIKEy
add-type -AssemblyName System.Web
#This is the process we'll be perfoming to set the admin account.
$LocalAdminPassword = [System.Web.Security.Membership]::GeneratePassword(24,5)
If($ChangeAdminUsername -eq $false) {
Set-LocalUser -name "Administrator" -Password ($LocalAdminPassword | ConvertTo-SecureString -AsPlainText -Force) -PasswordNeverExpires:$true
} else {
$ExistingNewAdmin = get-localuser | Where-Object {$_.Name -eq $NewAdminUsername}
if(!$ExistingNewAdmin){
write-host "Creating new user" -ForegroundColor Yellow
New-LocalUser -Name $NewAdminUsername -Password ($LocalAdminPassword | ConvertTo-SecureString -AsPlainText -Force) -PasswordNeverExpires:$true
Add-LocalGroupMember -Group Administrators -Member $NewAdminUsername
Disable-LocalUser -Name "Administrator"
}
else{
    write-host "Updating admin password" -ForegroundColor Yellow
   set-localuser -name $NewAdminUsername -Password ($LocalAdminPassword | ConvertTo-SecureString -AsPlainText -Force)
}
}
if($ChangeAdminUsername -eq $false ) { $username = "Administrator" } else { $Username = $NewAdminUsername }
#The script uses the following line to find the correct asset by serialnumber, match it, and connect it if found. Don't want it to tag at all? Comment it out by adding #
$TaggedResource = (Get-ITGlueConfigurations -organization_id $orgID -filter_serial_number (get-ciminstance win32_bios).serialnumber).data | Select-Object -Last 1
$PasswordObjectName = "$($Env:COMPUTERNAME) - Local Administrator Account"
$PasswordObject = @{
    type = 'passwords'
    attributes = @{
            name = $PasswordObjectName
            username = $username
            password = $LocalAdminPassword
            notes = "Local Admin Password for $($Env:COMPUTERNAME)"
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
Write-Host "Creating new Local Administrator Password" -ForegroundColor yellow
$ITGNewPassword = New-ITGluePasswords -organization_id $orgID -data $PasswordObject
} else {
Write-Host "Updating Local Administrator Password" -ForegroundColor Yellow
$ITGNewPassword = Set-ITGluePasswords -id $ExistingPasswordAsset.id -data $PasswordObject
}