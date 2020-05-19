#####################################################################
$APIKEy =  "APIKEY"
$orgID = "ORGID"
$APIEndpoint = "https://api.itglue.com"
$FlexAssetName = "Active Directory - AutoDoc"
$Description = "A network one-page document that shows the current configuration for Active Directory."
#####################################################################
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
  
function Get-WinADForestInformation {
    $Data = @{ }
    $ForestInformation = $(Get-ADForest)
    $Data.Forest = $ForestInformation
    $Data.RootDSE = $(Get-ADRootDSE -Properties *)
    $Data.ForestName = $ForestInformation.Name
    $Data.ForestNameDN = $Data.RootDSE.defaultNamingContext
    $Data.Domains = $ForestInformation.Domains
    $Data.ForestInformation = @{
        'Name'                    = $ForestInformation.Name
        'Root Domain'             = $ForestInformation.RootDomain
        'Forest Functional Level' = $ForestInformation.ForestMode
        'Domains Count'           = ($ForestInformation.Domains).Count
        'Sites Count'             = ($ForestInformation.Sites).Count
        'Domains'                 = ($ForestInformation.Domains) -join ", "
        'Sites'                   = ($ForestInformation.Sites) -join ", "
    }
      
    $Data.UPNSuffixes = Invoke-Command -ScriptBlock {
        $UPNSuffixList  =  [PSCustomObject] @{ 
                "Primary UPN" = $ForestInformation.RootDomain
                "UPN Suffixes"   = $ForestInformation.UPNSuffixes -join ","
            }  
        return $UPNSuffixList
    }
      
    $Data.GlobalCatalogs = $ForestInformation.GlobalCatalogs
    $Data.SPNSuffixes = $ForestInformation.SPNSuffixes
      
    $Data.Sites = Invoke-Command -ScriptBlock {
      $Sites = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest().Sites            
        $SiteData = foreach ($Site in $Sites) {          
          [PSCustomObject] @{ 
                "Site Name" = $site.Name
                "Subnets"   = ($site.Subnets) -join ", "
                "Servers" = ($Site.Servers) -join ", "
            }  
        }
        Return $SiteData
    }
      
        
    $Data.FSMO = Invoke-Command -ScriptBlock {
        [PSCustomObject] @{ 
            "Domain" = $ForestInformation.RootDomain
            "Role"   = 'Domain Naming Master'
            "Holder" = $ForestInformation.DomainNamingMaster
        }
 
        [PSCustomObject] @{ 
            "Domain" = $ForestInformation.RootDomain
            "Role"   = 'Schema Master'
            "Holder" = $ForestInformation.SchemaMaster
        }
          
        foreach ($Domain in $ForestInformation.Domains) {
            $DomainFSMO = Get-ADDomain $Domain | Select-Object PDCEmulator, RIDMaster, InfrastructureMaster
 
            [PSCustomObject] @{ 
                "Domain" = $Domain
                "Role"   = 'PDC Emulator'
                "Holder" = $DomainFSMO.PDCEmulator
            } 
 
             
            [PSCustomObject] @{ 
                "Domain" = $Domain
                "Role"   = 'Infrastructure Master'
                "Holder" = $DomainFSMO.InfrastructureMaster
            } 
 
            [PSCustomObject] @{ 
                "Domain" = $Domain
                "Role"   = 'RID Master'
                "Holder" = $DomainFSMO.RIDMaster
            } 
 
        }
          
        Return $FSMO
    }
      
    $Data.OptionalFeatures = Invoke-Command -ScriptBlock {
        $OptionalFeatures = $(Get-ADOptionalFeature -Filter * )
        $Optional = @{
            'Recycle Bin Enabled'                          = ''
            'Privileged Access Management Feature Enabled' = ''
        }
        ### Fix Optional Features
        foreach ($Feature in $OptionalFeatures) {
            if ($Feature.Name -eq 'Recycle Bin Feature') {
                if ("$($Feature.EnabledScopes)" -eq '') {
                    $Optional.'Recycle Bin Enabled' = $False
                }
                else {
                    $Optional.'Recycle Bin Enabled' = $True
                }
            }
            if ($Feature.Name -eq 'Privileged Access Management Feature') {
                if ("$($Feature.EnabledScopes)" -eq '') {
                    $Optional.'Privileged Access Management Feature Enabled' = $False
                }
                else {
                    $Optional.'Privileged Access Management Feature Enabled' = $True
                }
            }
        }
        return $Optional
        ### Fix optional features
    }
    return $Data
}
  
$TableHeader = "<table class=`"table table-bordered table-hover`" style=`"width:80%`">"
$Whitespace = "<br/>"
$TableStyling = "<th>", "<th style=`"background-color:#4CAF50`">"
  
$RawAD = Get-WinADForestInformation
  
$ForestRawInfo = new-object PSCustomObject -property $RawAD.ForestInformation | convertto-html -Fragment | Select-Object -Skip 1
$ForestNice = $TableHeader + ($ForestRawInfo -replace $TableStyling) + $Whitespace
  
$SiteRawInfo = $RawAD.Sites | Select-Object 'Site Name', Servers, Subnets | ConvertTo-Html -Fragment | Select-Object -Skip 1
$SiteNice = $TableHeader + ($SiteRawInfo -replace $TableStyling) + $Whitespace
  
$OptionalRawFeatures = new-object PSCustomObject -property $RawAD.OptionalFeatures | convertto-html -Fragment | Select-Object -Skip 1
$OptionalNice = $TableHeader + ($OptionalRawFeatures -replace $TableStyling) + $Whitespace
  
$UPNRawFeatures = $RawAD.UPNSuffixes |  convertto-html -Fragment -as list| Select-Object -Skip 1
$UPNNice = $TableHeader + ($UPNRawFeatures -replace $TableStyling) + $Whitespace
  
$DCRawFeatures = $RawAD.GlobalCatalogs | ForEach-Object { Add-Member -InputObject $_ -Type NoteProperty -Name "Domain Controller" -Value $_; $_ } | convertto-html -Fragment | Select-Object -Skip 1
$DCNice = $TableHeader + ($DCRawFeatures -replace $TableStyling) + $Whitespace
  
$FSMORawFeatures = $RawAD.FSMO | convertto-html -Fragment | Select-Object -Skip 1
$FSMONice = $TableHeader + ($FSMORawFeatures -replace $TableStyling) + $Whitespace
  
$ForestFunctionalLevel = $RawAD.RootDSE.forestFunctionality
$DomainFunctionalLevel = $RawAD.RootDSE.domainFunctionality
$domaincontrollerMaxLevel = $RawAD.RootDSE.domainControllerFunctionality
  
$passwordpolicyraw = Get-ADDefaultDomainPasswordPolicy | Select-Object ComplexityEnabled, PasswordHistoryCount, LockoutDuration, LockoutThreshold, MaxPasswordAge, MinPasswordAge | convertto-html -Fragment -As List | Select-Object -skip 1
$passwordpolicyheader = "<tr><th><b>Policy</b></th><th><b>Setting</b></th></tr>"
$passwordpolicyNice = $TableHeader + ($passwordpolicyheader -replace $TableStyling) + ($passwordpolicyraw -replace $TableStyling) + $Whitespace
  
$adminsraw = Get-ADGroupMember "Domain Admins" | Select-Object SamAccountName, Name | convertto-html -Fragment | Select-Object -Skip 1
$adminsnice = $TableHeader + ($adminsraw -replace $TableStyling) + $Whitespace
  
$EnabledUsers = (Get-AdUser -filter * | Where-Object { $_.enabled -eq $true }).count
$DisabledUSers = (Get-AdUser -filter * | Where-Object { $_.enabled -eq $false }).count
$AdminUsers = (Get-ADGroupMember -Identity "Domain Admins").count
$Users = @"
There are <b> $EnabledUsers </b> users Enabled<br>
There are <b> $DisabledUSers </b> users Disabled<br>
There are <b> $AdminUsers </b> Domain Administrator users<br>
"@
  
$FlexAssetBody = @{
    type       = 'flexible-assets'
    attributes = @{
        traits = @{
            'domain-name'               = $RawAD.ForestName
            'forest-summary'            = $ForestNice
            'site-summary'              = $SiteNice
            'domain-controllers'        = $DCNice
            'fsmo-roles'                = $FSMONice
            'optional-features'         = $OptionalNice
            'upn-suffixes'              = $UPNNice
            'default-password-policies' = $passwordpolicyNice
            'domain-admins'             = $adminsnice
            'user-count'                = $Users
        }
    }
}
  
#Checking if the FlexibleAsset exists. If not, create a new one.
$FilterID = (Get-ITGlueFlexibleAssetTypes -filter_name $FlexAssetName).data
if (!$FilterID) { 
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
                            name            = "Domain Name"
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
                            name           = "Forest Summary"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 3
                            name           = "Site Summary"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 4
                            name           = "Domain Controllers"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 5
                            name           = "FSMO Roles"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 6
                            name           = "Optional Features"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 7
                            name           = "UPN Suffixes"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 8
                            name           = "Default Password Policies"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 9
                            name           = "Domain Admins"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 10
                            name           = "User Count"
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
  
#Upload data to IT-Glue. We try to match the Server name to current computer name.
$ExistingFlexAsset = (Get-ITGlueFlexibleAssets -filter_flexible_asset_type_id $Filterid.id -filter_organization_id $orgID).data | Where-Object { $_.attributes.traits.'domain-name' -eq $RawAD.ForestName }
  
#If the Asset does not exist, we edit the body to be in the form of a new asset, if not, we just upload.
if (!$ExistingFlexAsset) {
    $FlexAssetBody.attributes.add('organization-id', $orgID)
    $FlexAssetBody.attributes.add('flexible-asset-type-id', $FilterID.id)
    Write-Host "Creating new flexible asset"
    New-ITGlueFlexibleAssets -data $FlexAssetBody
}
else {
    Write-Host "Updating Flexible Asset"
    $ExistingFlexAsset = $ExistingFlexAsset[-1]
    Set-ITGlueFlexibleAssets -id $ExistingFlexAsset.id  -data $FlexAssetBody
} 