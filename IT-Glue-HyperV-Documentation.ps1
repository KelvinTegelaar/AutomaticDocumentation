########################## IT-Glue ############################
$APIKEy = "ITGLUEAPIKEY"
$APIEndpoint = "https://api.eu.itglue.com"
$FlexAssetName = "Hyper-v AutoDoc v2"
$OrgID = "YOURORGID"
$Description = "A network one-page document that displays the current Hyper-V Settings and virtual machines"
#some layout options, change if you want colours to be different or do not like the whitespace.
$TableHeader = "<table class=`"table table-bordered table-hover`" style=`"width:80%`">"
$Whitespace = "<br/>"
$TableStyling = "<th>", "<th style=`"background-color:#4CAF50`">"
########################## IT-Glue ############################
#Grabbing ITGlue Module and installing.
If (Get-Module -ListAvailable -Name "ITGlueAPI") { 
    Import-module ITGlueAPI 
}
Else { 
    Install-Module ITGlueAPI -Force
    Import-Module ITGlueAPI
}
#Settings IT-Glue logon information
Add-ITGlueBaseURI -base_uri $APIEndpoint
Add-ITGlueAPIKey $APIKEy
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
                            name            = "Host name"
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
                            name           = "Virtual Machines"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 3
                            name           = "Network Settings"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 4
                            name           = "Replication Settings"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 5
                            name           = "Host Settings"
                            kind           = "Textbox"
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
 
write-host "Start documentation process." -foregroundColor green
 
$VirtualMachines = get-vm | select-object VMName, Generation, Path, Automatic*, @{n = "Minimum(gb)"; e = { $_.memoryminimum / 1gb } }, @{n = "Maximum(gb)"; e = { $_.memorymaximum / 1gb } }, @{n = "Startup(gb)"; e = { $_.memorystartup / 1gb } }, @{n = "Currently Assigned(gb)"; e = { $_.memoryassigned / 1gb } }, ProcessorCount | ConvertTo-Html -Fragment | Out-String
$VirtualMachines = $TableHeader + ($VirtualMachines -replace $TableStyling) + $Whitespace
$NetworkSwitches = Get-VMSwitch | select-object name, switchtype, NetAdapterInterfaceDescription, AllowManagementOS | convertto-html -Fragment -PreContent "<h3>Network Switches</h3>" | Out-String
$VMNetworkSettings = Get-VMNetworkAdapter * | Select-Object Name, IsManagementOs, VMName, SwitchName, MacAddress, @{Name = 'IP'; Expression = { $_.IPaddresses -join "," } } | ConvertTo-Html -Fragment -PreContent "<br><h3>VM Network Settings</h3>" | Out-String
$NetworkSettings = $TableHeader + ($NetworkSwitches -replace $TableStyling) + ($VMNetworkSettings -replace $TableStyling) + $Whitespace
$ReplicationSettings = get-vmreplication | Select-Object VMName, State, Mode, FrequencySec, PrimaryServer, ReplicaServer, ReplicaPort, AuthType | convertto-html -Fragment | Out-String
$ReplicationSettings = $TableHeader + ($ReplicationSettings -replace $TableStyling) + $Whitespace
$HostSettings = get-vmhost | Select-Object  Computername, LogicalProcessorCount, iovSupport, EnableEnhancedSessionMode,MacAddressMinimum, *max*, NumaspanningEnabled, VirtualHardDiskPath, VirtualMachinePath, UseAnyNetworkForMigration, VirtualMachineMigrationEnabled | convertto-html -Fragment -as List | Out-String
 
$FlexAssetBody =
@{
    type       = 'flexible-assets'
    attributes = @{
        traits = @{
            'host-name'            = $env:COMPUTERNAME
            'virtual-machines'     = $VirtualMachines
            'network-settings'     = $NetworkSettings
            'replication-settings' = $ReplicationSettings
            'host-settings'        = $HostSettings
        }
    }
}
 
write-host "Documenting to IT-Glue"  -ForegroundColor Green
$ExistingFlexAsset = (Get-ITGlueFlexibleAssets -filter_flexible_asset_type_id $($filterID.ID) -filter_organization_id $OrgID).data | Where-Object { $_.attributes.traits.'host-name' -eq $ENV:computername }
#If the Asset does not exist, we edit the body to be in the form of a new asset, if not, we just upload.
if (!$ExistingFlexAsset) {
    $FlexAssetBody.attributes.add('organization-id', $OrgID)
    $FlexAssetBody.attributes.add('flexible-asset-type-id', $($filterID.ID))
    write-host "  Creating Hyper-v into IT-Glue organisation $OrgID" -ForegroundColor Green
    New-ITGlueFlexibleAssets -data $FlexAssetBody
}
else {
    write-host "  Editing Hyper-v into IT-Glue organisation $OrgID"  -ForegroundColor Green
    $ExistingFlexAsset = $ExistingFlexAsset[-1]
    Set-ITGlueFlexibleAssets -id $ExistingFlexAsset.id -data $FlexAssetBody
}