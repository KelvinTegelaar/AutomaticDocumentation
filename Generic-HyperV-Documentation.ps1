########################## IT-Glue ############################
$TableHeader = "<table class=`"table table-bordered table-hover`" style=`"width:80%`">"
$Whitespace = "<br/>"
$TableStyling = "<th>", "<th style=`"background-color:#4CAF50`">"
########################## IT-Glue ############################
 
write-host "Start documentation process." -foregroundColor green
 
$VirtualMachines = get-vm | select-object VMName, Generation, Path, Automatic*, @{n = "Minimum(gb)"; e = { $_.memoryminimum / 1gb } }, @{n = "Maximum(gb)"; e = { $_.memorymaximum / 1gb } }, @{n = "Startup(gb)"; e = { $_.memorystartup / 1gb } }, @{n = "Currently Assigned(gb)"; e = { $_.memoryassigned / 1gb } }, ProcessorCount | ConvertTo-Html -Fragment -PreContent "<h2>Virtual Machines</h2>" | Out-String
$VirtualMachines = $TableHeader + ($VirtualMachines -replace $TableStyling) + $Whitespace
$NetworkSwitches = Get-VMSwitch | select-object name, switchtype, NetAdapterInterfaceDescription, AllowManagementOS | convertto-html -Fragment -PreContent "<h2>Network Switches</h2>" | Out-String
$VMNetworkSettings = Get-VMNetworkAdapter * | Select-Object Name, IsManagementOs, VMName, SwitchName, MacAddress, @{Name = 'IP'; Expression = { $_.IPaddresses -join "," } } | ConvertTo-Html -Fragment -PreContent "<br><h2>VM Network Settings</h2>" | Out-String
$NetworkSettings = $TableHeader + ($NetworkSwitches -replace $TableStyling) + ($VMNetworkSettings -replace $TableStyling) + $Whitespace
$ReplicationSettings = get-vmreplication | Select-Object VMName, State, Mode, FrequencySec, PrimaryServer, ReplicaServer, ReplicaPort, AuthType | convertto-html -Fragment "<h2>Replication Settings</h2>"  | Out-String
$ReplicationSettings = $TableHeader + ($ReplicationSettings -replace $TableStyling) + $Whitespace
$HostSettings = get-vmhost | Select-Object  Computername, LogicalProcessorCount, iovSupport, EnableEnhancedSessionMode,MacAddressMinimum, *max*, NumaspanningEnabled, VirtualHardDiskPath, VirtualMachinePath, UseAnyNetworkForMigration, VirtualMachineMigrationEnabled | convertto-html -Fragment -PreContent "<h2>Host Settings</h2>"  | Out-String
 
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
$head,$VirtualMachines,$NetworkSettings,$ReplicationSettings,$HostSettings |  Out-File "C:\temp\Hyper-v.html"