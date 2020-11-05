################### Secure Application Model Information ###################
$ApplicationId = 'ApplicationID'
$ApplicationSecret = 'ApplicationSecret' | Convertto-SecureString -AsPlainText -Force
$RefreshToken = 'ExtremelyLongRefreshToken'
################# /Secure Application Model Information ####################
 
################# API Keys #################################################
$ShodanAPIKey = 'YourShodanAPIKEy'
$HaveIBeenPwnedKey = 'HIBPAPIKey'
################# /API Keys ################################################
 
 
$head = @"
<script>
function myFunction() {
    const filter = document.querySelector('#myInput').value.toUpperCase();
    const trs = document.querySelectorAll('table tr:not(.header)');
    trs.forEach(tr => tr.style.display = [...tr.children].find(td => td.innerHTML.toUpperCase().includes(filter)) ? '' : 'none');
  }</script>
<Title>LNPP - Lime Networks Partner Portal</Title>
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
    
$PreContent = @"
<H1> Breach logbook</H1> <br>
    
This log contains all breaches found for the e-mail addresses in your Microsoft tenant. You can use the search to find specific e-mail addresses.
<br/>
<br/>
     
<input type="text" id="myInput" onkeyup="myFunction()" placeholder="Search...">
"@
    
 
 
write-host "Creating credentials and tokens." -ForegroundColor Green
$credential = New-Object System.Management.Automation.PSCredential($ApplicationId, $ApplicationSecret)
$aadGraphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.windows.net/.default' -ServicePrincipal
$graphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.microsoft.com/.default' -ServicePrincipal
$HIBPHeader = @{'hibp-api-key' = $HaveIBeenPwnedKey }
write-host "Connecting to Office365 to get all tenants." -ForegroundColor Green
Connect-MsolService -AdGraphAccessToken $aadGraphToken.AccessToken -MsGraphAccessToken $graphToken.AccessToken
$customers = Get-MsolPartnerContract -All
foreach ($Customer in $Customers) {
  $CustomerDomains = Get-MsolDomain -TenantId $Customer.TenantId
    write-host "  Retrieving Breach Info for $($customer.name)" -ForegroundColor Green
    $UserList = get-msoluser -all -TenantId $Customer.TenantId
    $HIBPList = foreach ($User in $UserList) {
        try {
            $Breaches = $null
            $Breaches = Invoke-RestMethod -Uri "https://haveibeenpwned.com/api/v3/breachedaccount/$($user.UserPrincipalName)?truncateResponse=false" -Headers $HIBPHeader -UserAgent 'CyberDrain.com PowerShell Breach Script'
        }
        catch {
            if ($_.Exception.Response.StatusCode.value__ -eq '404') {  } else { write-error "$($_.Exception.message)" }
        }
        start-sleep 1.5
        foreach ($Breach in $Breaches) {
            [PSCustomObject]@{
                Username              = $user.UserPrincipalName
                'Name'                = $Breach.name
                'Domain name'         = $breach.Domain
                'Date'                = $Breach.Breachdate
                'Verified by experts' = if ($Breach.isverified) { 'Yes' } else { 'No' }
                'Leaked data'         = $Breach.DataClasses -join ', '
                'Description'         = $Breach.Description
            }
        }
        if ($user.proxyaddresses.count -gt 1){                                                  #A seperate loop is needed as some user accounts have proxy addresses defined (ex. AzureAD)
            Write-Host "    This user has extra proxy addresses. Checking them."
            For ($i=0;$i -lt $user.proxyaddresses.count;$i++){
                $ProxyAddress = $user.proxyaddresses[$i].substring(5)                           #Remote smtp: and SMTP: from start of string.
                if(($ProxyAddress -ne $user.UserPrincipalName) -or ($ProxyAddress -eq "")){     #Skip checking UPN, already happened.
                    Write-Host "    Checking Proxy Address $ProxyAddress."
                    try {
                        $Breaches = $null
                        $Breaches = Invoke-RestMethod -Uri "https://haveibeenpwned.com/api/v3/breachedaccount/$($ProxyAddress)?truncateResponse=false" -Headers $HIBPHeader -UserAgent 'CyberDrain.com PowerShell Breach Script'
                    }
                    catch {
                        if ($_.Exception.Response.StatusCode.value__ -eq '404') {  } else { write-error "$($_.Exception.message)" }
                    }
                    start-sleep 1.5
                    foreach ($Breach in $Breaches) {
                        [PSCustomObject]@{
                            Username              = $ProxyAddress
                            'Name'                = $Breach.name
                            'Domain name'         = $breach.Domain
                            'Date'                = $Breach.Breachdate
                            'Verified by experts' = if ($Breach.isverified) { 'Yes' } else { 'No' }
                            'Leaked data'         = $Breach.DataClasses -join ', '
                            'Description'         = $Breach.Description
                        }
                    }
                }
            }
        }
    }
    $BreachListHTML = $HIBPList | ConvertTo-Html -Fragment -PreContent '<h2>Breaches</h2><br> A "breach" is an incident where data is inadvertently exposed in a vulnerable system, usually due to insufficient access controls or security weaknesses in the software. HIBP aggregates breaches and enables people to assess where their personal data has been exposed.<br>' | Out-String
 
    write-host "Getting Shodan information for $($Customer.name)'s domains."
    $SHodanInfo = foreach ($Domain in $CustomerDomains.Name) {
        $ShodanQuery = (Invoke-RestMethod -Uri "https://api.shodan.io/shodan/host/search?key=$($ShodanAPIKey)&query=$Domain" -UserAgent 'CyberDrain.com PowerShell Breach Script').matches
        foreach ($FoundItem in $ShodanQuery) {
            [PSCustomObject]@{
                'Searched for'    = $Domain
                'Found Product'   = $FoundItem.product
                'Found open port' = $FoundItem.port
                'Found IP'        = $FoundItem.ip_str
                'Found Domain'    = $FoundItem.domain
            }
 
        }
    }
    if (!$ShodanInfo) { $ShodanInfo = "No information found for domains on Shodan" }
    $ShodanHTML = $SHodanInfo | ConvertTo-Html -Fragment -PreContent "<h2>Shodan Information</h2><br>Shodan is a search engine, but one designed specifically for internet connected devices. It scours the invisible parts of the Internet most people won’t ever see. Any internet exposed connected device can show up in a search.<br>" | Out-String
     
$head,$PreContent,[System.Web.HttpUtility]::HtmlDecode($BreachListHTML),$ShodanHTML | Out-File "C:\temp\$($customer.name).html"
    
}