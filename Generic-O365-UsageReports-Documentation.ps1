$ApplicationId = 'YourApplicationID'
$ApplicationSecret = 'SecretApplicationSecret' | Convertto-SecureString -AsPlainText -Force
$TenantID = 'YourTenantID'
$RefreshToken = 'SuperSecretRefreshToken'
$upn = 'UPN-Used-To-Generate-Tokens'
##############################
$credential = New-Object System.Management.Automation.PSCredential($ApplicationId, $ApplicationSecret)
write-host "Generating access tokens" -ForegroundColor Green
$graphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.microsoft.com/.default' -ServicePrincipal -Tenant $tenantID
$aadGraphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.windows.net/.default' -ServicePrincipal -Tenant $tenantID
 
write-host "Connecting to MSOLService" -ForegroundColor Green
Connect-MsolService -AdGraphAccessToken $aadGraphToken.AccessToken -MsGraphAccessToken $graphToken.AccessToken
write-host "Grabbing client list" -ForegroundColor Green
$customers = Get-MsolPartnerContract -All
write-host "Connecting to clients" -ForegroundColor Green
 
foreach ($customer in $customers) {
    write-host "Generating token for $($Customer.name)" -ForegroundColor Green
    $graphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.microsoft.com/.default' -ServicePrincipal -Tenant $customer.TenantID
    $Header = @{
        Authorization = "Bearer $($graphToken.AccessToken)"
    }
    write-host "Gathering Reports for $($Customer.name)" -ForegroundColor Green
    #Gathers which devices currently use Teams, and the details for these devices.
    $TeamsDeviceReportsURI = "https://graph.microsoft.com/v1.0/reports/getTeamsDeviceUsageUserDetail(period='D7')"
    $TeamsDeviceReports = (Invoke-RestMethod -Uri $TeamsDeviceReportsURI -Headers $Header -Method Get -ContentType "application/json") -replace "ï»¿", "" | ConvertFrom-Csv | ConvertTo-Html -fragment -PreContent "<h1>Teams device report</h1>" | Out-String
    #Gathers which Users currently use Teams, and the details for these Users.
    $TeamsUserReportsURI = "https://graph.microsoft.com/v1.0/reports/getTeamsUserActivityUserDetail(period='D7')"
    $TeamsUserReports = (Invoke-RestMethod -Uri $TeamsUserReportsURI -Headers $Header -Method Get -ContentType "application/json") -replace "ï»¿", "" | ConvertFrom-Csv | ConvertTo-Html -fragment -PreContent "<h1>Teams user report</h1>"| Out-String
    #Gathers which users currently use email and the details for these Users
    $EmailReportsURI = "https://graph.microsoft.com/v1.0/reports/getEmailActivityUserDetail(period='D7')"
    $EmailReports = (Invoke-RestMethod -Uri $EmailReportsURI -Headers $Header -Method Get -ContentType "application/json") -replace "ï»¿", "" | ConvertFrom-Csv | ConvertTo-Html -fragment -PreContent "<h1>Email users Report</h1>"| Out-String
    #Gathers the storage used for each e-mail user.
    $MailboxUsageReportsURI = "https://graph.microsoft.com/v1.0/reports/getMailboxUsageDetail(period='D7')"
    $MailboxUsage = (Invoke-RestMethod -Uri $MailboxUsageReportsURI -Headers $Header -Method Get -ContentType "application/json") -replace "ï»¿", "" | ConvertFrom-Csv | ConvertTo-Html -fragment -PreContent "<h1>Email storage report</h1>"| Out-String
    #Gathers the activations for each user of office.
    $O365ActivationsReportsURI = "https://graph.microsoft.com/v1.0/reports/getOffice365ActivationsUserDetail"
    $O365ActivationsReports = (Invoke-RestMethod -Uri $O365ActivationsReportsURI -Headers $Header -Method Get -ContentType "application/json") -replace "ï»¿", "" | ConvertFrom-Csv | ConvertTo-Html -fragment -PreContent "<h1>O365 Activation report</h1>"| Out-String
    #Gathers the Onedrive activity for each user.
    $OneDriveActivityURI = "https://graph.microsoft.com/v1.0/reports/getOneDriveActivityUserDetail(period='D7')"
    $OneDriveActivityReports = (Invoke-RestMethod -Uri $OneDriveActivityURI -Headers $Header -Method Get -ContentType "application/json") -replace "ï»¿", "" | ConvertFrom-Csv | ConvertTo-Html -fragment -PreContent "<h1>Onedrive Activity report</h1>"| Out-String
    #Gathers the Onedrive usage for each user.
    $OneDriveUsageURI = "https://graph.microsoft.com/v1.0/reports/getOneDriveUsageAccountDetail(period='D7')"
    $OneDriveUsageReports = (Invoke-RestMethod -Uri $OneDriveUsageURI -Headers $Header -Method Get -ContentType "application/json") -replace "ï»¿", "" | ConvertFrom-Csv | ConvertTo-Html -fragment -PreContent "<h1>OneDrive usage report</h1>"| Out-String
    #Gathers the Sharepoint usage for each user.
    $SharepointUsageReportsURI = "https://graph.microsoft.com/v1.0/reports/getSharePointSiteUsageDetail(period='D7')"
    $SharepointUsageReports = (Invoke-RestMethod -Uri $SharepointUsageReportsURI -Headers $Header -Method Get -ContentType "application/json") -replace "ï»¿", "" | ConvertFrom-Csv | ConvertTo-Html -fragment -PreContent "<h1>Sharepoint usage report</h1>"| Out-String
 
$head = 
@"
      <Title>O365 Reports</Title>
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
 
$head,$TeamsDeviceReports,$TeamsUserReports,$EmailReports,$MailboxUsage,$O365ActivationsReports,$OneDriveActivityReports,$OneDriveUsageReports,$SharepointUsageReports | out-file "C:\Temp\$($Customer.name).html"
 
 
}