# Changelog

All notable changes to this project will be documented in this file.

This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.2.0] - 2026-02-27

### Highlights

**No external module required anymore.**
CheckCA2023 now reads all UEFI Secure Boot certificate databases natively, without any third-party dependency.
The UEFIv2 module is no longer needed and does not need to be installed.

### Added

- **Native UEFI certificate reading** — UEFI Secure Boot certificate databases are now read natively using a built-in EFI Signature List (ESL) binary parser. Only X.509 certificates are displayed.
- **DBX and DBXDefault stores** — the Forbidden Signature databases are now displayed in the GUI alongside PK, KEK, DB and their Default counterparts.
- **Tooltip on certificate CN** — hovering over a Common Name in any certificate grid displays a tooltip with the issuer (BN), country and state, and the certificate validity period.
- **ConfidenceLevel full description** — hovering over the `ConfidenceLevel` value displays the complete description, giving administrators immediate context without having to look up Microsoft documentation.
- **Windows Build version check** — the GUI now evaluates the current Windows build against the minimum required build for each supported version (Win10 21H2/22H2, Win11 22H2/23H2/24H2/25H2). A visual indicator shows whether the build meets the requirement.
- **Windows Build version in CSV log** — the build number is now included in each CSV log entry for better fleet tracking.
- **Event ID monitoring (1799, 1801, 1802, 1803)** — the Event Viewer section now tracks these additional TPM-WMI events if present, displaying the date and message of their last occurrence in the event log.

### Changed

- Certificate grids now display enriched data with tooltip support. The CN column uses a template cell to support tooltip binding.

### Requirements

- Windows 10 22H2 or later (build released on or after October 14, 2025)
- Secure Boot enabled
- PowerShell 5.1 or later
- ~~UEFIv2 PowerShell module~~ — **no longer required**
- Administrator privileges

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
