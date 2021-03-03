# Azure DevOps Variables
$DevOpsOrg = '<DevOpsOrganizationName>'
$DevOpsPAT = '<DevOpsPersonalAccessToken>'

# Azure Resource Variables
$AutomationName = '<AutomationName>'
$AutomationResourceGroup = '<AutomationResourceGroup>'
$DotNetAgentVMName = '<DotNetAgentVMName>'
$NodeJsAgentVMName = '<NodeJsAgentVMName>'
$AzureVMResourceGroup = '<AzureVMResourceGroup>'
$AzureVMLocation = '<AzureVMLocation>'

# DSC Configuration Path
$dscConfigPath = "$PSScriptRoot\SelfHostedAgent.ps1"

# Login to Azure
Connect-AzAccount

# Create Automation Variable Asset to store PAT.
New-AzAutomationVariable -ResourceGroupName $AutomationResourceGroup `
    –AutomationAccountName $AutomationName `
    –Name 'DevOpsPersonalAccessToken' `
    –Encrypted $true –Value $DevOpsPAT

# Import the DSC configuration
Import-AzAutomationDscConfiguration -ResourceGroupName $AutomationResourceGroup `
    –AutomationAccountName $AutomationName `
    -SourcePath $dscConfigPath -Force -Published

# Compile the DSC Configuration
$Parameters = @{
    'DevOpsOrganizationName' = $DevOpsOrg
} 

$ConfigData = @{
    AllNodes = @(
        @{
            NodeName = 'BuildAgents.DotNetAgent'
            AgentName = 'DotNetAgent'
            AgentPoolName = 'BuildAgents'
        },
        @{
            NodeName = 'BuildAgents.NodeJsAgent'
            AgentName = 'NodeJsAgent'
            AgentPoolName = 'BuildAgents'
            IncludeNodeJs = $true
        }
    )
}

Start-AzAutomationDscCompilationJob -ResourceGroupName $AutomationResourceGroup `
    -AutomationAccountName $AutomationName `
    -ConfigurationName 'SelfHostedAgent' `
    -Parameters $Parameters `
    -ConfigurationData $ConfigData

Get-AzAutomationDscNodeConfiguration -ResourceGroupName $AutomationResourceGroup `
    -AutomationAccountName $AutomationName 

# Onboard the node to Automation DSC
Register-AzAutomationDscNode -ResourceGroupName $AutomationResourceGroup `
    -AutomationAccountName $AutomationName `
    -AzureVMName $DotNetAgentVMName `
    -AzureVMResourceGroup $AzureVMResourceGroup `
    -AzureVMLocation $AzureVMLocation `
    -NodeConfigurationName 'SelfHostedAgent.BuildAgents.DotNetAgent' `
    -ConfigurationMode 'ApplyAndMonitor' `
    -ConfigurationModeFrequencyMins  15 `
    -RefreshFrequencyMins 30 `
    -RebootNodeIfNeeded $true


# Onboard the node to Automation DSC
Register-AzAutomationDscNode -ResourceGroupName $AutomationResourceGroup `
    -AutomationAccountName $AutomationName `
    -AzureVMName $NodeJsAgentVMName `
    -AzureVMResourceGroup $AzureVMResourceGroup `
    -AzureVMLocation $AzureVMLocation `
    -NodeConfigurationName 'SelfHostedAgent.BuildAgents.NodeJsAgent' `
    -ConfigurationMode 'ApplyAndMonitor' `
    -ConfigurationModeFrequencyMins  15 `
    -RefreshFrequencyMins 30 `
    -RebootNodeIfNeeded $true