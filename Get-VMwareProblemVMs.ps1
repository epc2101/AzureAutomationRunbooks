workflow Get-VMwareProblemVMs
{
    [OutputType([string[]])]

    #This is the host that has the VMware module installed on it
    #You can remove if PowerCLI is installed on all of your runbook workers
    $HostWithVMwareModule = "MyHost"

    #Retrieve server and credentials from Assets
    $Server = Get-AutomationVariable -Name 'VMwareServer'
    $Creds = Get-AutomationPSCredential -Name 'VMWareCredentials'
    $Username = $Creds.UserName
    $Password = $Creds.GetNetworkCredential().Password
     
    $VMsWithProblems = inlinescript { 
       #If PowerCLI is loaded in your PowerShell profile you do not need this line
       Add-PSSnapin VMware.VimAutomation.Core
       
       #Connect to the server if not connected.  
       if ($DefaultVIServers.Count -lt 1) {
            Connect-VIServer -Server $using:Server -User $using:Username -Password $using:Password
       }
        
        #Get each VM & make sure it is up and running 
        $VMs = Get-VM 
        
        $VMsWithProblems = @()
        foreach ($VM in $VMs) {
            if ($VM.powerstate -ne "PoweredOn") {
                $VMsWithProblems += $VM.Name
            } 
        }    
        
        $VMsWithProblems
        
    } -PSComputerName $HostWithVMwareModule
    
    $VMsWithProblems   
}