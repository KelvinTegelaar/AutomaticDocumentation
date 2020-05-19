$ApplicationId         = 'ApplicationID'
$ApplicationSecret     = 'ApplicationSecret' | Convertto-SecureString -AsPlainText -Force
$TenantID              = 'YourTenantID'
$RefreshToken          = 'RefreshToken'
$ExchangeRefreshToken  = 'ExchangeRefreshToken'
$upn                   = 'YourUPN'
#######################################################################
write-output "Getting Modules"
If (Get-Module -ListAvailable -Name "MsOnline") { Import-module "Msonline" } Else { install-module "MsOnline" -Force; import-module "Msonline" }
If (Get-Module -ListAvailable -Name "PartnerCenter") { Import-module "PartnerCenter" } Else { install-module "PartnerCenter" -Force; import-module "PartnerCenter" }
Write-Output "Generating tokens to login"
$credential = New-Object System.Management.Automation.PSCredential($ApplicationId, $ApplicationSecret)
$aadGraphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.windows.net/.default' -ServicePrincipal -Tenant $tenantID
$graphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.microsoft.com/.default' -ServicePrincipal -Tenant $tenantID
write-output "Logging in."
Connect-MsolService -AdGraphAccessToken $aadGraphToken.AccessToken -MsGraphAccessToken $graphToken.AccessToken
$customers = Get-MsolPartnerContract -All
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
foreach ($customer in $customers) {
    $MSOLPrimaryDomain = (get-msoldomain -TenantId $customer.tenantid | Where-Object { $_.IsInitial -eq $false }).name
    $customerDomains = Get-MsolDomain -TenantId $customer.TenantId | Where-Object { $_.status -contains "Verified" }
    $MSOLtentantID = $customer.tenantid
    #Connecting to the O365 tenant
    $InitialDomain = Get-MsolDomain -TenantId $customer.TenantId | Where-Object { $_.IsInitial -eq $true }
    Write-host "Documenting $($Customer.Name)"
    $token = New-PartnerAccessToken -ApplicationId 'a0c73c16-a7e3-4564-9a95-2bdf47383716'-RefreshToken $ExchangeRefreshToken -Scopes 'https://outlook.office365.com/.default' -Tenant $customer.TenantId
    $tokenValue = ConvertTo-SecureString "Bearer $($token.AccessToken)" -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential($upn, $tokenValue)
    $customerId = $customer.DefaultDomainName
    $session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri "https://ps.outlook.com/powershell-liveid?DelegatedOrg=$($customerId)&BasicAuthToOAuthConversion=true" -Credential $credential -Authentication Basic -AllowRedirection
    Import-PSSession $session -CommandName "Get-MailboxPermission", "Get-Mailbox" -AllowClobber
    $Mailboxes = Get-Mailbox -ResultSize:Unlimited | Sort-Object displayname
    $MSOLPrimaryDomain = $null
    $MSOLtentantID = $null
    $AccesPermissions = $null
    $HTMLPermissions = $null
    foreach ($mailbox in $mailboxes) {
        $AccesPermissions = Get-MailboxPermission -Identity $mailbox.identity | Where-Object { $_.user.tostring() -ne "NT AUTHORITY\SELF" -and $_.IsInherited -eq $false } -erroraction silentlycontinue | Select-Object User, accessrights
        if ($AccesPermissions) { $HTMLPermissions += $AccesPermissions | convertto-html -frag -PreContent "<h4>Permissions on $($mailbox.PrimarySmtpAddress)</h4>" | Out-String }
    }
    Remove-PSSession $session
    $CompleteHTML = $head,$HTMLPermissions | Out-String | out-file "C:\Temp\$($customer.name).html"
} 