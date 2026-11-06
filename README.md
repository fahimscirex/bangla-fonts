# Bangla Fonts

A curated collection of Bangla (Bengali) fonts, organized into one directory per
typeface family for easy browsing and installation. It currently holds **204 font
families** across **438 font files** — spanning modern Unicode fonts, display and
decorative faces, and older legacy (Bijoy-style) fonts.

## Removal / takedown requests

If you own the rights to any font in this repository and would like it removed,
please email **fahimscirex@tutanota.com** and it will be taken down.

## Structure

Each family lives in its own folder, with weight/style variants inside:

```
Bangla Fonts/
├── Anek Bangla/
│   ├── AnekBangla-Regular.ttf
│   ├── AnekBangla-Bold.ttf
│   └── ...
├── Kohinoor Bangla/
├── Solaiman Lipi/
└── ...
```

## Installation

The repository includes installers that copy every font into the correct system
font directory and refresh the font cache. Fonts are installed for the current
user by default; an optional system-wide mode is available on both platforms.

### Linux

Requires `bash` and fontconfig (the `fc-cache` command, usually installed by
default).

```sh
# Install for the current user
./install.sh

# Preview what would be installed
./install.sh --dry-run

# Install for every user (uses sudo when available)
sudo ./install.sh --system
```

If you downloaded the repository as an archive rather than cloning it, run
`chmod +x install.sh` first.

Fonts are installed as a flat set under
`~/.local/share/fonts/bangla-fonts` (or
`/usr/local/share/fonts/bangla-fonts` with `--system`). Windows uses the same
flat layout because its font folder does not handle subdirectories reliably.
Re-running the script only copies new or changed files and removes fonts that
are no longer in the repository; the `bangla-fonts` folder is managed by the
installer, so do not keep your own files there.

### Windows

Requires Windows 10 version 1809 or newer for a per-user installation.

- **Double-click `install.bat`** to install for the current user.
- Or run PowerShell manually:

```powershell
# Current user
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1

# Preview only
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -WhatIf
```

For an all-users install, open PowerShell as Administrator and run:

```powershell
.\install.ps1 -System
```

Fonts are copied to `%LOCALAPPDATA%\Microsoft\Windows\Fonts` (or
`%WINDIR%\Fonts` with `-System`) and registered under their real font names
(falling back to the file name when fonts share a name) in the matching
`CurrentVersion\Fonts` registry key.

### Removing the fonts

- **Linux:** delete `~/.local/share/fonts/bangla-fonts` (or
  `/usr/local/share/fonts/bangla-fonts` for a system-wide install), then run
  `fc-cache -f`.
- **Windows:** delete the installed font files from the font folder and remove
  their `(TrueType)` / `(OpenType)` entries under the corresponding
  `CurrentVersion\Fonts` registry key, then restart any running applications.

After installing, open a new application or restart one that is already
running. Legacy (Bijoy-style) fonts are installed too, but only Unicode fonts
render Bengali text as proper Unicode.

## Notes

- Font source archives (`*.zip`) are not tracked in this repository.

## Disclaimer

This is an unofficial, community archive gathered from various sources and
provided as-is, for convenience only. **No license is granted by this
repository.** Copyright in every font remains with its respective designer,
author, or foundry. Some of the included fonts are proprietary. Nothing here
should be taken as permission to use, modify, or redistribute any font — please
refer to each font's own license and obtain rights from its owner where
required. See [Removal / takedown requests](#removal--takedown-requests) above
to have a font taken down.

## Credits

- Some font files are sourced from [@mistu01](https://github.com/mistu01).
- And, above all, the original authors, designers, and foundries who created
  these typefaces — full credit and all rights belong to them.
