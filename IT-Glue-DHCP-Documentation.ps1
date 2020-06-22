###############
$ITGkey = "YOURIGLUEKEY"
$ITGbaseURI = "https://api.eu.itglue.com"
$FlexAssetName = "DHCP Server - Autodoc"
$ITGlueOrgID = "ITGLUEORGID"
$Description = "A logbook for DHCP server witha ll information about scopes, superscopes, etc.."
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
                            name            = "DHCP Server Name"
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
                            name           = "DHCP Server Settings"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 3
                            name           = "DHCP Server Database Information"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 4
                            name           = "DHCP Domain Authorisation"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 5
                            name           = "DHCP Scopes"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 6
                            name           = "DHCP Scope Information"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 7
                            name           = "DHCP Statistics"
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

write-host "Starting documentation process." -foregroundColor green


$DCHPServerSettings = Get-DhcpServerSetting | select-object ActivatePolicies, ConflictDetectionAttempts, DynamicBootp, IsAuthorized, IsDomainJoined, NapEnabled, NpsUnreachableAction, RestoreStatus | ConvertTo-Html -Fragment -PreContent "<h1>DHCP Server Settings</h1>" | Out-String
$databaseinfo = Get-DhcpServerDatabase | Select-Object BackupInterval, BackupPath, CleanupInterval, FileName, LoggingEnabled, RestoreFromBackup | ConvertTo-Html -Fragment -PreContent "<h1>DHCP Database information</h1>" | Out-String
$DHCPDCAuth = Get-DhcpServerInDC | select-object IPAddress, DnsName  | ConvertTo-Html -Fragment -PreContent "<h1>DHCP Domain Controller Authorisations</h1>" | Out-String
$Scopes = Get-DhcpServerv4Scope
$ScopesAvailable = $Scopes | Select-Object ScopeId, SubnetMask, StartRange, EndRange, ActivatePolicies, Delay, Description, LeaseDuration, MaxBootpClients, Name, NapEnable, NapProfile, State, SuperscopeName, Type | ConvertTo-Html -Fragment -PreContent "<h1>DHCP Server scopes</h1>" | Out-String
$ScopeInfo = foreach ($Scope in $scopes) {
    $scope | Get-DhcpServerv4Lease | select-object ScopeId, IPAddress, AddressState, ClientId, ClientType, Description, DnsRegistration, DnsRR, HostName, LeaseExpiryTime |  ConvertTo-Html -Fragment -PreContent "<h1>Scope Information: $($Scope.name) - $($scope.ScopeID) </h1>" | Out-String
}

$DHCPServerStats = Get-DhcpServerv4Statistics | Select-Object InUse, Available, Acks, AddressesAvailable, AddressesInUse, Declines, DelayedOffers, Discovers, Naks, Offers, PendingOffers, PercentageAvailable, PercentageInUse, PercentagePendingOffers, Releases, Requests, ScopesWithDelayConfigured, ServerStartTime, TotalAddresses, TotalScope | ConvertTo-Html -Fragment -PreContent "<h1>DHCP Server statistics</h1>" -As List | Out-String


write-host "Uploading to IT-Glue." -foregroundColor green
$FlexAssetBody = @{
    type       = 'flexible-assets'
    attributes = @{
        traits = @{
            'dhcp-server-name'                 = $env:computername
            'dhcp-server-settings'             = $DCHPServerSettings
            'dhcp-server-database-information' = $databaseinfo
            'dhcp-domain-authorisation'        = $DHCPDCAuth
            'dhcp-scopes'                      = $ScopesAvailable
            'dhcp-scope-information'           = $ScopeInfo
            'dhcp-statistics'                  = $DHCPServerStats
        }
    }
}
write-host "Documenting to IT-Glue"  -ForegroundColor Green
$ExistingFlexAsset = (Get-ITGlueFlexibleAssets -filter_flexible_asset_type_id $($filterID.ID) -filter_organization_id $ITGlueOrgID).data | Where-Object { $_.attributes.traits.'dhcp-server-name' -eq $env:computername }

#If the Asset does not exist, we edit the body to be in the form of a new asset, if not, we just upload.
if (!$ExistingFlexAsset) {
    $FlexAssetBody.attributes.add('organization-id', $ITGlueOrgID)
    $FlexAssetBody.attributes.add('flexible-asset-type-id', $($filterID.ID))
    write-host "  Creating DHCP Server Log into IT-Glue organisation $ITGlueOrgID" -ForegroundColor Green
    New-ITGlueFlexibleAssets -data $FlexAssetBody
}
else {
    write-host "  Editing DHCP Server Log into IT-Glue organisation $ITGlueOrgID"  -ForegroundColor Green
    $ExistingFlexAsset = $ExistingFlexAsset | select-object -last 1
    Set-ITGlueFlexibleAssets -id $ExistingFlexAsset.id -data $FlexAssetBody
}
 
