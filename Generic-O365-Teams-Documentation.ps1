################### Secure Application Model Information ###################
$ApplicationId = 'AppID'
$ApplicationSecret = 'AppSecret' 
$TenantID = 'YourTenantID'
$RefreshToken = 'VeryLongRefreshToken'
################# /Secure Application Model Information ####################
write-host "Creating credentials and tokens." -ForegroundColor Green

$credential = New-Object System.Management.Automation.PSCredential($ApplicationId, ($ApplicationSecret | Convertto-SecureString -AsPlainText -Force))
$aadGraphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.windows.net/.default' -ServicePrincipal 
$graphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.microsoft.com/.default' -ServicePrincipal

write-host "Creating body to request Graph access for each client." -ForegroundColor Green
$body = @{
    'resource'      = 'https://graph.microsoft.com'
    'client_id'     = $ApplicationId
    'client_secret' = $ApplicationSecret
    'grant_type'    = "client_credentials"
    'scope'         = "openid"
}
write-host "Setting HTML Headers" -ForegroundColor Green
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



write-host "Connecting to Office365 to get all tenants." -ForegroundColor Green
Connect-MsolService -AdGraphAccessToken $aadGraphToken.AccessToken -MsGraphAccessToken $graphToken.AccessToken
$customers = Get-MsolPartnerContract -All
foreach ($Customer in $Customers) {

    $ClientToken = Invoke-RestMethod -Method post -Uri "https://login.microsoftonline.com/$($customer.tenantid)/oauth2/token" -Body $body -ErrorAction Stop
    $headers = @{ "Authorization" = "Bearer $($ClientToken.accesstoken)" }
    
    write-host "Starting documentation process for $($customer.name)." -ForegroundColor Green
    $headers = @{ "Authorization" = "Bearer $($CustgraphToken.AccessToken)" }
    Write-Host "Grabbing all Teams" -ForegroundColor Green
    $AllTeamsURI = "https://graph.microsoft.com/beta/groups?`$filter=resourceProvisioningOptions/Any(x:x eq 'Team')&`$top=999"
    $Teams = (Invoke-RestMethod -Uri $AllTeamsURI -Headers $Headers -Method Get -ContentType "application/json").value
    Write-Host "Grabbing all Team Settings" -ForegroundColor Green
    $TeamSettings = foreach ($Team in $Teams) {
        $Settings = (Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/Teams/$($team.id)" -Headers $Headers -Method Get -ContentType "application/json")
        $Members = (Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/groups/$($team.id)/members?`$top=999" -Headers $Headers -Method Get -ContentType "application/json").value
        $Owners = (Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/groups/$($team.id)/Owners?`$top=999" -Headers $Headers -Method Get -ContentType "application/json").value

        [PSCustomObject]@{
            'Team Name'          = $settings.displayname
            'Team ID'            = $settings.id
            'Description'        = $Settings.description
            'Teams URL'          = $settings.webUrl
            'Messaging Settings' = $settings.messagingSettings
            'Member Settings'    = $Settings.memberSettings
            'Guest Settings'     = $Settings.guestSettings
            'Fun Settings'       = $settings.funSettings
            'Discovery Settings' = $settings.discoverySettings
            'Is Archived'        = $Settings.isArchived
            'Team Owners'        = $Owners | Select-Object Displayname, UserPrincipalname
            'Team Members'       = $Members | Where-Object { $_.UserType -eq "Member" } | Select-Object Displayname, UserPrincipalname
            'Team Guests'        = $Members | Where-Object { $_.UserType -eq "Guest" } | Select-Object Displayname, UserPrincipalname
        }
        $SettingsHTML = $Settings | ConvertTo-Html -as List - -Fragment -PreContent "<h1>Settings<h2>" | Out-String
        $OwnersHTML = $Owners | Select-Object Displayname, UserPrincipalname | ConvertTo-Html -Fragment -PreContent "<h1>Owners<h2>" | Out-String
        $MembersHTML = $Members | Where-Object { $_.UserType -eq "Member" } | Select-Object Displayname, UserPrincipalname | ConvertTo-Html  -Fragment -PreContent "<h1>Members<h2>" | Out-String
        $GuestsHTML = $Members | Where-Object { $_.UserType -eq "Guest" } | Select-Object Displayname, UserPrincipalname | ConvertTo-Html -Fragment -PreContent "<h1>Guests<h2>" | Out-String
    
        $head, $SettingsHTML, $OwnersHTML, $MembersHTML, $GuestsHTML -replace "<th>", "<th style=`"background-color:#4CAF50`">" | Out-File "C:\Temp\$($Customer.name) - $($Settings.displayname).html"

    }


}