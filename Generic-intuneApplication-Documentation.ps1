########################## Secure App Model Settings ############################
$ApplicationId = 'YourApplicationID'
$ApplicationSecret = 'yourApplicationsecret' | Convertto-SecureString -AsPlainText -Force
$TenantID = 'YourtenantID'
$RefreshToken = 'verylongrefreshtoken'
$upn = 'yourupn'
########################## Secure App Model Settings ############################
write-host "Generating token to log into Azure AD. Grabbing all tenants" -ForegroundColor Green
 
$credential = New-Object System.Management.Automation.PSCredential($ApplicationId, $ApplicationSecret)
$Baseuri = "https://graph.microsoft.com/beta"
$aadGraphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.windows.net/.default' -ServicePrincipal -Tenant $tenantID
$graphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.microsoft.com/.default' -ServicePrincipal -Tenant $tenantID
Connect-AzureAD -AadAccessToken $aadGraphToken.AccessToken -AccountId $upn -MsAccessToken $graphToken.AccessToken -TenantId $tenantID
$PreContent = @"
<H1> Graph Application Documentation</H1><br>
 
<br>Please note that this documentation only includes windows line-of-business applications and excludes the default applications such as ios and android applications.
<br/>
<br/>
 
<input type="text" id="myInput" onkeyup="myFunction()" placeholder="Search...">
"@
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
$tenants = Get-AzureAdContract -All:$true
 
 
 
foreach ($Tenant in $Tenants) {
    write-host "Starting documentation process for $($Tenant.Displayname)" -ForegroundColor Green
    $CustomergraphToken = New-PartnerAccessToken -ApplicationId $ApplicationId -Credential $credential -RefreshToken $refreshToken -Scopes 'https://graph.microsoft.com/.default' -ServicePrincipal -Tenant $Tenant.CustomerContextId
    $Header = @{
        Authorization = "Bearer $($CustomergraphToken.AccessToken)"
    }
 
    write-host "Grabbing all applications for $($Tenant.Displayname)." -ForegroundColor Green
    try {
        $ApplicationList = (Invoke-RestMethod -Uri "$baseuri/deviceAppManagement/mobileApps/?`$expand=categories,assignments" -Headers $Header -Method get -ContentType "application/json").value | Where-Object {$_.'@odata.type' -eq "#microsoft.graph.win32LobApp"}
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
    $applications | ConvertTo-Html -head $head -PreContent $PreContent | out-file "C:\temp\$($Tenant.Displayname).html"
 
}