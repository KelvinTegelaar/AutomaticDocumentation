$key                   = "YOUR IT Glue Key here"
$ApplicationId         = 'Application ID'
$ApplicationSecret     = 'Application Secret' | Convertto-SecureString -AsPlainText -Force
$TenantID              = 'YourTenantID'
$RefreshToken          = 'YourRefreshTokens'
$ExchangeRefreshToken  = 'YourExchangeRefresherToken'
$upn                   = 'UPN-That-Generated-Tokens'
$APIEndpoint           = "https://api.eu.itglue.com"
$FlexAssetName         = "Office365 Permissions - Automatic Documentation"
#######################################################################
write-output "Getting Module"
If (Get-Module -ListAvailable -Name "ITGlueAPI") { Import-module ITGlueAPI } Else { install-module ITGlueAPI -Force; import-module ITGlueAPI }
If (Get-Module -ListAvailable -Name "MsOnline") { Import-module "Msonline" } Else { install-module "MsOnline" -Force; import-module "Msonline" }
If (Get-Module -ListAvailable -Name "PartnerCenter") { Import-module "PartnerCenter" } Else { install-module "PartnerCenter" -Force; import-module "PartnerCenter" }
Write-Output "Generating tokens to login"
$credential = New-Object System.Management.Automation.PSCredential($ApplicationId, $ApplicationSecret)
$aadGraphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.windows.net/.default' -ServicePrincipal -Tenant $tenantID
$graphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.microsoft.com/.default' -ServicePrincipal -Tenant $tenantID
Add-ITGlueBaseURI -base_uri $APIEndpoint
Add-ITGlueAPIKey $key
write-output "Getting IT-Glue contact list"
$i = 0
do {
    $AllITGlueContacts += (Get-ITGlueContacts -page_size 1000 -page_number $i).data.attributes
    $i++
    Write-Host "Retrieved $($AllITGlueContacts.count) Contacts" -ForegroundColor Yellow
}while ($AllITGlueContacts.count % 1000 -eq 0 -and $AllITGlueContacts.count -ne 0) 
Write-Output "Checking if flexible asset exists."
$FilterID = (Get-ITGlueFlexibleAssetTypes -filter_name $FlexAssetName).data
if (!$FilterID) { 
Write-Output "No Flexible Asset found. Creating new one"
    $NewFlexAssetData = 
@{
    type = 'flexible-asset-types'
    attributes = @{
            name = $FlexAssetName
            icon = 'sitemap'
            description = $description
    }
    relationships = @{
        "flexible-asset-fields" = @{
            data = @(
                @{
                    type       = "flexible_asset_fields"
                    attributes = @{
                        order           = 1
                        name            = "tenantid"
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
                        name           = "permissions"
                        kind           = "Textbox"
                        required       = $false
                        "show-in-list" = $true
                    }
                },
                @{
                    type       = "flexible_asset_fields"
                    attributes = @{
                        order          = 3
                        name           = "tenant-name"
                        kind           = "Text"
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
 
 
write-output "Logging in."
Connect-MsolService -AdGraphAccessToken $aadGraphToken.AccessToken -MsGraphAccessToken $graphToken.AccessToken
$customers = Get-MsolPartnerContract -All
    
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
 
    foreach ($mailbox in $mailboxes) {
        $AccesPermissions = Get-MailboxPermission -Identity $mailbox.identity | Where-Object { $_.user.tostring() -ne "NT AUTHORITY\SELF" -and $_.IsInherited -eq $false } -erroraction silentlycontinue | Select-Object User, accessrights
        if ($AccesPermissions) { $HTMLPermissions += $AccesPermissions | convertto-html -frag -PreContent "
Permissions on $($mailbox.PrimarySmtpAddress)
" | Out-String }
    }
    Remove-PSSession $session
 
    $FlexAssetBody =
    @{
        type       = 'flexible-assets'
        attributes = @{
            traits = @{
                'permissions' = $HTMLPermissions
                'tenantid'    = $MSOLtentantID
                'tenant-name' = $initialdomain.name
            }
        }
    }
 
 
    write-output "             Finding $($customer.name) in IT-Glue"
    $orgID = @()
    foreach ($customerDomain in $customerdomains) {
        $orgID += ($AllITGlueContacts | Where-Object { $_.'contact-emails'.value -match $customerDomain.name }).'organization-id' | Select-Object -Unique
 
    }
 
 
 
    write-output "             Uploading Office Permission $($customer.name) into IT-Glue"
    foreach ($org in $orgID) {
        $ExistingFlexAsset = (Get-ITGlueFlexibleAssets -filter_flexible_asset_type_id $($filterID.ID) -filter_organization_id $org).data | Where-Object { $_.attributes.traits.'tenant-name' -eq $initialdomain.name }
        #If the Asset does not exist, we edit the body to be in the form of a new asset, if not, we just upload.
        if (!$ExistingFlexAsset) {
            $FlexAssetBody.attributes.add('organization-id', $org)
            $FlexAssetBody.attributes.add('flexible-asset-type-id', $($filterID.ID))
            write-output "                      Creating new Office Permission $($customer.name) into IT-Glue organisation $org"
            New-ITGlueFlexibleAssets -data $FlexAssetBody
        }
        else {
            write-output "                      Updating Office Permission $($customer.name) into IT-Glue organisation $org"
            $ExistingFlexAsset = $ExistingFlexAsset[-1]
            Set-ITGlueFlexibleAssets -id $ExistingFlexAsset.id  -data $FlexAssetBody
        }
 
    }
    $MSOLPrimaryDomain = $null
    $MSOLtentantID = $null
    $AccesPermissions = $null
    $HTMLPermissions = $null
}