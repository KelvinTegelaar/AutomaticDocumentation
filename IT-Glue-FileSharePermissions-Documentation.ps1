    #####################################################################
    $APIKEy =  "APIKEYHERE"
    $APIEndpoint = "https://api.eu.itglue.com"
    $orgID = "ORGIDHERE"
    $FlexAssetName = "ITGLue AutoDoc - File Share v2"
    $Description = "a list of unique file share permissions"
    $RecursiveDepth = 2
    #####################################################################
    If(Get-Module -ListAvailable -Name "ITGlueAPI") {Import-module ITGlueAPI} Else { install-module ITGlueAPI -Force; import-module ITGlueAPI}
    If(Get-Module -ListAvailable -Name "NTFSSecurity") {Import-module "NTFSSecurity"} Else { install-module "NTFSSecurity" -Force; import-module "NTFSSecurity"}
    #Settings IT-Glue logon information
    Add-ITGlueBaseURI -base_uri $APIEndpoint
    Add-ITGlueAPIKey $APIKEy
    #Collect Data
    $AllsmbShares = get-smbshare | Where-Object {(@('Remote Admin','Default share','Remote IPC') -notcontains $_.Description)}
    foreach($SMBShare in $AllSMBShares){
    $Permissions = get-item $SMBShare.path | get-ntfsaccess
    $Permissions += get-childitem -Depth $RecursiveDepth -Recurse $SMBShare.path | get-ntfsaccess
    $FullAccess = $permissions | where-object {$_.'AccessRights' -eq "FullControl" -AND $_.IsInherited -eq $false -AND $_.'AccessControlType' -ne "Deny"}| Select-Object FullName,Account,AccessRights,AccessControlType  | ConvertTo-Html -Fragment | Out-String
    $Modify = $permissions | where-object {$_.'AccessRights' -Match "Modify" -AND $_.IsInherited -eq $false -and $_.'AccessControlType' -ne "Deny"}| Select-Object FullName,Account,AccessRights,AccessControlType  | ConvertTo-Html -Fragment | Out-String
    $ReadOnly = $permissions | where-object {$_.'AccessRights' -Match "Read" -AND $_.IsInherited -eq $false -and $_.'AccessControlType' -ne "Deny"}| Select-Object FullName,Account,AccessRights,AccessControlType  | ConvertTo-Html -Fragment | Out-String
    $Deny =   $permissions | where-object {$_.'AccessControlType' -eq "Deny" -AND $_.IsInherited -eq $false} | Select-Object FullName,Account,AccessRights,AccessControlType | ConvertTo-Html -Fragment | Out-String

if($FullAccess.Length /1kb -gt 64) { $FullAccess = "The table is too long to display. Please see included CSV file."}
if($ReadOnly.Length /1kb -gt 64) { $ReadOnly = "The table is too long to display. Please see included CSV file."}
if($Modify.Length /1kb -gt 64) { $Modify = "The table is too long to display. Please see included CSV file."}
if($Deny.Length /1kb -gt 64) { $Deny = "The table is too long to display. Please see included CSV file."}
$PermCSV = ($Permissions | ConvertTo-Csv -NoTypeInformation -Delimiter ",") -join [Environment]::NewLine
$Bytes = [System.Text.Encoding]::UTF8.GetBytes($PermCSV)
$Base64CSV =[Convert]::ToBase64String($Bytes)    
    #Tagging devices
        $DeviceAsset = @()
        If($TagRelatedDevices -eq $true){
            Write-Host "Finding all related resources - Based on computername: $ENV:COMPUTERNAME"
            foreach($hostfound in $networkscan | Where-Object { $_.Ping -ne $false}){
            $DeviceAsset += (Get-ITGlueConfigurations -page_size "1000" -filter_name $ENV:COMPUTERNAME -organization_id $orgID).data }
            }     
    $FlexAssetBody = 
    @{
        type = 'flexible-assets'
        attributes = @{
                name = $FlexAssetName
                traits = @{
                    "share-name" = $($smbshare.name)
                    "share-path" = $($smbshare.path)
                    "full-control-permissions" = $FullAccess
                    "read-permissions" = $ReadOnly
                    "modify-permissions" = $Modify
                    "deny-permissions" = $Deny
                    "tagged-devices" = $DeviceAsset.ID
                    "csv-file" = @{
                        "content" = $Base64CSV
                        "file_name" = "Permissions.csv"
                    }
                }
        }
    }
    #Checking if the FlexibleAsset exists. If not, create a new one.
    $FilterID = (Get-ITGlueFlexibleAssetTypes -filter_name $FlexAssetName).data
    if(!$FilterID){ 
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
                                name            = "Share Name"
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
                                name           = "Share Path"
                                kind           = "Text"
                                required       = $false
                                "show-in-list" = $true
                            }
                        },
                        @{
                            type       = "flexible_asset_fields"
                            attributes = @{
                                order          = 3
                                name           = "Full Control Permissions"
                                kind           = "Textbox"
                                required       = $false
                                "show-in-list" = $false
                            }
                        },
                        @{
                            type       = "flexible_asset_fields"
                            attributes = @{
                                order          = 4
                                name           = "Modify Permissions"
                                kind           = "Textbox"
                                required       = $false
                                "show-in-list" = $false
                            }
                        },
                        @{
                            type       = "flexible_asset_fields"
                            attributes = @{
                                order          = 5
                                name           = "Read permissions"
                                kind           = "Textbox"
                                required       = $false
                                "show-in-list" = $false
                            }
                        },
                        @{
                            type       = "flexible_asset_fields"
                            attributes = @{
                                order          = 6
                                name           = "Deny permissions"
                                kind           = "Textbox"
                                required       = $false
                                "show-in-list" = $false
                            }
                        },
                        @{
                            type       = "flexible_asset_fields"
                            attributes = @{
                                order          = 7
                                name           = "CSV File"
                                kind           = "Upload"
                                required       = $false
                                "show-in-list" = $false
                            }
                        },
                        @{
                            type       = "flexible_asset_fields"
                            attributes = @{
                                order          = 8
                                name           = "Tagged Devices"
                                kind           = "Tag"
                                "tag-type"     = "Configurations"
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
    $ExistingFlexAsset = (Get-ITGlueFlexibleAssets -filter_flexible_asset_type_id $Filterid.id -filter_organization_id $orgID).data | Where-Object {$_.attributes.name -eq $($SMBShare.name)}
    #If the Asset does not exist, we edit the body to be in the form of a new asset, if not, we just upload.
    if(!$ExistingFlexAsset){
    $FlexAssetBody.attributes.add('organization-id', $orgID)
    $FlexAssetBody.attributes.add('flexible-asset-type-id', $FilterID.id)
    Write-Host "Creating new flexible asset"
    New-ITGlueFlexibleAssets -data $FlexAssetBody
    } else {
    Write-Host "Updating Flexible Asset"
    $ExistingFlexAsset = $ExistingFlexAsset[-1]
    Set-ITGlueFlexibleAssets -id $ExistingFlexAsset.id  -data $FlexAssetBody}
    }