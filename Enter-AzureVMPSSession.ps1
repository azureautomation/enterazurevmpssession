################################################################################################
# Enter-AzureVMPSSession.ps1
# Description:
# Creates and opens a PSSession to a virtual machine in Azure Cloud service. 
#
# AUTHOR: Robin Granberg (robin.granberg@microsoft.com)
# Date of creation: 2015-01-15
#
# COPIED CODE:
# This script includes code (Function InstallWinRMCert) from:
# Michael Washam, blog http://michaelwasham.com/2013/04/16/windows-azure-powershell-updates-for-iaas-ga/
#
# THIS CODE-SAMPLE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED 
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR 
# FITNESS FOR A PARTICULAR PURPOSE.
#
# This sample is not supported under any Microsoft standard support program or service. 
# The script is provided AS IS without warranty of any kind. Microsoft further disclaims all
# implied warranties including, without limitation, any implied warranties of merchantability
# or of fitness for a particular purpose. The entire risk arising out of the use or performance
# of the sample and documentation remains with you. In no event shall Microsoft, its authors,
# or anyone else involved in the creation, production, or delivery of the script be liable for 
# any damages whatsoever (including, without limitation, damages for loss of business profits, 
# business interruption, loss of business information, or other pecuniary loss) arising out of 
# the use of or inability to use the sample or documentation, even if Microsoft has been advised 
# of the possibility of such damages.
################################################################################################




param(
[string]$Service,
[string]$VM,
[switch]$help)
$strScriptName = $($MyInvocation.MyCommand.Name)

function funHelp()
{
clear
$helpText=@"
THIS CODE-SAMPLE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED 
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR 
FITNESS FOR A PARTICULAR PURPOSE.

This sample is not supported under any Microsoft standard support program or service. 
The script is provided AS IS without warranty of any kind. Microsoft further disclaims all
implied warranties including, without limitation, any implied warranties of merchantability
or of fitness for a particular purpose. The entire risk arising out of the use or performance
of the sample and documentation remains with you. In no event shall Microsoft, its authors,
or anyone else involved in the creation, production, or delivery of the script be liable for 
any damages whatsoever (including, without limitation, damages for loss of business profits, 
business interruption, loss of business information, or other pecuniary loss) arising out of 
the use of or inability to use the sample or documentation, even if Microsoft has been advised 

DESCRIPTION:
NAME: $strScriptName
Creates and opens a PSSession to a virtual machine in Azure Cloud service. 

PARAMETERS:

-Service         Name of the service that holds your VM
-VM              Your virtual machine name
-help            Prints the HelpFile (Optional)



SYNTAX:
 -------------------------- EXAMPLE 1 --------------------------
 

.\$strScriptName -Service AzureService1 -VM MySslSrv1


 Description
 -----------
 Enter a PSSession to your VM in Azure.


 -------------------------- EXAMPLE 2 --------------------------
 
.\$strScriptName -help

 Description
 -----------
 Displays the help topic for the script

 

"@
write-host $helpText
exit
}
if ($help -or (!$Service) -or (!$vm)){funHelp}

#Check for certificate installation
$global:boolCertInstallOk = $true

function InstallWinRMCert($serviceName, $vmname)
{
#Function copied from Michael Washam, blog http://michaelwasham.com/2013/04/16/windows-azure-powershell-updates-for-iaas-ga/
    $ErrorActionPreference = "SilentlyContinue"
    $winRMCert = (Get-AzureVM -ServiceName $serviceName -Name $vmname | select -ExpandProperty vm).DefaultWinRMCertificateThumbprint
 
    $AzureX509cert = Get-AzureCertificate -ServiceName $serviceName -Thumbprint $winRMCert -ThumbprintAlgorithm sha1
 
    $certTempFile = [IO.Path]::GetTempFileName()
    $AzureX509cert.Data | Out-File $certTempFile
 
    # Target The Cert That Needs To Be Imported
    $CertToImport = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 $certTempFile
 
    $store = New-Object System.Security.Cryptography.X509Certificates.X509Store "Root", "LocalMachine"
    #$store.Certificates.Count
      try
  {
    $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
    $store.Add($CertToImport)
  }
  catch
  {
    Write-Output "Unable to store the certificate! Do you got enough permissions?"
    $global:boolCertInstallOk = $false
  }

    $store.Close()
 
    Remove-Item $certTempFile
}


$vmObject = Get-AzureVM -service $Service -Name $VM
if ($vmObject.PowerState -eq 'Started' -and $vmObject.Status -eq 'ReadyRole')
{
    if(gci CERT:\\LocalMachine\Root | Where-Object{$_.Subject -eq "CN=$Service.cloudapp.net"})
    {
        #Write-Output "You got a certificate for your service!"
    }
    else
    {
        Write-output "You do not have a certificate for the service:$Service "
        $name = Read-Host 'Do you want to install a certificate for your Azure Service? Press [y] for yes. Press anything else for no'
        if ($name.length -eq 1  -and$name -match "y")
        {


            InstallWinRMCert -serviceName $Service -vmname $VM
        }
        else
        {
            Write-Output "Without certificate you cannot continue. Exiting!"
            Exit
        }
    }
    if ($global:boolCertInstallOk -eq $true)
    {
         Write-Output "Creating a new PowerShell session to: $VM"
        $uri = Get-AzureWinRMUri -ServiceName $Service -Name $VM

        $credentials = Get-Credential -ErrorAction SilentlyContinue -Message "Enter your credentials for $VM"
        if (!($credentials -eq $null))
        {

              
                $session = New-PSSession -ComputerName $uri[0].DnsSafeHost -Credential $credentials -Port $uri[0].Port -UseSSL -Name $VM
                if ($session -eq $null)
                {
                    Write-Output "Unable to create a PowerShell session. Exiting."
                    Exit
                }

              
            
            Write-output "Opening a Session to $VM. To exit your PSSession type Exit-PSSession)"
            Enter-PSSession -Session $session
        }
        else
        {
            Write-Output "No Creds Entered!"
        }
    }
    else
    {
    write-Output "Could not install certificate"
    }
}
else
{
write-output "Your machine: $VM or service: $service does not exist or are not available!"
}