# Changelog

All notable changes to this project will be documented in this file.

This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.1.0] - 2026-02-22

### Added

- **Set AvailableUpdates button** — sets the `AvailableUpdates` registry key to `0x5944` directly from the GUI, replacing the manual `reg add` command
- **Start "Secure-Boot-Update" Task button** — triggers the `\Microsoft\Windows\PI\Secure-Boot-Update` scheduled task directly from the GUI, replacing the manual `Start-ScheduledTask` command
- **Create/Append logs to CSV button** — saves a snapshot of the current registry values and Event Viewer entries to a CSV log file (`Log_CheckCA2023.csv`), allowing historical tracking of the deployment progress over time
- **Application logo and version number** included in the GUI

---

## [1.0.0] - 2026-02-21

### Initial Release

First public release of **CheckCA2023** — a PowerShell XAML GUI utility to monitor the Microsoft CA 2023 Secure Boot certificate update process.

### Features

- XAML/WPF graphical interface with Check / Refresh button for real-time monitoring
- Reads and displays WMI system and BIOS information
- Reads and displays Secure Boot state from UEFI firmware
- Reads and displays active Secure Boot DB certificates (via UEFIv2 module)
- Reads and displays default Secure Boot DBDefault certificates (via UEFIv2 module)
- Reads and displays registry keys from `HKLM\SYSTEM\CurrentControlSet\Control\SecureBoot`:
  - `AvailableUpdates` — update progress tracking
  - `UEFICA2023Status` — deployment status (NotStarted / InProgress / Updated)
  - `UEFICA2023Error` — error code if any
  - `WindowsUEFICA2023Capable` — certificate presence and boot manager status
- Reads and displays relevant Secure Boot events from Windows Event Viewer (TPM-WMI source)

### Requirements

- Windows 10 22H2 or later (build released on or after October 14, 2025)
- Secure Boot enabled
- PowerShell 5.1 or later
- UEFIv2 PowerShell module by Michael Niehaus (MIT License) — installed separately
- Administrator privileges

---

*For older versions and future updates, entries will be added above this initial release.*
