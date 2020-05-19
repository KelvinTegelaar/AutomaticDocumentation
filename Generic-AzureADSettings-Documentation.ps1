########################## Azure AD ###########################
$ApplicationId         = 'xxxx-xxxx-xxx-xxxx-xxxx'
$ApplicationSecret     = 'TheSecretTheSecret' | Convertto-SecureString -AsPlainText -Force
$TenantID              = 'YourTenantID'
$RefreshToken          = 'RefreshToken'
$ExchangeRefreshToken  = 'ExchangeRefreshToken'
$upn                   = 'UPN-Used-To-Generate-Tokens'
########################## Azure AD ###########################
#Connect to your Azure AD Account.
$credential = New-Object System.Management.Automation.PSCredential($ApplicationId, $ApplicationSecret)
$aadGraphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.windows.net/.default' -ServicePrincipal -Tenant $tenantID 
$graphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.microsoft.com/.default' -ServicePrincipal -Tenant $tenantID 
Connect-AzureAD -AadAccessToken $aadGraphToken.AccessToken -AccountId $UPN -MsAccessToken $graphToken.AccessToken -TenantId $tenantID | Out-Null
$Customers = Get-AzureADContract -All:$true
Disconnect-AzureAD
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

    $NormalUsers = $users | Where-Object { $_.UserType -eq "Member" } | Select-Object DisplayName, mail,ProxyAddresses | ConvertTo-Html -PreContent "<h2>Users</h2>" -Fragment | Out-String
    $NormalUsers = $TableHeader + ($NormalUsers -replace $TableStyling) + $Whitespace
    $GuestUsers = $users | Where-Object { $_.UserType -ne "Member" } | Select-Object DisplayName, mail | ConvertTo-Html -PreContent "<h2>Guests</h2>" -Fragment | Out-String
    $GuestUsers =  $TableHeader + ($GuestUsers -replace $TableStyling) + $Whitespace
    $AdminUsers = $AdminUsers | Select-Object Displayname, mail | ConvertTo-Html -PreContent "<h2>Admins</h2>" -Fragment | Out-String
    $AdminUsers = $TableHeader + ($AdminUsers  -replace $TableStyling) + $Whitespace
    $Devices = $Devices | select-object DisplayName, DeviceOSType, DEviceOSversion, ApproximateLastLogonTimeStamp | ConvertTo-Html -PreContent "<h2>Devices</h2>" -Fragment | Out-String
    $Devices =  $TableHeader + ($Devices -replace $TableStyling) + $Whitespace
    $HTMLDomains = $customerdomains | Select-Object Name, IsDefault, IsInitial, Isverified | ConvertTo-Html -PreContent "<h2>Domains</h2>" -Fragment | Out-String
    $HTMLDomains = $TableHeader + ($HTMLDomains -replace $TableStyling) + $Whitespace
    $Applications = $Applications | Select-Object Displayname, AvailableToOtherTenants,PublisherDomain | ConvertTo-Html -PreContent "<h2>Applications</h2>" -Fragment | Out-String
    $Applications = $TableHeader + ($Applications -replace $TableStyling) + $Whitespace
    $head = @"
    <script>
    function myFunction() {
        const filter = document.querySelector('#myInput').value.toUpperCase();
        const trs = document.querySelectorAll('table tr:not(.header)');
        trs.forEach(tr => tr.style.display = [...tr.children].find(td => td.innerHTML.toUpperCase().includes(filter)) ? '' : 'none');
      }</script>
    <Title>Audit Log Report</Title>
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
    #myInput {
      background-image: url('https://www.w3schools.com/css/searchicon.png'); /* Add a search icon to input */
      background-position: 10px 12px; /* Position the search icon */
      background-repeat: no-repeat; /* Do not repeat the icon image */
      width: 50%; /* Full-width */
      font-size: 16px; /* Increase font-size */
      padding: 12px 20px 12px 40px; /* Add some padding */
      border: 1px solid #ddd; /* Add a grey border */
      margin-bottom: 12px; /* Add some space below the input */
    }
    </style>
"@
write-host "      Done - Creating HTML file for $($customer.Displayname)" -foregroundColor green
    $head, $NormalUsers,$GuestUsers,$AdminUsers,$Applications, $Devices,$HTMLDomains | Out-File "C:\temp\$($customer.displayname).html"
}