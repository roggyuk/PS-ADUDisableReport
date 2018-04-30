$Output = @()

#Dates
$DaysSinceLastLogon = $(Get-Date).AddDays(-5)
$MinimumAccountAge = $(Get-Date).AddDays(-1)
$TodaysDate = Get-Date

#OU
$OUSearchbase = "OU=Clients,DC=rogersdigital,DC=co,DC=uk"

$DomainUsers = Get-ADDomainController -Filter * | 
    ForEach-Object {
    Get-ADUser -Filter * -SearchBase $OUSearchbase -Properties LastLogon -Server $_.HostName |
        Select-Object SamAccountName, Name, @{Name = 'LastLogon'; Expression = {[DateTime]::FromFileTime($_.LastLogon)}}    
}

$Accounts = foreach ($User in $DomainUsers | Group-Object SamAccountName) {
    $User.Group | Sort-Object -Property LastLogon -Descending | Select-Object -First 1
}

foreach ($Account in $Accounts) {
    $AccountSAM = $Account.SamAccountName
    $AccountDetail = Get-ADUser $AccountSAM -Properties whencreated, name
    $Name = $AccountDetail.Name
    $Enabled = $AccountDetail.Enabled   

    if ($Account.LastLogon -eq "01/01/1601 00:00:00" -and $Enabled -eq $True -and $AccountDetail.whencreated -lt $MinimumAccountAge) {
        Set-ADUser $Account.SamAccountName -Enabled $false -whatif
        $Output += New-Object psobject -Property @{
            Name                  = $Name
            "Inactive For (Days)" = "Never logged on"
            Action                = "Disabled account"
            Created               = $AccountDetail.WhenCreated
        }
        
    }
    elseif ($Account.LastLogon -lt $DaysSinceLastLogon -and $Enabled -eq $True -and $AccountDetail.whencreated -lt $MinimumAccountAge) {
        $LastLogon = $Account.LastLogon
        $DaysSinceLogon = ($TodaysDate - $Account.LastLogon).Days
        Set-ADUser $Account.SamAccountName -Enabled $False -whatif
        $Output += New-Object psobject -Property @{
            Name                  = $Name
            "Inactive For (Days)" = "$DaysSinceLogon"
            Action                = "Disabled account"
            Created               = $AccountDetail.WhenCreated
        }
        
    }
    elseif ($Account.LastLogon -eq "01/01/1601 00:00:00" -and $Enabled -eq $False -and $AccountDetail.whencreated -lt $MinimumAccountAge) {
        $Output += New-Object psobject -Property @{
            Name                  = $Name
            "Inactive For (Days)" = "Never logged on"
            Action                = "Account Already Disabled"
            Created               = $AccountDetail.WhenCreated
        }
        
    }
    elseif ($Account.LastLogon -lt $DaysSinceLastLogon -and $Enabled -eq $False -and $AccountDetail.whencreated -lt $MinimumAccountAge) {
        $lastlogon = $Account.LastLogon
        $DaysSinceLogon = ($todaysdate - $Account.LastLogon).days
        $Output += New-Object psobject -Property @{
            Name                  = $Name
            "Inactive For (Days)" = "$DaysSinceLogon"
            Action                = "Account Already Disabled"
            Created               = $AccountDetail.WhenCreated
        }
        
    }
        
}
$Output | Export-Csv c:\ADUReport.csv -NoClobber -NoTypeInformation -Force
