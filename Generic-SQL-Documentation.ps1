import-module SQLPS
$Instances = Get-ChildItem "SQLSERVER:\SQL\$($ENV:COMPUTERNAME)"
foreach ($Instance in $Instances) {
    $InstanceInfo = $Instance | Select-Object DisplayName, Collation, AuditLevel, BackupDirectory, DefaultFile, DefaultLog, Edition, ErrorLogPath
    $databaseList = get-childitem "SQLSERVER:\SQL\$($ENV:COMPUTERNAME)\$($Instance.Displayname)\Databases"
    $Databases = @()
    foreach($Database in $databaselist){
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

    $output = $InstanceInfo,$DatabasesHTML | out-file "C:\Temp\Output.html"

}