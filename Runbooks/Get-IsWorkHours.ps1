<# 
.SYNOPSIS 
    Determines whether the current time is in or out of work hours   
 
.DESCRIPTION 
    This runbook determines if the current time is in or out of work hours. It checks
    if the time is in the specified work hours range and if it is a weekend. 
 
    Returns $true if the time is in work hours.  
    Returns $false if the time is outside of work hours. 
    
 .PARAMETER MyWeekDayStartHour
    The hour that a work day starts.  Can be 0 - 23.
     
.PARAMETER MyWeekDayEndHour 
    The hour that a work day ends.  Can be 0 - 23.
 
.EXAMPLE 
    Get-IsWorkHours -MyWeekDayStartHour 07 
                    -MyWeekDayEndHour 18
 
.NOTES 
    Author: Beth Cooper  
    Last Updated: 10/30/2014    
#>


workflow Get-IsWorkHours
{
    param (
        [int] $MyWeekDayStartHour = 8,
                        
        [int] $MyWeekDayEndHour = 18
    )
    
    # Convert the date to be in the local time zone
    # See http://msdn.microsoft.com/en-us/library/system.timezoneinfo.findsystemtimezonebyid(v=vs.110).aspx
    # for more information
    function ConvertDatetime {
        param(
            [DateTime]$DateTime,
            [String] $ToTimeZone
        )
    
        $oToTimeZone = [System.TimeZoneInfo]::FindSystemTimeZoneById($ToTimeZone)
        $UtcDateTime = $DateTime.ToUniversalTime()
        $ConvertedTime = [System.TimeZoneInfo]::ConvertTime($UtcDateTime, $oToTimeZone)
    
        return $ConvertedTime
    }
    
    #Set the dates 
    $Now = Get-Date -Day 1 -Month 11
    $Now = ConvertDatetime -Datetime $Now -ToTimeZone 'Central European Standard Time'
    $TodayStart = Get-Date -Hour $MyWeekDayStartHour -Minute 00 -Day $Now.Day -Month $Now.Month
    $TodayEnd = Get-Date -Hour $MyWeekDayEndHour -Minute 00 -Day $Now.Day -Month $Now.Month

    # Check if today is a holiday
    $IsHoliday = Get-IsHoliday -country "US" -dateToCheck $Now 
    
    if ($IsHoliday) {
        $Holidays = Get-Holidays -country "US" -dateToCheck $Now 
        foreach ($Holiday in $Holidays)   {
            $Name = $Holiday.Name    
            Write-Verbose -Message "Today is a holiday: $Name" -Verbose
        }
        return $false
    }

    # Check if the time is currently within work hours
    if ($Now -lt $TodayStart -or $Now -gt $TodayEnd) {
        Write-Verbose -Message "It is currently outside of work hours. Time: $Now" -Verbose
        return $false
    }   
    
    # Check if today is a weekend
    $Day = InlineScript {
     $using:Now.DayOfWeek
    }
        
    #Day 0 = Sunday, 1 = Monday, etc. 
    #See http://technet.microsoft.com/en-us/library/ff730960.aspx
    if ($Day -eq 0 -or $Day -eq 6) {
        Write-Verbose -Message "It is a weekend: Today is the $Day of the week." -Verbose
        return $false
    }
     
    #Return true if none of the above hits
    return $true
}