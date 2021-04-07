﻿#Author Jonathan Johnson
#License: GPL-3.0

#Resources -
#Microsoft-Docs:https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.management/rename-computer?view=powershell-6
#Microsoft-Docs: https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.security/get-credential?view=powershell-6

Write-Output "Setting timezone to UTC...."

c:\windows\system32\tzutil.exe /s "UTC"

Write-Output "Renaming Host..."

$User = Read-Host "Please enter username"
$Password = Read-Host "Please enter username password" -AsSecureString

$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $Password

Rename-computer –computername $env:COMPUTERNAME –newname (“Earth-DC”) -DomainCredential $Credential -Force -Restart