<#
.SYNOPSIS
    Sends an email 

.DESCRIPTION
    This runbook sends an email using the specified body, subject and email address
    It can be called from a monitoring or troubleshooting runbook to alert the on call employee of a potential issue.   

    REQUIREMENTS
    You must add an asset containing the email credentials for the account that the email should be sent from.  
    
.PARAMETER Body
    REQUIRED. The body of the email.

.PARAMETER Subject
   REQUIRED. The subject of the email.

.PARAMETER SendTo
    REQUIRED. The email address for the to line of the email. 

.EXAMPLE
    Send-Email -Body "This is the body" -Subject "This is the Subject" -SendTo "myemail@contoso.com"

.NOTES
    AUTHOR: Beth Cooper, Azure Automation Team
    LAST EDIT: June 23, 2014
#>


Workflow Send-Email {
    Param (
        [Parameter(Mandatory=$true)]
        [String]
        $Body,
        
        [Parameter(Mandatory=$true)]
        [String]
        $Subject,
        
        [Parameter(Mandatory=$true)]
        [String]
        $SendTo,
        
        [Parameter(Mandatory=$true)]
        [String]
        $EmailCredentials,
        
        [Parameter(Mandatory=$true)]
        [String]
        $SmtpServer
    )

    
    #Email information
    $Creds = Get-AutomationPSCredential -Name $EmailCredentials
    $EmailFrom = $Creds.UserName

    Send-MailMessage `
        -to $SendTo `
        -from $EmailFrom `
        -subject $Subject `
        -body $Body `
        -smtpserver $SmtpServer `
        -port 587 `
        -credential $Creds `
        -usessl:$true `
        -erroraction Stop
    
}