$TenantID = 'CUSTOMERTENANT.ONMICROSOFT.COM'
$ApplicationId = "YOURPPLICTIONID"
$ApplicationSecret = "YOURAPPLICATIONSECRET"
 
$body = @{
    'resource'      = 'https://graph.microsoft.com'
    'client_id'     = $ApplicationId
    'client_secret' = $ApplicationSecret
    'grant_type'    = "client_credentials"
    'scope'         = "openid"
}

$ClientToken = Invoke-RestMethod -Method post -Uri "https://login.microsoftonline.com/$($tenantid)/oauth2/token" -Body $body -ErrorAction Stop
$headers = @{ "Authorization" = "Bearer $($ClientToken.access_token)" }
$Users = (Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/users" -Headers $Headers -Method Get -ContentType "application/json").value.id
 
foreach ($userid in $users) {
    $AllTeamsURI = "https://graph.microsoft.com/beta/users/$($UserID)/JoinedTeams"
    $Teams = (Invoke-RestMethod -Uri $AllTeamsURI -Headers $Headers -Method Get -ContentType "application/json").value
    foreach ($Team in $teams) {
        $SiteRootReq = Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/groups/$($Team.id)/sites/root" -Headers $Headers -Method Get -ContentType "application/json"
        $AddSitesbody = [PSCustomObject]@{
            value = [array]@{
                "id" = $SiteRootReq.id
            }
        } | convertto-json
        $FavoritedSites = Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/users/$($userid)/followedSites/add" -Headers $Headers -Method POST -body $AddSitesBody -ContentType "application/json"
        write-host "Added $($SiteRootReq.webURL) to favorites for $userid"
    }


}
