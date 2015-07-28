workflow Copy-BlobAcrossStorageAccount
{
    param(
        [Parameter(Mandatory=$True)]
        [string]
        $SourceAccount = 'storage123abc',
        
        [Parameter(Mandatory=$True)]
        [string]
        $SourceContainer = 'container123',
        
        [Parameter(Mandatory=$True)]
        [string]
        $SourceBlobName = 'PSWindowsUpdate.zip',
        
        [Parameter(Mandatory=$True)]
        [string]
        $DestContainer = 'bethcontainer',
        
        [Parameter(Mandatory=$True)]
        [string]
        $DestAccount = 'dfstore01bc1'
    )
    
	# Retrieve the credential & subscription to use to authenticate to Azure from Asset store. 
	$Cred = Get-AutomationPSCredential -Name 'AdAzureCred'
    $AzureSubscription = Get-AutomationVariable -Name 'MySubscriptionName'
    
	# Connect to Azure
	$null = Add-AzureAccount -Credential $Cred
	$null = Select-AzureSubscription -SubscriptionName $AzureSubscription
    $null = Set-AzureSubscription -CurrentStorageAccountName $DestAccount -SubscriptionName $AzureSubscription    

    #Get the storage keys
    $SourceStorageKey = (Get-AzureStorageKey -StorageAccountName $SourceAccount).Primary 
    $SourceStorageKey
    $DestStorageKey = (Get-AzureStorageKey -StorageAccountName $DestAccount).Primary 
    $DestStorageKey
    
    InlineScript {
        # Set storage contexts
        $DestContext = New-AzureStorageContext  –StorageAccountName $Using:DestAccount `
                                                -StorageAccountKey $Using:DestStorageKey  
        
        $SourceContext = New-AzureStorageContext  –StorageAccountName $Using:SourceAccount `
                                                -StorageAccountKey $Using:SourceStorageKey  
        
        #Allow container access to the source                                        
        Set-AzureStorageContainerAcl -Container $Using:SourceContainer -Permission Container -Context $SourceContext 
                                                
        $SourceURI = 'https://' + $Using:SourceAccount + '.blob.core.windows.net/' `
                     + $Using:SourceContainer +'/' + $Using:SourceBlobName
       
        # Copy from one account to another
        Start-AzureStorageBlobCopy -srcUri $SourceURI `
                                    -DestContainer $Using:DestContainer `
                                    -DestBlob $Using:SourceBlobName `
                                    -DestContext $Using:DestContext
    }
                                        
}