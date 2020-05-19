########################## IT-Glue ############################
$APIKEy = "ITGlueKey"
$APIEndpoint = "https://api.eu.itglue.com"
$FlexAssetName = "Azure AD - AutoDoc v2"
$Description = "A network one-page document that shows the Azure AD settings."
########################## IT-Glue ############################

########################## Azure AD ###########################
$ApplicationId         = 'xxxx-xxxx-xxx-xxxx-xxxx'
$ApplicationSecret     = 'TheSecretTheSecret' | Convertto-SecureString -AsPlainText -Force
$TenantID              = 'YourTenantID'
$RefreshToken          = 'RefreshToken'
$ExchangeRefreshToken  = 'ExchangeRefreshToken'
$upn                   = 'UPN-Used-To-Generate-Tokens'
########################## Azure AD ###########################
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
 

#Connect to your Azure AD Account.
$credential = New-Object System.Management.Automation.PSCredential($ApplicationId, $ApplicationSecret)
$aadGraphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.windows.net/.default' -ServicePrincipal -Tenant $tenantID 
$graphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.microsoft.com/.default' -ServicePrincipal -Tenant $tenantID 
Connect-AzureAD -AadAccessToken $aadGraphToken.AccessToken -AccountId $UPN -MsAccessToken $graphToken.AccessToken -TenantId $tenantID | Out-Null
$Customers = Get-AzureADContract -All:$true
Disconnect-AzureAD
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
                            name            = "Primary Domain Name"
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
                            name           = "Users"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 3
                            name           = "Guest Users"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 4
                            name           = "Domain admins"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 5
                            name           = "Applications"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 6
                            name           = "Devices"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 7
                            name           = "Domains"
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

#Grab all IT-Glue contacts to match the domain name.
write-host "Getting IT-Glue contact list" -foregroundColor green
$i = 0
do {
    $AllITGlueContacts += (Get-ITGlueContacts -page_size 1000 -page_number $i).data.attributes
    $i++
    Write-Host "Retrieved $($AllITGlueContacts.count) Contacts" -ForegroundColor Yellow
}while ($AllITGlueContacts.count % 1000 -eq 0 -and $AllITGlueContacts.count -ne 0) 



write-host "Start documentation process." -foregroundColor green

foreach ($Customer in $Customers) {
    $CustAadGraphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes "https://graph.windows.net/.default" -ServicePrincipal -Tenant $customer.CustomerContextId
    $CustGraphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes "https://graph.microsoft.com/.default" -ServicePrincipal -Tenant $customer.CustomerContextId
    write-host "Connecting to $($customer.Displayname)" -foregroundColor green
    Connect-AzureAD -AadAccessToken $CustAadGraphToken.AccessToken -AccountId $upn -MsAccessToken $CustGraphToken.AccessToken -TenantId $customer.CustomerContextId | out-null
    write-host "       Documenting Users for $($customer.Displayname)" -foregroundColor green
    $Users = Get-AzureADUser -All:$true
    write-host "       Documenting Applications for $($customer.Displayname)" -foregroundColor green
    $Applications = Get-AzureADApplication -All:$true
    write-host "       Documenting Devices for $($customer.Displayname)" -foregroundColor green
    $Devices = Get-AzureADDevice -all:$true
    write-host "       Documenting AzureAD Domains for $($customer.Displayname)" -foregroundColor green
    $customerdomains = get-azureaddomain
    $AdminUsers = Get-AzureADDirectoryRole | Where-Object { $_.Displayname -eq "Company Administrator" } | Get-AzureADDirectoryRoleMember
    $PrimaryDomain = ($customerdomains | Where-Object { $_.IsDefault -eq $true }).name
    Disconnect-AzureAD
    $TableHeader = "<table class=`"table table-bordered table-hover`" style=`"width:80%`">"
    $Whitespace = "<br/>"
    $TableStyling = "<th>", "<th style=`"background-color:#4CAF50`">"

    $NormalUsers = $users | Where-Object { $_.UserType -eq "Member" } | Select-Object DisplayName, mail,ProxyAddresses | ConvertTo-Html -Fragment | Out-String
    $NormalUsers = $TableHeader + ($NormalUsers -replace $TableStyling) + $Whitespace
    $GuestUsers = $users | Where-Object { $_.UserType -ne "Member" } | Select-Object DisplayName, mail | ConvertTo-Html -Fragment | Out-String
    $GuestUsers =  $TableHeader + ($GuestUsers -replace $TableStyling) + $Whitespace
    $AdminUsers = $AdminUsers | Select-Object Displayname, mail | ConvertTo-Html -Fragment | Out-String
    $AdminUsers = $TableHeader + ($AdminUsers  -replace $TableStyling) + $Whitespace
    $Devices = $Devices | select-object DisplayName, DeviceOSType, DEviceOSversion, ApproximateLastLogonTimeStamp | ConvertTo-Html -Fragment | Out-String
    $Devices =  $TableHeader + ($Devices -replace $TableStyling) + $Whitespace
    $HTMLDomains = $customerdomains | Select-Object Name, IsDefault, IsInitial, Isverified | ConvertTo-Html -Fragment | Out-String
    $HTMLDomains = $TableHeader + ($HTMLDomains -replace $TableStyling) + $Whitespace
    $Applications = $Applications | Select-Object Displayname, AvailableToOtherTenants,PublisherDomain | ConvertTo-Html -Fragment | Out-String
    $Applications = $TableHeader + ($Applications -replace $TableStyling) + $Whitespace
    


    $FlexAssetBody =
    @{
        type       = 'flexible-assets'
        attributes = @{
            traits = @{
                'primary-domain-name' = $PrimaryDomain
                'users'               = $NormalUsers
                'guest-users'         = $GuestUsers
                'domain-admins'       = $AdminUsers
                'applications'        = $Applications
                'devices'             = $Devices
                'domains'             = $HTMLDomains
            }
        }
    }

    Write-Host "          Finding $($customer.name) in IT-Glue" -ForegroundColor Green
    $orgID = @()
    foreach ($customerDomain in $customerdomains) {
        $orgID += ($AllITGlueContacts | Where-Object { $_.'contact-emails'.value -match $customerDomain.name }).'organization-id' | Select-Object -Unique
    }
    write-host "             Uploading Azure AD $($customer.name) into IT-Glue"  -ForegroundColor Green
    foreach ($org in $orgID) {
        $ExistingFlexAsset = (Get-ITGlueFlexibleAssets -filter_flexible_asset_type_id $($filterID.ID) -filter_organization_id $org).data | Where-Object { $_.attributes.traits.'primary-domain-name' -eq $PrimaryDomain }
        #If the Asset does not exist, we edit the body to be in the form of a new asset, if not, we just upload.
        if (!$ExistingFlexAsset) {
            $FlexAssetBody.attributes.add('organization-id', $org)
            $FlexAssetBody.attributes.add('flexible-asset-type-id', $($filterID.ID))
            write-host "                      Creating new Azure AD $($customer.name) into IT-Glue organisation $org" -ForegroundColor Green
            New-ITGlueFlexibleAssets -data $FlexAssetBody
        }
        else {
            write-host "                      Updating Azure AD $($customer.name) into IT-Glue organisation $org"  -ForegroundColor Green
            $ExistingFlexAsset = $ExistingFlexAsset[-1]
            Set-ITGlueFlexibleAssets -id $ExistingFlexAsset.id -data $FlexAssetBody
        }

    }

}