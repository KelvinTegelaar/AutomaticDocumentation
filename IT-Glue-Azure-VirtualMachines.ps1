######### Secrets #########
$ApplicationId = 'ApplicationID'
$ApplicationSecret = 'AppSecret' | ConvertTo-SecureString -Force -AsPlainText
$TenantID = 'TenantID'
$RefreshToken = 'LongRefreshToken'
$UPN = "limenetworks@limenetworks.nl"
######### Secrets #########

########################## IT-Glue ############################
$APIKEy = "ITGlueKey"
$APIEndpoint = "https://api.eu.itglue.com"
$FlexAssetName = "Azure Virtual Machines"
$Description = "A network one-page document that shows the Azure VM Settings."
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
                            name            = "Subscription ID"
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
                            name           = "VMs"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 3
                            name           = "NSGs"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 4
                            name           = "Networks"
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

$DomainList = $DomainList | sort-object -Property Combined -Unique

$credential = New-Object System.Management.Automation.PSCredential($ApplicationId, $ApplicationSecret)
$azureToken = New-PartnerAccessToken -ApplicationId $ApplicationID -Credential $credential -RefreshToken $refreshToken -Scopes 'https://management.azure.com/user_impersonation' -ServicePrincipal -Tenant $TenantId
$graphToken = New-PartnerAccessToken -ApplicationId $ApplicationID -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.microsoft.com/.default' -ServicePrincipal -Tenant $TenantId
$aadGraphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.windows.net/.default' -ServicePrincipal 

Connect-MsolService -AdGraphAccessToken $aadGraphToken.AccessToken -MsGraphAccessToken $graphToken.AccessToken
Connect-Azaccount -AccessToken $azureToken.AccessToken -GraphAccessToken $graphToken.AccessToken -AccountId $upn -TenantId $tenantID 
$Subscriptions = Get-AzSubscription  | Where-Object { $_.State -eq 'Enabled' } | Sort-Object -Unique -Property Id
foreach ($Sub in $Subscriptions) {
    $OrgTenant = ((Invoke-AzRestMethod -path "/subscriptions/$($sub.subscriptionid)/?api-version=2020-06-01" -method GET).content | convertfrom-json).tenantid
    write-host "Processing client $($sub.name)"
    $Domains = get-msoldomain -tenant $OrgTenant
    $null = $Sub | Set-AzContext
    $VMs = Get-azvm -Status | Select-Object PowerState, Name, ProvisioningState, Location, 
    @{Name = 'OS Type'; Expression = { $_.Storageprofile.osdisk.OSType } }, 
    @{Name = 'VM Size'; Expression = { $_.hardwareprofile.vmsize } },
    @{Name = 'OS Disk Type'; Expression = { $_.StorageProfile.osdisk.manageddisk.storageaccounttype } }
    $networks = get-aznetworkinterface | select-object Primary,
    @{Name = 'NSG'; Expression = { ($_.NetworkSecurityGroup).id -split "/" | select-object -last 1 } }, 
    @{Name = 'DNS Settings'; Expression = { ($_.DNSsettings).dnsservers -join ',' } }, 
    @{Name = 'Connected VM'; Expression = { ($_.VirtualMachine).id -split '/' | select-object -last 1 } },
    @{Name = 'Internal IP'; Expression = { ($_.IPConfigurations).PrivateIpAddress -join "," } },
    @{Name = 'External IP'; Expression = { ($_.IPConfigurations).PublicIpAddress.IpAddress -join "," } }, tags
    $NSGs = get-aznetworksecuritygroup | select-object Name, Location,
    @{Name = 'Allowed Destination Ports'; Expression = { ($_.SecurityRules | Where-Object { $_.direction -eq 'inbound' -and $_.Access -eq 'allow' }).DestinationPortRange } } ,
    @{Name = 'Denied Destination Ports'; Expression = { ($_.SecurityRules | Where-Object { $_.direction -eq 'inbound' -and $_.Access -ne 'allow' }).DestinationPortRange } }
    
    $FlexAssetBody = 
    @{
        type       = "flexible-assets"
        attributes = @{
            traits = @{
                "subscription-id" = $sub.SubscriptionId
                "vms"             = ($VMs | convertto-html -Fragment | out-string)
                "nsgs"            = ($NSGs | convertto-html -Fragment | out-string)
                "networks"        = ($networks | convertto-html -Fragment | out-string)
                                     
            }
        }
    }
     



    write-output "             Finding $($sub.name) in IT-Glue"
    $orgid = foreach ($customerDomain in $domains) {
        ($domainList | Where-Object { $_.domain -eq $customerDomain.name }).'OrgID' | Select-Object -Unique
    }
    write-output "             Uploading Azure VMs for $($sub.name) into IT-Glue"
    foreach ($org in $orgID) {
        $ExistingFlexAsset = (Get-ITGlueFlexibleAssets -filter_flexible_asset_type_id $FilterID.id -filter_organization_id $org).data | Where-Object { $_.attributes.traits.'subscription-id' -eq $sub.subscriptionid }
        #If the Asset does not exist, we edit the body to be in the form of a new asset, if not, we just upload.
        if (!$ExistingFlexAsset) {
            if ($FlexAssetBody.attributes.'organization-id') {
                $FlexAssetBody.attributes.'organization-id' = $org 
            }
            else { 
                $FlexAssetBody.attributes.add('organization-id', $org)
                $FlexAssetBody.attributes.add('flexible-asset-type-id', $FilterID.id)
            }
            write-output "                      Creating new Azure VMs for $($sub.name) into IT-Glue organisation $org"
            New-ITGlueFlexibleAssets -data $FlexAssetBody
 
        }
        else {
            write-output "                      Updating Azure VMs $($sub.name) into IT-Glue organisation $org"
            $ExistingFlexAsset = $ExistingFlexAsset | select-object -Last 1
            Set-ITGlueFlexibleAssets -id $ExistingFlexAsset.id  -data $FlexAssetBody
        }
 
    }

}