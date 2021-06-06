Configuration SyncHybridWorkerModules
{
    param
    (
        [Parameter(Mandatory = $false)]
        [string[]]$ModuleToIgnore = @()
    )

    Import-DSCResource -Module AutomationHybridWorkerDsc

    # These modules will be excluded from sync by default always
    $builtInModules = @("Microsoft.PowerShell.Diagnostics","Microsoft.WSMan.Management", "Microsoft.PowerShell.Utility", "Microsoft.PowerShell.Security", "Microsoft.PowerShell.Management", "GPRegistryPolicyParser", "Orchestrator.AssetManagement.Cmdlets", "Microsoft.PowerShell.Core")
    $dscModules = @("AuditPolicyDsc","ComputerManagementDsc","PSDscResources", "SecurityPolicyDsc", "StateConfigCompositeResources", "xDSCDomainjoin", "xPowerShellExecutionPolicy", "xRemoteDesktopAdmin", "AutomationHybridWorkerDsc")

    $ModuleToIgnore += $builtInModules
    $ModuleToIgnore += $dscModules

    # Connect to azure
    Connect-AzAccount -Identity

    # Retrieve the automation account details
    $automationAccountName = Get-AutomationVariable -Name 'AutomationAccountName'
    $automationAccountRGName = Get-AutomationVariable -Name 'AutomationAccountRGName'

    # Retrieve the automation account modules list and filter it
    $modules = Get-AzAutomationModule -AutomationAccountName $automationAccountName -ResourceGroupName $automationAccountRGName
    $modules = $modules | Where-Object { $_.Name -notin $ModuleToIgnore }

    Node localhost
    {
        foreach($module in $modules)
        {
            if (-not [System.String]::IsNullOrEmpty($module.Version))
            {
                Write-Output "Processing module $($module.Name) and version $($module.Version)..."
                $resourceName = $($module.Name + '-' +$module.Version)

                AutomationPSModuleResource $resourceName
                {
                    Name = $module.Name
                    RequiredVersion = $module.Version
                    Ensure = "Present"
                }  
            }
            else
            {
                throw "Version info could not be retrieved for $($module.Name)"
            }      
        }
    }
}