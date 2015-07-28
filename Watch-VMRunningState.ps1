workflow Watch-VMRunningState
{
    param (
    #Monitor AWS
    [bool] $checkAWS = $true,
    
    #Monitor VMware
    [bool] $checkVMware = $false
    )
    
    #Keep the last failed machines
    $DownAwsMachines = @()
    $DownVMwareMachines = @()
    
    while ($true) {
        
        #********************************************************************
        #AWS
        if ($checkAWS) {
            #List of new failed VMs
            $InstanceIDs = @()
            $HasNewFailures = $false
            
            #Get the machine IDs of any VMs that are not running
            $StoppedAWSVMs = Get-AwsProblemVMs
            ForEach ($VM in $StoppedAWSVMs) {
                #Remove VMs for which notifications have been sent
                if ($DownAwsMachines -NotContains $VM) {
                    "AWS VM instance: $VM is not responding"
                    $InstanceIDs += $VM
                    $HasNewFailures = $true
                }
            }
            
            #Send email alert 
            if ($HasNewFailures) {
                $AWSOnCallEmail = Get-AutomationVariable -Name 'AWSOnCallEmail' 
                $Message = "AWS Instance ID(s): `r" + ($InstanceIDs -join "`r")
                $Subject = "Warning - AWS VM is down!"
                Send-Email -Body $Message  -Subject $Subject -SendTo $AWSOnCallEmail
            }
            
            $DownAwsMachines = $StoppedAWSVMs
        } 
        
        #********************************************************************
        #VMware
        if ($checkVMware) {
            #List of new failed VMs 
            $VMs = @()
            $HasNewFailures = $false
            
            #Get the machine names of any VMs that are not running
            $StoppedVMwareVMs = Get-VMwareProblemVMs
            
            ForEach ($VM in $StoppedVMwareVMs) {
                #Remove VMs for which notifications have been sent
                if ($DownVMwareMachines -NotContains $VM) {
                   "VMware VM is not responding"
                    $VMs += $VM
                    $HasNewFailures = $true
                }
            }
            
            #Send email alert if one has not already been sent            
            if ($HasNewFailures) {
                    $VMwareOnCall = Get-AutomationVariable -Name 'VMwareOnCallEmail'
                    $Message = "VMware VM(s): `r" + ($VMs -join "`r")
                    $Subject = "Warning - VMware VM is down!"
                    Send-Email -Body $Message  -Subject $Subject -SendTo $VMwareOnCall
            }
            
            $DownVMwareMachines = $StoppedVMwareVMs
        }

        Start-Sleep -s 60
    }  
}