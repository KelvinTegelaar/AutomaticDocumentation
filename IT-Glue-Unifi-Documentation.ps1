###############
$ITGkey = "ITGAPIKey"
$ITGbaseURI = "https://api.eu.itglue.com"
$UnifiBaseUri = "https://YourController.com:8443/api"
$UnifiUser = "APIUSER"
$UnifiPassword = "APIPAssword"
$FlexAssetName = "Unifi Controller Autodoc"
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
                            name            = "Site Name"
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
                            name           = "WAN"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 3
                            name           = "LAN"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 4
                            name           = "VPN"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 5
                            name           = "Wi-Fi"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },  
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 6
                            name           = "Port Forwards"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    }, @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 7
                            name           = "Switches"
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
    $UnifiSwitches = $unifiDevices.data | Where-Object { $_.type -contains "usw" }
    $SwitchPorts = foreach ($unifiswitch in $UnifiSwitches) {
        "<h2>$($unifiswitch.name) - $($unifiswitch.mac)</h2> <table><tr>"
        foreach ($Port in $unifiswitch.port_table) {
            "<th>$($port.port_idx)</th>"
        }
        "</tr><tr>"
        foreach ($Port in $unifiswitch.port_table) {
            $colour = if ($port.up -eq $true) { '02ab26' } else { 'ad2323' }
            $speed = switch ($port.speed) {
                10000 { "10Gb" }
                1000 { "1Gb" }
                100 { "100Mb" }
                10 { "10Mb" }
                0 { "Port off" }
            }
            "<td style='background-color:#$($colour)'>$speed</td>"
        }
        '</tr><tr>'
        foreach ($Port in $unifiswitch.port_table) {
            $poestate = if ($port.poe_enable -eq $true) { 'PoE on'; $colour = '02ab26' } elseif ($port.port_poe -eq $false) { 'No PoE'; $colour = '#696363' } else { "PoE Off"; $colour = 'ad2323' }
            "<td style='background-color:#$($colour)'>$Poestate</td >"
        }
        '</tr></table>'
    }
 
    $uaps = $unifiDevices.data | Where-Object { $_.type -contains "uap" }
 
    $Wifinetworks = $uaps.vap_table | Group-Object Essid
    $wifi = foreach ($Wifinetwork in $Wifinetworks) {
        $Wifinetwork | Select-object @{n = "SSID"; e = { $_.Name } }, @{n = "Access Points"; e = { $uaps.name -join "`n" } }, @{n = "Channel"; e = { $_.group.channel -join ", " } }, @{n = "Usage"; e = { $_.group.usage | Sort-Object -Unique } }, @{n = "Enabled"; e = { $_.group.up | sort-object -Unique } }
    } 
      
    $alarms = (Invoke-RestMethod -Uri "$UnifiBaseUri/s/$($site.name)/stat/alarm" -WebSession $websession).data
    $alarms = $alarms | Select-Object @{n = "Universal Time"; e = { [datetime]$_.datetime } }, @{n = "Device Name"; e = { $_.$(($_ | Get-Member | Where-Object { $_.Name -match "_name" }).name) } }, @{n = "Message"; e = { $_.msg } } -First 10
 
    $portforward = (Invoke-RestMethod -Uri "$UnifiBaseUri/s/$($site.name)/rest/portforward" -WebSession $websession).data
    $portForward = $portforward | Select-Object Name, @{n = "Source"; e = { "$($_.src):$($_.dst_port)" } }, @{n = "Destination"; e = { "$($_.fwd):$($_.fwd_port)" } }, @{n = "Protocol"; e = { $_.proto } }
 
  
    $networkConf = (Invoke-RestMethod -Uri "$UnifiBaseUri/s/$($site.name)/rest/networkconf" -WebSession $websession).data
  
    $NetworkInfo = foreach ($network in $networkConf) {
        [pscustomobject] @{
            'Purpose'                 = $network.purpose
            'Name'                    = $network.name
            'vlan'                    = "$($network.vlan_enabled) $($network.vlan)"
            "LAN IP Subnet"           = $network.ip_subnet                 
            "LAN DHCP Relay Enabled"  = $network.dhcp_relay_enabled        
            "LAN DHCP Enabled"        = $network.dhcpd_enabled
            "LAN Network Group"       = $network.networkgroup              
            "LAN Domain Name"         = $network.domain_name               
            "LAN DHCP Lease Time"     = $network.dhcpd_leasetime           
            "LAN DNS 1"               = $network.dhcpd_dns_1               
            "LAN DNS 2"               = $network.dhcpd_dns_2               
            "LAN DNS 3"               = $network.dhcpd_dns_3               
            "LAN DNS 4"               = $network.dhcpd_dns_4                           
            'DHCP Range'              = "$($network.dhcpd_start) - $($network.dhcpd_stop)"
            "WAN IP Type"             = $network.wan_type 
            'WAN IP'                  = $network.wan_ip 
            "WAN Subnet"              = $network.wan_netmask
            'WAN Gateway'             = $network.wan_gateway 
            "WAN DNS 1"               = $network.wan_dns1 
            "WAN DNS 2"               = $network.wan_dns2 
            "WAN Failover Type"       = $network.wan_load_balance_type
            'VPN Ike Version'         = $network.ipsec_key_exchange
            'VPN Encryption protocol' = $network.ipsec_encryption
            'VPN Hashing protocol'    = $network.ipsec_hash
            'VPN DH Group'            = $network.ipsec_dh_group
            'VPN PFS Enabled'         = $network.ipsec_pfs
            'VPN Dynamic Routing'     = $network.ipsec_dynamic_routing
            'VPN Local IP'            = $network.ipsec_local_ip
            'VPN Peer IP'             = $network.ipsec_peer_ip
            'VPN IPSEC Key'           = $network.x_ipsec_pre_shared_key
        }
 
    }
 
    $WANs = ($networkinfo | where-object { $_.Purpose -eq "wan" } | select-object Name, *WAN* | convertto-html -frag | out-string) -replace $tablestyling
    $LANS = ($networkinfo | where-object { $_.Purpose -eq "corporate" } | select-object Name, *LAN* | convertto-html -frag | out-string) -replace $tablestyling
    $VPNs = ($networkinfo | where-object { $_.Purpose -eq "site-vpn" } | select-object Name, *VPN* | convertto-html -frag | out-string) -replace $tablestyling
    $Wifi = ($wifi | convertto-html -frag | out-string) -replace $tablestyling
    $PortForwards = ($Portforward | convertto-html -frag | out-string) -replace $tablestyling
 
    $FlexAssetBody = @{
        type       = 'flexible-assets'
        attributes = @{
            traits = @{
                'site-name'     = $site.name
                'wan'           = $WANs
                'lan'           = $LANS
                'vpn'           = $VPNs
                'wi-fi'          = $wifi
                'port-forwards' = $PortForwards
                'switches'      = ($SwitchPorts | out-string)
            }
        }
    }
    write-host "Documenting to IT-Glue"  -ForegroundColor Green
    $ExistingFlexAsset = (Get-ITGlueFlexibleAssets -filter_flexible_asset_type_id $($filterID.ID) -filter_organization_id $ITGlueOrgID).data | Where-Object { $_.attributes.traits.'site-name' -eq $site.name }
    #If the Asset does not exist, we edit the body to be in the form of a new asset, if not, we just upload.
    if (!$ExistingFlexAsset) {
        $FlexAssetBody.attributes.add('organization-id', $ITGlueOrgID)
        $FlexAssetBody.attributes.add('flexible-asset-type-id', $($filterID.ID))
        write-host "  Creating Unifi into IT-Glue organisation $ITGlueOrgID" -ForegroundColor Green
        New-ITGlueFlexibleAssets -data $FlexAssetBody
    }
    else {
        write-host "  Editing Unifi into IT-Glue organisation $ITGlueOrgID"  -ForegroundColor Green
        $ExistingFlexAsset = $ExistingFlexAsset[-1]
        Set-ITGlueFlexibleAssets -id $ExistingFlexAsset.id -data $FlexAssetBody
    }
 
}