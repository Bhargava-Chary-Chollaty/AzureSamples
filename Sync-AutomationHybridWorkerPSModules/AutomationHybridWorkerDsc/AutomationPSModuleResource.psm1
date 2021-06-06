enum Ensure
{
    Absent
    Present
}

[DscResource()]
class AutomationPSModuleResource {

    [DscProperty(Key)]
    [string] $Name

    [DscProperty(Key)]
    [string] $RequiredVersion

    [DscProperty(Mandatory)]
    [Ensure] $Ensure

    [DscProperty(NotConfigurable)]
    [string] $ModuleBasePath

    <#
        This method is equivalent of the Set-TargetResource script function.
        Here we try to ensure that the module provided is either present or absent.
    #>
    [void] Set()
    {
        $this.TestDscLcmRefreshMode()
        $moduleInstalled = $this.TestModuleInstallation()

        if ($this.ensure -eq [Ensure]::Present)
        {
            if(-not $moduleInstalled)
            {
                Write-Verbose -Message "Module is not installed. Attempting to install it now"
                $this.DownloadAndInstallModule()
            }
        }
        else
        {
            if ($moduleInstalled)
            {
                Write-Verbose -Message "Module is installed. Attempting to uninstall it now"
                $this.UnInstallModule()
            }
        }
    }

    <#
        This method is equivalent of the Test-TargetResource script function.
        It should return True or False, showing whether the resource
        is in a desired state.
    #>
    [bool] Test()
    {
        $this.TestDscLcmRefreshMode()
        $present = $this.TestModuleInstallation()

        if ($this.Ensure -eq [Ensure]::Present)
        {
            return $present
        }
        else
        {
            return -not $present
        }
    }

    <#
        This method is equivalent of the Get-TargetResource script function.
        The implementation should use the keys to find appropriate resources.
        This method returns an instance of this class with the updated key
         properties.
    #>
    [AutomationPSModuleResource] Get()
    {
        $this.TestDscLcmRefreshMode()
        $present = $this.TestModuleInstallation()

        if ($present)
        {
            $module = $this.GetModuleInfo($this.Name, $this.RequiredVersion)
            $this.Ensure = [Ensure]::Present
            $this.ModuleBasePath = $module.ModuleBase
        }
        else
        {
            $this.ModuleBasePath = [System.String]::Empty
            $this.Ensure = [Ensure]::Absent
        }

        return $this
    }

    <#
        Helper method to check if the required version of module is installed.
    #>
    [bool] TestModuleInstallation()
    {
        $present = $true

        Write-Verbose "Checking if the module is installed on the machine"
        $module = $this.GetModuleInfo($this.Name, $this.RequiredVersion)

        # if moduleinfo is null, it implies required version of module is not installed.
        if ($null -eq $module)
        {
            $present = $false
        }

        Write-Verbose -Message "Module install status: $present"
        return $present
    }

    <#
        Helper method to get the module info object for current module
    #>
    [PSModuleInfo] GetModuleInfo([string] $moduleName, [string] $moduleVersion)
    {
        # Get all the versions of module and filter the required version   
        Write-Verbose -Message "Retrieving module info from the machine for $moduleName for version $moduleVersion"
        $module = Get-Module -Name $moduleName -ListAvailable -ErrorAction Ignore | Where-Object { $_.Version -eq $moduleVersion }
        return $module
    }

    <#
        Helper method to download and install the required version of module from azure automation account
    #>
    [void] DownloadAndInstallModule()
    {
        $moduleRequestUrlFormat = "{0}/Modules(ModuleName='{1}',ModuleVersion='{2}')/ModuleContent"
        $moduleDownloadPath = Join-Path $Env:TEMP "$(New-Guid).zip"
        $moduleInstallationPath = "C:\Program Files\WindowsPowerShell\Modules\$($this.Name)\$($this.RequiredVersion)"

        Write-Verbose -Message "Retrieving ModuleManagers from LCM"
        $lcm = Get-DscLocalConfigurationManager -ErrorAction Continue
        
        # Retrieve the module server url
        if ($null -ne $lcm -and $null -ne $lcm.ResourceModuleManagers -and $lcm.ResourceModuleManagers.Count -gt 0)
        {
            $moduleServerUrl = $lcm.ResourceModuleManagers[0].ServerURL
        }
        else 
        {
            throw "Could not retrieve ResourceModuleManagers from the LCM"
        }

        # Retrieve the client auth certificate for Oaas DSC
        Write-Verbose -Message "Retrieving client authentication certificates from certificate store."
        $clientCerts = Get-ChildItem -Path cert:\LocalMachine\My | Where-Object {$_.FriendlyName -eq 'DSC-OaaS Client Authentication'} | Sort-Object -Property NotAfter -Descending 

        if ($null -eq $clientCerts -or $clientCerts.Count -eq 0)
        {
            throw "Could not retrieve ClientAuthentication certificate for DSC pull server"
        }

        # Construct the module request URL
        $moduleRequestUrl = $moduleRequestUrlFormat -f $moduleServerUrl, $this.Name, $this.RequiredVersion

        try 
        {
            Write-Verbose -Message "Trying to download module from module managers"
            Invoke-RestMethod -Uri $moduleRequestUrl -Method Get -Certificate $clientCerts[0] -Headers @{ProtocolVersion='2.0'} -UseBasicParsing -OutFile $moduleDownloadPath  | Out-Null
            Expand-Archive -Path $moduleDownloadPath -DestinationPath $moduleInstallationPath -Force  | Out-Null
            Remove-Item -Path $moduleDownloadPath -Force  | Out-Null
            Write-Verbose -Message "Succesfully downloaded and installed the module"
        }
        catch 
        {
            throw "Error occured while trying to download and install module $_"
        }
    }

    <#
        Helper method to check if the DSC LCM is setup in PULL mode for the resource to work.
    #>
    [void] TestDscLcmRefreshMode()
    {
        $requiredDscLcmRefreshMode = 'PULL'

        Write-Verbose -Message "Cheking LCM refresh mode"
        $lcm = Get-DscLocalConfigurationManager -ErrorAction Continue

        if($null -eq $lcm -or [System.String]::Compare($requiredDscLcmRefreshMode, $lcm.RefreshMode, $true) -ne 0)
        {
            throw "HybridWorkerModule resource can only be used in $requiredDscLcmRefreshMode mode of DSC"
        }
        else
        {
            Write-Verbose -Message "The LCM refresh mode is $requiredDscLcmRefreshMode"
        }
    }

    <#
        Helper method to uninstall the module if it is already installed
    #>
    [void] UnInstallModule()
    {
        $module = $this.GetModuleInfo($this.Name, $this.RequiredVersion)

        if($null -eq $module)
        {
            Write-Verbose -Message "The module is not installed. Uninstallation is skipped."
        }
        else
        {
            Write-Verbose -Message "The module is installed at $($module.ModuleBase). Purging all the files to uninstall the module."
            Remove-Item -Path $module.ModuleBase -Recurse -Force
            Write-Verbose -Message "The module is succesfully uninstalled."
        }
    }

}