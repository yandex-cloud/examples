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
    }
    else {
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

    "Creating forest" | Out-Serial  
    $PlainSafeModeAdministratorPassword = Get-InstanceMetadata -SubPath "/attributes/smadminpass"
    $SafeModeAdministratorPassword = ConvertTo-SecureString $PlainSafeModeAdministratorPassword `
        -AsPlainText `
        -Force
    Install-ADDSForest `
        -ForestMode                    "WinThreshold" `
        -DomainMode                    "WinThreshold" `
        -DomainName                    $DomainName `
        -DomainNetbiosName             $DomainName.Split(".")[0] `
        -DatabasePath                  "C:\Windows\NTDS" `
        -SysvolPath                    "C:\Windows\SYSVOL" `
        -LogPath                       "C:\Windows\NTDS" `
        -InstallDns:                   $true `
        -CreateDnsDelegation:          $false `
        -NoRebootOnCompletion:         $true `
        -Force:                        $true `
        -SafeModeAdministratorPassword $SafeModeAdministratorPassword

    "Configuring dns" | Out-Serial
    $InterfaceIndex = Get-NetAdapter | Select-Object -ExpandProperty InterfaceIndex
    $MyIP = Get-NetIPAddress -InterfaceIndex $InterfaceIndex -AddressFamily IPv4 | `
        Select-Object -ExpandProperty IPAddress
    Set-DnsClientServerAddress -InterfaceIndex $InterfaceIndex -ServerAddresses "$MyIP,127.0.0.1"

    $DHCPServer = Get-WmiObject Win32_NetworkAdapterConfiguration | `
        Where-Object InterfaceIndex -eq $InterfaceIndex | `
        Select-Object -ExpandProperty "DHCPServer"
    Set-DnsServerForwarder $DHCPServer

    "Restarting" | Out-Serial
    Restart-Computer -Force
}
else {  
    Wait-ADDSOnline -DomainName $DomainName -Credential $Credential
    
    "Adding $User to AD administrative groups" | Out-Serial  
    Import-Module ActiveDirectory
    Add-ADGroupMember -Identity "Domain Admins"     -Members $Credential.GetNetworkCredential().UserName
    Add-ADGroupMember -Identity "Enterprise Admins" -Members $Credential.GetNetworkCredential().UserName
    
    "Creating sites" | Out-Serial
    $ADSites = (Get-InstanceMetadata -SubPath "/attributes/sites") -split ","
    $ADSubnets = (Get-InstanceMetadata -SubPath "/attributes/cidrs") -split ","  
    for ($i = 0; $i -lt $ADSites.length; $i++) {
        "Creating site $($ADSites[$i])" | Out-Serial
        New-ADReplicationSite $ADSites[$i]
        "Creating replication subnet $($ADSubnets[$i])" | Out-Serial
        New-ADReplicationSubnet -Name $ADSubnets[$i] -Site $ADSites[$i]
    }

    "Creating site-link" | Out-Serial
    $MySite = Split-Path -Leaf (Get-InstanceMetadata -SubPath "/zone")
    $MyLink = ($MySite -split "-" | Select-Object -First 2) -join "-"
    Move-ADDirectoryServer -Identity $ENV:COMPUTERNAME -Site $MySite
    New-ADReplicationSiteLink `
        -Name $MyLink `
        -Cost 100 `
        -InterSiteTransportProtocol IP `
        -ReplicationFrequencyInMinutes 15 `
        -OtherAttributes @{'options' = 1 } `
        -SitesIncluded $ADSites

    Remove-ADReplicationSiteLink DEFAULTIPSITELINK -Confirm:$false
    Remove-ADReplicationSite "Default-First-Site-Name" -Confirm:$false

    "Deployment Complete" | Out-Serial
    Unregister-ScheduledTask -TaskName 'deploy' -Confirm:$false
}
