# Azure Resource Variables
$AutomationName = '<AutomationName>'
$AutomationResourceGroup = '<AutomationResourceGroup>'
$HybridWorkerVMName = '<HybridWorkerVMName>'
$AzureVMResourceGroup = '<AzureVMResourceGroup>'
$AzureVMLocation = '<AzureVMLocation>'
$HybridWorkerGroupName = '<HybridWorkerGroupName>'

# Module Uri.
# For Az Module they can be retieved from powershell gallery
# Custom Module it has to be upoaded to a blob.
$azAccountsModuleUri = 'https://psg-prod-eastus.azureedge.net/packages/az.accounts.2.3.0.nupkg'
$azAutomationModuleUri = 'https://psg-prod-eastus.azureedge.net/packages/az.automation.1.7.0.nupkg'
$azResourcesModuleUri = 'https://psg-prod-eastus.azureedge.net/packages/az.resources.4.1.1.nupkg'
$auditResourceModuleUri = 'https://contososta.blob.core.windows.net/modules/Audit.Resources.zip'
$automationHybridWorkerDscModuleUri = 'https://contososta.blob.core.windows.net/modules/AutomationHybridWorkerDsc.zip'

# DSC Configuration Path
$dscConfigPath = "$PSScriptRoot\SyncHybridWorkerModules.ps1"

# Runbook Path
$runbookPath = "$PSScriptRoot\Audit-AzureResources.ps1"

# Login to Azure
Connect-AzAccount

# Create Automation Variable Asset to store account name.
New-AzAutomationVariable -ResourceGroupName $AutomationResourceGroup `
    -AutomationAccountName $AutomationName `
    -Name 'AutomationAccountName' `
    -Value $AutomationName `
    -Encrypted $false

# Create Automation Variable Asset to store account RG name.
New-AzAutomationVariable -ResourceGroupName $AutomationResourceGroup `
    -AutomationAccountName $AutomationName `
    -Name 'AutomationAccountRGName' `
    -Value $AutomationResourceGroup `
    -Encrypted $false

# Import Az.Accounts module
New-AzAutomationModule -ResourceGroupName $AutomationResourceGroup `
    -AutomationAccountName $AutomationName `
    -Name 'Az.Accounts' `
    -ContentLinkUri $azAccountsModuleUri

# Import Az.Automation module
New-AzAutomationModule -ResourceGroupName $AutomationResourceGroup `
    -AutomationAccountName $AutomationName `
    -Name 'Az.Automation' `
    -ContentLinkUri $azAutomationModuleUri

# Import Az.Resource module
New-AzAutomationModule -ResourceGroupName $AutomationResourceGroup `
    -AutomationAccountName $AutomationName `
    -Name 'Az.Resources' `
    -ContentLinkUri $azResourcesModuleUri

# Import Audit.Resources module
New-AzAutomationModule -ResourceGroupName $AutomationResourceGroup `
    -AutomationAccountName $AutomationName `
    -Name 'Audit.Resources' `
    -ContentLinkUri $auditResourceModuleUri

# Import AutomationHybridWorkerDsc module
New-AzAutomationModule -ResourceGroupName $AutomationResourceGroup `
    -AutomationAccountName $AutomationName `
    -Name 'AutomationHybridWorkerDsc' `
    -ContentLinkUri $automationHybridWorkerDscModuleUri

# Import the DSC configuration
Import-AzAutomationDscConfiguration -ResourceGroupName $AutomationResourceGroup `
    -AutomationAccountName $AutomationName `
    -SourcePath $dscConfigPath -Force -Published

# Compile the DSC Configuration
Start-AzAutomationDscCompilationJob -ResourceGroupName $AutomationResourceGroup `
    -AutomationAccountName $AutomationName `
    -ConfigurationName 'SyncHybridWorkerModules'

Get-AzAutomationDscNodeConfiguration -ResourceGroupName $AutomationResourceGroup `
    -AutomationAccountName $AutomationName 

# Import the runbook for testing modules
Import-AzAutomationRunbook -ResourceGroup $AutomationResourceGroup `
    -AutomationAccountName $AutomationName `
    -Type PowerShell `
    -Path $runbookPath `
    -Published -Force
    
# Start a cloud job
Start-AzAutomationRunbook -ResourceGroup $AutomationResourceGroup `
    -AutomationAccountName $AutomationName `
    -Name 'Audit-AzureResources' 

# Start a hybrid job
Start-AzAutomationRunbook -ResourceGroup $AutomationResourceGroup `
    -AutomationAccountName $AutomationName `
    -Name 'Audit-AzureResources' `
    -RunOn $hybridWorkerGroupName

# Onboard the worker to Automation DSC
Register-AzAutomationDscNode -ResourceGroupName $AutomationResourceGroup `
    -AutomationAccountName $AutomationName `
    -AzureVMName $HybridWorkerVMName `
    -AzureVMResourceGroup $AzureVMResourceGroup `
    -AzureVMLocation $AzureVMLocation `
    -NodeConfigurationName 'SyncHybridWorkerModules.localhost' `
    -ConfigurationMode 'ApplyAndAutoCorrect' `
    -ConfigurationModeFrequencyMins  15 `
    -RefreshFrequencyMins 30 `
    -RebootNodeIfNeeded $true