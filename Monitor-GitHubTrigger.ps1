<# 
.SYNOPSIS  
    Monitors a GitHub repository, downloads the GitHub repo, and publishes the ARM template
    in the repo.  
 
.DESCRIPTION 
    This runbook monitors an a GitHub respository looking for a new commit.  Once a commit is found, 
    it downloads the repository, and publishes the specified ARM template.  
    
    RUNBOOK DEPENDENCIES - this runbook requires Copy-GithubRepository  https://gallery.technet.microsoft.com/scriptcenter/a-GitHub-Repository-265c0b49
    and Deploy-ArmTemplate TODO: INSERT LINK to be downloaded and published.   
    
    ASSET DEPENDENCIES - Credential Azure AD OrgID, String GitHub token, 
    String GitHub SHA, Credential email credentials
#> 


workflow Monitor-GitHubTrigger {

    #GitHub + ARM info for Azure deployment
    $AzureResourceGroupName = "BethTest123"
	$Location = "East US"
	$ParameterFileName = "ParametersContosoItSite.json"
    $ARMTemplateName = "DeployTemplate.json"
    $TokenName =  'GitHubToken'
    $TemplateRepo = "ARM-test"
    $GitUser = "epc2101"
    $Branch = "master"

    #Action runbook info
    $AzureADCredName = 'AdAzureCred'
    $AzureSubscriptionName = Get-AutomationVariable -Name 'MySubscriptionName'
    $AutomationAccountName = "ARM-example"
    $ActionRunbookName = 'Deploy-ArmTemplate'
    $SendTo = "elcooper@microsoft.com"
    $SmtpServer = "smtp.gmail.com"
    $EmailCredentialsName = 'EmailCredentials'


    #Pull response content and process if there was a checkin
    $Token = Get-AutomationVariable -Name 'GitHubToken'
    $ResponseContent = Get-GithubCommit -AccessToken $Token -Author $GitUser -Repository $TemplateRepo -Branch $Branch 
    
    $LastSHA = Get-AutomationVariable -Name 'GitSHA'
	
    if ($ResponseContent.SHA -ne $LastSHA) 
    {
        Write-Output "Found new content! Pushing updates."
        
        # Retrieve the Azure AD user credential and add the account
        $AzureAdCredential = Get-AutomationPSCredential -Name $AzureADCredName
        Add-AzureAccount -Credential $AzureAdCredential | Write-Verbose
        
        # Select a subscription if it a name is specified, otherwise use the default
        if($AzureSubscriptionName -and ($AzureSubscriptionName.Length -gt 0) -and ($AzureSubscriptionName -ne "default")) {
            Write-Output "Selecting subscription"
            Select-AzureSubscription -SubscriptionId 'f2092f2a-a813-4e15-856d-64c11ad8ec33'
        }

        # Retrieve the runbook to call 
        $ActionRunbook = Get-AzureAutomationRunbook `
            -AutomationAccountName $AutomationAccountName `
            -Name $ActionRunbookName 
       
        # Determine if the action runbook accepts the TriggerRunbookData parameter, used by the trigger
        # runbook to pass the data that caused it to fire to the action runbook. If the action runbook
        # accepts this parameter, pass the data when starting it 
        if($ActionRunbook.Parameters.TriggerRunbookData) {
            
            <#$ActionRunbookParameters = @{
                "TriggerRunbookData" = @{
                    # Standard for trigger runbooks - pass whatever data caused the trigger runbook to fire
                    "Url" = $UrlToCheck
                    "UrlStatusCode" = $WebsiteStatusCode
                    "UrlStatusDescription" = $WebsiteStatusDescription
                }
            }#>     
        }
        else {
            #This runbook doesn't take the standard triggers.  Use specific parameters
            $ActionRunbookParameters = @{
                'ARMTemplateName'= $ARMTemplateName; `
                'AzureADCredName' = $AzureADCredName; `
                'SubscriptionName' = $AzureSubscriptionName; `
                'AzureResourceGroupName' =  $AzureResourceGroupName; `
                'Location' =  $Location; `
                'ParametersTemplateName' = $ParameterFileName; `
                'Branch' = $Branch; `
                'TemplateRepo' = $TemplateRepo; `
                'GitUser' = $GitUser; `
                'TokenName' = $TokenName; `
                'EmailCredentialsName' = $EmailCredentialsName; `
                'SendTo' = $SendTo; `
                'SmtpServer' = $SmtpServer
            }
        }
        
        # Start the action runbook 
        Write-Verbose "Calling action runbook $ActionRunbookName"

        $Job = Start-AzureAutomationRunbook `
            -AutomationAccountName $AutomationAccountName `
            -Name $ActionRunbookName `
            -Parameters $ActionRunbookParameters
            
        "Job started: $($Job.Id)" | Write-Verbose
    } 
    
    #Update var with the lastest URL 
    Set-AutomationVariable -Name 'GitSHA' -Value $ResponseContent.SHA
   
}