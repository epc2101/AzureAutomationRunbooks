workflow Say-HelloSample {
    param ( [string] $Name )


    Write-Output "Hello"

    Get-Date


    Get-Module -ListAvailable


}