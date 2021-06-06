<#
.SYNOPSIS
This simply logs to console as output

.DESCRIPTION
Reports the resource status as compliant.

.EXAMPLE
Report-CompliantResource -ResourceId '/subscriptions/vmsubid/resourceGroups/vmrg/providers/Microsoft.Compute/virtualMachines/vmname'
#>

function Report-CompliantResource()
{
    param (
        [string]
        $ResourceId
    )

    Write-Output "`n***************************************"
    Write-Output "TimeStamp: $(Get-Date)"
    Write-Output "ResourceId: $ResourceId"
    Write-Output "Status: Compliant"
    Write-Output "***************************************`n"
} 

<#
.SYNOPSIS
This simply logs to console as warning

.DESCRIPTION
Reports the resource status as not compliant.

.EXAMPLE
Report-NotCompliantResource -ResourceId '/subscriptions/vmsubid/resourceGroups/vmrg/providers/Microsoft.Compute/virtualMachines/vmname'
#>

function Report-NotCompliantResource()
{
    param (
        [string]
        $ResourceId
    )

    Write-Warning "`n***************************************"
    Write-Warning "TimeStamp: $(Get-Date)"
    Write-Warning "ResourceId: $ResourceId"
    Write-Warning "Status: Not Compliant"
    Write-Warning "***************************************`n"
} 