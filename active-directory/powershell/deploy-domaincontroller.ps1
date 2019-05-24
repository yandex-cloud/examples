# log
Start-Transcript -Path "$ENV:SystemDrive\Log\deploy.txt" -IncludeInvocationHeader -Force

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

##########
# some helpers
##########

filter Out-Serial {
    $SerialPort.WriteLine("[$((Get-Date).ToString())]::[PROVISION]::$_")
}

function Get-InstanceMetadata ($SubPath) {
    $Headers = @{"Metadata-Flavor" = "Google"}
    $Url = "http://169.254.169.254/computeMetadata/v1/instance" + $SubPath

    return Invoke-RestMethod -Headers $Headers $Url
}

function Test-ADDSOnline ($DomainName, $Credential) {
    $Context = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext(
        'Domain', 
        $DomainName, 
        $Credential.UserName, 
        $Credential.GetNetworkCredential().Password)
    
    if ([System.DirectoryServices.ActiveDirectory.DomainController]::FindOne($Context)) {
        return $true
    } else {
        return $false
    }
}

function Wait-ADDSOnline ($DomainName, $Credential) {
    while (-not (Test-ADDSOnline -Domain $DomainName -Credential $Credential)) {
        "Waiting 1m for ADDS..." | Out-Serial
        Clear-DnsClientCache
        Start-Sleep -Seconds 60
    }
}

function Wait-ADSiteCreated ($DomainName, $Site) {
    while (-not (Resolve-DnsName "_ldap._tcp.$Site._sites.$DomainName")) {
        "Waiting 1m for AD Site RR..." | Out-Serial
        Clear-DnsClientCache
        Start-Sleep -Seconds 60
    }
}

##########
# deployment
##########

$DomainName = Get-InstanceMetadata -SubPath "/attributes/domainname"
$User       = "$DomainName\$(Get-InstanceMetadata -SubPath "/attributes/user")"
$PlainPass  = Get-InstanceMetadata -SubPath "/attributes/pass"
$Password   = ConvertTo-SecureString $PlainPass -AsPlainText -Force
$Credential = New-Object PSCredential($User, $Password)

$isADDSRoleInstalled = (Get-WindowsFeature -Name AD-Domain-Services).Installed
if (-not $isADDSRoleInstalled) {
    "Installing Roles" | Out-Serial
    Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

    "Pointing dns to forest root" | Out-Serial
    $ForestRootName = Get-InstanceMetadata -SubPath "/attributes/forestroot"
    $ForestRootIP   = Resolve-DnsName -Name $ForestRootName -Type A | `
        Where-Object Section -eq Answer | `
        Select-Object -ExpandProperty IPAddress
    $InterfaceIndex = Get-NetAdapter | Select-Object -ExpandProperty InterfaceIndex
    Set-DnsClientServerAddress `
        -InterfaceIndex $InterfaceIndex `
        -ServerAddresses $ForestRootIP

    Wait-ADDSOnline -DomainName $DomainName -Credential $Credential
    Add-Computer    -DomainName $DomainName -Credential $Credential

    "Restarting" | Out-Serial
    Restart-Computer -Force
} else {
    $MySite = Split-Path -Leaf (Get-InstanceMetadata -SubPath "/zone")
    Wait-ADSiteCreated -DomainName $DomainName -Site $MySite

    $PlainSafeModeAdministratorPassword = Get-InstanceMetadata -SubPath "/attributes/smadminpass"
    $SafeModeAdministratorPassword = ConvertTo-SecureString $PlainSafeModeAdministratorPassword -AsPlainText -Force
    "Promoting domain controller" | Out-Serial
    Install-ADDSDomainController `
        -DomainName                    $DomainName `
        -SiteName                      $MySite `
        -DatabasePath                  "C:\Windows\NTDS" `
        -SysvolPath                    "C:\Windows\SYSVOL" `
        -LogPath                       "C:\Windows\NTDS" `
        -InstallDns:                   $true `
        -CreateDnsDelegation:          $false `
        -NoGlobalCatalog:              $false `
        -CriticalReplicationOnly:      $false `
        -NoRebootOnCompletion:         $true `
        -Force:                        $true `
        -Credential                    $Credential `
        -SafeModeAdministratorPassword $SafeModeAdministratorPassword

    "Configuring dns" | Out-Serial
    $InterfaceIndex = Get-NetAdapter | Select-Object -ExpandProperty InterfaceIndex  
    $MyIP           = (Get-NetIPAddress -InterfaceIndex $InterfaceIndex -AddressFamily IPv4).IPAddress
    Set-DnsClientServerAddress -InterfaceIndex $InterfaceIndex -ServerAddresses "$MyIP,127.0.0.1"

    $DHCPServer = Get-WmiObject Win32_NetworkAdapterConfiguration | `
        Where-Object InterfaceIndex -eq $InterfaceIndex | `
            Select-Object -ExpandProperty "DHCPServer"
    Set-DnsServerForwarder $DHCPServer

    "Deployment Complete, restarting" | Out-Serial
    Unregister-ScheduledTask -TaskName 'deploy' -Confirm:$false
    Restart-Computer -Force
}
