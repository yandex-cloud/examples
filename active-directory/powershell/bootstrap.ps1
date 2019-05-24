#ps1
Start-Transcript -Path "$ENV:SystemDrive\Log\bootstrap.txt" -IncludeInvocationHeader -Force

function Get-InstanceMetadata ($SubPath) {
    $Headers = @{"Metadata-Flavor"="Google"}
    $Url = "http://169.254.169.254/computeMetadata/v1/instance" + $SubPath

    return Invoke-RestMethod -Headers $Headers $Url
}

"Creating local user" | Write-Host
$UserName          = Get-InstanceMetadata -SubPath "/attributes/user"
$PlainTextPassword = Get-InstanceMetadata -SubPath "/attributes/pass"
$Password          = ConvertTo-SecureString $PlainTextPassword -AsPlainText -Force
New-LocalUser -Name $UserName -Password $Password -PasswordNeverExpires -AccountNeverExpires | Add-LocalGroupMember -Group 'Administrators'
Set-LocalUser 'Administrator' -Password $Password

"Checking if deployment set" | Write-Host
$deployAvailible = Get-InstanceMetadata -SubPath "/attributes/deploy"
if ( $deployAvailible ) {
    "Deployment found" | Write-Host
    schtasks /Create /TN "deploy" /RU SYSTEM /SC ONSTART /RL HIGHEST /TR "Powershell -NoProfile -ExecutionPolicy Bypass -Command \`"& {iex (irm -H @{\\\`"Metadata-Flavor\\\`"=\\\`"Google\\\`"} \\\`"http://169.254.169.254/computeMetadata/v1/instance/attributes/deploy\\\`")}\`""
}

"Bootstrap complete" | Write-Host
