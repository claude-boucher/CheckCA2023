# CheckCA2023

> A PowerShell utility with a XAML GUI to monitor and validate the Microsoft CA 2023 Secure Boot certificate update process on Windows devices.

![Version](https://img.shields.io/badge/version-1.0.0-blue)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell)
![License](https://img.shields.io/badge/license-MIT-green)
![Platform](https://img.shields.io/badge/platform-Windows-lightgrey?logo=windows)

---

## Table of Contents

- [Overview](#overview)
- [Background](#background)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Usage](#usage)
- [What It Checks](#what-it-checks)
- [Registry Reference](#registry-reference)
- [Update Process Summary](#update-process-summary)
- [Troubleshooting](#troubleshooting)
- [References](#references)
- [License](#license)

---

## Overview

**CheckCA2023** is a PowerShell script with a graphical user interface (XAML/WPF) that reads and displays all relevant data needed during the deployment of the new Microsoft CA 2023 Secure Boot certificates.

Instead of manually querying the registry, WMI, BIOS, and Event Viewer, CheckCA2023 consolidates all the information into a single, readable dashboard — making it easier for IT professionals to monitor the update status across their devices.

> ⚠️ **Scope of this tool**
> CheckCA2023 monitors the **Registry Key deployment method** — one of several methods documented by Microsoft for deploying the CA 2023 Secure Boot certificate updates. Other deployment methods (Group Policy Objects, Microsoft Intune, WinCS APIs) are not covered by this tool.
> For the full list of available deployment methods, refer to: [Secure Boot Certificate Updates — Guidance for IT Professionals](https://support.microsoft.com/en-us/topic/secure-boot-certificate-updates-guidance-for-it-professionals-and-organizations-e2b43f9f-b424-42df-bc6a-8476db65ab2f)

---

## Background

Microsoft is updating Secure Boot certificates as part of a major infrastructure refresh. The new **Windows UEFI CA 2023** and **Microsoft UEFI CA 2023** certificates replace the older ones to maintain the integrity of the Secure Boot chain of trust.

This update involves changes to:
- The Secure Boot **KEK** (Key Exchange Key)
- The Secure Boot **DB** (Allowed Signatures Database)
- The Secure Boot **DBX** (Forbidden Signatures Database)
- The boot manager signing chain

Failure to apply these updates before the old certificates expire may result in devices being unable to boot. IT administrators need clear visibility into where each device stands in this process.

> 📌 **Important:** Certificate update support requires a minimum build released on or after **October 14, 2025** (KB5066835 for Windows 11 24H2/23H2).

---

## Prerequisites

### Minimum OS Build

Your system must be running a build released on or after **October 14, 2025**.

- **Windows 10 22H2** and newer (including 21H2 LTSC)
- **Windows 11** — all supported versions
- **Windows Server 2022** and later

> Verify your build at: [KB5066835 - October 14, 2025](https://support.microsoft.com/en-us/topic/october-14-2025-kb5066835-os-builds-26200-6899-and-26100-6899-1db237d8-9f3b-4218-9515-3e0a32729685)
> Select your OS on the left and verify your installed build is equal to or higher than the October 2025 release.

### Secure Boot

Secure Boot must be **enabled** in the BIOS/UEFI firmware of the device.

### UEFIv2 PowerShell Module

CheckCA2023 uses the **UEFIv2** module by [Michael Niehaus](https://oofhours.com) to read Secure Boot certificate databases.

Install it before running CheckCA2023:

```powershell
Install-Module -Name UEFIv2
# Answer Y to NuGet provider and PSGallery prompts

Set-ExecutionPolicy -ExecutionPolicy RemoteSigned

Import-Module -Name UEFIv2
```

> UEFIv2 is an independent module licensed under the **MIT License**. It is not included in this project and must be installed separately.

### PowerShell

- **PowerShell 5.1** minimum (included with Windows 10/11)
- Must be run with **Administrator privileges**

---

## Installation

1. Clone or download this repository:

```powershell
git clone https://github.com/claude-boucher/CheckCA2023.git
```

2. Navigate to the project folder:

```powershell
cd CheckCA2023
```

3. Run the script:

```powershell
.\CheckCA2023.ps1
```

> ⚠️ **Run as Administrator** — reading UEFI variables and registry keys requires elevated privileges.

---

## Usage

Launch the script as Administrator. The GUI will open and automatically read the current state of your system.

Use the **Check / Refresh** button to update the displayed values at any time — especially useful while the Secure Boot update scheduled task is running in the background.

The interface displays all relevant data organized by category (see [What It Checks](#what-it-checks) below).

---

## What It Checks

CheckCA2023 consolidates data from multiple system sources:

| Source | Data |
|---|---|
| **WMI** | System information, BIOS details |
| **BIOS / UEFI Firmware** | Secure Boot state, firmware version |
| **Secure Boot DB** | Active certificate database (via UEFIv2) |
| **Secure Boot DBDefault** | Default/factory certificate database (via UEFIv2) |
| **Registry** | Update progress (`AvailableUpdates`), status (`UEFICA2023Status`), capability (`WindowsUEFICA2023Capable`) |
| **Event Viewer** | Secure Boot DB and DBX variable update events |

---

## Registry Reference

### `HKLM\SYSTEM\CurrentControlSet\Control\SecureBoot`

| Value | Key | Meaning |
|---|---|---|
| `AvailableUpdates` | `0x0000` or not set | No Secure Boot key update will be performed |
| | `0x5944` | **Start** — Deploy all needed certificates and update to PCA2023 signed boot manager |
| | `0x5904` | Applied the Windows UEFI CA 2023 successfully |
| | `0x5104` | Applied the Microsoft Option ROM UEFI CA 2023 (if needed) |
| | `0x4104` | Applied the Microsoft UEFI CA 2023 (if needed) |
| | `0x4100` | Applied the Microsoft Corporation KEK 2K CA 2023 |
| | `0x4000` | Applied the Windows UEFI CA 2023 signed boot manager |

### `HKLM\SYSTEM\CurrentControlSet\Control\SecureBoot\Servicing`

| Key | Value | Meaning |
|---|---|---|
| `UEFICA2023Status` | `NotStarted` | The update has not yet run |
| | `InProgress` | The update is actively in progress |
| | `Updated` | The update has completed successfully |
| `UEFICA2023Error` | `0` | Success |
| | `#Error` | Error code (see Troubleshooting) |
| `WindowsUEFICA2023Capable` | `0` | Windows UEFI CA 2023 certificate is **not** in the DB |
| | `1` | Windows UEFI CA 2023 certificate is in the DB |
| | `2` | Certificate is in the DB **and** the system is starting from the 2023 signed boot manager ✅ |

> If `WindowsUEFICA2023Capable` key does not exist, it is treated as `0` (certificate not present).

---

## Update Process Summary

> This section is provided for reference. CheckCA2023 **monitors** this process — it does not trigger it automatically.

To manually initiate the Secure Boot certificate update (IT-managed deployment):

**Step 1 — Set the registry key to start the process:**
```powershell
reg add HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Secureboot /v AvailableUpdates /t REG_DWORD /d 0x5944 /f
```

**Step 2 — Start the scheduled task:**
```powershell
Start-ScheduledTask -TaskName "\Microsoft\Windows\PI\Secure-Boot-Update"
```
> You can now use the **Check / Refresh** button in CheckCA2023 to monitor progress in real time.

**Step 3 — Wait until `AvailableUpdates` reaches `0x4100`, then reboot.**

**Step 4 — After reboot, run the scheduled task a second time:**
```powershell
Start-ScheduledTask -TaskName "\Microsoft\Windows\PI\Secure-Boot-Update"
```

**Expected final state:**
- `AvailableUpdates` = `0x4000`
- `UEFICA2023Status` = `Updated`
- `WindowsUEFICA2023Capable` = `2`

---

## Troubleshooting

### Secure Boot is not enabled
CheckCA2023 will report that Secure Boot is inactive. Enable it in your BIOS/UEFI settings before proceeding.

### UEFIv2 module not found
The script requires UEFIv2 to be installed and imported. See [Prerequisites](#prerequisites).

### Error codes in `UEFICA2023Error`

These error codes are reported as Windows Event Log entries (Source: **TPM-WMI**, Log: **System**).

| Event ID | Level | Description | Action |
|---|---|---|---|
| **1795** | ❌ Error | The system firmware returned an error when attempting to update a Secure Boot variable (DB, DBX, or KEK). The event log entry includes the firmware error code. | Contact your device manufacturer to determine if a firmware update is available. |
| **1801** | ❌ Error | The required new Secure Boot certificates have **not** been applied to the device's firmware. The event includes device attributes (FirmwareManufacturer, FirmwareVersion, OEMModelNumber), a BucketConfidenceLevel (High Confidence / Needs More Data / Unknown / Paused), and an UpdateType value. | Monitor the process and investigate if the state does not progress. |
| **1808** | ✅ Information | **Expected positive outcome.** All required new Secure Boot certificates have been applied to the firmware, **and** the boot manager has been updated to the version signed by the Windows UEFI CA 2023 certificate. The presence of this event confirms the successful completion of the entire certificate installation process. | No action required — the update is complete. |

> For the full list of Secure Boot event IDs, refer to: [Secure Boot DB and DBX variable update events](https://support.microsoft.com/en-us/topic/secure-boot-db-and-dbx-variable-update-events-37e47cf8-608b-4a87-8175-bdead630eb69)

### Build version too old
The registry keys (`AvailableUpdates`, `UEFICA2023Status`, etc.) are only available on builds released on or after October 14, 2025. Update Windows first.

---

## References

| Resource | Link |
|---|---|
| Windows Secure Boot Certificate Expiration and CA Updates | [Microsoft Support](https://support.microsoft.com/en-us/topic/windows-secure-boot-certificate-expiration-and-ca-updates-7ff40d33-95dc-4c3c-8725-a9b95457578e) |
| Secure Boot Certificate Updates — IT Pro Guidance | [Microsoft Support EN](https://support.microsoft.com/en-us/topic/secure-boot-certificate-updates-guidance-for-it-professionals-and-organizations-e2b43f9f-b424-42df-bc6a-8476db65ab2f) |
| Secure Boot Certificate Updates — Guide IT Pro (FR) | [Microsoft Support FR](https://support.microsoft.com/fr-fr/topic/mises-à-jour-des-certificats-de-démarrage-sécurisé-conseils-pour-les-professionnels-de-l-informatique-et-les-organisations-e2b43f9f-b424-42df-bc6a-8476db65ab2f) |
| Registry Key Updates — IT-Managed Deployment | [Microsoft Support](https://support.microsoft.com/en-au/topic/registry-key-updates-for-secure-boot-windows-devices-with-it-managed-updates-a7be69c9-4634-42e1-9ca1-df06f43f360d) |
| Secure Boot DB and DBX Variable Update Events | [Microsoft Support](https://support.microsoft.com/en-us/topic/secure-boot-db-and-dbx-variable-update-events-37e47cf8-608b-4a87-8175-bdead630eb69) |
| KB5066835 — October 14, 2025 Minimum Build | [Microsoft Support](https://support.microsoft.com/en-us/topic/october-14-2025-kb5066835-os-builds-26200-6899-and-26100-6899-1db237d8-9f3b-4218-9515-3e0a32729685) |
| UEFIv2 PowerShell Module — Michael Niehaus | [PowerShell Gallery](https://www.powershellgallery.com/packages/UEFIv2) |

---

## License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

*CheckCA2023 v1.0.0 — Helping IT professionals navigate the Microsoft CA 2023 Secure Boot certificate transition.*
