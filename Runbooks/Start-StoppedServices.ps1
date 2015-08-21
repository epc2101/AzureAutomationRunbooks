workflow Start-StoppedServices
{
	param (
		[string] $ComputerName = "cooper-sma",
		[string] $CredentialName = "Cooper-Sma-Cred",
		[string] $ServiceName = "aspnet_state"
	)
	
	#Retreive credential from secure asset store
   	$Cred = Get-AutomationPSCredential -Name $CredentialName
	
	#Remote to specified machine	   
    $Out = InlineScript {
		
        #Example of starting all stopped services 
		#Get-Service | Where-Object {$_.status -eq "stopped"} | Start-Service 
				
		#For demo purposes just start one service
		$ServiceToStart = Get-Service -Name $Using:ServiceName | Where-Object {$_.status -eq "stopped"}  
		
		
		#If the service is already running or the service cannot be found do nothing
		if (!$ServiceToStart) { 
			
			#Check if the name is incorrect or is not on the server
			$ServiceToStart = Get-Service -Name $Using:ServiceName 		
			
			if (!$ServiceToStart) {
				Write-Error "The service $Using:ServiceName does not exist on the server."
			} else {
				$State = $ServiceToStart.status
				Write-Output "The service $Using:ServiceName is not stopped and is currently $State."
			}
			
			return 
		}
		
        Start-Service -Name $Using:ServiceName
		
		#Give service 15 seconds to start 
		sleep 15 
		
		#Log current state of service
		$State = $ServiceToStart.Status		
        if ($State -eq "Running") { Write-Output "$Using:ServiceName is now running" } 
		else { Write-Output "$Using:ServiceName is $State"}
	
    } -PSComputerName $ComputerName -PSCredential $Cred
	
	#Print out results	
	Write-Output $Out
	
}