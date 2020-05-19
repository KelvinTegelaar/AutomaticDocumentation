########################## IT-Glue ############################
$APIKEy = "YourITGlueAPIKey"
$APIEndpoint = "https://api.eu.itglue.com"
$FlexAssetName = "intune - Application documentation v1"
$Description = "Documentation for all registered intune applications"
########################## IT-Glue ############################
 
########################## Secure App Model Settings ############################
$ApplicationId = 'YourApplicationID'
$ApplicationSecret = 'yourApplicationsecret' | Convertto-SecureString -AsPlainText -Force
$TenantID = 'YourtenantID'
$RefreshToken = 'verylongrefreshtoken'
$upn = 'UPN-Used-To-Generate-Tokens'
########################## Secure App Model Settings ############################
 
write-host "Grabbing IT-Glue module" -ForegroundColor Green
 
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
                            order          = 2
                            name           = "Tenant ID"
                            kind           = "Text"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 3
                            name           = "Application info"
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
 
 
write-host "Generating token to log into Azure AD. Grabbing all tenants" -ForegroundColor Green
 
$credential = New-Object System.Management.Automation.PSCredential($ApplicationId, $ApplicationSecret)
$Baseuri = "https://graph.microsoft.com/beta"
$aadGraphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.windows.net/.default' -ServicePrincipal -Tenant $tenantID
$graphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.microsoft.com/.default' -ServicePrincipal -Tenant $tenantID
Connect-AzureAD -AadAccessToken $aadGraphToken.AccessToken -AccountId $upn -MsAccessToken $graphToken.AccessToken -TenantId $tenantID | Out-Null
$tenants = Get-AzureAdContract -All:$true
Disconnect-AzureAD
foreach ($Tenant in $Tenants) {
    $CustAadGraphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes "https://graph.windows.net/.default" -ServicePrincipal -Tenant $tenant.CustomerContextId
    $CustGraphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes "https://graph.microsoft.com/.default" -ServicePrincipal -Tenant $tenant.CustomerContextId
    Connect-AzureAD -AadAccessToken $CustAadGraphToken.AccessToken -AccountId $upn -MsAccessToken $CustGraphToken.AccessToken -TenantId $tenant.CustomerContextId | out-null
    write-host "Starting documentation process for $($Tenant.Displayname)" -ForegroundColor Green
    $Header = @{
        Authorization = "Bearer $($CustGraphToken.AccessToken)"
    }
 
    write-host "Grabbing all applications for $($Tenant.Displayname)." -ForegroundColor Green
    try {
        $ApplicationList = (Invoke-RestMethod -Uri "$baseuri/deviceAppManagement/mobileApps/?`$expand=categories,assignments" -Headers $Header -Method get -ContentType "application/json").value | Where-Object { $_.'@odata.type' -eq "#microsoft.graph.win32LobApp" }
    }
    catch {
        write-host "     Could not grab application list for $($Tenant.Displayname). Is intune configured? Error was: $($_.Exception.Message)" -ForegroundColor Yellow
        continue
    }
    $Applications = foreach ($Application in $ApplicationList) {
        write-host "              grabbing Application Assignment for $($Application.displayname)" -ForegroundColor Green
        $GroupsRequired = foreach ($ApplicationAssign in $Application.assignments | where-object { $_.intent -eq "Required" }) {
            (Invoke-RestMethod -Uri "$baseuri/groups/$($Applicationassign.target.groupId)" -Headers $Header -Method get -ContentType "application/json").value.displayName
        }
        $GroupsAvailable = foreach ($ApplicationAssign in $Application.assignments | where-object { $_.intent -eq "Available" }) {
            (Invoke-RestMethod -Uri "$baseuri/groups/$($Applicationassign.target.groupId)" -Headers $Header -Method get -ContentType "application/json").value.displayName
        }
        [pscustomobject]@{
            Displayname               = $Application.Displayname
            description               = $Application.description
            Publisher                 = $application.Publisher
            "Featured Application"    = $application.IsFeatured
            Notes                     = $Application.notes
            "Application is assigned" = $application.isassigned
            "Install Command"         = $Application.InstallCommandLine
            "Uninstall Command"       = $Application.Uninstallcommandline
            "Architectures"           = $Application.applicableArchitectures
            "Created on"              = $Application.createdDateTime
            "Last Modified"           = $Application.LastModifieddatetime
            "Privacy Information URL" = $Application.PrivacyInformationURL
            "Information URL"         = $Application.PrivacyInformationURL
            "Required for group"      = $GroupsRequired -join "`n'"
            "Available to group"      = $GroupsAvailable -join "`n"
        } 
 
    }
    $TableStyling = "<th>", "<th> <style=`"background-color:#4CAF50`">"
    $AppHTML = ($applications | convertto-html -Fragment | out-string) -replace $TableStyling
 
    $FlexAssetBody =
    @{
        type       = 'flexible-assets'
        attributes = @{
            traits = @{
                'tenant-name'      = $tenant.DisplayName
                'tenant-id'        = $tenant.CustomerContextId
                'application-info' = $AppHTML
            }
        }
    }
    $customerdomains = get-azureaddomain
    $PrimaryDomain = ($customerdomains | Where-Object { $_.IsDefault -eq $true }).name
    Write-Host "          Finding $($customer.name) in IT-Glue" -ForegroundColor Green
    $orgID = @()
    foreach ($customerDomain in $customerdomains) {
        $orgID += ($AllITGlueContacts | Where-Object { $_.'contact-emails'.value -match $customerDomain.name }).'organization-id' | Select-Object -Unique
    }
    write-host "             Uploading Application list $($customer.name) into IT-Glue"  -ForegroundColor Green
    foreach ($org in $orgID) {
        $ExistingFlexAsset = (Get-ITGlueFlexibleAssets -filter_flexible_asset_type_id $($filterID.ID) -filter_organization_id $org).data | Where-Object { $_.attributes.traits.'tenant-id' -eq $tenant.CustomerContextId }
        #If the Asset does not exist, we edit the body to be in the form of a new asset, if not, we just upload.
        if (!$ExistingFlexAsset) {
            $FlexAssetBody.attributes.add('organization-id', $org)
            $FlexAssetBody.attributes.add('flexible-asset-type-id', $($filterID.ID))
            write-host "                      Creating new Application list $($customer.name) into IT-Glue organisation $org" -ForegroundColor Green
            New-ITGlueFlexibleAssets -data $FlexAssetBody
        }
        else {
            write-host "                      Updating Application list$($customer.name) into IT-Glue organisation $org"  -ForegroundColor Green
            $ExistingFlexAsset = $ExistingFlexAsset | select-object -last 1
            Set-ITGlueFlexibleAssets -id $ExistingFlexAsset.id -data $FlexAssetBody
        }
        Disconnect-AzureAD
    }
 
 
}