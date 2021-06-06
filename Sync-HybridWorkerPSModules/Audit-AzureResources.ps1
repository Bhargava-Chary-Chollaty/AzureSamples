$ErrorActionPreference = 'Stop'

# Connect to Azure
Connect-AzAccount -Identity

# Retrieve Resources
$resources = Get-AzResource

# Loop through the resources and report the status
foreach ($resource in $resources) {
    # Owner tag is present, report compliant
    if ($null -ne $resource.Tags -and $resource.Tags.Keys -contains 'owner')
    {
        Report-CompliantResource -ResourceId $resource.Id
    }
    else 
    {
        Report-NotCompliantResource -ResourceId $resource.Id
    }
    
}