<# 
.SYNOPSIS  
    Deploys an Azure Resource Manager template
 
.DESCRIPTION 
    This runbook deploys an Azure Resource Manager template using a template an a parameter template.
    Use this runbook after downloading the resource templates to the Automation runbook host.  You can use
    https://gallery.technet.microsoft.com/scriptcenter/a-GitHub-Repository-265c0b49 or https://gallery.technet.microsoft.com/scriptcenter/a-Blob-from-Azure-Storage-6bc13745
    to download the Azure Resource Manager templates from GitHub or blob storage, respectively.  
    
.PARAMETER $FilePath 
    Path where the Azure Resource Manager templates (parameters and deployement template) have been downloaded.

.PARAMTER $ARMTemplateName
    The name of the Azure Resource Manager template to deploy
    
.PARAMETER $ParametersTemplateName
    The name of the template containing the parameter values for the deployement
    
.PARAMETER $AzureResourceGroupName
    The name of the Azure resource group to deploy your template to

.PARAMETER $Location
    The region to create the resource group in if it is not already created

.PARAMTER $SubscriptionName
    The name of your Azure subscription
      
.PARAMETER $AzureADCredName 
    A credential containing an Org Id username / password with access to this Azure subscription. 
#> 

workflow Deploy-ArmTemplate
{
    param(
        
        [parameter(Mandatory=$true)] 
        [String] 
        $ARMTemplateName, 
        
        [parameter(Mandatory=$true)] 
        [String] 
        $ParametersTemplateName,

        [parameter(Mandatory=$true)] 
        [String] 
        $AzureResourceGroupName,
        
        [parameter(Mandatory=$true)] 
        [String]          
        $TokenName,
        
        [parameter(Mandatory=$true)] 
        [String]  
        $TemplateRepo,
        
        [parameter(Mandatory=$true)] 
        [String]  
        $GitUser,
        
        [parameter(Mandatory=$true)] 
        [String]  
        $Branch,
        
        [parameter(Mandatory=$true)] 
        [String] 
        $Location,
        
        [parameter(Mandatory=$true)] 
        [String] 
        $SubscriptionName,
        
        [parameter(Mandatory=$true)] 
        [String] 
        $AzureADCredName,
        
        [parameter(Mandatory=$true)] 
        [String]  
        $SendTo,
       
        [parameter(Mandatory=$true)] 
        [String]  
        $SmtpServer,
        
        [parameter(Mandatory=$true)] 
        [String]         
        $EmailCredentialsName 
    )

    #Set error action to stop so runbook fails if there are any errors in deployement
    $ErrorActionPreference = "Stop"

    #Get assets from secure asset store
    $EmailCreds = Get-AutomationPSCredential -Name $EmailCredentialsName
    $AzureCred = Get-AutomationPSCredential -Name $AzureADCredName
    $Token = Get-AutomationVariable -Name $TokenName
    $EmailFrom = $EmailCreds.UserName
    
    Checkpoint-Workflow
    
    $FilePath = Copy-GitHubRepository `
        -AccessToken $Token `
        -Author $GitUser `
        -DownloadPath "C:\" `
        -Name $TemplateRepo `
        -Branch $Branch 
    
    $TemplatePath = $FilePath + "\" + $ARMTemplateName
    $ParameterPath = $FilePath + "\" + $ParametersTemplateName

    #Set Azure subscription
    Add-AzureAccount -Credential $AzureCred | Write-Verbose
    Select-AzureSubscription -SubscriptionName $SubscriptionName | Write-Verbose

    # Make sure the resource group exists
    try 
    {
        Get-AzureResourceGroup -Name $AzureResourceGroupName
    }
    catch 
    {
        Write-Verbose "Creating new Azure resource group: $AzureResourceGroupName" -Verbose
        New-AzureResourceGroup -Name $AzureResourceGroupName -Location $Location         
    }

    
    try 
    {
        # Test the resource group deployement to ensure the template is correctly constructed
        Write-Verbose "Testing the resource group, template and parameters.."
        Test-AzureResourceGroupTemplate -ResourceGroupName $AzureResourceGroupName `
                                        -TemplateParameterFile $ParameterPath `
                                        -TemplateFile $TemplatePath
    
        #Deploy the template 
        Write-Verbose "Deploying Azure Resource Manager template..."
        $Output = New-AzureResourceGroupDeployment -ResourceGroupName $AzureResourceGroupName `
                            -TemplateParameterFile $ParameterPath `
                            -TemplateFile $TemplatePath
        
        #TODO: insert your own tests or post provisioning steps here!
       
        Write-Output "Deployment suceeded!"
        Write-Output $Output
        $Subject = "Test deployment succeeded!"
        $Body = "Deployment  completed successfully. `r`n"
        $Body += $Output
    } 
    catch 
    {
        Write-Warning "Deployment failed!"
        Write-Warning $_
        $Subject = "Test deployment  failed."
        $Body = "Deployment  failed with the following error: "
        $Body += $_ 
    }
                        
    #Send email with status of job                
    Send-MailMessage `
        -to $SendTo `
        -from $EmailFrom `
        -subject $Subject `
        -body $Body `
        -smtpserver $SmtpServer `
        -port 587 `
        -credential $EmailCreds `
        -usessl:$true `
        -erroraction Stop
    
}