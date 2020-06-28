################### Secure Application Model Information ###################
$ApplicationId = 'ApplicationID'
$ApplicationSecret = 'ApplicationSecret' | Convertto-SecureString -AsPlainText -Force
$RefreshToken = 'ExtremelyLongRefreshToken'
################# /Secure Application Model Information ####################
 
################# API Keys #################################################
$ShodanAPIKey = 'YourShodanAPIKEy'
$HaveIBeenPwnedKey = 'HIBPAPIKey'
################# /API Keys ################################################
 
################# IT-Glue Information ######################################
$ITGkey = "ITGluekey"
$ITGbaseURI = "https://api.eu.itglue.com"
$FlexAssetName = "Breach v1 - Autodoc"
$Description = "Automatic Documentation for known breaches."
$TableStyling = "<th>", "<th style=`"background-color:#4CAF50`">"
################# /IT-Glue Information #####################################
  
  
write-host "Checking if IT-Glue Module is available, and if not install it." -ForegroundColor Green
#Settings IT-Glue logon information
If (Get-Module -ListAvailable -Name "ITGlueAPI") { 
    Import-module ITGlueAPI 
}
Else { 
    Install-Module ITGlueAPI -Force
    Import-Module ITGlueAPI
}
#Setting IT-Glue logon information
Add-ITGlueBaseURI -base_uri $ITGbaseURI
Add-ITGlueAPIKey $ITGkey
   
write-host "Getting IT-Glue contact list" -ForegroundColor Green
$i = 0
do {
    $AllITGlueContacts += (Get-ITGlueContacts -page_size 1000 -page_number $i).data.attributes
    $i++
    Write-Host "Retrieved $($AllITGlueContacts.count) Contacts" -ForegroundColor Yellow
}while ($AllITGlueContacts.count % 1000 -eq 0 -and $AllITGlueContacts.count -ne 0) 
write-host "Generating unique ID List" -ForegroundColor Green
$DomainList = foreach ($Contact in $AllITGlueContacts) {
    $ITGDomain = ($contact.'contact-emails'.value -split "@")[1]
    [PSCustomObject]@{
        Domain   = $ITGDomain
        OrgID    = $Contact.'organization-id'
        Combined = "$($ITGDomain)$($Contact.'organization-id')"
    }
} 
$DomainList = $DomainList | sort-object -Property Combined -Unique
   
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
                            name            = "Tenant name"
                            kind            = "Text"
                            required        = $true
                            "show-in-list"  = $true
                            "use-for-title" = $true
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order           = 2
                            name            = "Breaches"
                            kind            = "Textbox"
                            required        = $true
                            "show-in-list"  = $false
                            "use-for-title" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 3
                            name           = "Shodan Info"
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
    write-host "Finding possible organisation IDs for $($customer.name)" -ForegroundColor Green
    $orgid = foreach ($customerDomain in $customerdomains) {
        ($domainList | Where-Object { $_.domain -eq $customerDomain.name }).'OrgID' | Select-Object -Unique
    }
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
     
    $FlexAssetBody =
    @{
        type       = 'flexible-assets'
        attributes = @{
            traits = @{
                'tenant-name' = $customer.DefaultDomainName
                'breaches'    = [System.Web.HttpUtility]::HtmlDecode($BreachListHTML -replace $TableStyling)
                'shodan-info' = ($ShodanHTML -replace $TableStyling)
            }
        }
    }
 
    write-host "   Uploading Breach Info $($customer.name) into IT-Glue" -foregroundColor green
    foreach ($org in $orgID | Select-Object -Unique) {
        $ExistingFlexAsset = (Get-ITGlueFlexibleAssets -filter_flexible_asset_type_id $FilterID.id -filter_organization_id $org).data | Where-Object { $_.attributes.traits.'tenant-name' -eq $($Customer.DefaultDomainName) } | Select-Object -last 1
        #If the Asset does not exist, we edit the body to be in the form of a new asset, if not, we just upload.
        if (!$ExistingFlexAsset) {
            if ($FlexAssetBody.attributes.'organization-id') {
                $FlexAssetBody.attributes.'organization-id' = $org
            }
            else { 
                $FlexAssetBody.attributes.add('organization-id', $org)
                $FlexAssetBody.attributes.add('flexible-asset-type-id', $FilterID.id)
            }
            write-output "                      Creating new Breach Info for $($Customer.name) into IT-Glue organisation $org"
            New-ITGlueFlexibleAssets -data $FlexAssetBody
  
        }
        else {
            write-output "                      Updating Breach Info for $($Customer.name) into IT-Glue organisation $org"
            $ExistingFlexAsset = $ExistingFlexAsset | select-object -Last 1
            Set-ITGlueFlexibleAssets -id $ExistingFlexAsset.id  -data $FlexAssetBody
        }
  
    }
}