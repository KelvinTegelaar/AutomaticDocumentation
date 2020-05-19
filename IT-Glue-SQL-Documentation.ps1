#####################################################################
$APIKEy = "ITGLUEAPIKEY"
$APIEndpoint = "https://api.eu.itglue.com"
$orgID = "ORGIDHERE"
$FlexAssetName = "ITGLue AutoDoc - SQL Server"
$Description = "SQL Server settings and configuration, Including databases."
#####################################################################
If (Get-Module -ListAvailable -Name "ITGlueAPI") { Import-module ITGlueAPI } Else { install-module ITGlueAPI -Force; import-module ITGlueAPI }
#Settings IT-Glue logon information
Add-ITGlueBaseURI -base_uri $APIEndpoint
Add-ITGlueAPIKey $APIKEy
#Collect Data
import-module SQLPS
$Instances = Get-ChildItem "SQLSERVER:\SQL\$($ENV:COMPUTERNAME)"
foreach ($Instance in $Instances) {
    $databaseList = get-childitem "SQLSERVER:\SQL\$($ENV:COMPUTERNAME)\$($Instance.Displayname)\Databases"
    $Databases = @()
    foreach ($Database in $databaselist) {
        $Databaseobj = New-Object -TypeName PSObject
        $Databaseobj | Add-Member -MemberType NoteProperty -Name "Name" -value $Database.Name
        $Databaseobj | Add-Member -MemberType NoteProperty -Name "Status" -value $Database.status
        $Databaseobj | Add-Member -MemberType NoteProperty -Name  "RecoveryModel" -value $Database.RecoveryModel
        $Databaseobj | Add-Member -MemberType NoteProperty -Name  "LastBackupDate" -value $Database.LastBackupDate
        $Databaseobj | Add-Member -MemberType NoteProperty -Name  "DatabaseFiles" -value $database.filegroups.files.filename
        $Databaseobj | Add-Member -MemberType NoteProperty -Name  "Logfiles"      -value $database.LogFiles.filename
        $Databaseobj | Add-Member -MemberType NoteProperty -Name  "MaxSize" -value $database.filegroups.files.MaxSize
        $Databases += $Databaseobj
    }
    $InstanceInfo = $Instance | Select-Object DisplayName, Collation, AuditLevel, BackupDirectory, DefaultFile, DefaultLog, Edition, ErrorLogPath | convertto-html -PreContent "&lt;h1>Settings&lt;/h1>" -Fragment | Out-String
    $Instanceinfo = $instanceinfo -replace "&lt;th>", "&lt;th style=`"background-color:#4CAF50`">"
    $InstanceInfo = $InstanceInfo -replace "&lt;table>", "&lt;table class=`"table table-bordered table-hover`" style=`"width:80%`">"
    $DatabasesHTML = $Databases | ConvertTo-Html -fragment -PreContent "&lt;h3>Database Settings&lt;/h3>" | Out-String
    $DatabasesHTML = $DatabasesHTML -replace "&lt;th>", "&lt;th style=`"background-color:#4CAF50`">"
    $DatabasesHTML = $DatabasesHTML -replace "&lt;table>", "&lt;table class=`"table table-bordered table-hover`" style=`"width:80%`">"



    #Tagging devices
    $DeviceAsset = @()
    If ($TagRelatedDevices -eq $true) {
        Write-Host "Finding all related resources - Based on computername: $ENV:COMPUTERNAME"
        foreach ($hostfound in $networkscan | Where-Object { $_.Ping -ne $false }) {
            $DeviceAsset += (Get-ITGlueConfigurations -page_size "1000" -filter_name $ENV:COMPUTERNAME -organization_id $orgID).data 
        }
    }     
    $FlexAssetBody = 
    @{
        type       = 'flexible-assets'
        attributes = @{
            name   = $FlexAssetName
            traits = @{
                "instance-name"     = "$($ENV:COMPUTERNAME)\$($Instance.displayname)"
                "instance-settings" = $InstanceInfo
                "databases"         = $DatabasesHTML
                "tagged-devices"    = $DeviceAsset.ID
                    
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
                                name            = "Instance Name"
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
                                name           = "Instance Settings"
                                kind           = "Textbox"
                                required       = $false
                                "show-in-list" = $true
                            }
                        },
                        @{
                            type       = "flexible_asset_fields"
                            attributes = @{
                                order          = 3
                                name           = "Databases"
                                kind           = "Textbox"
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
    $ExistingFlexAsset = (Get-ITGlueFlexibleAssets -filter_flexible_asset_type_id $Filterid.id -filter_organization_id $orgID).data | Where-Object { $_.attributes.traits.'instance-name' -eq "$($ENV:COMPUTERNAME)\$($Instance.displayname)" }
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
}