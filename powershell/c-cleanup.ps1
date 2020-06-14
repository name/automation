<#
Name:
C-Cleanup.ps1 - C:\ Disk Drive Cleanup Script

DESCRIPTION:
A PowerShell script to delete/archive temporary files on Windows Servers.
This script is compatible with all server roles and will not delete any
information that may be needed in the future.
This script logs it's output so you can see what was removed incase you
need to troubleshoot.


Written by: Charlie Maddex
Change Log
V1.00, 14/06/2020, Initial version
#>

Function Clean-Folder{

    Param (
        [String]$Path,
        $ComputerOBJ
    )
    Write-Host "`t...Cleaning $Path" -ForegroundColor Green
    If($ComputerOBJ.PSRemoting -eq $True){
        Invoke-Command -ComputerName $ComputerOBJ.ComputerName -ScriptBlock {
            If(Test-Path $Using:Path){
                Foreach($Item in $(Get-ChildItem -Path $Using:Path -Recurse)){
                    Try{
                        Remove-item -Path $item.FullName -Confirm:$False -Recurse -ErrorAction Stop
                    }
                    Catch [System.Exception]{
                        Write-verbose "$($Item.path) - $($_.Exception.Message)"
                    }
                }
            }
        } -Credential $ComputerOBJ.Credential
    }
    Else{
        If(Test-Path $Path){
            Foreach($Item in $(Get-ChildItem -Path $Path -Recurse)){
                Try{
                    Remove-item -Path $item.FullName -Confirm:$False -Recurse -ErrorAction Stop
                }
                Catch [System.Exception]{
                    Write-verbose "$($Item.path) - $($_.Exception.Message)"
                }
            }
        }
    }
}
Function Get-AllUserProfiles{
    Param (
       $ComputerOBJ 
    )
    If($ComputerOBJ.PSRemoting -eq $true){
        $Result = Invoke-Command -ComputerName $ComputerOBJ.ComputerName -ScriptBlock {
            Try{
                $Profiles = (get-childitem c:\users -Directory -erroraction Stop).Name
                $ProfileError = $false
            } Catch [System.Exception]{
                $ProfileError = $true
            } Finally{
                If($ProfileError -eq $False){
                    Write-output $Profiles
                }
                Else{
                    Write-Output $False
                }
            }
        } -Credential $ComputerOBJ.Credential
        If($Result -eq $False){
            Write-Host "`nUnable to pull a list of user profile folders." -ForegroundColor Red
        } Else{
            Write-Host "`nUser profiles gathered. Beginning cleanup" -ForegroundColor Green
            Foreach($Profile in $Result){
                Write-host "Starting Profile : $Profile" -ForegroundColor Yellow
                $TempPath = "C:\Users\$Profile\AppData\Local\Temp"
                #$DownloadPath = "C:\Users\$Profile\Downloads"

                Clean-Folder -Path $TempPath -ComputerOBJ $ComputerOBJ
                #Clean-Folder -Path $DownloadPath -ComputerOBJ $ComputerOBJ
            }
        }
    }
    Else{
        Try{
            $Profiles = (get-childitem c:\users -Directory -erroraction Stop).Name
            $ProfileError = $false
        } Catch [System.Exception]{
            $ProfileError = $true
        } Finally{
            If($ProfileError -eq $False){
                Write-Host "User profiles gathered. Beginning cleanup" -ForegroundColor Green
                Foreach($Profile in $Profiles){
                    Write-host "Starting Profile : $Profile" -ForegroundColor Yellow
                    $TempPath = "C:\Users\$Profile\AppData\Local\Temp"
                    #$DownloadPath = "C:\Users\$Profile\Downloads"

                    Clean-Folder -Path $TempPath -ComputerOBJ $ComputerOBJ
                    #Clean-Folder -Path $DownloadPath -ComputerOBJ $ComputerOBJ
                }
            } Else{
                Write-Host "Unable to pull a list of user profile folders." -ForegroundColor Red
            }
        }
    }

}
Function Get-Computername {
    $obj = New-object PSObject -Property @{
        ComputerName = $env:COMPUTERNAME
        Remote = $False
    }
    Write-output $obj
}
Function Get-FreeSpace{
    Param (
        $ComputerOBJ
    )
    Try{
        $RawFreespace = (Get-WmiObject Win32_logicaldisk -ComputerName $ComputerOBJ.ComputerName -Credential $ComputerOBJ.Credential -ErrorAction Stop | Where-Object {$_.DeviceID -eq 'C:'}).freespace
        $FreeSpaceGB = [decimal]("{0:N2}" -f($RawFreespace/1gb))
        Write-host "Current Free Space on the OS Drive : $FreeSpaceGB GB" -ForegroundColor Yellow
    } Catch [System.Exception]{
        $FreeSpaceGB = $False
        Write-Host "Unable to pull free space from OS drive. Press enter to Exit..." -ForegroundColor Red    
    } Finally{
        $ComputerOBJ | Add-Member -MemberType NoteProperty -Name OrigFreeSpace -Value $FreeSpaceGB
        Write-output $ComputerOBJ
    }
}
Function Get-FinalFreeSpace{
    Param (
        $ComputerOBJ
    )
    Try{
        $RawFreespace = (Get-WmiObject Win32_logicaldisk -ComputerName $ComputerOBJ.ComputerName -Credential $ComputerOBJ.Credential -ErrorAction Stop | Where-Object {$_.DeviceID -eq 'C:'}).freespace
        $FreeSpaceGB = [decimal]("{0:N2}" -f($RawFreespace/1gb))
        Write-host "Final Free Space on the OS Drive : $FreeSpaceGB GB" -ForegroundColor Yellow
    } Catch [System.Exception]{
        $FreeSpaceGB = $False
        Write-Host "Unable to pull free space from OS drive. Press enter to Exit..." -ForegroundColor Red    
    } Finally{
        $ComputerOBJ | Add-Member -MemberType NoteProperty -Name FinalFreeSpace -Value $FreeSpaceGB
        Write-output $ComputerOBJ
    }
}

Clear-Host
# get hostname and remote!=
$ComputerOBJ = Get-Computername

# get current disk space
$ComputerOBJ = Get-FreeSpace -ComputerOBJ $ComputerOBJ
Write-Host ""

# clear temporary folders
Write-host "Clearing Temp folders:" -ForegroundColor Green
Clean-Folder -Path 'C:\Temp' -ComputerOBJ $ComputerOBJ
Clean-Folder -Path 'C:\Windows\Temp' -ComputerOBJ $ComputerOBJ
Clean-Folder -Path 'C:\ProgramData\Microsoft\Windows\WER\ReportArchive' -ComputerOBJ $ComputerOBJ
Clean-Folder -Path 'C:\ProgramData\Microsoft\Windows\WER\ReportQueue' -ComputerOBJ $ComputerOBJ
Write-Host "Cleared Temp Folders`n" -ForegroundColor Green

# clear users temp folders
Get-AllUserProfiles -ComputerOBJ $ComputerOBJ
Write-Host "`nAll user profiles have been processed" -ForegroundColor Green

# get disk space and display total and amount cleared
Write-Host ""
$ComputerOBJ = Get-FinalFreeSpace -ComputerOBJ $ComputerOBJ
$SpaceRecovered = $($Computerobj.finalfreespace) - $($ComputerOBJ.OrigFreeSpace)
If($SpaceRecovered -lt 0){
    Write-Host "Less than a 1 GB of Free Space was recovered." -ForegroundColor Yellow
}
ElseIf($SpaceRecovered -eq 0){
    Write-host "No Space Was saved :(" -ForegroundColor Red
}
Else{
    Write-host "Space Recovered : $SpaceRecovered GB" -ForegroundColor Green
}