<#
.SYNOPSIS
    Install the Bangla Fonts collection on Windows.

.DESCRIPTION
    Copies every .ttf/.otf file in this repository into the Windows font folder
    and registers it, so the fonts appear in applications without a reboot.

    By default the fonts are installed for the current user only:
        %LOCALAPPDATA%\Microsoft\Windows\Fonts
        HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts

    With -System they are installed for all users (requires an elevated shell):
        %WINDIR%\Fonts
        HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Fonts

    Registry value names use the font's own full name (read from its OpenType
    name table), falling back to the file name for malformed fonts or when
    several files claim the same name.

.PARAMETER System
    Install for all users. Requires an Administrator PowerShell session.

.EXAMPLE
    .\install.ps1
    Install the fonts for the current user.

.EXAMPLE
    .\install.ps1 -System
    Install the fonts for every user (run from an elevated PowerShell).

.EXAMPLE
    .\install.ps1 -WhatIf
    Show what would happen without changing anything.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$System
)

$ErrorActionPreference = 'Stop'

function Test-Administrator {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object -TypeName System.Security.Principal.WindowsPrincipal -ArgumentList $identity
    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Read-BE16 {
    param([byte[]]$Bytes, [int]$Offset)
    return ([int]$Bytes[$Offset] -shl 8) -bor [int]$Bytes[$Offset + 1]
}

function Read-BE32 {
    param([byte[]]$Bytes, [int]$Offset)
    return (([uint32]$Bytes[$Offset] -shl 24) -bor ([uint32]$Bytes[$Offset + 1] -shl 16) -bor ([uint32]$Bytes[$Offset + 2] -shl 8) -bor [uint32]$Bytes[$Offset + 3])
}

function Get-FontFullName {
    param([string]$Path)

    try {
        $bytes = [System.IO.File]::ReadAllBytes($Path)
        if ($bytes.Length -lt 12) { return $null }

        $sfntVersion = [System.Text.Encoding]::ASCII.GetString($bytes, 0, 4)
        if ($sfntVersion -eq 'ttcf') { return $null }  # font collections hold multiple faces

        $numTables = Read-BE16 -Bytes $bytes -Offset 4
        $nameOffset = -1
        for ($i = 0; $i -lt $numTables; $i++) {
            $record = 12 + ($i * 16)
            if (($record + 16) -gt $bytes.Length) { break }
            $tag = [System.Text.Encoding]::ASCII.GetString($bytes, $record, 4)
            if ($tag -eq 'name') {
                $nameOffset = [int](Read-BE32 -Bytes $bytes -Offset ($record + 8))
                break
            }
        }

        if ($nameOffset -lt 0 -or ($nameOffset + 6) -gt $bytes.Length) { return $null }

        $count = Read-BE16 -Bytes $bytes -Offset ($nameOffset + 2)
        $stringOffset = Read-BE16 -Bytes $bytes -Offset ($nameOffset + 4)
        $best = $null
        $bestScore = -1

        for ($i = 0; $i -lt $count; $i++) {
            $record = $nameOffset + 6 + ($i * 12)
            if (($record + 12) -gt $bytes.Length) { break }

            $platformId = Read-BE16 -Bytes $bytes -Offset $record
            $languageId = Read-BE16 -Bytes $bytes -Offset ($record + 4)
            $nameId = Read-BE16 -Bytes $bytes -Offset ($record + 6)
            if ($nameId -ne 4) { continue }

            $length = Read-BE16 -Bytes $bytes -Offset ($record + 8)
            $offset = Read-BE16 -Bytes $bytes -Offset ($record + 10)
            $start = $nameOffset + $stringOffset + $offset
            if ($start -lt 0 -or ($start + $length) -gt $bytes.Length) { continue }

            if ($platformId -eq 3 -or $platformId -eq 0) {
                $value = [System.Text.Encoding]::BigEndianUnicode.GetString($bytes, $start, $length)
            } elseif ($platformId -eq 1) {
                $value = [System.Text.Encoding]::ASCII.GetString($bytes, $start, $length)
            } else {
                continue
            }

            $value = $value.Replace(([char]0).ToString(), '').Trim()
            if ([string]::IsNullOrWhiteSpace($value)) { continue }

            $score = 0
            if ($platformId -eq 3) { $score += 10 }
            if ($platformId -eq 3 -and $languageId -eq 0x409) { $score += 5 }
            if ($platformId -eq 0) { $score += 3 }

            if ($score -gt $bestScore) {
                $bestScore = $score
                $best = $value
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($best)) { return $best }
    } catch {
        Write-Verbose "Could not read the font name from ${Path}: $($_.Exception.Message)"
    }

    return $null
}

$repoRoot = $PSScriptRoot
if (-not $repoRoot) {
    throw 'Run this script from the repository (.\install.ps1).'
}

if (-not (Test-Path -LiteralPath (Join-Path $repoRoot 'README.md'))) {
    throw "README.md not found in $repoRoot. Run this script from the repository root."
}

$fontFiles = @(
    Get-ChildItem -LiteralPath $repoRoot -Recurse -File |
        Where-Object {
            ($_.Extension -in '.ttf', '.otf') -and
            ($_.FullName -notmatch '[\\/]\.git[\\/]')
        } |
        Sort-Object FullName
)

if ($fontFiles.Count -eq 0) {
    throw "No .ttf or .otf files found in $repoRoot."
}

if ($System) {
    if (-not $WhatIfPreference -and -not (Test-Administrator)) {
        throw 'System-wide installation requires an elevated PowerShell. Right-click PowerShell, choose "Run as administrator", then run: .\install.ps1 -System'
    }
    $fontDir = Join-Path $env:WINDIR 'Fonts'
    $registryKey = 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    $registryValueIsFullPath = $false
} else {
    $fontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
    $registryKey = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    $registryValueIsFullPath = $true
}

# Windows flattens fonts into the font folder, so file names must be unique.
$seenNames = @{}
foreach ($font in $fontFiles) {
    if ($seenNames.ContainsKey($font.Name)) {
        throw "Two font files share the name '$($font.Name)', which Windows cannot install side by side:`n  $($seenNames[$font.Name])`n  $($font.FullName)"
    }
    $seenNames[$font.Name] = $font.FullName
}

# Read the real font name from each file so the registry entries are named the
# way Windows expects. Falls back to the file base name.
$fontDisplayNames = @{}
$nameCounts = @{}
foreach ($font in $fontFiles) {
    $fullName = Get-FontFullName -Path $font.FullName
    if ([string]::IsNullOrWhiteSpace($fullName)) {
        $fullName = $font.BaseName
    }

    $fontDisplayNames[$font.FullName] = $fullName
    $nameKey = $fullName.ToLowerInvariant()
    if ($nameCounts.ContainsKey($nameKey)) {
        $nameCounts[$nameKey] = $nameCounts[$nameKey] + 1
    } else {
        $nameCounts[$nameKey] = 1
    }
}

# A dozen files in this archive share an internal font name with another file.
# Use the (unique) file base name for every member of such a group so no
# registry entry silently overwrites another one.
$registryValueNames = @{}
$usedValueNames = @{}
foreach ($font in $fontFiles) {
    $fullName = $fontDisplayNames[$font.FullName]
    if ($nameCounts[$fullName.ToLowerInvariant()] -gt 1) {
        $displayName = $font.BaseName
    } else {
        $displayName = $fullName
    }

    if ($font.Extension.ToLowerInvariant() -eq '.otf') {
        $suffix = '(OpenType)'
    } else {
        $suffix = '(TrueType)'
    }

    $candidate = "$displayName $suffix"
    $counter = 2
    while ($usedValueNames.ContainsKey($candidate.ToLowerInvariant())) {
        $candidate = "$displayName ($counter) $suffix"
        $counter++
    }
    $usedValueNames[$candidate.ToLowerInvariant()] = $true
    $registryValueNames[$font.FullName] = $candidate
}

if (-not (Test-Path -LiteralPath $fontDir)) {
    if ($PSCmdlet.ShouldProcess($fontDir, 'Create font directory')) {
        New-Item -ItemType Directory -Path $fontDir -Force | Out-Null
    }
}

if (-not (Test-Path -LiteralPath $registryKey)) {
    if ($PSCmdlet.ShouldProcess($registryKey, 'Create font registry key')) {
        New-Item -Path $registryKey -Force | Out-Null
    }
}

$installed = 0
$unchanged = 0
$failed = New-Object System.Collections.Generic.List[string]
$newlyInstalled = New-Object System.Collections.Generic.List[string]

foreach ($font in $fontFiles) {
    $destination = Join-Path $fontDir $font.Name
    $upToDate = $false

    if (Test-Path -LiteralPath $destination -PathType Leaf) {
        try {
            $sourceHash = (Get-FileHash -LiteralPath $font.FullName -Algorithm SHA256).Hash
            $destinationHash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
            $upToDate = $sourceHash -eq $destinationHash
        } catch {
            $upToDate = $false
        }
    }

    if ($upToDate) {
        $unchanged++
        continue
    }

    if ($PSCmdlet.ShouldProcess($destination, 'Install font')) {
        try {
            Copy-Item -LiteralPath $font.FullName -Destination $destination -Force
            $newlyInstalled.Add($destination)
            $installed++
        } catch {
            $failed.Add($font.Name)
            Write-Warning "Could not install $($font.Name): $($_.Exception.Message)"
        }
    }
}

# Register every font that exists in the font folder. Re-registering an existing
# font is harmless and repairs entries that were removed by hand.
foreach ($font in $fontFiles) {
    $destination = Join-Path $fontDir $font.Name
    if (-not (Test-Path -LiteralPath $destination -PathType Leaf)) {
        continue
    }

    $valueName = $registryValueNames[$font.FullName]
    if ($registryValueIsFullPath) {
        $valueData = $destination
    } else {
        $valueData = $font.Name
    }

    if ($PSCmdlet.ShouldProcess($valueName, 'Register font')) {
        New-ItemProperty -Path $registryKey -Name $valueName -Value $valueData -PropertyType String -Force | Out-Null
    }
}

if ($WhatIfPreference) {
    Write-Host ''
    Write-Host "What if: $($fontFiles.Count) font file(s) would be installed to $fontDir."
    return
}

# Tell Windows about newly copied fonts so running applications can use them.
# Fonts that were already present are loaded automatically at logon.
if ($newlyInstalled.Count -gt 0) {
    try {
        if (-not ('BanglaFonts.NativeMethods' -as [type])) {
            Add-Type -Namespace BanglaFonts -Name NativeMethods -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("gdi32.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode, SetLastError = true)]
public static extern int AddFontResourceW(string lpFileName);

[System.Runtime.InteropServices.DllImport("user32.dll", SetLastError = true)]
public static extern System.IntPtr SendMessageTimeout(
    System.IntPtr hWnd,
    uint Msg,
    System.IntPtr wParam,
    System.IntPtr lParam,
    uint fuFlags,
    uint uTimeout,
    out System.IntPtr lpdwResult);
'@
        }

        foreach ($fontPath in $newlyInstalled) {
            try {
                [void][BanglaFonts.NativeMethods]::AddFontResourceW($fontPath)
            } catch {
                Write-Verbose "Could not register ${fontPath}: $($_.Exception.Message)"
            }
        }

        $broadcastResult = [IntPtr]::Zero
        [void][BanglaFonts.NativeMethods]::SendMessageTimeout(
            [IntPtr]0xffff,  # HWND_BROADCAST
            0x001D,          # WM_FONTCHANGE
            [IntPtr]::Zero,
            [IntPtr]::Zero,
            2,               # SMTO_ABORTIFHUNG
            1000,
            [ref]$broadcastResult)
    } catch {
        Write-Warning "Fonts were copied and registered, but notifying Windows failed: $($_.Exception.Message)"
    }
}

Write-Host ''
Write-Host "Installed: $installed   Unchanged: $unchanged   Failed: $($failed.Count)   Total: $($fontFiles.Count)"
Write-Host "Font directory: $fontDir"

if ($failed.Count -gt 0) {
    Write-Warning 'Some fonts could not be installed. Close applications that are using them and run the script again.'
    exit 1
}

Write-Host 'Done. Open a new application (or restart running ones) to use the fonts.'
