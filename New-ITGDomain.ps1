<#
.SYNOPSIS
    Creates ITG domains using the current ITG cookie
.DESCRIPTION
    A method to create ITGlue domains by abusing the cooking and commiting the normal form workflow. This is due to no Domain API is currently available. The function expects you to be logged into ITGlue using Chrome as your browser.
.EXAMPLE
    PS C:\> New-ITGDomain -OrgID 12345 -DomainName 'example.com' -ITGURL 'Yourcompany.Itglue.com'
    Creates a new ITGlue domain example.com in organisation 12345 for the ITglue YourCompany.ITGlue.com. Please note to *not* use the API URL in this case.
.INPUTS
    OrgID = Organisation ID in IT-Glue
    DomainName = Domain name you wish to add.
    ITGURL = The normal access URL to your IT-Glue instance.
.OUTPUTS
    Fail/Success
.NOTES
   No notes
#>
function New-ITGDomain {
    param (
        [string]$OrgID,
        [string]$DomainName,
        [string]$ITGURL
    )
    $ChromeCookieviewPath = "$($ENV:TEMP)/Chromecookiesview.zip"
    if (!(Test-Path $ChromeCookieviewPath)) {
        write-host "Downloading ChromeCookieView" -ForegroundColor Green
        Invoke-WebRequest 'https://www.nirsoft.net/utils/chromecookiesview.zip' -UseBasicParsing -OutFile $ChromeCookieviewPath
        Expand-Archive -path $ChromeCookieviewPath -DestinationPath  "$($ENV:TEMP)" -Force
    }
    Start-Process -FilePath "$($ENV:TEMP)/Chromecookiesview.exe" -ArgumentList "/scomma $($ENV:TEMP)/chromecookies.csv"
    start-sleep 1
    $Cookies = import-csv "$($ENV:TEMP)/chromecookies.csv"
    write-host "Grabbing Chrome Cookies" -ForegroundColor Green
    $hosts = $cookies | Where-Object { $_.'host name' -like '*ITGlue*' }

    write-host "Found cookies. Trying to create request" -ForegroundColor Green
    write-host "Grabbing ITGlue session" -ForegroundColor Green
    $null = Invoke-RestMethod -uri "https://$($ITGURL)/$($orgid)/domains/new" -Method GET -SessionVariable WebSessionITG
    foreach ($CookieFile in $hosts) {
        $cookie = New-Object System.Net.Cookie     
        $cookie.Name = $cookiefile.Name
        $cookie.Value = $cookiefile.Value
        $cookie.Domain = $cookiefile.'Host Name'
        $WebSessionITG.Cookies.Add($cookie)
    }
    write-host "Grabbing ITGlue unique token" -ForegroundColor Green
    $AuthToken = (Invoke-RestMethod -uri "https://$($ITGURL)/$($orgid)/domains/new" -Method GET -WebSession $WebSessionITG) -match '.*csrf-token"'
    $Token = $matches.0 -split '"' | Select-Object -Index 1
    write-host "Creating domain" -ForegroundColor Green
    $Result = Invoke-RestMethod -Uri "https://$($ITGURL)/$($orgid)/domains?submit=1" -Method "POST" -ContentType "application/x-www-form-urlencoded"   -Body "utf8=%E2%9C%93&authenticity_token=$($Token)&domain%5Bname%5D=$($DomainName)&domain%5Bnotes%5D=&domain%5Baccessible_option%5D=all&domain%5Bresource_access_group_ids%5D%5B%5D=&domain%5Bresource_access_accounts_user_ids%5D%5B%5D=&commit=Save" -WebSession $WebSessionITG
    if ($Result -like "*Domain has been created successfully.*") {
        write-host "Succesfully created domain $DomainName for $OrgID" -ForegroundColor Green
    }
    else {
        write-host "Failed to create $DomainName for $orgid" -ForegroundColor Red
    }
}
