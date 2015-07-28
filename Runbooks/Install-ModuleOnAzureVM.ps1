workflow Install-ModuleOnAzureVM {
     param
     (
        [parameter(Mandatory=$true)]
        [String]
        $AzureConnectionName,

        [parameter(Mandatory=$true)]
        [String]
        $CredentialAssetNameWithAccessToVM,

        [parameter(Mandatory=$true)]
        [String]
        $ModuleStorageAccountName,

        [parameter(Mandatory=$true)]
        [String]
        $ModuleContainerName,

        [parameter(Mandatory=$true)]
        [String]
        $ModuleBlobName,

        [parameter(Mandatory=$true)]
        [object]
        $VM,

        [parameter(Mandatory=$true)]
        [string]
        $ModuleName
    )

    $PathToPlaceModule = "C:\Windows\System32\WindowsPowerShell\v1.0\Modules\$ModuleName"
    $PathToPlaceModuleZip = "C:\$ModuleName.zip"

    $CredentialWithAccessToVM = Get-AutomationPSCredential -Name $CredentialAssetNameWithAccessToVM

    $Uri = Connect-AzureVM -AzureConnectionName $AzureConnectionName -ServiceName $VM.ServiceName -VMName $VM.Name
        
    Write-Verbose ("Checking if " + $VM.Name + " contains module $ModuleName")

    $HasModule = InlineScript {
        Invoke-Command -ConnectionUri $Using:Uri -Credential $Using:CredentialWithAccessToVM -ScriptBlock {
            Test-Path $args[0]
        } -ArgumentList $Using:PathToPlaceModule
    }

    # Install module on VM if it doesn't have module already
    if(!$HasModule) {
        Write-Verbose ($VM.Name + " does not contain module $ModuleName")
        
        Write-Verbose ("Copying $ModuleBlobName to " + $VM.Name)

        Copy-FileFromAzureStorageToAzureVM `
            -AzureConnectionName $AzureConnectionName `
            -CredentialAssetNameWithAccessToVM $CredentialAssetNameWithAccessToVM `
            -StorageAccountName $ModuleStorageAccountName `
            -ContainerName $ModuleContainerName `
            -BlobName $ModuleBlobName `
            -PathToPlaceFile $PathToPlaceModuleZip `
            -VM $VM

        Write-Verbose ("Unzipping $ModuleBlobName to $PathToPlaceModule")

        InlineScript {
            Invoke-Command -ConnectionUri $Using:Uri -Credential $Using:CredentialWithAccessToVM -ScriptBlock {
                $DestinationPath = $args[0]
                $ZipFilePath = $args[1]

                # Unzip the module to the modules directory
                $Shell = New-Object -ComObject Shell.Application 

                $ZipShell = $Shell.NameSpace($ZipFilePath)
                $ZipItems = $ZipShell.items()

                New-Item -ItemType Directory -Path $DestinationPath | Out-Null
                $DestinationShell = $Shell.Namespace($DestinationPath)
                
                $DestinationShell.copyhere($ZipItems) 

                # Clean up
                Remove-Item $ZipFilePath
            } -ArgumentList $Using:PathToPlaceModule, $Using:PathToPlaceModuleZip
        }
    }
    else {
        Write-Verbose ($VM.Name + " does contain module $ModuleName")
    }
}