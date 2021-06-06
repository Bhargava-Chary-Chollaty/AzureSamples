Configuration ImportHybridWorkerModules
{

    Import-DSCResource -Module AutomationHybridWorkerDsc

    AutomationPSModuleResource Az_Accounts
    {
        Name = "Az.Accounts"
        RequiredVersion = "2.2.1"
        Ensure = "Present"
    }
}