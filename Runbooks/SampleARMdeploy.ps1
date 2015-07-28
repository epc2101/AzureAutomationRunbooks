
#Connect to your Azure account
Add-AzureAccount

#Select your subscription if you have more than one
Select-AzureSubscription -SubscriptionId "f2092f2a-a813-4e15-856d-64c11ad8ec33"

#Use Azure resource Manager to deploy template (note this is being deprecated)
Switch-AzureMode -Name AzureResourceManager

#Set the parameter values for the template
$Params = @{
    "accountName" = "BethTest123" ;
    "location" = "Japan East";
}

$TemplateFile = "C:\Users\elcooper\Source\Repos\automation-packs\101-sample-deploy-automation-resources\sample-deploy-module\DeployModule.json"

New-AzureResourceGroupDeployment -TemplateParameterObject $Params -ResourceGroupName "BethGallery" -TemplateFile $TemplateFile
