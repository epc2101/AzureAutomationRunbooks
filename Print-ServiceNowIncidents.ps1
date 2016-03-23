<#*******************************************
Using global var to store auth creds in.  
Will not work in PS Workflow.  
*********************************************#>

$Cred = Get-AutomationPSCredential -Name 'ServiceNowCred'
$Url = "msitpovitsmpov.service-now.com"

Write-Output "Testing using auth`n`n"
Set-ServiceNowAuth `
		-Credentials $Cred `
		-url $Url
	
Get-ServiceNowIncident `
		-DisplayValues 'true' `
		-Limit 15 
		
New-ServiceNowIncident `
		-Caller "elcooper" `
		-ShortDescription "Automation auto-generate incident #1"


<#*******************************************
Using cred & URL.  
*********************************************#>

Write-Output "Testing using cred & URL`n`n"
Get-ServiceNowIncident -ServiceNowCredential $Cred -ServiceNowURL $Url

Write-Output "Testing new incident using cred & Url"
New-ServiceNowIncident `
		-Caller "elcooper" `
		-ServiceNowCredential $Cred `
		-ServiceNowURL $Url `
		-ShortDescription "Automation auto-generate incident #2" `
		
<#*******************************************
Using connection.  
*********************************************#>
Write-Output "testing using connection`n`n"
	
$Conn = Get-AutomationConnection -Name 'ServiceNowConnection'	
$Conn.Username
$Conn.Password
$Conn.URL

Get-ServiceNowIncident -Connection $Conn

