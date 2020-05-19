$BitlockVolumes = Get-BitLockerVolume
#Some HTML to make the page pretty.
$head = @"
<script>
function myFunction() {
    const filter = document.querySelector('#myInput').value.toUpperCase();
    const trs = document.querySelectorAll('table tr:not(.header)');
    trs.forEach(tr => tr.style.display = [...tr.children].find(td => td.innerHTML.toUpperCase().includes(filter)) ? '' : 'none');
  }</script>
<title>Audit Log Report</title>
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

foreach($BitlockVolume in $BitlockVolumes) {
$HTMLTop = @"
    <h1>Bitlocker Information</h1>
    <b>Computername: </b>$($BitlockVolume.ComputerName)<br>
    <b>Encryption Method:</b>$($BitlockVolume.EncryptionMethod)<br>
    <b>Volume Type:</b>$($BitlockVolume.VolumeType)<br>
    <b>Volume Status:</b>$($BitlockVolume.VolumeStatus)<br>
"@
$HTML += $BitlockVolume.KeyProtector | convertto-html -Head $head -PreContent "$HTMLTop <br> <h1>Keys for $($ENV:COMPUTERNAME) - $($BitlockVolume.Mountpoint)</h1>"
}
$html | Out-File C:\Temp\temp.html