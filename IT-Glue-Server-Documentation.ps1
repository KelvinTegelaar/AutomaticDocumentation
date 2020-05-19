#####################################################################
$APIKEy =  "YOUR API KEY GOES HERE"
$APIEndpoint = "https://api.eu.itglue.com"
$orgID = "THE ORGANISATIONID YOU WOULD LIKE TO UPDATE GOES HERE"
$FlexAssetName = "ITGLue AutoDoc - Server Overview"
$Description = "a server one-page document that shows the current configuration"
#####################################################################
#This is the object we'll be sending to IT-Glue. 
$ComputerSystemInfo = Get-CimInstance -ClassName Win32_ComputerSystem
if($ComputerSystemInfo.model -match "Virtual" -or $ComputerSystemInfo.model -match "VMware") { $MachineType = "Virtual"} Else { $MachineType = "Physical"}
$networkName = Get-CimInstance -ClassName Win32_NetworkAdapter | Where-Object {$_.PhysicalAdapter -eq "True"} | Sort Index
$networkIP = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration | Where-Object {$_.MACAddress -gt 0} | Sort Index
$networkSummary = New-Object -TypeName 'System.Collections.ArrayList'

foreach($nic in $networkName) {
    $nic_conf = $networkIP | Where-Object {$_.Index -eq $nic.Index}
 
    $networkDetails = New-Object PSObject -Property @{
        Index                = [int]$nic.Index;
        AdapterName         = [string]$nic.NetConnectionID;
        Manufacturer         = [string]$nic.Manufacturer;
        Description          = [string]$nic.Description;
        MACAddress           = [string]$nic.MACAddress;
        IPEnabled            = [bool]$nic_conf.IPEnabled;
        IPAddress            = [string]$nic_conf.IPAddress;
        IPSubnet             = [string]$nic_conf.IPSubnet;
        DefaultGateway       = [string]$nic_conf.DefaultIPGateway;
        DHCPEnabled          = [string]$nic_conf.DHCPEnabled;
        DHCPServer           = [string]$nic_conf.DHCPServer;
        DNSServerSearchOrder = [string]$nic_conf.DNSServerSearchOrder;
    }
    $networkSummary += $networkDetails
}
$NicRawConf = $networkSummary | select AdapterName,IPaddress,IPSubnet,DefaultGateway,DNSServerSearchOrder,MACAddress | Convertto-html -Fragment | select -Skip 1
$NicConf = "<br/><table class=`"table table-bordered table-hover`" >" + $NicRawConf

$RAM = (systeminfo | Select-String 'Total Physical Memory:').ToString().Split(':')[1].Trim()

$ApplicationsFrag = Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Select-Object DisplayName, DisplayVersion, Publisher, InstallDate | Convertto-html -Fragment | select -skip 1
$ApplicationsTable = "<br/><table class=`"table table-bordered table-hover`" >" + $ApplicationsFrag

$RolesFrag = Get-WindowsFeature | Where-Object {$_.Installed -eq $True} | Select-Object displayname,name  | convertto-html -Fragment | Select-Object -Skip 1
$RolesTable = "<br/><table class=`"table table-bordered table-hover`" >" + $RolesFrag

if($machineType -eq "Physical" -and $ComputerSystemInfo.Manufacturer -match "Dell"){
$DiskLayoutRaw = omreport storage pdisk controller=0 -fmt cdv
$DiskLayoutSemi = $DiskLayoutRaw |  select-string -SimpleMatch "ID,Status," -context 0,($DiskLayoutRaw).Length | convertfrom-csv -Delimiter "," | select Name,Status,Capacity,State,"Bus Protocol","Product ID","Serial No.","Part Number",Media | convertto-html -Fragment
$DiskLayoutTable = "<br/><table class=`"table table-bordered table-hover`" >" + $DiskLayoutsemi

#Try to get RAID layout
$RAIDLayoutRaw = omreport storage vdisk controller=0 -fmt cdv
$RAIDLayoutSemi = $RAIDLayoutRaw |  select-string -SimpleMatch "ID,Status," -context 0,($RAIDLayoutRaw).Length | convertfrom-csv -Delimiter "," | select Name,Status,State,Layout,"Device Name","Read Policy","Write Policy",Media |  convertto-html -Fragment
$RAIDLayoutTable = "<br/><table class=`"table table-bordered table-hover`" >" + $RAIDLayoutsemi
}else {
    $RAIDLayoutTable = "Could not get physical disk info"
    $DiskLayoutTable = "Could not get physical disk info"
}

$HTMLFile = @"
<b>Servername</b>: $ENV:COMPUTERNAME <br>
<b>Server Type</b>: $machineType <br>
<b>Amount of RAM</b>: $RAM <br>
<br>
<h1>NIC Configuration</h1> <br>
$NicConf
<br>
<h1>Installed Applications</h1> <br>
$ApplicationsTable
<br>
<h1>Installed Roles</h1> <br>
$RolesTable
<br>
<h1>Physical Disk information</h1>
$DiskLayoutTable
<h1>RAID information</h1>
$RAIDLayoutTable
"@



$FlexAssetBody = 
@{
    type = 'flexible-assets'
    attributes = @{
            name = $FlexAssetName
            traits = @{
                "name" = $ENV:COMPUTERNAME
                "information" = $HTMLFile
            }
    }
}

#ITGlue upload starts here.
If(Get-Module -ListAvailable -Name "ITGlueAPI") {Import-module ITGlueAPI} Else { install-module ITGlueAPI -Force; import-module ITGlueAPI}
#Settings IT-Glue logon information
Add-ITGlueBaseURI -base_uri $APIEndpoint
Add-ITGlueAPIKey $APIKEy
#Checking if the FlexibleAsset exists. If not, create a new one.
$FilterID = (Get-ITGlueFlexibleAssetTypes -filter_name $FlexAssetName).data
if(!$FilterID){ 
    $NewFlexAssetData = 
    @{
        type = 'flexible-asset-types'
        attributes = @{
                name = $FlexAssetName
                icon = 'sitemap'
                description = $description
        }
        relationships = @{
            "flexible-asset-fields" = @{
                data = @(
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order           = 1
                            name            = "name"
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
                            name           = "information"
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

#Upload data to IT-Glue. We try to match the Server name to current computer name.
$ExistingFlexAsset = (Get-ITGlueFlexibleAssets -filter_flexible_asset_type_id $Filterid.id -filter_organization_id $orgID).data | Where-Object {$_.attributes.name -eq $ENV:COMPUTERNAME}

#If the Asset does not exist, we edit the body to be in the form of a new asset, if not, we just upload.
if(!$ExistingFlexAsset){
$FlexAssetBody.attributes.add('organization-id', $orgID)
$FlexAssetBody.attributes.add('flexible-asset-type-id', $FilterID.id)
Write-Host "Creating new flexible asset"
New-ITGlueFlexibleAssets -data $FlexAssetBody

} else {
Write-Host "Updating Flexible Asset"
Set-ITGlueFlexibleAssets -id $ExistingFlexAsset.id  -data $FlexAssetBody}