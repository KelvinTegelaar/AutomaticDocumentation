#Head for HTML file
$head = @"
<Title>Server AD report</Title>
<style>
body { background-color:#E5E4E2;
      font-family:Monospace;
      font-size:10pt; }
td, th { border:0px solid black; 
        border-collapse:collapse;
        white-space:pre; }
th { color:white;
    background-color:black; }
table, tr, td, th {
     padding: 2px; 
     margin: 0px;
     white-space:pre; }
tr:nth-child(odd) {background-color: lightgray}
table { width:95%;margin-left:5px; margin-bottom:20px; }
h2 {
font-family:Tahoma;
color:#6D7B8D;
}
.footer 
{ color:green; 
 margin-left:10px; 
 font-family:Tahoma;
 font-size:8pt;
 font-style:italic;
}
</style>
"@
 
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
  
$UPNRawFeatures = $RawAD.UPNSuffixes | convertto-html -Fragment | Select-Object -Skip 1
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
 
$HTMLFile = @"
$head
<b>Domain Name</b>: $($RawAD.ForestName) <br>
<br>
<h1>Forest Configuration</h1> <br>
$ForestNice
<br>
<h1>Site Summary</h1> <br>
$SiteNice
<br>
<h1>Domain Controllers</h1> <br>
$DCNice
<br>
<h1>FSMO Roles</h1>
$FSMONice
<h1>Optional Features</h1>
$OptionalNice
<br>
<h1>UPN Suffixes</h1>
$UPNNice
<br>
<h1>Password Policies</h1>
$passwordpolicyNice
<br>
<h1>Domain Admins</h1>
$adminsnice
<br>
<h1>Domain Admins</h1>
$Users
<br>
"@
$HTMLFile | out-file C:\Temp\ServerDoc.html 