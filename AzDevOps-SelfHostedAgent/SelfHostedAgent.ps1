Configuration SelfHostedAgent
{
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$DevOpsOrganizationName,

        [Parameter(Mandatory = $false)]
        [string]$DevOpsPersonalAccessToken
    )

    $agentDownloadUri = 'https://vstsagentpackage.azureedge.net/agent/2.182.1/vsts-agent-win-x64-2.182.1.zip'
    $devOpsUri = "https://dev.azure.com/$DevOpsOrganizationName"

    if ([String]::IsNullOrEmpty($DevOpsPersonalAccessToken)) {
        $DevOpsPersonalAccessToken = Get-AutomationVariable -Name 'DevOpsPersonalAccessToken'
    }

    Node $AllNodes.NodeName
    {
        $agentName = $Node.AgentName
        $agentPoolName = $Node.AgentPoolName
        $agentId = "vstsagent.$DevOpsOrganizationName.$agentPoolName.$agentName"
        $agentDirectoryPath = Join-Path 'C:' $agentId
        $agentConfigPath = Join-Path $agentDirectoryPath '.agent'
        $agentChecksumFilePath = Join-Path $agentDirectoryPath 'AgentCheckSum'
        $agentChecksum = (Get-Date).Ticks.ToString()
        $agentDependsOn = @('[Package]VSBuildTools')
        if ($Node.IncludeNodeJs) {
            $agentDependsOn += '[Package]NodeJs'
        }

        Package VSBuildTools
        {
            Name = 'Microsoft .NET Framework 4.7.2 Targeting Pack'
            Path = 'https://aka.ms/vs/16/release/vs_buildtools.exe'
            ProductId = '1784A8CD-F7FE-47E2-A87D-1F31E7242D0D'
            Arguments = '--add Microsoft.VisualStudio.Workload.AzureBuildTools --installPath C:\BuildTools --wait --quiet --norestart'
            Ensure = 'Present'
        }

        if ($Node.IncludeNodeJs)
        {
            Package NodeJs 
            {
                Name = 'Node.js'
                Path = 'https://nodejs.org/dist/v14.16.0/node-v14.16.0-x64.msi'
                ProductId = '6fba594e-4bea-4ba0-a310-a74291707d0e'
                Arguments = '/quiet'
                Ensure = 'Present'
            }
        }

        Script AzureDevOpsAgent
        {
            GetScript = {     
                if ((Test-Path $using:agentDirectoryPath) -and (Test-Path $using:agentConfigPath)) {
                    $agentConfigData = Get-Content -Path $using:agentConfigPath
                }
                else {
                    $errorMessage = "Agent is not configured on the machine"
                    $agentConfigData = $errorMessage
                    Write-Warning $errorMessage
                } 
                return @{ 'Result' = "$agentConfigData" }
            }
            TestScript = {
                # Check if the agentchecksum mismatch.
                $previousAgentChecksum = Get-Content $using:agentChecksumFilePath -ErrorAction Ignore
                if ($previousAgentChecksum -ne $using:agentChecksum) {
                    Write-Warning 'AgentCheckSum mismatch...'
                    return $false
                }

                # Check if the agent is directory exists and Agent is configured.
                if ((Test-Path $using:agentDirectoryPath) -and (Test-Path $using:agentConfigPath)) {
                    Write-Verbose 'Agent directory exists and the agent is already configured.'
                    
                    # Check if the agent service is running.
                    $agentService = Get-Service -Name $using:agentId -ErrorAction Ignore
                    if ($null -ne $agentService -and $agentService.Status -eq 'Running') {
                        Write-Verbose 'Agent service is running.'
                        return $true
                    }
                }
                
                Write-Verbose 'Agent directory does not exist or the agent is not configured.'
                return $false
            }
            SetScript = {
                # Download the agent on to machine and extract it.
                if ((Get-ChildItem $using:agentDirectoryPath -ErrorAction Ignore).Count -eq 0) {
                    Write-Verbose "Agent is not present on the machine. Downloading now..."
                    $agentDownloadPath = Join-Path $env:TEMP "$(New-Guid).zip"
                    Invoke-WebRequest $using:agentDownloadUri -OutFile $agentDownloadPath -UseBasicParsing
                    Expand-Archive -LiteralPath $agentDownloadPath -DestinationPath $using:agentDirectoryPath 
                    Remove-Item $agentDownloadPath    
                    Write-Verbose "Agent succesfully downloaded and extracted to $using:agentDirectoryPath"             
                }

                # Agent is downloaded and extracted on to machine and Configure it
                if ((Test-Path $using:agentDirectoryPath) -and -not (Test-Path $using:agentConfigPath)) {
                    Write-Verbose "Agent is already downloaded and extracted to $using:agentDirectoryPath."
                    Write-Verbose "Agent is not configured, Configuring now..."

                    $agentConfigCmdPath = Join-Path $using:agentDirectoryPath 'config.cmd'

                    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
                    $startInfo.FileName = $agentConfigCmdPath
                    $startInfo.Arguments = "--unattended --url $using:devOpsUri --auth pat --token $using:DevOpsPersonalAccessToken --pool $using:agentPoolName --agent $using:agentName --runAsAutoLogon --runAsService"
                    $startInfo.UseShellExecute = $false
                    $startInfo.RedirectStandardOutput = $true
                    $startInfo.RedirectStandardError = $true

                    $process = New-Object System.Diagnostics.Process
                    $process.StartInfo = $startInfo
                    $process.Start()
                    $process.WaitForExit()
                    $standardError = $process.StandardError.ReadToEnd()
                    $standardOutput = $process.StandardOutput.ReadToEnd()
                    $exitCode = $process.ExitCode

                    Write-Verbose "Config.cmd Output: $standardOutput"
                    Write-Verbose "Config.cmd ExitCode: $exitCode"
                    Write-Warning "Config.cmd Error: $standardError"

                    if ($process.ExitCode -ne 0) {
                        throw "Agent configuration failed."
                    }
                    Write-Verbose "Agent succesfully configured."

                    Set-Content $using:agentChecksum -Path $using:agentChecksumFilePath
                    Write-Verbose "AgentCheckSum ($using:agentChecksum) is updated at $using:agentChecksumFilePath"

                    # Check if the agent service is running.
                    $agentService = Get-Service -Name $using:agentId -ErrorAction Ignore
                    if ($null -ne $agentService -and $agentService.Status -eq 'Running') {
                        Write-Verbose 'Agent service is running.'
                        return
                    }
                    else {
                        throw "Agent is configured but agent service is not running, Manual troubleshooting is needed."
                    }  
                }  
                
                # Agent is already configured and a restart of agent service may be needed.
                if ((Test-Path $using:agentDirectoryPath) -and (Test-Path $using:agentConfigPath)) {
                    # Check if the agent service is running.
                    $agentService = Get-Service -Name $using:agentId -ErrorAction Ignore
                    if ($null -ne $agentService -and $agentService.Status -eq 'Running') {
                        Write-Verbose 'Agent service is running.'
                        $previousAgentChecksum = Get-Content $using:agentChecksumFilePath -ErrorAction Ignore
                        if ($previousAgentChecksum -ne $using:agentChecksum) {
                            Write-Verbose 'AgentCheckSum mis-match service restart is required. Attemping to restart...'
                            Restart-Service $using:agentId
                            Write-Verbose 'Agent service is restarted succesfully...'

                            # Update the agent checksum after restart
                            Set-Content $using:agentChecksum -Path $using:agentChecksumFilePath
                            Write-Verbose "AgentCheckSum ($using:agentChecksum) is updated at $using:agentChecksumFilePath"

                            return
                        }
                    }
                    else {
                        throw "Agent serivce is currently not running, Manual troubleshooting is needed."
                    }  
                }
            }
            DependsOn = $agentDependsOn
        }
    }
}