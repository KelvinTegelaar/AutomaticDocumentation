#Server documentation script
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
#Head for HTML
$head = @"
<Title>Server Log Report</Title>
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
</style>
"@

$HTMLFile = @"
$head
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

$HTMLFile | out-file C:\Temp\ServerDoc.html