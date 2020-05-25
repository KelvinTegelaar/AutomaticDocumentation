###############
$ITGkey = "ITGLUEAPIKEY"
$ITGbaseURI = "https://api.eu.itglue.com"
$FlexAssetName = "Device logbook - Autodoc"
$ITGlueOrgID = "ORGID"
$Description = "A logbook for each device that contains information about the last logged on users, dates of software installation."
$TableStyling = "<th>", "<th style=`"background-color:#4CAF50`">"
##############
 

#Settings IT-Glue logon information
If (Get-Module -ListAvailable -Name "ITGlueAPI") { 
    Import-module ITGlueAPI 
}
Else { 
    Install-Module ITGlueAPI -Force
    Import-Module ITGlueAPI
}
#Settings IT-Glue logon information
Add-ITGlueBaseURI -base_uri $ITGbaseURI
Add-ITGlueAPIKey $ITGkey
 
write-host "Checking if Flexible Asset exists in IT-Glue." -foregroundColor green
$FilterID = (Get-ITGlueFlexibleAssetTypes -filter_name $FlexAssetName).data
if (!$FilterID) { 
    write-host "Does not exist, creating new." -foregroundColor green
    $NewFlexAssetData = 
    @{
        type          = 'flexible-asset-types'
        attributes    = @{
            name        = $FlexAssetName
            icon        = 'sitemap'
            description = $description
        }
        relationships = @{
            "flexible-asset-fields" = @{
                data = @(
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order           = 1
                            name            = "Device Name"
                            kind            = "Text"
                            required        = $true
                            "show-in-list"  = $true
                            "use-for-title" = $true
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 2
                            name           = "Events"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 3
                            name           = "User Profiles"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 4
                            name           = "Installed Updates"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 5
                            name           = "Installed Software"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 6
                            name           = "Device"
                            kind           = "Tag"
                            "tag-type"     = 'Configurations'
                            required       = $false
                            "show-in-list" = $false
                        }
                    }
                )
            }
        }
    }
    New-ITGlueFlexibleAssetTypes -Data $NewFlexAssetData
    $FilterID = (Get-ITGlueFlexibleAssetTypes -filter_name $FlexAssetName).data
}


write-host "Starting documentation process." -foregroundColor green

write-host "Getting update history." -foregroundColor green
$date = Get-Date 
$hotfixesInstalled = get-hotfix

write-host "Getting User Profiles." -foregroundColor green

$UsersProfiles = Get-CimInstance win32_userprofile | Where-Object { $_.special -eq $false } | select-object localpath, LastUseTime, Username
$UsersProfiles = foreach ($Profile in $UsersProfiles) {
    $profile.username = ($profile.localpath -split '\', -1, 'simplematch') | Select-Object -Last 1
    $Profile
}
write-host "Getting Installed applications." -foregroundColor green

$InstalledSoftware = (Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\" | Get-ItemProperty) + ($software += Get-ChildItem "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\" | Get-ItemProperty) | Select-Object Displayname, Publisher, Displayversion, InstallLocation, InstallDate
$installedSoftware = foreach ($Application in $installedSoftware) {
    if ($null -eq $application.InstallLocation) { continue }
    if ($null -eq $Application.InstallDate) { $application.installdate = (get-item $application.InstallLocation -ErrorAction SilentlyContinue).CreationTime.ToString('yyyyMMdd')  }
    $Application.InstallDate = [datetime]::parseexact($Application.InstallDate, 'yyyyMMdd', $null).ToString('yyyy-MM-dd HH:mm') 
    $application
}


write-host "Checking WAN IP" -foregroundColor green
$events = @()
$previousIP = get-content "$($env:ProgramData)/LastIP.txt" -ErrorAction SilentlyContinue | Select-Object -first 1
if (!$previousIP) { Write-Host "No previous IP found. Compare will fail." }
$Currentip = (Invoke-RestMethod -Uri "https://ipinfo.io/ip") -replace "`n", ""
$Currentip | out-file "$($env:ProgramData)/LastIP.txt" -Force

if ($Currentip -ne $previousIP) {
    $Events += [pscustomobject]@{
        date  = $date.ToString('yyyy-MM-dd HH:mm') 
        Event = "WAN IP has changed from $PreviousIP to $CurrentIP"
        type  = "WAN Event"
    }
}
write-host "Getting Installed applications in last 24 hours for events list" -foregroundColor green
$InstalledInLast24Hours = $installedsoftware | where-object { $_.installDate -ge $date.addhours(-24).tostring('yyyy-MM-dd') }
foreach ($installation in $InstalledInLast24Hours) {
    $Events += [pscustomobject]@{
        date  = $installation.InstallDate
        Event = "New Software: $($Installation.displayname) has been installed or updated."
        type  = "Software Event"
    }
}
write-host "Getting KBs in last 24 hours for events list" -foregroundColor green
$hotfixesInstalled = get-hotfix | where-object { $_.InstalledOn -ge $date.adddays(-2) }
foreach ($InstalledHotfix in $hotfixesInstalled) {
    $Events += [pscustomobject]@{
        date  = $InstalledHotfix.installedOn.tostring('yyyy-MM-dd HH:mm') 
        Event = "Update $($InstalledHotfix.Hotfixid) has been installed."
        type  = "Update Event"
    }

}
write-host "Getting user logon/logoff events of last 24 hours." -foregroundColor green
$UserProfilesDir = get-childitem "C:\Users"
foreach ($Users in $UserProfilesDir) {
    if ($users.CreationTime -gt $date.AddDays(-1)) { 
        $Events += [pscustomobject]@{
            date  = $users.CreationTime.tostring('yyyy-MM-dd HH:mm') 
            Event = "First time logon: $($Users.name) has logged on for the first time."
            type  = "User event"
        }
    }
    $NTUser = get-item "$($users.FullName)\NTUser.dat" -force -ErrorAction SilentlyContinue
    if ($NTUser.LastWriteTime -gt $date.AddDays(-1)) {
        $Events += [pscustomobject]@{
            date  = $NTUser.LastWriteTime.tostring('yyyy-MM-dd HH:mm') 
            Event = "Logoff: $($Users.name) has logged off or restarted the computer."
            type  = "User event"
        }
    }
    if ($NTUser.LastAccessTime -gt $date.AddDays(-1)) {
        $Events += [pscustomobject]@{
            date  = $NTUser.LastAccessTime.tostring('yyyy-MM-dd HH:mm') 
            Event = "Logon: $($Users.name) has logged on."
            type  = "User event"
                
        }
    }
}
$events = $events | Sort-Object -Property date -Descending
$TaggedResource = (Get-ITGlueConfigurations -organization_id $ITGlueOrgID -filter_serial_number (get-ciminstance win32_bios).serialnumber).data
$eventshtml = ($Events | convertto-html -fragment | out-string) -replace $TableStyling
$ProfilesHTML = ($UsersProfiles | convertto-html -Fragment | out-string)  -replace $TableStyling
$updatesHTML = ($hotfixesInstalled | select-object InstalledOn, Hotfixid, caption, InstalledBy  | convertto-html -Fragment | out-string) -replace $TableStyling
$SoftwareHTML = ($installedSoftware | convertto-html -Fragment | out-string) -replace $TableStyling

write-host "Uploading to IT-Glue." -foregroundColor green
$FlexAssetBody = @{
    type       = 'flexible-assets'
    attributes = @{
        traits = @{
            'device-name'        = $env:computername
            'events'             = $eventshtml
            'user-profiles'      = $ProfilesHTML
            'installed-updates'  = $UpdatesHTML
            'installed-software' = $SoftwareHTML
            'device'             = $TaggedResource.id
        }
    }
}
write-host "Documenting to IT-Glue"  -ForegroundColor Green
$ExistingFlexAsset = (Get-ITGlueFlexibleAssets -filter_flexible_asset_type_id $($filterID.ID) -filter_organization_id $ITGlueOrgID).data | Where-Object { $_.attributes.traits.'device-name' -eq $env:computername }

#If the Asset does not exist, we edit the body to be in the form of a new asset, if not, we just upload.
if (!$ExistingFlexAsset) {
    $FlexAssetBody.attributes.add('organization-id', $ITGlueOrgID)
    $FlexAssetBody.attributes.add('flexible-asset-type-id', $($filterID.ID))
    write-host "  Creating Device Asset Log into IT-Glue organisation $ITGlueOrgID" -ForegroundColor Green
    New-ITGlueFlexibleAssets -data $FlexAssetBody
}
else {
    write-host "  Editing Device Asset Log into IT-Glue organisation $ITGlueOrgID"  -ForegroundColor Green
    $ExistingFlexAsset = $ExistingFlexAsset | select-object -last 1
    write-host "  Adding previous events from asset to current one."  -ForegroundColor Green
    $CombinedList =  "$($Eventshtml)`n$($ExistingFlexAsset.attributes.traits.events)" -split "`n" | Select-Object -Unique | Out-String
    $FlexAssetBody.attributes.traits.events = $CombinedList
    Set-ITGlueFlexibleAssets -id $ExistingFlexAsset.id -data $FlexAssetBody
}
 
