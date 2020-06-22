###############
$TableStyling = "<th>", "<th style=`"background-color:#4CAF50`">"
##############


write-host "Starting documentation process." -foregroundColor green

$head = @"
<script>
function myFunction() {
    const filter = document.querySelector('#myInput').value.toUpperCase();
    const trs = document.querySelectorAll('table tr:not(.header)');
    trs.forEach(tr => tr.style.display = [...tr.children].find(td => td.innerHTML.toUpperCase().includes(filter)) ? '' : 'none');
  }</script>
<Title>DHCP Report</Title>
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

$DCHPServerSettings = Get-DhcpServerSetting | select-object ActivatePolicies,ConflictDetectionAttempts,DynamicBootp,IsAuthorized,IsDomainJoined,NapEnabled,NpsUnreachableAction,RestoreStatus | ConvertTo-Html -Fragment -PreContent "<h1>DHCP Server Settings</h1>" | Out-String
$databaseinfo = Get-DhcpServerDatabase | Select-Object BackupInterval,BackupPath,CleanupInterval,FileName,LoggingEnabled,RestoreFromBackup | ConvertTo-Html -Fragment -PreContent "<h1>DHCP Database information</h1>" | Out-String
$DHCPDCAuth = Get-DhcpServerInDC | select-object IPAddress,DnsName  |ConvertTo-Html -Fragment -PreContent "<h1>DHCP Domain Controller Authorisations</h1>" | Out-String
$Scopes = Get-DhcpServerv4Scope
$ScopesAvailable = $Scopes | Select-Object ScopeId,SubnetMask,StartRange,EndRange,ActivatePolicies,Delay,Description,LeaseDuration,MaxBootpClients,Name,NapEnable,NapProfile,State,SuperscopeName,Type | ConvertTo-Html -Fragment -PreContent "<h1>DHCP Server scopes</h1>" | Out-String
$ScopeInfo = foreach ($Scope in $scopes) {
    $scope | Get-DhcpServerv4Lease | select-object ScopeId, IPAddress, AddressState, ClientId, ClientType, Description, DnsRegistration, DnsRR, HostName, LeaseExpiryTime |  ConvertTo-Html -Fragment -PreContent "<h1>Scope Information: $($Scope.name) - $($scope.ScopeID) </h1>" | Out-String
}

$DHCPServerStats = Get-DhcpServerv4Statistics | Select-Object InUse,Available,Acks,AddressesAvailable,AddressesInUse,Declines,DelayedOffers,Discovers,Naks,Offers,PendingOffers,PercentageAvailable,PercentageInUse,PercentagePendingOffers,Releases,Requests,ScopesWithDelayConfigured,ServerStartTime,TotalAddresses,TotalScope | ConvertTo-Html -Fragment -PreContent "<h1>DHCP Server statistics</h1>" -As List | Out-String


$head, $DCHPServerSettings, $databaseinfo, $DHCPDCAuth, $ScopesAvailable,$ScopeInfo,$DHCPServerStats | out-file "C:\Temp\Auditoutput.html"