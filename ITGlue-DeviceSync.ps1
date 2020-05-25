###############
$ITGkey = "ITGKEU"
$ITGbaseURI = "https://api.eu.itglue.com"
$UnifiBaseUri = "https://YourController:8443/api"
$UnifiUser = "APIUSER"
$UnifiPassword = "APIPASSWORD"
$FlexAssetName = "Unifi - Sites"
$Description = "A network one-page document that displays the unifi status."
##############

$TableStyling = "<th>", "<th style=`"background-color:#4CAF50`">"
#Settings IT-Glue logon information
If (Get-Module -ListAvailable -Name "ITGlueAPI") { 
    Import-module ITGlueAPI 
}
Else { 
    Install-Module ITGlueAPI -Force
    Import-Module ITGlueAPI
}
Add-ITGlueBaseURI -base_uri $ITGbaseURI
Add-ITGlueAPIKey $ITGkey
write-host "Checking if products exist in IT-Glue, and if not creating them."
$unifiAllModels = @"
[{"c":"BZ2","t":"uap","n":"UniFi AP"},{"c":"BZ2LR","t":"uap","n":"UniFi AP-LR"},{"c":"U2HSR","t":"uap","n":"UniFi AP-Outdoor+"},
{"c":"U2IW","t":"uap","n":"UniFi AP-In Wall"},{"c":"U2L48","t":"uap","n":"UniFi AP-LR"},{"c":"U2Lv2","t":"uap","n":"UniFi AP-LR v2"},
{"c":"U2M","t":"uap","n":"UniFi AP-Mini"},{"c":"U2O","t":"uap","n":"UniFi AP-Outdoor"},{"c":"U2S48","t":"uap","n":"UniFi AP"},
{"c":"U2Sv2","t":"uap","n":"UniFi AP v2"},{"c":"U5O","t":"uap","n":"UniFi AP-Outdoor 5G"},{"c":"U7E","t":"uap","n":"UniFi AP-AC"},
{"c":"U7EDU","t":"uap","n":"UniFi AP-AC-EDU"},{"c":"U7Ev2","t":"uap","n":"UniFi AP-AC v2"},{"c":"U7HD","t":"uap","n":"UniFi AP-HD"},
{"c":"U7SHD","t":"uap","n":"UniFi AP-SHD"},{"c":"U7NHD","t":"uap","n":"UniFi AP-nanoHD"},{"c":"UCXG","t":"uap","n":"UniFi AP-XG"},
{"c":"UXSDM","t":"uap","n":"UniFi AP-BaseStationXG"},{"c":"UCMSH","t":"uap","n":"UniFi AP-MeshXG"},{"c":"U7IW","t":"uap","n":"UniFi AP-AC-In Wall"},
{"c":"U7IWP","t":"uap","n":"UniFi AP-AC-In Wall Pro"},{"c":"U7MP","t":"uap","n":"UniFi AP-AC-Mesh-Pro"},{"c":"U7LR","t":"uap","n":"UniFi AP-AC-LR"},
{"c":"U7LT","t":"uap","n":"UniFi AP-AC-Lite"},{"c":"U7O","t":"uap","n":"UniFi AP-AC Outdoor"},{"c":"U7P","t":"uap","n":"UniFi AP-Pro"},
{"c":"U7MSH","t":"uap","n":"UniFi AP-AC-Mesh"},{"c":"U7PG2","t":"uap","n":"UniFi AP-AC-Pro"},{"c":"p2N","t":"uap","n":"PicoStation M2"},
{"c":"US8","t":"usw","n":"UniFi Switch 8"},{"c":"US8P60","t":"usw","n":"UniFi Switch 8 POE-60W"},{"c":"US8P150","t":"usw","n":"UniFi Switch 8 POE-150W"},
{"c":"S28150","t":"usw","n":"UniFi Switch 8 AT-150W"},{"c":"USC8","t":"usw","n":"UniFi Switch 8"},{"c":"US16P150","t":"usw","n":"UniFi Switch 16 POE-150W"},
{"c":"S216150","t":"usw","n":"UniFi Switch 16 AT-150W"},{"c":"US24","t":"usw","n":"UniFi Switch 24"},{"c":"US24P250","t":"usw","n":"UniFi Switch 24 POE-250W"},
{"c":"US24PL2","t":"usw","n":"UniFi Switch 24 L2 POE"},{"c":"US24P500","t":"usw","n":"UniFi Switch 24 POE-500W"},{"c":"S224250","t":"usw","n":"UniFi Switch 24 AT-250W"},
{"c":"S224500","t":"usw","n":"UniFi Switch 24 AT-500W"},{"c":"US48","t":"usw","n":"UniFi Switch 48"},{"c":"US48P500","t":"usw","n":"UniFi Switch 48 POE-500W"},
{"c":"US48PL2","t":"usw","n":"UniFi Switch 48 L2 POE"},{"c":"US48P750","t":"usw","n":"UniFi Switch 48 POE-750W"},{"c":"S248500","t":"usw","n":"UniFi Switch 48 AT-500W"},
{"c":"S248750","t":"usw","n":"UniFi Switch 48 AT-750W"},{"c":"US6XG150","t":"usw","n":"UniFi Switch 6XG POE-150W"},{"c":"USXG","t":"usw","n":"UniFi Switch 16XG"},
{"c":"UGW3","t":"ugw","n":"UniFi Security Gateway 3P"},{"c":"UGW4","t":"ugw","n":"UniFi Security Gateway 4P"},{"c":"UGWHD4","t":"ugw","n":"UniFi Security Gateway HD"},
{"c":"UGWXG","t":"ugw","n":"UniFi Security Gateway XG-8"},{"c":"UP4","t":"uph","n":"UniFi Phone-X"},{"c":"UP5","t":"uph","n":"UniFi Phone"},
{"c":"UP5t","t":"uph","n":"UniFi Phone-Pro"},{"c":"UP7","t":"uph","n":"UniFi Phone-Executive"},{"c":"UP5c","t":"uph","n":"UniFi Phone"},
{"c":"UP5tc","t":"uph","n":"UniFi Phone-Pro"},{"c":"UP7c","t":"uph","n":"UniFi Phone-Executive"}]
"@
 
$configTypes = @"
[{"t":"uap","n":"Unifi AP"},{"t":"usw","n":"Unifi Switch"},{"t":"ugw","n":"Unifi Gateway"},{"t":"uph","n":"Unifi VOIP"}]
"@ | ConvertFrom-Json

$unifiAllModels = $unifiAllModels | ConvertFrom-Json
$unifiModels = $unifiAllModels | Sort-Object n -Unique
$ITGConfigTypes = (Get-ITGlueConfigurationTypes).data
write-host "Check Config Types and creating if required" -ForegroundColor Green
foreach ($ConfType in $configTypes) {
    if ($ConfType.n -notin $ITGConfigTypes.attributes.name) {
        write-host "Creating $($Model.n)" -ForegroundColor Green
        New-ITGlueConfigurationTypes -data @{
            type       = 'configuration-types'
            attributes = @{
                name = $ConfType.n
            }
        }

    }
}
$ExistingModels = (Get-ITGlueModels -page_size 1000).data
write-host "Checkings manufacture and creating if required" -ForegroundColor Green
$Manafacture = (Get-ITGlueManufacturers -filter_name "UniFi").data
if (!$Manafacture) {
    New-ITGlueManufacturers -data @{
        type       = 'manufacturers'
        attributes = @{
            name = 'uniFi-2'
        }
    }
    $Manafacture = (Get-ITGlueManufacturers -filter_name "UniFi").data
}
write-host "Grabbing active status"
$ConfigurationStatusId = (Get-ITGlueConfigurationStatuses -filter_name 'Active').data.ID | Select-Object -Last 1
write-host "Checkings models and creating if required" -ForegroundColor Green
foreach ($Model in $unifiAllModels) {
    if ($model.n -notin $ExistingModels.attributes.name) {
        write-host "Creating $($Model.n)" -ForegroundColor Green
        New-ITGlueModels -data @{
            type       = 'models'
            attributes = @{
                'manufacturer-id' = $Manafacture.id
                name              = $model.n
            }
        }

    }
}

write-host "Start configuration syncing process." -foregroundColor green


$UniFiCredentials = @{
    username = $UnifiUser
    password = $UnifiPassword
    remember = $true
} | ConvertTo-Json

write-host "Logging in to Unifi API." -ForegroundColor Green
try {
    Invoke-RestMethod -Uri "$UnifiBaseUri/login" -Method POST -Body $uniFiCredentials -SessionVariable websession
}
catch {
    write-host "Failed to log in on the Unifi API. Error was: $($_.Exception.Message)" -ForegroundColor Red
}
write-host "Collecting sites from Unifi API." -ForegroundColor Green
try {
    $sites = (Invoke-RestMethod -Uri "$UnifiBaseUri/self/sites" -WebSession $websession).data
}
catch {
    write-host "Failed to collect the sites. Error was: $($_.Exception.Message)" -ForegroundColor Red
}

foreach ($site in $sites) {
    $ITGlueOrgID = $site.desc.split('()')[1]
    if (!$ITGlueOrgID) {
        write-host "Could not get IT-Glue OrgID for site $($site.desc). Moving on to next site." -ForegroundColor Yellow
        continue
    }
    else {
        write-host "Documenting $($site.desc), using ITGlue ID: $ITGlueOrgID" -ForegroundColor Green
    }

    $unifiDevices = Invoke-RestMethod -Uri "$UnifiBaseUri/s/$($site.name)/stat/device" -WebSession $websession
    foreach ($device in $unifiDevices.data) {
        $ExistingConfiguration = Get-ITGlueConfigurations -organization_id $ITGlueOrgID -filter_serial_number $device.serial
        $DeviceName = if (!$device.name) { "Unifi Device $($device.serial)" } else { $device.name }
        $ModelName = ($unifiAllModels | Where-Object {$_.c -eq $device.model}).n
        $modelid = $ExistingModels | Where-Object {$_.attributes.name -eq $ModelName} | Select-Object -last 1
        $ConfigName = ($configtypes | Where-Object {$_.t -eq $device.type }).n
        $Configurationtypeid = ($ITGConfigTypes | Where-Object {$_.attributes.name -eq $Configname}).id
        $ConfigurationBody = @{
                type       = "configurations"
                attributes = @{
                    "organization-id"         = $ITGlueOrgID
                    "name"                    = $DeviceName
                    "configuration-type-id"   = $Configurationtypeid
                    "configuration-status-id" = $ConfigurationStatusId
                    "manufacturer-id"         = $Manafacture.id
                    "model-id"                = $ModelID.id
                    "primary-ip"              = $device.ip
                    "serial-number"           = $device.serial
                    "mac-address"             = $device.mac
                }
        }
        if (!$ExistingConfiguration) { 
            write-host "Creating new device" -ForegroundColor Green
            New-ITGlueConfigurations -organization_id $ITGlueOrgID -data $ConfigurationBody
        } 
        else {
            write-host "Editing previous existing device" -ForegroundColor Green
            Set-ITGlueConfigurations -id ($ExistingConfiguration.data.id | Select-Object -last 1) -data $ConfigurationBody

        }
    }


}
