###############
$UnifiBaseUri = "https://Controller.com:8443/api"
$UnifiUser = "APIUSER"
$UnifiPassword = "APIUSER"
##############
 
$TableStyling = "<th>", "<th style=`"background-color:#4CAF50`">"
 
$UniFiCredentials = @{
    username = $UnifiUser
    password = $UnifiPassword
    remember = $true
} | ConvertTo-Json
  
$UnifiCredentials
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
    $head = @"
    <script>
    function myFunction() {
        const filter = document.querySelector('#myInput').value.toUpperCase();
        const trs = document.querySelectorAll('table tr:not(.header)');
        trs.forEach(tr => tr.style.display = [...tr.children].find(td => td.innerHTML.toUpperCase().includes(filter)) ? '' : 'none');
      }</script>
    <Title>Audit Log Report</Title>
    <style>
    body { background-color:#E5E4E2;
          font-family:Monospace;
          font-size:10pt; }
    td, th { border:0px solid black; 
            border-collapse:collapse;
            white-space:pre; }
    th { color:white;
        background-color:black; }
    table, tr, td, th {
         padding: 2px; 
         margin: 0px;
         white-space:pre; }
    tr:nth-child(odd) {background-color: lightgray}
    table { width:95%;margin-left:5px; margin-bottom:20px; }
    h2 {
    font-family:Tahoma;
    color:#6D7B8D;
    }
    .footer 
    { color:green; 
     margin-left:10px; 
     font-family:Tahoma;
     font-size:8pt;
     font-style:italic;
    }
    #myInput {
      background-image: url('https://www.w3schools.com/css/searchicon.png'); /* Add a search icon to input */
      background-position: 10px 12px; /* Position the search icon */
      background-repeat: no-repeat; /* Do not repeat the icon image */
      width: 50%; /* Full-width */
      font-size: 16px; /* Increase font-size */
      padding: 12px 20px 12px 40px; /* Add some padding */
      border: 1px solid #ddd; /* Add a grey border */
      margin-bottom: 12px; /* Add some space below the input */
    }
    </style>
"@
    $WANs = ($networkinfo | where-object { $_.Purpose -eq "wan" } | select-object Name, *WAN* | convertto-html -frag -PreContent "<h1>WANS</h2>" | out-string) -replace $tablestyling
    $LANS = ($networkinfo | where-object { $_.Purpose -eq "corporate" } | select-object Name, *LAN* | convertto-html -frag -PreContent "<h1>LANs</h2>" | out-string) -replace $tablestyling
    $VPNs = ($networkinfo | where-object { $_.Purpose -eq "site-vpn" } | select-object Name, *VPN* | convertto-html -frag -PreContent "<h1>VPNs</h2>" | out-string) -replace $tablestyling
    $Wifi = ($wifi | convertto-html -frag -PreContent "<h1>Wi-Fi</h2>" | out-string) -replace $tablestyling
    $PortForwards = ($Portforward | convertto-html -frag -PreContent "<h1>Port Forwards</h2>" | out-string) -replace $tablestyling
     
$head,$WANs,$LANS,$VPNs,$wifi,$PortForwards,$SwitchPorts | out-file "C:\Temp\$($site.desc).html"
}