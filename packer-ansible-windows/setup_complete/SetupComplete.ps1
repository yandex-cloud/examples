# LOG
Start-Transcript -Path "$ENV:windir\Panther\SetupComplete.log" -IncludeInvocationHeader -Force

# WAIT CLOUDBASE-INIT
while ((Get-Service 'cloudbase-init').Status -eq 'Running') {
    Start-Sleep -Seconds 10
    Write-Host "Waiting cloudbase-init to stop"
}

$SerialPort = New-Object System.IO.Ports.SerialPort('COM1')

while ($SerialPort.IsOpen) {
    Start-Sleep -Seconds 10
    Write-Host "Waiting COM1 port to become availible"
}

$SerialPort.Open()

# WRITE COM1 PORT
filter Out-Serial {
    $SerialPort.WriteLine("[$((Get-Date).ToString())]::[SETUPCOMPLETE]::$_")
}

# GET METADATA
function Get-InstanceMetadata ($SubPath) {
    $Headers = @{"Metadata-Flavor" = "Google"}
    $Url = "http://169.254.169.254/computeMetadata/v1/instance" + $SubPath

    return Invoke-RestMethod -Headers $Headers $Url
}

# CORRECT ETH
"Rename network adapters" | Out-Serial
$ethIndexes = (Get-InstanceMetadata -SubPath "/network-interfaces/") -replace "/"
foreach ($index in $ethIndexes)
{
    $MacAddress = Get-InstanceMetadata -SubPath "/network-interfaces/$index/mac"
    Get-NetAdapter | `
        Where-Object MacAddress -eq ($MacAddress -replace ":", "-") | `
            Rename-NetAdapter -NewName "eth$index"
}

# SET SHUTDOWN POLICY
"Allow react on ACPI calls" | Out-Serial
Set-ItemProperty `
    -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" `
    -Name "shutdownwithoutlogon" `
    -Value 1

# SET WINRM
"Set WinRM" | Out-Serial

Remove-Item -Path WSMan:\Localhost\listener\listener* -Recurse
Remove-Item -Path Cert:\LocalMachine\My\*

$DnsName     = Get-InstanceMetadata -SubPath "/hostname"
$Certificate = New-SelfSignedCertificate `
    -CertStoreLocation "Cert:\LocalMachine\My" `
    -DnsName $DnsName `
    -Subject $ENV:COMPUTERNAME

New-Item -Path WSMan:\LocalHost\Listener `
    -Transport HTTPS `
    -Address * `
    -CertificateThumbPrint $Certificate.Thumbprint `
    -HostName $ENV:COMPUTERNAME `
    -Force

New-Item -Path WSMan:\LocalHost\Listener `
    -Transport HTTP `
    -Address * `
    -Force

# FIREWALL
# Recreating rule, this is loose step, mainly coz of unsupported --metadata-from-file
# in packer yandex builder, cleaning some mess (soon it will be)
"Set Firewall" | Out-Serial
Get-NetFirewallRule -DisplayName "WINRM-HTTPS-In-TCP" | Remove-NetFirewallRule
Get-NetFirewallRule -Name "Windows Remote Management (HTTPS-In)" | Remove-NetFirewallRule
"Creating WinRM Rule" | Out-Serial
New-NetFirewallRule `
    -Group "Windows Remote Management" `
    -DisplayName "Windows Remote Management (HTTPS-In)" `
    -Name "WINRM-HTTPS-In-TCP" `
    -LocalPort 5986 `
    -Action "Allow" `
    -Protocol "TCP" `
    -Program "System"

Get-NetFirewallRule -DisplayGroup "Windows Remote Management" | `
    Set-NetFirewallRule -Enabled "True"

"Enable ICMP Rule" | Out-Serial
Get-NetFirewallRule -Name "vm-monitoring-icmpv4" | `
    Set-NetFirewallRule -Enabled "True"

# DELETE ITSELF
"Remove itself" | Out-Serial
Get-ChildItem "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\LocalScripts" | Remove-Item
Get-ChildItem  "C:\Windows\Setup\Scripts\SetupComplete.ps1" | Remove-Item

# COMPLETE
"Complete, logs located at: $ENV:windir\Panther\SetupComplete.log" | Out-Serial
