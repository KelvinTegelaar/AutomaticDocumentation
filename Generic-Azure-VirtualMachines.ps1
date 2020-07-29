######### Secrets #########
$ApplicationId = 'ApplicationID'
$ApplicationSecret = 'AppSecret' | ConvertTo-SecureString -Force -AsPlainText
$TenantID = 'TenantID'
$RefreshToken = 'LongRefreshToken'
$UPN = "limenetworks@limenetworks.nl"
######### Secrets #########
$credential = New-Object System.Management.Automation.PSCredential($ApplicationId, $ApplicationSecret)
$azureToken = New-PartnerAccessToken -ApplicationId $ApplicationID -Credential $credential -RefreshToken $refreshToken -Scopes 'https://management.azure.com/user_impersonation' -ServicePrincipal -Tenant $TenantId
$graphToken = New-PartnerAccessToken -ApplicationId $ApplicationID -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.microsoft.com/.default' -ServicePrincipal -Tenant $TenantId

Connect-Azaccount -AccessToken $azureToken.AccessToken -GraphAccessToken $graphToken.AccessToken -AccountId $upn -TenantId $tenantID 
$Subscriptions = Get-AzSubscription  | Where-Object { $_.State -eq 'Enabled' } | Sort-Object -Unique -Property Id
foreach ($Sub in $Subscriptions) {
    write-host "Processing client $($sub.name)"
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
    @{Name = 'Allowed Destination Ports'; Expression = { ($_.SecurityRules | Where-Object { $_.direction -eq 'inbound' -and $_.Access -eq 'allow'}).DestinationPortRange}  } ,
    @{Name = 'Denied Destination Ports'; Expression = { ($_.SecurityRules | Where-Object { $_.direction -eq 'inbound' -and $_.Access -ne 'allow'}).DestinationPortRange} }
    
    New-HTML {
        New-HTMLTab -Name 'Azure VM documentation' {
                New-HTMLSection -HeaderText 'Virtual Machines' {
                    New-HTMLTable -DataTable $VMs
                }
                New-HTMLSection -Invisible {
                New-HTMLSection -HeaderText 'Network Security Groups' {
                    New-HTMLTable -DataTable $NSGs
                }

                New-HTMLSection -HeaderText "Networks" {
                    New-HTMLTable -DataTable $networks
                }
            }
            }
        } -FilePath "C:\temp\$($sub.name) .html" -Online

}