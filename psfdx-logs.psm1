function Watch-SalesforceLogs {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)][string] $Username,        
        [Parameter(Mandatory = $false)][switch] $UseDebugLogSetup        
    )  
    $command = "sfdx force:apex:log:tail "  
    if ($UseDebugLogSetup) {
        $command += ""
    }
    else {    
        $command += "--skiptraceflag "
    }
    $command += "--color -u $Username"
    return Invoke-Sfdx -Command $command
}

function Get-SalesforceLogs {
    [CmdletBinding()]
    Param([Parameter(Mandatory = $true)][string] $Username)  
    $result = Invoke-Sfdx -Command "sfdx force:apex:log:list -u $Username --json"
    return Show-SfdxResult -Result $result
}

function Get-SalesforceLog {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)][string] $LogId,
        [Parameter(Mandatory = $false)][switch] $Last,
        [Parameter(Mandatory = $true)][string] $Username
    )   
    
    if ((-not $LogId) -and (-not $Last)) { throw "Please provide either -LogId OR -Last" }

    if ($Last) {
        $LogId = (Get-SalesforceLogs -Username $Username | Sort-Object StartTime -Descending | Select-Object -First 1).Id
    }

    $result = Invoke-Sfdx -Command "sfdx force:apex:log:get -i $LogId -u $Username --json"
    $result = $result | ConvertFrom-Json
    # TODO: Check status
    return $result.result.log
}

function Export-SalesforceLogs {
    [CmdletBinding()]
    Param(        
        [Parameter(Mandatory = $false)][int] $Limit = 50,
        [Parameter(Mandatory = $false)][string] $OutputFolder = $null,
        [Parameter(Mandatory = $true)][string] $Username
    )        
        
    if (($OutputFolder -eq $null) -or ($OutputFolder -eq "") ) {
        $currentFolder = (Get-Location).Path
        $OutputFolder = $currentFolder        
    }
    if ((Test-Path -Path $OutputFolder) -eq $false) { throw "Folder $OutputFolder does not exist" }
    Write-Verbose "Output Folder: $OutputFolder"

    $logs = Get-SalesforceLogs -Username $Username | Sort-Object -Property StartTime -Descending | Select-Object -First $Limit
    if ($null -eq $logs) {
        Write-Verbose "No Logs"
        return
    }

    $logsCount = ($logs | Measure-Object).Count + 1    
    $i = 0
    foreach ($log in $logs) {
        $fileName = $log.Id + ".log"
        $filePath = Join-Path -Path $OutputFolder -ChildPath $fileName
        Write-Verbose "Exporting file: $filePath"
        Get-SalesforceLog -LogId $log.Id -Username $Username | Out-File -FilePath $filePath   

        $percentCompleted = ($i / $logsCount) * 100
        Write-Progress -Activity "Export Salesforce Logs" -Status "Completed $fileName" -PercentComplete $percentCompleted
        $i = $i + 1
    }
}

function Convert-SalesforceLog {
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline, Mandatory = $true)][string] $Log
    )      

    Write-Warning "Function still in Development"

    $results = @()
    $lines = $Log.Split([Environment]::NewLine) | Select-Object -Skip 1 # Skip Header
    $line = $lines | Select-Object -First 5
    foreach ($line in $lines) {
        $statements = $line.Split('|')
        
        $result = New-Object -TypeName PSObject
        $result | Add-Member -MemberType NoteProperty -Name 'DateTime' -Value $statements[0]
        $result | Add-Member -MemberType NoteProperty -Name 'LogType' -Value $statements[1]
        if ($null -ne $statements[2]) { $result | Add-Member -MemberType NoteProperty -Name 'SubType' -Value $statements[2] }
        if ($null -ne $statements[3]) { $result | Add-Member -MemberType NoteProperty -Name 'Detail' -Value $statements[3] }
        $results += $result
    }
    return $results
}

function Out-Notepad {
    [CmdletBinding()]
    Param([Parameter(ValueFromPipeline, Mandatory = $true)][string] $Content)     
    $filename = New-TemporaryFile
    $Content | Out-File -FilePath $filename
    notepad $filename
}

Export-ModuleMember Watch-SalesforceLogs
Export-ModuleMember Get-SalesforceLogs
Export-ModuleMember Get-SalesforceLog
Export-ModuleMember Export-SalesforceLogs
Export-ModuleMember Convert-SalesforceLog
Export-ModuleMember Out-Notepad