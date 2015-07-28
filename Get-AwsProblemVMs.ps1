workflow Get-AwsProblemVMs {
   
    [OutputType([string[]])]
     
    #Retrieve the values for the access and secret key
    $Creds = Get-AutomationPSCredential -Name 'AWSCredentials'
    $AccessKey = $Creds.UserName
    $SecretKey =  $Creds.GetNetworkCredential().Password
    $DefaultRegion = "us-west-1"
    
    $VMsWithProblems = InlineScript {
        #Set the credentials and default region for the session
        Set-AWSCredentials -AccessKey $using:AccessKey -SecretKey $using:SecretKey
        Set-DefaultAWSRegion -Region $using:DefaultRegion

        $VMsWithProblems = @()

        #Get each instance in every region & check if it is running
        $Instances = (Get-EC2Region | Get-EC2Instance).Instances
        ForEach ($Instance in $Instances) 
        {
            if ($Instance.State.Name -ne "running") 
            {
                $VMsWithProblems += $Instance.InstanceID
            }
        }
        
        $VMsWithProblems
    }
    
    $VMsWithProblems
}