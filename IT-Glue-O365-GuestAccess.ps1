######### Secrets #########
$ApplicationId = 'ApplicationID'
$ApplicationSecret = 'ApplicationSecret' | ConvertTo-SecureString -Force -AsPlainText
$TenantID = 'TenantID'
$RefreshToken = 'LongRefreshToken'
$ExchangeRefreshToken = 'LongExchangeRefreshToken'
$UPN = "YourPrettyUpnUsedToGenerateTokens"
######### Secrets #########

######################### IT-Glue ############################
$APIKEy = "ITG-API-KEY"
$APIEndpoint = "https://api.eu.itglue.com"
$FlexAssetName = "O365 Guest logbook"
$Description = "A logbook of actions a external user has performed"
########################## IT-Glue ############################
 
#Grabbing ITGlue Module and installing.
If (Get-Module -ListAvailable -Name "ITGlueAPI") { 
    Import-module ITGlueAPI 
}
Else { 
    Install-Module ITGlueAPI -Force
    Import-Module ITGlueAPI
}
#Settings IT-Glue logon information
Add-ITGlueBaseURI -base_uri $APIEndpoint
Add-ITGlueAPIKey $APIKEy
 
write-host "Checking if Flexible Asset exists in IT-Glue." -foregroundColor green
$FilterID = (Get-ITGlueFlexibleAssetTypes -filter_name $FlexAssetName).data
if (!$FilterID) { 
    write-host "Does not exist, creating new." -foregroundColor green
    $NewFlexAssetData = 
    @{
        type          = 'flexible-asset-types'
        attributes    = @{
            name        = $FlexAssetName
            icon        = 'sitemap'
            description = $description
        }
        relationships = @{
            "flexible-asset-fields" = @{
                data = @(
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order           = 1
                            name            = "Guest"
                            kind            = "Text"
                            required        = $true
                            "show-in-list"  = $true
                            "use-for-title" = $true
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 2
                            name           = "Actions"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    }
                )
            }
        }
    }
    New-ITGlueFlexibleAssetTypes -Data $NewFlexAssetData
    $FilterID = (Get-ITGlueFlexibleAssetTypes -filter_name $FlexAssetName).data
}
 
write-host "Getting IT-Glue contact list" -ForegroundColor Green
$i = 0
$AllITGlueContacts = do {
    $Contacts = (Get-ITGlueContacts -page_size 1000 -page_number $i).data.attributes
    $i++
    $Contacts
    Write-Host "Retrieved $($Contacts.count) Contacts" -ForegroundColor Yellow
}while ($Contacts.count % 1000 -eq 0 -and $Contacts.count -ne 0) 
  
write-host "Generating unique ID List" -ForegroundColor Green
$DomainList = foreach ($Contact in $AllITGlueContacts) {
    $ITGDomain = ($contact.'contact-emails'.value -split "@")[1]
    [PSCustomObject]@{
        Domain   = $ITGDomain
        OrgID    = $Contact.'organization-id'
        Combined = "$($ITGDomain)$($Contact.'organization-id')"
    }
} 
 

$credential = New-Object System.Management.Automation.PSCredential($ApplicationId, $ApplicationSecret)
$aadGraphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.windows.net/.default' -ServicePrincipal -Tenant $tenantID
$graphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.microsoft.com/.default' -ServicePrincipal -Tenant $tenantID
Connect-MsolService -AdGraphAccessToken $aadGraphToken.AccessToken -MsGraphAccessToken $graphToken.AccessToken
 
$customers = Get-MsolPartnerContract -All

foreach ($customer in $customers) {
    $domains = Get-MsolDomain -TenantId $customer.TenantId
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
    foreach ($guest in $GuestUsers) {
        $Logs = do {
            $log = Search-unifiedAuditLog -SessionCommand ReturnLargeSet -SessionId $customer.name -UserIds $guest.userprincipalname -ResultSize 5000 -StartDate $startDate -EndDate $endDate
            $log
            Write-Host "    Retrieved $($log.count) logs for user $($guest.UserPrincipalName)" -ForegroundColor Green
        }while ($Log.count % 5000 -eq 0 -and $log.count -ne 0)
        if ($logs) {
            $AuditData = $logs.AuditData | ForEach-Object { ConvertFrom-Json $_ }
            $FlexAssetBody = 
            @{
                type       = "flexible-assets"
                attributes = @{
                    traits = @{
                        "guest"   = $guest.userprincipalname
                        "actions" = ($AuditData | select-object CreationTime, Operation, ClientIP, UserID, SiteURL, SourceFilename, UserAgent | convertto-html -Fragment | Out-String)
                                                  
                    }
                }
            }
            write-output "             Finding $($customer.name) in IT-Glue"
            $orgid = foreach ($customerDomain in $domains) {
                ($domainList | Where-Object { $_.domain -eq $customerDomain.name }).'OrgID' | Select-Object -Unique
            }
            write-output "             Uploading O365 guest $($guest.userprincipalname) into IT-Glue"
            foreach ($org in $orgID) {
                $ExistingFlexAsset = (Get-ITGlueFlexibleAssets -filter_flexible_asset_type_id $FilterID.id -filter_organization_id $org).data | Where-Object { $_.attributes.traits.'guest' -eq $guest.UserPrincipalName }
                #If the Asset does not exist, we edit the body to be in the form of a new asset, if not, we just upload.
                if (!$ExistingFlexAsset) {
                    if ($FlexAssetBody.attributes.'organization-id') {
                        $FlexAssetBody.attributes.'organization-id' = $org
                    }
                    else { 
                        $FlexAssetBody.attributes.add('organization-id', $org)
                        $FlexAssetBody.attributes.add('flexible-asset-type-id', $FilterID.id)
                    }
                    write-output "                      Creating new guest $($guest.userprincipalname) into IT-Glue organisation $org"
                    New-ITGlueFlexibleAssets -data $FlexAssetBody
              
                }
                else {
                    write-output "                      Updating guest $($guest.userprincipalname)  into IT-Glue organisation $org"
                    $ExistingFlexAsset = $ExistingFlexAsset | select-object -Last 1
                    Set-ITGlueFlexibleAssets -id $ExistingFlexAsset.id  -data $FlexAssetBody
                }
              
            }
        }
    } 
} 