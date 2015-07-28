workflow Watch-SharePointList
{
    $ListName = "Support Requests"
    
    $Cred = Get-AutomationPSCredential -Name 'SharePointCred'
    
    $URL = "https://scautomation.sharepoint.com"
    $SqlServer = "pc2lg0xblg.database.windows.net"
    $Database = "MyDB"
    
    
    $ListItemID = InlineScript {
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
        $List = Get-SharePointOnlineListItem `
            -Credential $Using:Cred `
            -ListName $Using:ListName `
            -SiteURL $Using:URL 
       
        if ($List) {
            foreach ($ListItem in $List)
            {
                if (($ListItem.Status) -eq "Closed")
                {
                    # Update the list to show remdiation is occurring
                    $UpdatedValues = @{}
                    $UpdatedValues.Add("StatusDetails", "Remediating...")
                    $UpdatedValues.Add("ID", $ListItem.ID)
                    
                    Update-SharePointOnlineListItem `
                        -Credential $Using:Cred `
                        -ListName $Using:ListName `
                        -ListProperties $Using:UpdatedValues `
                        -SiteURL $Using:URL 
                    
                    $ListItem.ID.ToString()
                    
                    #Call the remdiation runbook
                    $Action = $ListItem.Remediation_x0020_Action
                    $Action 
                    $Status = ""
                    if ($Action -eq "Index SQL Tables") 
                    {
                        $Status = "Indexing SQL..."
                        #$Status = Update-SQLIndexRunbook 
                        
                    } 
                    elseif ($Action -eq "Truncate SQL DB") 
                    {
                        "Truncating SQL tables..."
                        $Status = Remove-DataFromSqlDbTable -SqlServerName $Using:SqlServer
                    }
                    elseif ($Action -eq "Vertically scale SQL") 
                    {
                        "Vertically scaling SQL up..."
                        $Status = Set-AzureSqlDatabaseEdition -DatabaseName $Using:Database -Edition 'Premium' -PerfLevel 'P1' -SqlServerName $Using:SqlServer
                    } 
                    
                    #Update SharePoint to reflect status of remediation runbooks
                    $UpdatedValues = @{}
                    $UpdatedValues.Add("StatusDetails", $Status)
                    $UpdatedValues.Add("Status", "Closed")
                    $UpdatedValues.Add("ID", $ListItem.ID)
                    
                    Update-SharePointOnlineListItem `
                        -Credential $Using:Cred `
                        -ListName $Using:ListName `
                        -ListProperties $Using:UpdatedValues `
                        -SiteURL $Using:URL 
                    
                    
                }
            }
        }
        
        
    }
    
    
}