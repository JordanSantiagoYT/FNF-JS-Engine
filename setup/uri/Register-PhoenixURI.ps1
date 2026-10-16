# Per-user registration: no administrator rights required.
param([string]$Executable = (Join-Path $PSScriptRoot '..\FNF-Phoenix-Engine.exe'))
$ErrorActionPreference = 'Stop'
$exe = (Resolve-Path -LiteralPath $Executable).Path
if ([IO.Path]::GetExtension($exe) -ine '.exe') { throw 'Select the Phoenix Engine executable.' }
$key = 'HKCU:\Software\Classes\phoenix'
# Check before writing: never clobber another copy's handler.
if (Test-Path "$key\shell\open\command") {
    $existing = (Get-Item "$key\shell\open\command").GetValue('')
    $expected = '"' + $exe + '" "%1"'
    if ($existing -ne $null -and $existing -ne $expected) {
        throw 'Another installation owns phoenix://; refusing to overwrite its registration.'
    }
}
New-Item -Path $key -Force | Out-Null
Set-Item -Path $key -Value 'URL:Phoenix Engine Protocol'
New-ItemProperty -Path $key -Name 'URL Protocol' -Value '' -PropertyType String -Force | Out-Null
New-Item -Path "$key\DefaultIcon" -Force | Out-Null
Set-Item -Path "$key\DefaultIcon" -Value ('"' + $exe + '",0')
New-Item -Path "$key\shell\open\command" -Force | Out-Null
# Direct invocation, never cmd.exe/PowerShell and never an unquoted URI.
Set-Item -Path "$key\shell\open\command" -Value ('"' + $exe + '" "%1"')
Write-Host "Registered phoenix:// for $exe. Re-run after moving the game."
