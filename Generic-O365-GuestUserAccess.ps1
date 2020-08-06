######### Secrets #########
$ApplicationId = 'ApplicationID'
$ApplicationSecret = 'ApplicationSecret' | ConvertTo-SecureString -Force -AsPlainText
$TenantID = 'TenantID'
$RefreshToken = 'LongRefreshToken'
$ExchangeRefreshToken = 'LongExchangeRefreshToken'
$UPN = "YourPrettyUpnUsedToGenerateTokens"
######### Secrets #########

$credential = New-Object System.Management.Automation.PSCredential($ApplicationId, $ApplicationSecret)
$aadGraphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.windows.net/.default' -ServicePrincipal -Tenant $tenantID
$graphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.microsoft.com/.default' -ServicePrincipal -Tenant $tenantID
Connect-MsolService -AdGraphAccessToken $aadGraphToken.AccessToken -MsGraphAccessToken $graphToken.AccessToken
 
$customers = Get-MsolPartnerContract -All

foreach ($customer in $customers) {
    $token = New-PartnerAccessToken -ApplicationId 'a0c73c16-a7e3-4564-9a95-2bdf47383716'-RefreshToken $ExchangeRefreshToken -Scopes 'https://outlook.office365.com/.default' -Tenant $customer.TenantId
    $tokenValue = ConvertTo-SecureString "Bearer $($token.AccessToken)" -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential($upn, $tokenValue)
    $customerId = $customer.DefaultDomainName
    $session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri "https://ps.outlook.com/powershell-liveid?DelegatedOrg=$($customerId)&BasicAuthToOAuthConversion=true" -Credential $credential -Authentication Basic -AllowRedirection
    $null = Import-PSSession $session -allowclobber -DisableNameChecking -CommandName "Search-unifiedAuditLog", "Get-AdminAuditLogConfig"
    $GuestUsers = get-msoluser -TenantId $customer.TenantId -all | Where-Object { $_.Usertype -eq "guest" }
    if (!$GuestUsers) { 
        Write-Host "No guests for $($customer.name)" -ForegroundColor Yellow
        continue 
    }
    $startDate = (Get-Date).AddDays(-31)
    $endDate = (Get-Date)
    Write-Host "Retrieving logs for $($customer.name)" -ForegroundColor Blue
    New-HTML {
        foreach ($guest in $GuestUsers) {
         
            $Logs = do {
                $log = Search-unifiedAuditLog -SessionCommand ReturnLargeSet -SessionId $customer.name -UserIds $guest.userprincipalname -ResultSize 5000 -StartDate $startDate -EndDate $endDate
                $log
                Write-Host "    Retrieved $($log.count) logs for user $($guest.UserPrincipalName)" -ForegroundColor Green
            }while ($Log.count % 5000 -eq 0 -and $log.count -ne 0)
            if ($logs) {
                $AuditData = $Logs.AuditData | ForEach-Object { ConvertFrom-Json $_ }
                New-HTMLTab -Name $guest.UserPrincipalName {
                    New-HTMLSection -Invisible {
                        New-HTMLSection -HeaderText 'Logbook' {
                            New-HTMLTable -DataTable ($AuditData | select-object CreationTime, Operation, ClientIP, UserID, SiteURL, SourceFilename, UserAgent )
                        }
                    }
                }
            }
        } 
    } -FilePath "C:\temp\$($customer.DefaultDomainName).html" -Online
}