$RecursiveDepth = 2
  
 
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
 
If(Get-Module -ListAvailable -Name "NTFSSecurity") {Import-module "NTFSSecurity"} Else { install-module "NTFSSecurity" -Force; import-module "NTFSSecurity"}
      
$AllsmbShares = get-smbshare | Where-Object {(@('Remote Admin','Default share','Remote IPC') -notcontains $_.Description)}
foreach($SMBShare in $AllSMBShares){
$Permissions = get-item $SMBShare.path | get-ntfsaccess
$Permissions += get-childitem -Depth $RecursiveDepth -Recurse $SMBShare.path | get-ntfsaccess
$FullAccess = $permissions | where-object {$_.'AccessRights' -eq "FullControl" -AND $_.IsInherited -eq $false -AND $_.'AccessControlType' -ne "Deny"}| Select-Object FullName,Account,AccessRights,AccessControlType  | ConvertTo-Html -PreContent "<h1>Full Access</h1>" -Fragment | Out-String
$Modify = $permissions | where-object {$_.'AccessRights' -Match "Modify" -AND $_.IsInherited -eq $false -and $_.'AccessControlType' -ne "Deny"}| Select-Object FullName,Account,AccessRights,AccessControlType  | ConvertTo-Html -PreContent "<h1>Modify</h1>"  -Fragment | Out-String
$ReadOnly = $permissions | where-object {$_.'AccessRights' -Match "Read" -AND $_.IsInherited -eq $false -and $_.'AccessControlType' -ne "Deny"}| Select-Object FullName,Account,AccessRights,AccessControlType  | ConvertTo-Html -PreContent "<h1>Read Only</h1>" -Fragment | Out-String
$Deny =   $permissions | where-object {$_.'AccessControlType' -eq "Deny" -AND $_.IsInherited -eq $false} | Select-Object FullName,Account,AccessRights,AccessControlType | ConvertTo-Html -PreContent "<h1>Deny</h1>" -Fragment | Out-String
$PermCSV = $Permissions | ConvertTo-Csv -Delimiter "," | out-file "C:\Export\ExportOfPermissions.csv" -append
$head,$FullAccess,$Modify,$ReadOnly,$Deny | Out-File "C:\Export\$($SMBShare.name).html"
}
