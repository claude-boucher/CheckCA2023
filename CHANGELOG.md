# Changelog

All notable changes to this project will be documented in this file.

This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.5.0] - 2026-04-29

### Added
- **Rollback button** in ESP bootloader panel: one-click rollback to PCA 2011 by 
  overwriting `S:\EFI\Microsoft\Boot\bootmgfw.efi` with the system 
  `C:\Windows\Boot\EFI\bootmgfw.efi` (PCA 2011 signed).
- Button is enabled only when System bootloader is **PCA 2011** and ESP bootloader 
  is **CA 2023** — the only state where rollback is meaningful.
- Confirmation dialog with explicit prerequisite reminders (BitLocker suspended, 
  PCA 2011 still in db, SBAT compatibility).
- Tooltip styled with the existing `BitToolTipStyle` for visual consistency.

### Changed
- ESP bootloader panel layout refactored from stacked StackPanels into a 
  2-column Grid to host the Rollback button on the right.

### Notes
- Rollback is intended for **diagnostic and test rollback only** (BIOS 
  downgrade scenarios, certificate-installation procedure validation).
- Operator is responsible for prerequisites — no automated checks performed.
- Action is not logged to CSV.

## [1.4.0] - 2026-04-08

### Added
- **"Show GUID" checkbox** in the Secure Boot variables panel: displays the 
  `SignatureOwner` GUID of each certificate alongside its CN.
- Color coding for ownership identification:
  - **Blue** — Microsoft-owned certificates (expected GUID)
  - **BlueViolet** — OEM-owned certificates (Lenovo or other vendor GUID)
- Enables fast diagnosis of misattributed certificates in `db` — typical 
  symptom: BitLocker recovery loop after KB updates due to wrong 
  `SignatureOwner` on Windows UEFI CA 2023 (observed on ThinkCentre neo 50q 
  Gen 4 fleet).

## [1.3.0] - 2026-03-18

### Highlights

**One more thing...** — Click MORE to reveal two new diagnostic panels: a detailed breakdown of the `AvailableUpdates` bit flags, and bootloader certificate information for `bootmgfw.efi`.

### Added

- **BitLocker status** — the Configuration panel now displays the BitLocker protection status of the system drive, including the active key protector type (TPM, TPM+PIN, Password). A visual indicator (✔/✘) provides immediate visibility into the encryption state.

- **AvailableUpdates details panel** *(visible after clicking MORE)* — a new bit-level breakdown of the `AvailableUpdates` registry value, displaying all 13 individual bit flags (0x0002 → 0x4000) with their hex value, sequence order, and designation. Each row includes a detailed tooltip explaining the exact operation performed by that bit. Rows are color-coded dynamically: gray when inactive, black when scheduled, green when completed since the last refresh.

- **Bootloader certificates panel** *(visible after clicking MORE)* — displays the signing certificate, thumbprint, and file version of `bootmgfw.efi` from two locations: the system volume (`C:\Windows\Boot\EFI\`) and the EFI System Partition (`\EFI\Microsoft\Boot\`). Certificate authority is color-coded: green for CA 2023, default color for PCA 2011. The full thumbprint is available via tooltip. Reading is performed by parsing the embedded PKCS#7 signature directly from the PE binary — no external dependency required.

- **Last refresh timestamp** *(visible after clicking MORE)* — displays the date and time of the last data refresh.

### Changed

- **SET AvailableUpdates button** replaced by a ComboBox + SET button — all known `AvailableUpdates` values from the lookup table are available for selection, allowing administrators to test individual update stages rather than being limited to `0x5944`.

---

## [1.2.1] - 2026-03-01

### Fixed

- Fixed display issue when DBX or DBXDefault store is empty — the grid now correctly reports the absence of X.509 certificates instead of throwing an error.
- Minor typo corrections in registry value descriptions.

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
