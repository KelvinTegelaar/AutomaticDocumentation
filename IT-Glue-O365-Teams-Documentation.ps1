################### Secure Application Model Information ###################
$ApplicationId = 'YourApplicationID'
$ApplicationSecret = 'YourApplicationSecret'
$RefreshToken = 'YourVeryLongRefreshToken'
################# /Secure Application Model Information ####################
 
################# IT-Glue Information ######################################
$ITGkey = "YourITGAPIKEY"
$ITGbaseURI = "https://api.eu.itglue.com"
$FlexAssetName = "Teams - Autodoc"
$Description = "Teams information automatically retrieved."
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
                            name            = "Team Name"
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
                            name            = "Team URL"
                            kind            = "Text"
                            required        = $true
                            "show-in-list"  = $false
                            "use-for-title" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 3
                            name           = "Team Message settings"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 4
                            name           = "Team Member settings"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 5
                            name           = "Team Guest settings"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 6
                            name           = "Team Fun Settings"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 7
                            name           = "Team Owners"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 8
                            name           = "Team Members"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 9
                            name           = "Team Guests"
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
 
write-host "Connecting to Office365 to get all tenants." -ForegroundColor Green
Connect-MsolService -AdGraphAccessToken $aadGraphToken.AccessToken -MsGraphAccessToken $graphToken.AccessToken
$customers = Get-MsolPartnerContract -All
foreach ($Customer in $Customers) {
    write-host "Grabbing domains for client $($Customer.name)." -ForegroundColor Green
    $CustomerDomains = Get-MsolDomain -TenantId $Customer.TenantId
    write-host "Finding possible organisation IDs" -ForegroundColor Green
    $orgid = foreach ($customerDomain in $customerdomains) {
        ($domainList | Where-Object { $_.domain -eq $customerDomain.name }).'OrgID' | Select-Object -Unique
    }
    write-host "Documenting in the following organizations." -ForegroundColor Green
    $ClientToken = Invoke-RestMethod -Method post -Uri "https://login.microsoftonline.com/$($customer.tenantid)/oauth2/token" -Body $body -ErrorAction Stop
    $headers = @{ "Authorization" = "Bearer $($ClientToken.access_token)" }
    write-host "Starting documentation process for $($customer.name)." -ForegroundColor Green
    Write-Host "Grabbing all Teams" -ForegroundColor Green
    $AllTeamsURI = "https://graph.microsoft.com/beta/groups?`$filter=resourceProvisioningOptions/Any(x:x eq 'Team')&`$top=999"
    $Teams = (Invoke-RestMethod -Uri $AllTeamsURI -Headers $Headers -Method Get -ContentType "application/json").value
    Write-Host "Grabbing all Team Settings" -ForegroundColor Green
    foreach ($Team in $Teams) {
        $Settings = (Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/Teams/$($team.id)" -Headers $Headers -Method Get -ContentType "application/json")
        $Members = (Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/groups/$($team.id)/members?`$top=999" -Headers $Headers -Method Get -ContentType "application/json").value
        $Owners = (Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/groups/$($team.id)/Owners?`$top=999" -Headers $Headers -Method Get -ContentType "application/json").value
 
        $FlexAssetBody =
        @{
            type       = 'flexible-assets'
            attributes = @{
                traits = @{
                    'team-name'             = $settings.displayname
                    'team-url'              = $settings.webUrl
                    'team-message-settings' = ($settings.messagingSettings | convertto-html -Fragment -as list | out-string) -replace $TableStyling
                    'team-member-settings'  = ($Settings.memberSettings | convertto-html -Fragment -as list | out-string) -replace $TableStyling
                    "team-guest-settings"   = ($Settings.guestSettings | convertto-html -Fragment -as list | out-string) -replace $TableStyling
                    "team-fun-settings"     = ($settings.funSettings | convertto-html -Fragment -as list | out-string) -replace $TableStyling
                    'team-owners'           = ($Owners | Select-Object Displayname, UserPrincipalname | convertto-html -Fragment | out-string) -replace $TableStyling
                    'team-members'          = ($Members | Where-Object { $_.UserType -eq "Member" } | Select-Object Displayname, UserPrincipalname | convertto-html -Fragment | out-string) -replace $TableStyling
                    'team-guests'           = ($Members | Where-Object { $_.UserType -eq "Guest" } | Select-Object Displayname, UserPrincipalname | convertto-html -Fragment | out-string) -replace $TableStyling
                }
            }
        }
 
        write-host "   Uploading $($Settings.displayName) into IT-Glue" -foregroundColor green
        foreach ($org in $orgID | Select-Object -Unique) {
            $ExistingFlexAsset = (Get-ITGlueFlexibleAssets -filter_flexible_asset_type_id $FilterID.id -filter_organization_id $org).data | Where-Object { $_.attributes.traits.'team-name' -eq $Settings.displayName }
            #If the Asset does not exist, we edit the body to be in the form of a new asset, if not, we just upload.
            if (!$ExistingFlexAsset) {
                if ($FlexAssetBody.attributes.'organization-id') {
                    $FlexAssetBody.attributes.'organization-id' = $org
                }
                else { 
                    $FlexAssetBody.attributes.add('organization-id', $org)
                    $FlexAssetBody.attributes.add('flexible-asset-type-id', $FilterID.id)
                }
                write-output "                      Creating new Team: $($Settings.displayName) into IT-Glue organisation $org"
                New-ITGlueFlexibleAssets -data $FlexAssetBody
     
            }
            else {
                write-output "                      Updating Team: $($Settings.displayName)into IT-Glue organisation $org"
                $ExistingFlexAsset = $ExistingFlexAsset | select-object -Last 1
                Set-ITGlueFlexibleAssets -id $ExistingFlexAsset.id  -data $FlexAssetBody
            }
     
        }
    }
}