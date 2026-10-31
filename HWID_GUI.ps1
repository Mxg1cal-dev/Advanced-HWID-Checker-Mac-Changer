# ============================================================
#  HWID Checker GUI
#  Made by Mxg1cal
# ============================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -STA -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

$ErrorActionPreference = 'SilentlyContinue'
$Desktop = [Environment]::GetFolderPath('Desktop')
$FilePattern = 'HWID_Report_*.txt'
$script:SaveLocation = $Desktop

$Categories = [ordered]@{
    'System (SMBIOS / chassis)' = @('System.')
    'Windows identifiers'       = @('Windows.')
    'BIOS'                      = @('BIOS.')
    'Motherboard'               = @('Baseboard.')
    'CPU'                       = @('CPU[')
    'RAM modules'               = @('RAM[')
    'Disks'                     = @('Disk[', 'PhysicalDisk[', 'DiskGPT[', 'Volume[')
    'Network / IP'              = @('NetAdapter[', 'Network.')
    'Graphics cards'            = @('GPU[')
    'Monitors'                  = @('Monitor[')
    'Sound devices'             = @('Sound[')
    'TPM / Secure Boot'         = @('TPM.', 'SecureBoot.')
    'Battery'                   = @('Battery[')
}

# a distinct, readable color per category (dark-background friendly)
$CategoryColors = @{
    'System (SMBIOS / chassis)' = [System.Drawing.Color]::FromArgb(255, 180, 120)
    'Windows identifiers'       = [System.Drawing.Color]::FromArgb(120, 200, 255)
    'BIOS'                      = [System.Drawing.Color]::FromArgb(220, 160, 255)
    'Motherboard'               = [System.Drawing.Color]::FromArgb(255, 140, 180)
    'CPU'                       = [System.Drawing.Color]::FromArgb(140, 220, 140)
    'RAM modules'               = [System.Drawing.Color]::FromArgb(180, 255, 180)
    'Disks'                     = [System.Drawing.Color]::FromArgb(255, 220, 120)
    'Network / IP'              = [System.Drawing.Color]::FromArgb(120, 255, 230)
    'Graphics cards'            = [System.Drawing.Color]::FromArgb(255, 120, 120)
    'Monitors'                  = [System.Drawing.Color]::FromArgb(180, 180, 255)
    'Sound devices'             = [System.Drawing.Color]::FromArgb(255, 200, 220)
    'TPM / Secure Boot'         = [System.Drawing.Color]::FromArgb(200, 255, 255)
    'Battery'                   = [System.Drawing.Color]::FromArgb(255, 255, 160)
    'Other'                     = [System.Drawing.Color]::FromArgb(200, 200, 200)
}

function Get-CategoryForKey($key) {
    foreach ($cat in $Categories.Keys) {
        foreach ($prefix in $Categories[$cat]) {
            if ($key.StartsWith($prefix)) { return $cat }
        }
    }
    return 'Other'
}

function Get-HWIDData($includePublicIP) {
    $items = New-Object System.Collections.Generic.List[object]
    function Add-Item($k, $v) { $items.Add([PSCustomObject]@{ Key = $k; Value = ([string]$v).Trim() }) }
    function Get-Reg($path, $name) { (Get-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue).$name }
    function Decode($arr) { if ($arr) { -join ($arr | Where-Object { $_ -ne 0 } | ForEach-Object { [char]$_ }) } }

    $p = Get-CimInstance Win32_ComputerSystemProduct
    Add-Item 'System.SMBIOS.Vendor' $p.Vendor
    Add-Item 'System.SMBIOS.Name' $p.Name
    Add-Item 'System.SMBIOS.IdentifyingNumber' $p.IdentifyingNumber
    Add-Item 'System.SMBIOS.UUID' $p.UUID

    $cs = Get-CimInstance Win32_ComputerSystem
    Add-Item 'System.ComputerSystem.Manufacturer' $cs.Manufacturer
    Add-Item 'System.ComputerSystem.Model' $cs.Model
    Add-Item 'System.ComputerSystem.SKU' $cs.SystemSKUNumber

    $enc = Get-CimInstance Win32_SystemEnclosure
    Add-Item 'System.Enclosure.Manufacturer' $enc.Manufacturer
    Add-Item 'System.Enclosure.SerialNumber' $enc.SerialNumber
    Add-Item 'System.Enclosure.AssetTag' $enc.SMBIOSAssetTag

    Add-Item 'Windows.MachineGuid' (Get-Reg 'HKLM:\SOFTWARE\Microsoft\Cryptography' 'MachineGuid')
    Add-Item 'Windows.HwProfileGuid' (Get-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\IDConfigDB\Hardware Profiles\0001' 'HwProfileGuid')
    Add-Item 'Windows.ProductId' (Get-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' 'ProductId')
    Add-Item 'Windows.SQMMachineId' (Get-Reg 'HKLM:\SOFTWARE\Microsoft\SQMClient' 'MachineId')
    Add-Item 'Windows.SusClientId' (Get-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate' 'SusClientId')
    Add-Item 'Windows.UserSID' ([Security.Principal.WindowsIdentity]::GetCurrent().User.Value)
    $os = Get-CimInstance Win32_OperatingSystem
    Add-Item 'Windows.OSCaption' $os.Caption
    Add-Item 'Windows.OSSerialNumber' $os.SerialNumber
    Add-Item 'Windows.OSArchitecture' $os.OSArchitecture
    Add-Item 'Windows.EditionID' (Get-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' 'EditionID')
    Add-Item 'Windows.DisplayVersion' (Get-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' 'DisplayVersion')
    Add-Item 'Windows.CurrentBuild' (Get-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' 'CurrentBuild')
    Add-Item 'Windows.UBR' (Get-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' 'UBR')
    Add-Item 'Windows.InstallDate' $os.InstallDate
    Add-Item 'Windows.RegisteredOwner' (Get-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' 'RegisteredOwner')

    $bios = Get-CimInstance Win32_BIOS
    Add-Item 'BIOS.Manufacturer' $bios.Manufacturer
    Add-Item 'BIOS.Version' $bios.SMBIOSBIOSVersion
    Add-Item 'BIOS.SerialNumber' $bios.SerialNumber

    $bb = Get-CimInstance Win32_BaseBoard
    Add-Item 'Baseboard.Manufacturer' $bb.Manufacturer
    Add-Item 'Baseboard.Product' $bb.Product
    Add-Item 'Baseboard.SerialNumber' $bb.SerialNumber

    $i = 0
    foreach ($c in (Get-CimInstance Win32_Processor)) {
        Add-Item "CPU[$i].Name" $c.Name
        Add-Item "CPU[$i].ProcessorId" $c.ProcessorId
        Add-Item "CPU[$i].SerialNumber" $c.SerialNumber
        $i++
    }

    $i = 0
    foreach ($r in (Get-CimInstance Win32_PhysicalMemory | Sort-Object DeviceLocator)) {
        Add-Item "RAM[$i].DeviceLocator" $r.DeviceLocator
        Add-Item "RAM[$i].Manufacturer" $r.Manufacturer
        Add-Item "RAM[$i].PartNumber" $r.PartNumber
        Add-Item "RAM[$i].SerialNumber" $r.SerialNumber
        $i++
    }

    $i = 0
    foreach ($d in (Get-CimInstance Win32_DiskDrive | Sort-Object SerialNumber, Model)) {
        Add-Item "Disk[$i].Model" $d.Model
        Add-Item "Disk[$i].SerialNumber" $d.SerialNumber
        Add-Item "Disk[$i].FirmwareRevision" $d.FirmwareRevision
        Add-Item "Disk[$i].PNPDeviceID" $d.PNPDeviceID
        $i++
    }
    $i = 0
    foreach ($d in (Get-PhysicalDisk | Sort-Object SerialNumber, FriendlyName)) {
        Add-Item "PhysicalDisk[$i].FriendlyName" $d.FriendlyName
        Add-Item "PhysicalDisk[$i].SerialNumber" $d.SerialNumber
        Add-Item "PhysicalDisk[$i].UniqueId" $d.UniqueId
        $i++
    }
    $i = 0
    foreach ($d in (Get-Disk | Sort-Object SerialNumber, FriendlyName)) {
        Add-Item "DiskGPT[$i].FriendlyName" $d.FriendlyName
        Add-Item "DiskGPT[$i].SerialNumber" $d.SerialNumber
        Add-Item "DiskGPT[$i].Guid" $d.Guid
        $i++
    }
    foreach ($v in (Get-CimInstance Win32_LogicalDisk)) {
        Add-Item "Volume[$($v.DeviceID)].VolumeSerialNumber" $v.VolumeSerialNumber
    }

    # network adapters incl. IPv4/IPv6/gateway/DNS/MAC
    # sorted by MAC (a stable key) instead of raw enumeration order, since Windows doesn't
    # guarantee adapters come back in the same order between runs
    $i = 0
    foreach ($n in (Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' -or $_.Status -eq 'Disconnected' } | Sort-Object MacAddress)) {
        Add-Item "NetAdapter[$i].Name" $n.Name
        Add-Item "NetAdapter[$i].MacAddress" $n.MacAddress
        Add-Item "NetAdapter[$i].InterfaceGuid" $n.InterfaceGuid
        Add-Item "NetAdapter[$i].Status" $n.Status
        $ipv4 = Get-NetIPAddress -InterfaceIndex $n.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
        # exclude "Random" (temporary/privacy) IPv6 addresses - Windows rotates these by design,
        # they are not a stable identifier and will always show as "changed" otherwise
        $ipv6 = Get-NetIPAddress -InterfaceIndex $n.ifIndex -AddressFamily IPv6 -ErrorAction SilentlyContinue |
                Where-Object { $_.SuffixOrigin -ne 'Random' }
        $cfg = Get-NetIPConfiguration -InterfaceIndex $n.ifIndex -ErrorAction SilentlyContinue
        Add-Item "NetAdapter[$i].IPv4Address" (($ipv4.IPAddress | Sort-Object) -join ', ')
        Add-Item "NetAdapter[$i].IPv6Address" (($ipv6.IPAddress | Sort-Object) -join ', ')
        if ($cfg) {
            Add-Item "NetAdapter[$i].Gateway" (($cfg.IPv4DefaultGateway.NextHop | Sort-Object) -join ', ')
            Add-Item "NetAdapter[$i].DNSServers" (($cfg.DNSServer.ServerAddresses | Sort-Object) -join ', ')
        }
        $i++
    }
    Add-Item 'Network.Hostname' $env:COMPUTERNAME
    if ($includePublicIP) {
        try {
            $pub = Invoke-RestMethod -Uri 'https://api.ipify.org?format=json' -TimeoutSec 5
            Add-Item 'Network.PublicIP' $pub.ip
        } catch {
            Add-Item 'Network.PublicIP' '(lookup failed / no internet)'
        }
    }

    $i = 0
    foreach ($g in (Get-CimInstance Win32_VideoController | Sort-Object PNPDeviceID)) {
        Add-Item "GPU[$i].Name" $g.Name
        Add-Item "GPU[$i].PNPDeviceID" $g.PNPDeviceID
        $i++
    }

    $i = 0
    foreach ($m in (Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID | Sort-Object InstanceName)) {
        Add-Item "Monitor[$i].Manufacturer" (Decode $m.ManufacturerName)
        Add-Item "Monitor[$i].Serial" (Decode $m.SerialNumberID)
        Add-Item "Monitor[$i].Name" (Decode $m.UserFriendlyName)
        $i++
    }

    $i = 0
    foreach ($s in (Get-CimInstance Win32_SoundDevice | Sort-Object PNPDeviceID)) {
        Add-Item "Sound[$i].Name" $s.Name
        Add-Item "Sound[$i].PNPDeviceID" $s.PNPDeviceID
        $i++
    }

    $tpm = Get-Tpm
    if ($tpm) {
        Add-Item 'TPM.Present' $tpm.TpmPresent
        Add-Item 'TPM.ManufacturerIdTxt' $tpm.ManufacturerIdTxt
    }
    Add-Item 'SecureBoot.Enabled' (Confirm-SecureBootUEFI)

    $i = 0
    foreach ($b in (Get-CimInstance Win32_Battery)) {
        Add-Item "Battery[$i].DeviceID" $b.DeviceID
        $i++
    }

    return $items
}

function Write-Report($items, $path) {
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("# HWID Report")
    $lines.Add("# Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    $lines.Add("# PC: $env:COMPUTERNAME  User: $env:USERNAME")
    $lines.Add("")
    foreach ($it in $items) { $lines.Add("$($it.Key) : $($it.Value)") }
    Set-Content -Path $path -Value $lines -Encoding UTF8
}

function Read-Report($path) {
    $map = @{}
    foreach ($line in (Get-Content -Path $path)) {
        if ($line -match '^\s*#' -or $line.Trim() -eq '') { continue }
        $idx = $line.IndexOf(' : ')
        if ($idx -lt 0) { continue }
        $map[$line.Substring(0, $idx)] = $line.Substring($idx + 3)
    }
    return $map
}

function Get-SelectedCategories {
    $sel = @()
    for ($i = 0; $i -lt $catList.Items.Count; $i++) {
        if ($catList.GetItemChecked($i)) { $sel += $catList.Items[$i] }
    }
    return $sel
}

function Filter-ByCategories($items, $selectedCats) {
    if ($selectedCats.Count -eq 0) { return $items }
    return $items | Where-Object { $selectedCats -contains (Get-CategoryForKey $_.Key) }
}

function Refresh-FileList {
    $listBox.Items.Clear()
    Get-ChildItem -Path $script:SaveLocation -Filter $FilePattern -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        ForEach-Object { [void]$listBox.Items.Add($_.Name) }
}

# ---------- colored output helpers ----------
function Clear-Output { $outputBox.Clear() }
function Append-Colored($text, $color, $bold = $false) {
    $outputBox.SelectionStart = $outputBox.TextLength
    $outputBox.SelectionLength = 0
    $outputBox.SelectionColor = $color
    $outputBox.SelectionFont = New-Object System.Drawing.Font('Consolas', 9.5, $(if ($bold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }))
    $outputBox.AppendText($text)
}

function Show-ItemsColored($items) {
    Clear-Output
    $grouped = $items | Group-Object { Get-CategoryForKey $_.Key }
    foreach ($grp in $grouped) {
        $color = $CategoryColors[$grp.Name]; if (-not $color) { $color = $CategoryColors['Other'] }
        Append-Colored "`r`n== $($grp.Name) ==`r`n" $color $true
        foreach ($it in $grp.Group) {
            Append-Colored "$($it.Key) : $($it.Value)`r`n" $color $false
        }
    }
}

function Show-DiffColored($diffEntries, $headerText) {
    Clear-Output
    Append-Colored "$headerText`r`n`r`n" ([System.Drawing.Color]::White) $true
    if ($diffEntries.Count -eq 0) {
        Append-Colored "No differences found.`r`n" ([System.Drawing.Color]::FromArgb(140, 220, 140)) $false
        return
    }
    foreach ($e in $diffEntries) {
        $color = switch ($e.Type) {
            'NEW'      { [System.Drawing.Color]::FromArgb(140, 220, 140) }
            'MISSING'  { [System.Drawing.Color]::FromArgb(255, 120, 120) }
            'CHANGED'  { [System.Drawing.Color]::FromArgb(255, 210, 100) }
        }
        Append-Colored "[$($e.Type)]  " $color $true
        Append-Colored "$($e.Text)`r`n" $color $false
    }
}

# ---------- accounts / sessions check (safe, non-secret data only) ----------
function Get-AccountsInfo {
    $lines = New-Object System.Collections.Generic.List[object]  # {Text, Color, Bold}
    function L($text, $color, $bold = $false) { $lines.Add([PSCustomObject]@{Text=$text; Color=$color; Bold=$bold}) }

    $cWin  = [System.Drawing.Color]::FromArgb(120, 200, 255)
    $cOk   = [System.Drawing.Color]::FromArgb(140, 220, 140)
    $cWarn = [System.Drawing.Color]::FromArgb(255, 210, 100)
    $cInfo = [System.Drawing.Color]::FromArgb(200, 200, 200)

    L "== Windows session ==" $cWin $true
    L "Current user : $env:USERDOMAIN\$env:USERNAME" $cWin
    L "" $cInfo

    # Steam: loginusers.vdf only stores account/persona names, written by Steam itself for the login picker - not a secret.
    L "== Steam accounts (local login list) ==" $cOk $true
    $steamPath = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
    if ($steamPath) {
        $vdf = Join-Path $steamPath 'config\loginusers.vdf'
        if (Test-Path $vdf) {
            $content = Get-Content $vdf -Raw
            $blocks = [regex]::Matches($content, '"(\d+)"\s*\{([^}]*)\}')
            if ($blocks.Count -eq 0) { L "(no saved accounts found)" $cInfo }
            foreach ($b in $blocks) {
                $body = $b.Groups[2].Value
                $accountName = [regex]::Match($body, '"AccountName"\s*"([^"]*)"').Groups[1].Value
                $personaName = [regex]::Match($body, '"PersonaName"\s*"([^"]*)"').Groups[1].Value
                $mostRecent  = [regex]::Match($body, '"MostRecent"\s*"([^"]*)"').Groups[1].Value
                $tag = if ($mostRecent -eq '1') { '  <-- most recent' } else { '' }
                L "AccountName: $accountName   PersonaName: $personaName$tag" $cOk
            }
        } else { L "(Steam installed, but no login history file found)" $cInfo }
    } else { L "(Steam not found on this PC)" $cInfo }
    L "" $cInfo

    # Other clients: we only report whether the process is running, never read their session/token storage.
    L "== Other clients (running status only - no token/session data is read) ==" $cWarn $true
    $apps = @{
        'Discord'      = 'Discord'
        'DiscordPTB'   = 'Discord PTB'
        'DiscordCanary'= 'Discord Canary'
        'Battle.net'   = 'Battle.net'
        'EpicGamesLauncher' = 'Epic Games'
        'Origin'       = 'EA Origin'
        'EADesktop'    = 'EA App'
        'RiotClientServices' = 'Riot Client'
        'Spotify'      = 'Spotify'
    }
    foreach ($procName in $apps.Keys) {
        $running = Get-Process -Name $procName -ErrorAction SilentlyContinue
        $status = if ($running) { 'running (likely signed in to something - open the app to see which account)' } else { 'not running' }
        L "$($apps[$procName]): $status" $cInfo
    }
    L "" $cInfo

    # Credential Manager: names of stored credentials only, never secrets
    L "== Windows Credential Manager (stored entry names only) ==" $cWarn $true
    $cmdkeyOut = cmdkey /list 2>$null
    $targets = $cmdkeyOut | Select-String 'Target:' | ForEach-Object { $_.ToString().Trim() }
    if ($targets) { foreach ($t in $targets) { L $t $cInfo } }
    else { L "(no stored credentials found, or none readable)" $cInfo }

    return $lines
}

# ---------------- MAC address changer (uses Windows' own supported "Network Address" adapter property) ----------------
function Show-MacChangeDialog($parentColors) {
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = 'Change MAC Address'
    $dlg.Size = New-Object System.Drawing.Size(520, 300)
    $dlg.StartPosition = 'CenterParent'
    $dlg.BackColor = $parentColors.Bg
    $dlg.ForeColor = $parentColors.Text
    $dlg.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
    $dlg.FormBorderStyle = 'FixedDialog'
    $dlg.MaximizeBox = $false

    $lblAdapter = New-Object System.Windows.Forms.Label
    $lblAdapter.Text = 'Adapter:'
    $lblAdapter.Location = New-Object System.Drawing.Point(15, 20)
    $lblAdapter.Size = New-Object System.Drawing.Size(100, 20)
    $dlg.Controls.Add($lblAdapter)

    $cmbAdapter = New-Object System.Windows.Forms.ComboBox
    $cmbAdapter.Location = New-Object System.Drawing.Point(120, 17)
    $cmbAdapter.Size = New-Object System.Drawing.Size(370, 24)
    $cmbAdapter.DropDownStyle = 'DropDownList'
    $cmbAdapter.BackColor = $parentColors.Panel
    $cmbAdapter.ForeColor = $parentColors.Text
    $adapters = @(Get-NetAdapter -Physical | Where-Object { $_.Status -ne 'NotPresent' })
    foreach ($a in $adapters) { [void]$cmbAdapter.Items.Add("$($a.Name)  [current: $($a.MacAddress)]") }
    if ($cmbAdapter.Items.Count -gt 0) { $cmbAdapter.SelectedIndex = 0 }
    $dlg.Controls.Add($cmbAdapter)

    $lblNew = New-Object System.Windows.Forms.Label
    $lblNew.Text = 'New MAC (12 hex chars):'
    $lblNew.Location = New-Object System.Drawing.Point(15, 60)
    $lblNew.Size = New-Object System.Drawing.Size(180, 20)
    $dlg.Controls.Add($lblNew)

    $txtMac = New-Object System.Windows.Forms.TextBox
    $txtMac.Location = New-Object System.Drawing.Point(200, 57)
    $txtMac.Size = New-Object System.Drawing.Size(290, 24)
    $txtMac.BackColor = $parentColors.Panel
    $txtMac.ForeColor = $parentColors.Text
    $txtMac.Text = '02XXXXXXXXXX'
    $dlg.Controls.Add($txtMac)

    $lblHint = New-Object System.Windows.Forms.Label
    $lblHint.Text = "Example: 001A2B3C4D5E  (no colons needed). First byte's low nibble`r`nshould be even for a valid 'locally administered' address, e.g. 02, 06, 0A, 0E."
    $lblHint.Location = New-Object System.Drawing.Point(15, 90)
    $lblHint.Size = New-Object System.Drawing.Size(475, 40)
    $lblHint.ForeColor = [System.Drawing.Color]::Gray
    $dlg.Controls.Add($lblHint)

    $status = New-Object System.Windows.Forms.Label
    $status.Location = New-Object System.Drawing.Point(15, 140)
    $status.Size = New-Object System.Drawing.Size(475, 60)
    $status.ForeColor = $parentColors.Accent
    $dlg.Controls.Add($status)

    $btnApply = New-Object System.Windows.Forms.Button
    $btnApply.Text = 'Apply New MAC'
    $btnApply.Location = New-Object System.Drawing.Point(15, 210)
    $btnApply.Size = New-Object System.Drawing.Size(225, 32)
    Style-Button $btnApply $true
    $dlg.Controls.Add($btnApply)

    $btnReset = New-Object System.Windows.Forms.Button
    $btnReset.Text = 'Reset to Factory MAC'
    $btnReset.Location = New-Object System.Drawing.Point(250, 210)
    $btnReset.Size = New-Object System.Drawing.Size(240, 32)
    Style-Button $btnReset
    $dlg.Controls.Add($btnReset)

    $btnApply.Add_Click({
        if ($cmbAdapter.SelectedIndex -lt 0) { $status.Text = 'Pick an adapter first.'; return }
        $adapter = $adapters[$cmbAdapter.SelectedIndex]
        $mac = ($txtMac.Text -replace '[^0-9A-Fa-f]', '').ToUpper()
        if ($mac.Length -ne 12) {
            $status.Text = "Invalid MAC: need exactly 12 hex characters, got $($mac.Length)."
            return
        }
        $supports = Get-NetAdapterAdvancedProperty -Name $adapter.Name -RegistryKeyword 'NetworkAddress' -ErrorAction SilentlyContinue
        if (-not $supports) {
            $status.Text = "This adapter/driver does not expose a settable Network Address property (common on some Wi-Fi/virtual adapters)."
            return
        }
        try {
            Set-NetAdapterAdvancedProperty -Name $adapter.Name -RegistryKeyword 'NetworkAddress' -RegistryValue $mac -ErrorAction Stop
            Restart-NetAdapter -Name $adapter.Name -Confirm:$false -ErrorAction Stop
            $status.Text = "Applied $mac to '$($adapter.Name)' and restarted it. Your network briefly dropped during this - that's expected."
        } catch {
            $status.Text = "Failed: $($_.Exception.Message)"
        }
    })

    $btnReset.Add_Click({
        if ($cmbAdapter.SelectedIndex -lt 0) { $status.Text = 'Pick an adapter first.'; return }
        $adapter = $adapters[$cmbAdapter.SelectedIndex]
        try {
            Remove-NetAdapterAdvancedProperty -Name $adapter.Name -RegistryKeyword 'NetworkAddress' -ErrorAction Stop
            Restart-NetAdapter -Name $adapter.Name -Confirm:$false -ErrorAction Stop
            $status.Text = "Reset '$($adapter.Name)' back to its factory/burned-in MAC and restarted it."
        } catch {
            $status.Text = "Failed (it may already be at its factory MAC): $($_.Exception.Message)"
        }
    })

    [void]$dlg.ShowDialog()
}

# ---------------- colors / theme ----------------
$colBg      = [System.Drawing.Color]::FromArgb(30, 30, 34)
$colPanel   = [System.Drawing.Color]::FromArgb(40, 40, 46)
$colText    = [System.Drawing.Color]::FromArgb(230, 230, 235)
$colAccent  = [System.Drawing.Color]::FromArgb(0, 153, 255)
$colBtnText = [System.Drawing.Color]::White
$colBorder  = [System.Drawing.Color]::FromArgb(60, 60, 68)

function Style-Button($btn, $accent = $false) {
    $btn.FlatStyle = 'Flat'
    $btn.FlatAppearance.BorderColor = $colBorder
    $btn.FlatAppearance.BorderSize = 1
    $btn.BackColor = if ($accent) { $colAccent } else { $colPanel }
    $btn.ForeColor = $colBtnText
    $btn.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
    $btn.Cursor = 'Hand'
}

# ---------------- GUI ----------------
$form = New-Object System.Windows.Forms.Form
$form.Text = 'HWID Checker  -  by Mxg1cal'
$form.Size = New-Object System.Drawing.Size(1000, 810)
$form.StartPosition = 'CenterScreen'
$form.BackColor = $colBg
$form.ForeColor = $colText
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

$listLabel = New-Object System.Windows.Forms.Label
$listLabel.Text = 'Previous checks (Desktop)'
$listLabel.Location = New-Object System.Drawing.Point(10, 10)
$listLabel.Size = New-Object System.Drawing.Size(260, 20)
$listLabel.ForeColor = $colText
$form.Controls.Add($listLabel)

$listBox = New-Object System.Windows.Forms.ListBox
$listBox.Location = New-Object System.Drawing.Point(10, 32)
$listBox.Size = New-Object System.Drawing.Size(260, 190)
$listBox.BackColor = $colPanel
$listBox.ForeColor = $colText
$listBox.BorderStyle = 'FixedSingle'
$form.Controls.Add($listBox)

$btnOpenFile = New-Object System.Windows.Forms.Button
$btnOpenFile.Text = 'Open Selected'
$btnOpenFile.Location = New-Object System.Drawing.Point(10, 228)
$btnOpenFile.Size = New-Object System.Drawing.Size(125, 30)
Style-Button $btnOpenFile
$form.Controls.Add($btnOpenFile)

$btnDelete = New-Object System.Windows.Forms.Button
$btnDelete.Text = 'Delete Selected'
$btnDelete.Location = New-Object System.Drawing.Point(145, 228)
$btnDelete.Size = New-Object System.Drawing.Size(125, 30)
Style-Button $btnDelete
$form.Controls.Add($btnDelete)

$catLabel = New-Object System.Windows.Forms.Label
$catLabel.Text = 'Categories to include (none checked = all):'
$catLabel.Location = New-Object System.Drawing.Point(10, 268)
$catLabel.Size = New-Object System.Drawing.Size(260, 20)
$catLabel.ForeColor = $colText
$form.Controls.Add($catLabel)

$catList = New-Object System.Windows.Forms.CheckedListBox
$catList.Location = New-Object System.Drawing.Point(10, 290)
$catList.Size = New-Object System.Drawing.Size(260, 190)
$catList.BackColor = $colPanel
$catList.ForeColor = $colText
$catList.BorderStyle = 'FixedSingle'
$catList.CheckOnClick = $true
foreach ($cat in $Categories.Keys) { [void]$catList.Items.Add($cat) }
$form.Controls.Add($catList)

$btnSelAll = New-Object System.Windows.Forms.Button
$btnSelAll.Text = 'Select All'
$btnSelAll.Location = New-Object System.Drawing.Point(10, 486)
$btnSelAll.Size = New-Object System.Drawing.Size(125, 28)
Style-Button $btnSelAll
$form.Controls.Add($btnSelAll)

$btnSelNone = New-Object System.Windows.Forms.Button
$btnSelNone.Text = 'Select None'
$btnSelNone.Location = New-Object System.Drawing.Point(145, 486)
$btnSelNone.Size = New-Object System.Drawing.Size(125, 28)
Style-Button $btnSelNone
$form.Controls.Add($btnSelNone)

$chkPublicIP = New-Object System.Windows.Forms.CheckBox
$chkPublicIP.Text = 'Include public IP (contacts ipify.org)'
$chkPublicIP.Location = New-Object System.Drawing.Point(10, 520)
$chkPublicIP.Size = New-Object System.Drawing.Size(260, 20)
$chkPublicIP.ForeColor = $colText
$form.Controls.Add($chkPublicIP)

$chkSaveFile = New-Object System.Windows.Forms.CheckBox
$chkSaveFile.Text = 'Save report to a file after scan'
$chkSaveFile.Location = New-Object System.Drawing.Point(10, 544)
$chkSaveFile.Size = New-Object System.Drawing.Size(260, 20)
$chkSaveFile.ForeColor = $colText
$chkSaveFile.Checked = $true
$form.Controls.Add($chkSaveFile)

$lblSaveLoc = New-Object System.Windows.Forms.Label
$lblSaveLoc.Text = 'Save folder:'
$lblSaveLoc.Location = New-Object System.Drawing.Point(10, 568)
$lblSaveLoc.Size = New-Object System.Drawing.Size(70, 18)
$lblSaveLoc.ForeColor = $colText
$form.Controls.Add($lblSaveLoc)

$txtSaveLoc = New-Object System.Windows.Forms.TextBox
$txtSaveLoc.Location = New-Object System.Drawing.Point(10, 588)
$txtSaveLoc.Size = New-Object System.Drawing.Size(195, 22)
$txtSaveLoc.ReadOnly = $true
$txtSaveLoc.BackColor = $colPanel
$txtSaveLoc.ForeColor = $colText
$txtSaveLoc.Text = $script:SaveLocation
$form.Controls.Add($txtSaveLoc)

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = '...'
$btnBrowse.Location = New-Object System.Drawing.Point(210, 587)
$btnBrowse.Size = New-Object System.Drawing.Size(60, 24)
Style-Button $btnBrowse
$form.Controls.Add($btnBrowse)

$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text = 'Run New Check'
$btnRun.Location = New-Object System.Drawing.Point(10, 618)
$btnRun.Size = New-Object System.Drawing.Size(260, 32)
Style-Button $btnRun $true
$form.Controls.Add($btnRun)

$btnCompare = New-Object System.Windows.Forms.Button
$btnCompare.Text = 'Compare Selected vs Current'
$btnCompare.Location = New-Object System.Drawing.Point(10, 654)
$btnCompare.Size = New-Object System.Drawing.Size(260, 32)
Style-Button $btnCompare
$form.Controls.Add($btnCompare)

$btnAccounts = New-Object System.Windows.Forms.Button
$btnAccounts.Text = 'Check Logged-in Accounts'
$btnAccounts.Location = New-Object System.Drawing.Point(10, 690)
$btnAccounts.Size = New-Object System.Drawing.Size(260, 32)
Style-Button $btnAccounts
$form.Controls.Add($btnAccounts)

$btnChangeMac = New-Object System.Windows.Forms.Button
$btnChangeMac.Text = 'Change MAC Address...'
$btnChangeMac.Location = New-Object System.Drawing.Point(10, 726)
$btnChangeMac.Size = New-Object System.Drawing.Size(260, 32)
Style-Button $btnChangeMac
$form.Controls.Add($btnChangeMac)

$outputBox = New-Object System.Windows.Forms.RichTextBox
$outputBox.Location = New-Object System.Drawing.Point(285, 32)
$outputBox.Size = New-Object System.Drawing.Size(695, 650)
$outputBox.Font = New-Object System.Drawing.Font('Consolas', 9.5)
$outputBox.ReadOnly = $true
$outputBox.WordWrap = $false
$outputBox.ScrollBars = 'Both'
$outputBox.BackColor = $colPanel
$outputBox.ForeColor = $colText
$outputBox.BorderStyle = 'FixedSingle'
$form.Controls.Add($outputBox)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = 'Ready.'
$statusLabel.Location = New-Object System.Drawing.Point(285, 688)
$statusLabel.Size = New-Object System.Drawing.Size(695, 50)
$statusLabel.ForeColor = $colAccent
$form.Controls.Add($statusLabel)

# ---------------- events ----------------
$listBox.Add_DoubleClick({
    if ($listBox.SelectedItem) { Start-Process notepad.exe (Join-Path $script:SaveLocation $listBox.SelectedItem) }
})

$btnOpenFile.Add_Click({
    if ($listBox.SelectedItem) { Start-Process notepad.exe (Join-Path $script:SaveLocation $listBox.SelectedItem) }
    else { [System.Windows.Forms.MessageBox]::Show('Select a file first.', 'No file selected') | Out-Null }
})

$btnDelete.Add_Click({
    if (-not $listBox.SelectedItem) {
        [System.Windows.Forms.MessageBox]::Show('Select a file first.', 'No file selected') | Out-Null
        return
    }
    $name = $listBox.SelectedItem
    $confirm = [System.Windows.Forms.MessageBox]::Show("Delete '$name' permanently?", 'Confirm delete', 'YesNo', 'Warning')
    if ($confirm -eq 'Yes') {
        Remove-Item -Path (Join-Path $script:SaveLocation $name) -Force
        Refresh-FileList
        $statusLabel.Text = "Deleted: $name"
    }
})

$btnBrowse.Add_Click({
    $fbd = New-Object System.Windows.Forms.FolderBrowserDialog
    $fbd.Description = 'Choose where HWID reports should be saved'
    $fbd.SelectedPath = $script:SaveLocation
    if ($fbd.ShowDialog() -eq 'OK') {
        $script:SaveLocation = $fbd.SelectedPath
        $txtSaveLoc.Text = $script:SaveLocation
        Refresh-FileList
        $statusLabel.Text = "Save folder set to: $($script:SaveLocation)"
    }
})

$btnSelAll.Add_Click({ for ($i = 0; $i -lt $catList.Items.Count; $i++) { $catList.SetItemChecked($i, $true) } })
$btnSelNone.Add_Click({ for ($i = 0; $i -lt $catList.Items.Count; $i++) { $catList.SetItemChecked($i, $false) } })

$btnRun.Add_Click({
    $statusLabel.Text = 'Running check...'
    $form.Refresh()
    $allItems = Get-HWIDData $chkPublicIP.Checked
    $selCats = Get-SelectedCategories
    $shown = Filter-ByCategories $allItems $selCats
    Show-ItemsColored $shown
    $catNote = if ($selCats.Count -eq 0) { "all categories" } else { "$($selCats.Count) selected categor$(if($selCats.Count -eq 1){'y'}else{'ies'})" }

    if ($chkSaveFile.Checked) {
        if (-not (Test-Path $script:SaveLocation)) {
            $statusLabel.Text = "Save folder '$($script:SaveLocation)' doesn't exist - nothing was saved. Pick a valid folder and try again."
            return
        }
        $stamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
        $path = Join-Path $script:SaveLocation "HWID_Report_$stamp.txt"
        Write-Report $shown $path
        Refresh-FileList
        $statusLabel.Text = "Saved: $path  ($catNote, $($shown.Count) values)"
    } else {
        $statusLabel.Text = "Scan complete - not saved to a file ($catNote, $($shown.Count) values). Check 'Save report to a file' to write one next time."
    }
})

$btnCompare.Add_Click({
    if (-not $listBox.SelectedItem) {
        [System.Windows.Forms.MessageBox]::Show('Select a previous report from the list first.', 'No file selected') | Out-Null
        return
    }
    $statusLabel.Text = 'Comparing...'
    $form.Refresh()
    $oldPath = Join-Path $script:SaveLocation $listBox.SelectedItem
    $oldMap = Read-Report $oldPath

    $allItems = Get-HWIDData $chkPublicIP.Checked
    $selCats = Get-SelectedCategories
    $currentItems = Filter-ByCategories $allItems $selCats
    $currentMap = @{}
    foreach ($it in $currentItems) { $currentMap[$it.Key] = $it.Value }

    $oldMapFiltered = @{}
    foreach ($k in $oldMap.Keys) {
        if ($selCats.Count -eq 0 -or ($selCats -contains (Get-CategoryForKey $k))) { $oldMapFiltered[$k] = $oldMap[$k] }
    }

    $allKeys = ($oldMapFiltered.Keys + $currentMap.Keys) | Sort-Object -Unique
    $diffEntries = New-Object System.Collections.Generic.List[object]
    foreach ($k in $allKeys) {
        $o = $oldMapFiltered[$k]; $n = $currentMap[$k]
        if ($o -ne $n) {
            if ($null -eq $o) { $diffEntries.Add([PSCustomObject]@{Type='NEW'; Text="$k : $n"}) }
            elseif ($null -eq $n) { $diffEntries.Add([PSCustomObject]@{Type='MISSING'; Text="$k : (was $o)"}) }
            else { $diffEntries.Add([PSCustomObject]@{Type='CHANGED'; Text="$k : $o  -->  $n"}) }
        }
    }

    Show-DiffColored $diffEntries "Comparing '$($listBox.SelectedItem)' (OLD) vs current system (NEW):"
    $statusLabel.Text = "Compared against $($listBox.SelectedItem). $($diffEntries.Count) difference(s) found."
})

$btnAccounts.Add_Click({
    $statusLabel.Text = 'Checking local account info (no passwords or tokens are read)...'
    $form.Refresh()
    $lines = Get-AccountsInfo
    Clear-Output
    foreach ($l in $lines) { Append-Colored "$($l.Text)`r`n" $l.Color $l.Bold }
    $statusLabel.Text = "Done. Steam account names come from Steam's own local login list; Discord/Epic/etc. only show running status, never session tokens."
})

$btnChangeMac.Add_Click({
    $parentColors = [PSCustomObject]@{ Bg = $colBg; Panel = $colPanel; Text = $colText; Accent = $colAccent }
    Show-MacChangeDialog $parentColors
    Show-ItemsColored (Filter-ByCategories (Get-HWIDData $false) (Get-SelectedCategories))
    $statusLabel.Text = 'Refreshed view after MAC dialog closed.'
})

$lblWatermark = New-Object System.Windows.Forms.Label
$lblWatermark.Text = 'Made by Mxg1cal'
$lblWatermark.AutoSize = $true
$lblWatermark.ForeColor = [System.Drawing.Color]::FromArgb(90, 90, 98)
$lblWatermark.Font = New-Object System.Drawing.Font('Segoe UI', 8, [System.Drawing.FontStyle]::Italic)
$lblWatermark.Location = New-Object System.Drawing.Point(880, 745)
$form.Controls.Add($lblWatermark)
$lblWatermark.BringToFront()

Refresh-FileList
[void]$form.ShowDialog()
