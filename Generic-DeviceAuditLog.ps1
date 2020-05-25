###############
$TableStyling = "<th>", "<th style=`"background-color:#4CAF50`">"
##############
 

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


$events = $events | Sort-Object -Property date -Descending

$eventshtml = ($Events | convertto-html -fragment | out-string) -replace $TableStyling
$ProfilesHTML = ($UsersProfiles | convertto-html -Fragment | out-string)  -replace $TableStyling
$updatesHTML = ($hotfixesInstalled | select-object InstalledOn, Hotfixid, caption, InstalledBy  | convertto-html -Fragment | out-string) -replace $TableStyling
$SoftwareHTML = ($installedSoftware | convertto-html -Fragment | out-string) -replace $TableStyling


$head,$eventshtml,$ProfilesHTML,$updatesHTML,$SoftwareHTML | out-file "C:\Temp\Auditoutput.html"