# This script disables event collection rules as long as they are not from one of the defined MPs.
# Patrick Seidl, s2 - seidl solutions
# 21.03.2018

"="*70
$error.Clear()

Import-Module OperationsManager

# Target MP Information: 
$Name = "s2.Event.Collection.Disabling.Overrides"
$DisplayName = "s2 Event Collection Disabling Overrides"

# MPs to be excluded:
$internalMPs = @("Microsoft.SystemCenter.2007"
"System.NetworkManagement.Monitoring"
"Microsoft.SystemCenter.DataWarehouse.Internal"
"Microsoft.SystemCenter.Notifications.Library"
"Microsoft.Exchange.Server.2007.Monitoring.Edge"
"Microsoft.Exchange.Server.2007.Monitoring.Hub"
"Microsoft.Exchange.Server.2007.Monitoring.Cas"
"Microsoft.Exchange.Server.2007.Monitoring.UM"
"Microsoft.Exchange.Server.2007.Monitoring.Mailbox"
"Microsoft.Exchange.Server.2007.Library"
"Microsoft.Exchange.2010"
"s2.OperationsManager.Extensions"
"Syliance.Exchange.Correlation.Engine"
#"Microsoft.SystemCenter.Apm.Infrastructure.Monitoring"
#"Microsoft.SystemCenter.ACS.Internal"
#"Microsoft.SystemCenter.NTService.Library"
#"Microsoft.SystemCenter.OperationsManager.DataAccessService"
)

# Create target MP if not found:
if (!(Get-SCOMManagementPack -Name $Name)){
    Write-Host "Create new MP"
    $MpStore = New-Object Microsoft.EnterpriseManagement.Configuration.IO.ManagementPackFileStore
    $Mp = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPack($Name, $DisplayName, (New-Object Version(1, 0, 0, 0)), $MpStore)
    Import-SCOMManagementPack $Mp
}

# Get all Event Collection Rules with WriteToDB/DW action:
Write-Host "Get EventCollection Rules"
$EventCollectionRules = Get-SCOMRule | ? {$_.Category -eq "EventCollection" -and $_.WriteActionCollection.Name -like "WriteToD*"}

# Set array
$RulesToBeDisabled = New-Object System.Collections.Generic.List[System.Object]

# Validate all rules found if they have alert action as well; add them to the list if not:
foreach ($EventCollectionRule in $EventCollectionRules) {
    $alertFound = $false
    if ($EventCollectionRule.WriteActionCollection.Name -like "*Alert*") {
        $alertFound = $true
    }
    if ($alertFound -ne $true) {
        $RulesToBeDisabled.Add($EventCollectionRule)
    }   
}

# Get the target MP:
Write-Host "Get target MP"
$TagetManagementPack = Get-SCOMManagementPack -Name $Name

# Create the overrides: (need to loop, otherwise DB eror)
Write-Host "Create overrides"
$i=0
$all = $RulesToBeDisabled.Count

foreach ($RuleToBeDisabled in $RulesToBeDisabled) {
    write-progress -activity "Processing overrides" -status "$i of $all done" -percentcomplete ($i / $all * 100)
    if ($internalMPs -notcontains $RuleToBeDisabled.ManagementPackName) {
        if ($RuleToBeDisabled.GetManagementPack().sealed -eq $true) {
            try {
                Disable-SCOMRule -Rule $RuleToBeDisabled -ManagementPack $TagetManagementPack -ErrorAction Stop
                Write-Host "Disabled Event Collection rule:" $RuleToBeDisabled.DisplayName -ForegroundColor green
            } catch {
                "-"*70
                Write-Host "Failed to disable:"  $RuleToBeDisabled.DisplayName -ForegroundColor red
                $error[0]
                $RuleToBeDisabled | fl *
            }
        } else {
            try {
                $UnsealedTagetManagementPack = Get-SCOMManagementPack -Name $RuleToBeDisabled.GetManagementPack().Name
                Disable-SCOMRule -Rule $RuleToBeDisabled -ManagementPack $UnsealedTagetManagementPack -ErrorAction Stop
            } catch {
                Write-Host "Failed to disable:" $RuleToBeDisabled.DisplayName -ForegroundColor red
            }
        }
    } else {
        Write-Host "Skipped System Center rule:" $RuleToBeDisabled.DisplayName -ForegroundColor yellow
    }
    #Start-Sleep 10
    $i++
}

Write-Host "Amount of disabled EventCollection rules: $all"