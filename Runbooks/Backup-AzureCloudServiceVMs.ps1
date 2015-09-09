<#
.SYNOPSIS
    This Azure Automation runbook provides a way to back up data and OS disks of Azure VMs in a specified Cloud Service using only 
    the native Azure module cmdlets.  If specified it will shutdown and restart VMs that are running.  Backup Location defaults to vhd-backups 
    container in the same storage account your VMs reside, but you can also specify a different destination storage account and/or 
    different destination container name.  If you specify a different storage account, it will not restart the VMs because the copy will not complete 
    before the runbook times out. In this case, the output log produces the PowerShell command line to check the status of each pending blob copy.

.DESCRIPTION
    The runbook makes copies of each disk AFTER SHUTTING DOWN THE VM. The backups are stored in the specified
    container (defaults to "vhd-backups") in the specified storage account. 
    The Purge_Old_Backups defaults to true but can be changed to $false if you want to retain previous backups. The backup blob names are in the format
    of backupDatetime/blobNameOfTheDisk, for example,
    2015-01-14T20-50-10/<cloud_Service_name>-<vm_Name><disk_name>.vhd
    VMs that are stopped will be restarted.  

   You can find more information on configuring Azure so that Azure Automation can manage your
   Azure subscription(s) here: http://aka.ms/Sspv1l

   After configuring Azure and creating the Azure Automation credential asset, you can schedule this directly in Azure using your parameters,
   
   e.g. Backup-AzureCloudService -psCredName 'yourCredentialName' -SubscriptionName 'yourSubName' -DestStorageAcctName 'yourStgAcctName'  -BackupContainer "yourContainer" -Cloud_Service_Name 'yourCldService' -forceShutdown $true -Purge_Old_Backups $true
        
   Or use the companion Backup-AllCloudServices runbook to pass the credential name, your cloud service names and your parameters to this runbook.
#>

workflow Backup-AzureCloudServiceVMs {

    [OutputType( [string] )]
  
    param (
        [parameter(Mandatory=$false)]
        [String]
        $CredentialAssetName = ' ',
        
        [parameter(Mandatory=$true)]
        [String]
        $SubscriptionName,
        
        [parameter(Mandatory=$false)]
        [String]
        $DestStorageAcctName,

        [parameter(Mandatory=$false)]
        [String]
        $BackupContainer,

        [parameter(Mandatory=$true)]
        [String]
        $Cloud_Service_Name,

        [parameter(Mandatory=$false)]
        [boolean]
        $ForceShutdown = $false,

        [parameter(Mandatory=$false)]
        [boolean]
        $Purge_Old_Backups =$true
    )

    # Retreive the credential used to authenticate to Azure 
    $Cred = Get-AutomationPSCredential -Name $poSh_Cred_Name 
    if ($Cred -eq $null)
    {
        throw "Error: there is no credential named $CredentialAssetName. Make sure you have created the asset."
    } 

    # Connect to Azure and select the subscription to work against
	Add-AzureAccount -Credential $Cred -ErrorAction Stop| Write-Verbose
	Select-AzureSubscription -SubscriptionName $SubscriptionName
    
    # Get VMs from specified cloud service
    $cloudServiceVMnames = (Get-AzureVM | where{$_.servicename -eq $Cloud_Service_Name}).name
    $cloudServiceDiskStorage = (Get-AzureVM | where{$_.servicename -eq $Cloud_Service_Name}).VM.OSVirtualHardDisk.medialink.Host.Split('.')[0] 

    # Set Storage Account to same location of target VMs if not passed.
    if(! $DestStorageAcctName) {$DestStorageAcctName = $cloudServiceDiskStorage}
    
    # Specify the backup destination container if not passed
    if(! $BackupContainer) {$BackupContainer  = 'vhd-backups'}

    # Set current storage account 
    Set-AzureSubscription -CurrentStorageAccountName $DestStorageAcctName -SubscriptionName $SubscriptionName

    inLineScript 
    {
        # Create backup container if doesn't exist    
        if (!(Get-AzureStorageContainer -Name $using:BackupContainer -ea SilentlyContinue)) 
        { 
            $newRtn = New-AzureStorageContainer -Name $using:BackupContainer -Permission Off 
            Write-Output "Backup container $($newRtn.name) was created." 
        } 
    }

    #backup all VMs in a cloud service in parallel
    foreach -parallel ($Name in $cloudServiceVMnames)
    {
        
    inlineScript {

        $vmName = $using:name
        $VM = Get-AzureVM |where{$_.name -eq $vmName }
            
              
        [boolean]$restart =$false 
  
        # Stop Azure VMs that were running
        if($vm.status -notlike 'Stopped*' -and $using:ForceShutdown)
        {
        [boolean]$stopped = $false

        $stopRtn=$vm|Stop-AzureVM -stayProvisioned -ea SilentlyContinue
        if(($stopRtn.OperationStatus) -ne 'Succeeded')
        {
            do{
				Write-Output "Failed to stop $vmName. Retrying in 60 seconds..."
				sleep 60
				$stopRtn=$vm|Stop-AzureVM -stayProvisioned -ea SilentlyContinue
				$count++
            }
            while(($stopRtn.OperationStatus) -ne 'Succeeded' -and $count -lt 5)
         
        }
       
        if($stopRtn){$stopStatus=$stopRtn.OperationStatus}else{$stopStatus = "Failed"}

        if($stopStatus -eq 'Succeeded')
        {
			$stopped=$true
			$restart = $true
			Write-Output "Stop-AzureVM cmdlet for $vmName $stopStatus"
        }
        else
        {
			Write-Output "Stop-AzureVM cmdlet for $vmName $stopStatus after $count retrys. This VM will not be backed up."
        }
       
        }
        elseif($vm.status -notlike 'Stopped*' -and $using:ForceShutdown -eq $false)
        {
			[boolean]$stopped = $false
			Write-Output "$vmName is running and -ForceShutdown is set to false. This VM will not be backed up."
        }
        else
        {
			[boolean]$stopped = $true
        }

  
    <####################################
    function: Get-StorageContext
    param:  [mandatory] -StorageAccountName [string]
    global:
    local:   $context
    return: Azure storage context object
    purpose: Create an azure storage context using azure storage credentials for the specified storage account
    Usage:     $destcontext = Get-StorageContext -StgAcctName $DestStorageAcctName
    ####################################>
	function Get-StorageContext
	{
		param([parameter(mandatory=$true)][string]$StgAcctName) 
     
     
		$PrimaryKey = (Get-AzureStorageKey -StorageAccountName $StgAcctName).primary

		$context = New-AzureStorageContext -StorageAccountName $StgAcctName -StorageAccountKey $primaryKey

		return $context

	}

   <####################################
   function: Copy-Disk
   param:  -Disk [object]
   global:  $using:DestStorageAcctName, $using:BackupContainer
   local:   $now, $blob, $SrcStorageAccountName
   return:   ICloudBlob object
   purpose: copy Azure blob to specified storage account and container.  Returns iCloudBlob to allow copy status
   Usage:     $backRtn = Copy-Disk -Disk $osDisk 
   ####################################>              
	function Copy-Disk 
	{
		param($Disk) 
			$now =  Get-Date -format s
			$now = $now -replace ":", "-" 
			$Blob = $Disk.MediaLink.Segments[-1] 
			# $Container = $Disk.MediaLink.Segments[-2].TrimEnd('/') 
			[string]$SrcStorageAccountName = $Disk.MediaLink.Host.Split('.')[0] 
			$sourcecontext = Get-StorageContext -StgAcctName $SrcStorageAccountName
			$SourceURI = $Disk.MediaLink.absoluteURI
			if($using:Purge_Old_Backups)
			{
				Write-Verbose -Verbose "Purging old backups and snapshots from $using:DestStorageAcctName $using:BackupContainer for file $blob" 
				Get-AzureStorageBlob -Container $using:BackupContainer -context $destcontext | where {$_.name -match $blob} | Remove-AzureStorageBlob -context $destcontext -force 
			}

				$BlobCopyParams = @{ 
				'absoluteuri' = $SourceURI; 
				'SrcContext' = $sourcecontext;
				'DestContainer' = $using:BackupContainer;
				'DestBlob' = $now + "/" + $Blob;
				'DestContext' = $destcontext;
	} 
            
			Write-Verbose -Verbose "Start-AzureStorageBlobCopy CopyParams: absoluteuri $SourceURI; srcContext $SrcStorageAccountName; destcontext $using:DestStorageAcctName; DestContainer $using:BackupContainer"
			$ret = Start-AzureStorageBlobCopy @BlobCopyParams 
			$iCloud=$ret.ICloudBlob
			return $iCloud
		} 
         
          
            $destcontext = Get-StorageContext -StgAcctName $using:DestStorageAcctName
            $backupstates = @()
           
            $osDisks = $Vm | Get-AzureOsDisk 
            if ($osDisks -and $stopped) 
              { 
                foreach ($osDisk in $osDisks) 
                  { 
                    Write-Verbose -Verbose "Backing up OS disk for VM $vmName, Lun $($osDisk.Lun), $($osDisk.DiskLabel)" 
                    $backRtn = Copy-Disk -Disk $osDisk 
                    $backupstates += $backRtn
                  } 
              } 
            
            $dataDisks = $Vm | Get-AzureDataDisk 
            if ($dataDisks -and $stopped) 
              { 
                foreach ($dataDisk in $dataDisks) 
                 { 
                    Write-Verbose -Verbose "Backing up data disk for VM $vmName, Lun $($dataDisk.Lun), $($dataDisk.DiskLabel)" 
                   $backRtn = Copy-Disk -Disk $dataDisk 
                   $backupstates += $backRtn
                 } 
              } 
        # assume copy will complete
        [boolean]$copyComplete = $true

        foreach($iCB in $backupstates)
          {
           
           do{
               $copyStatus = (get-azureStorageBlobCopyState -ICloudBlob  $iCB -context $destcontext).Status
               $stscount++
               Write-Verbose -Verbose "Checking copy status for $($iCB.name) for $vmName. $stscount attempt." 
               sleep 5
             }
           while($copyStatus -ne 'Success' -and $stscount -lt 5)

           if($copyStatus -eq 'Success') 
             {
              Write-Output "Backup to $($iCB.name) for $vmName was successful"
             }
            else
             {
              # explicitly set status so incompletion of any one drive will result in overall copy completion status of false.
              [boolean]$copyComplete = $false
              Write-Output "Backup to $($iCB.name) for $vmName did not complete in 30 secs.  Last copy status was $copyStatus" 
              write-output  "Retreive the copy status with the following command: Get-AzureStorageblobcopystate -blob '$($iCB.name)' -Container '$using:BackupContainer' -context (New-AzureStorageContext -StorageAccountName '$using:DestStorageAcctName' -StorageAccountKey (Get-AzureStorageKey -StorageAccountName '$using:DestStorageAcctName').primary)"
             }

           }
         
         if(! $copyComplete -and $restart) {Write-Output "$vmName was not restarted due to incomplete copy status"}

         # Restart Azure VMs that were previously running and stopped for backup
         # Will not restart if any one drive failed to complete the copy
         if($restart -and $copyComplete)
           {
            $startRtn =$vm|Start-AzureVM -ea SilentlyContinue
            if(($startRtn.OperationStatus) -ne 'Succeeded')
             {
               do{
                  Write-Output "Failed to restart $vmName. Retrying in 60 seconds..."
                  sleep 60
                  $startRtn =$vm|Start-AzureVM -ea SilentlyContinue
                  $rstcount++
                  }
               while(($startRtn.OperationStatus) -ne 'Succeeded' -and $rstcount -lt 5)
              }
       
               if($startRtn){$startStatus=$startRtn.OperationStatus}else{$startStatus = "Failed"}

               Write-Output "Start-AzureVM cmdlet for $vmName $startStatus"
            
           
           }
  
    } # end of inlinescript
   
         
  } # end of foreach  -parallel

    Write-Output "Completed backup of all VMs in $Cloud_Service_Name"
}
