#Requires -Version 5.1

#Requires -Version 5.1
<#
.SYNOPSIS
    Application CheckCA2023 with XAML interface to read all the datas involved 
    in the Windows UEFI CA 2023 update process.
.DESCRIPTION
    Read data from WMI BIOS, SecureBoot certificate databases, Registry, 
    and TPM-WMI events. Display results in a WPF window with a refresh button.
.NOTES
    Author  : Claude Boucher - sometools.eu
    Contact : checkca2023@sometools.eu
    Version : 1.0.0
    Date    : 2026-02-21
    License : MIT
    GitHub  : https://github.com/claude-boucher/CheckCA2023
#>

# Force run as Administrator (for testing) - Best practice is to run the script from an elevated PowerShell prompt, but this can help if launched via double-click.
# It will restart the script with admin rights if not already elevated.
#if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
#    $scriptPath = $MyInvocation.MyCommand.Path
#    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
#    exit
#}

# Hide PowerShell window (optional) - Associated with the above code to run as admin, can be uncommented if you want to hide the console window when running the script via double-click.
# Note that if you run the script from an already elevated PowerShell prompt, the console will remain visible.
# $consoleWindow = (Get-Process -Id $PID).MainWindowHandle
# if ($consoleWindow -ne 0) {
#     Add-Type -Name Win -Namespace Console -MemberDefinition '
#     [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);'
#     [Console.Win]::ShowWindow($consoleWindow, 0)
# }

# Enable strict mode - uncommented for development to catch potential issues.
# Can be left commented in production for better resilience to minor issues in the code.
#Set-StrictMode -Version Latest

#region Loading assemblies
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
#endregion

#region Loading XAML
try {
    $xamlPath = Join-Path -Path $PSScriptRoot -ChildPath "MainWindow.xaml"
    
    if (-not (Test-Path $xamlPath)) {
        throw "XAML file not found: $xamlPath"
    }
    
    [xml]$xaml = Get-Content -Path $xamlPath -Encoding UTF8
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $window = [Windows.Markup.XamlReader]::Load($reader)
}
catch {
    Write-Error "Error loading XAML: $_"
    exit 1
}
#endregion

#region Helper function to retrieve XAML controls
function Get-XamlControl {
    param (
        [Parameter(Mandatory)]
        [string]$Name
    )
    
    try {
        $control = $window.FindName($Name)
        if ($null -eq $control) {
            Write-Warning "Control '$Name' not found in XAML"
        }
        return $control
    }
    catch {
        Write-Warning "Error retrieving control '$Name': $_"
        return $null
    }
}
#endregion

#region Retrieve required controls
$btnExecute     = Get-XamlControl -Name "btnExecute"
$btnClose       = Get-XamlControl -Name "btnClose"

$PK_Grid         = Get-XamlControl -Name "PK_Grid"
$PKDefault_Grid  = Get-XamlControl -Name "PKDefault_Grid"
$KEK_Grid        = Get-XamlControl -Name "KEK_Grid"
$KEKDefault_Grid = Get-XamlControl -Name "KEKDefault_Grid"
$DB_Grid         = Get-XamlControl -Name "DB_Grid"
$DBDefault_Grid  = Get-XamlControl -Name "DBDefault_Grid"

$TxtStatus      = Get-XamlControl -Name "TxtStatus"
$BorderStatus   = Get-XamlControl -Name "BorderStatus"

$tbSecureBoot   = Get-XamlControl -Name "tbSecureBoot"
$WinVer         = Get-XamlControl -Name "WinVer"
$WinBuild       = Get-XamlControl -Name "WinBuild"

$SystemFamily   = Get-XamlControl -Name "SystemFamily"
$MachineType    = Get-XamlControl -Name "MachineType"
$BiosVer        = Get-XamlControl -Name "BiosVer"
$BiosDate       = Get-XamlControl -Name "BiosDate"
#endregion

function Get-SecureBootState {
    param (
        [Parameter(Mandatory=$true)]
        [System.Windows.Controls.TextBlock]$OutputControl
    )

    try {
        $state = Confirm-SecureBootUEFI
        if ($state) {
            $OutputControl.Text       = "✔"
            $OutputControl.Foreground = "Green"
        } else {
            $OutputControl.Text       = "✘"
            $OutputControl.Foreground = "Red"
        }
    }
    catch [System.PlatformNotSupportedException] {
        $OutputControl.Text       = "?"
        $OutputControl.Foreground = "Orange"
    }
    catch {
        $OutputControl.Text       = "?"
        $OutputControl.Foreground = "Orange"
    }
}

function Get-WindowsVersionInfo {
    param (
        [Parameter(Mandatory)] [System.Windows.Controls.TextBox]$VerControl,
        [Parameter(Mandatory)] [System.Windows.Controls.TextBox]$BuildControl
    )

    try {
        $reg = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
        $os  = Get-CimInstance Win32_OperatingSystem

        $VerControl.Text   = "$($os.Caption -replace 'Windows', 'Win') $($reg.DisplayVersion)"
        $BuildControl.Text = "$($reg.CurrentBuild).$($reg.UBR)"
    }
    catch {
        Write-Warning "Error in Get-WindowsVersionInfo : $_"
    }
}

function Get-BiosInfo {
    param (
        [Parameter(Mandatory)] [System.Windows.Controls.TextBlock]$SystemFamilyControl,
        [Parameter(Mandatory)] [System.Windows.Controls.TextBlock]$MachineTypeControl,
        [Parameter(Mandatory)] [System.Windows.Controls.TextBlock]$BiosVersionControl,
        [Parameter(Mandatory)] [System.Windows.Controls.TextBlock]$BiosDateControl
    )

    try {
        # Retrieve BIOS info
        $bios = Get-CimInstance Win32_BIOS
        $biosVersion = $bios.SMBIOSBIOSVersion -replace "Version", "" -replace "^\s+|\s+$", ""
        
        # Format date YYYYMMDD -> YYYY-MM-DD
        $biosDateRaw = $bios.ReleaseDate.ToString("yyyyMMdd")
        $biosDate = "$($biosDateRaw.Substring(0,4))-$($biosDateRaw.Substring(4,2))-$($biosDateRaw.Substring(6,2))"
        
        # Retrieve System Family and Machine Type
        $csp = Get-CimInstance Win32_ComputerSystemProduct
        $systemFamily = $csp.Version
        $machineType = $csp.Name.Substring(0, 4)
        
        # Display
        $SystemFamilyControl.Text = $systemFamily
        $MachineTypeControl.Text = $machineType
        $BiosVersionControl.Text = $biosVersion
        $BiosDateControl.Text = $biosDate
    }
    catch {
        Write-Warning "Error in Get-BiosInfo : $_"
    }
}

#region Generic function to retrieve and display UEFI certificates in a DataGrid
function Get-UEFICertificates {
    <#
    .SYNOPSIS
        Retrieves certificates from a UEFI database and displays them in a DataGrid.
        Text turns green if "2023" is detected.
    .PARAMETER DatabaseName
        UEFI database name (db, dbx, KEK, PK, dbdefault, KEKdefault, etc.)
    .PARAMETER GridControl
        DataGrid control where results will be displayed
    .EXAMPLE
        Get-UEFICertificates -DatabaseName "KEK" -GridControl $KEK_Grid
    #>
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet("PK", "PKdefault", "KEK", "KEKdefault", "DB", "DBdefault", "DBX", "DBXdefault")]
        [string]$DatabaseName,
        
        [Parameter(Mandatory=$true)]
        [System.Windows.Controls.DataGrid]$GridControl
    )
    
    try {
        # Check that UEFIv2 module is available
        if (-not (Get-Command Get-UEFISecureBootCerts -ErrorAction SilentlyContinue)) {
            # Display error message in the grid
            $errorData = @([PSCustomObject]@{ CN = "ERROR"; O = "UEFIv2 module not available" })
            $GridControl.ItemsSource = $errorData
            return $false
        }
        
        # Retrieve certificates from the specified database
        $certs = (Get-UEFISecureBootCerts $DatabaseName -ErrorAction Stop).signature
        
        if ($null -eq $certs) {
            # Display message if no certificates found
            $noData = @([PSCustomObject]@{ CN = "No certificate"; O = "Database '$DatabaseName' is empty" })
            $GridControl.ItemsSource = $noData
            return $false
        }

        # Create object collection for the DataGrid
        $gridData = @()
        
        foreach ($cert in $certs) {
            # Extract CN (Common Name)
            $cn = if ($cert.Subject -match 'CN=([^,]+)') { $matches[1] } else { "N/A" }
            
            # Extract O (Organization)
            $o = if ($cert.Subject -match 'O=([^,]+)') { $matches[1] } else { "N/A" }
            
            # Check if "2023" is present in CN or O - color the row only
            $rowColor = if ($cn -match '2023' -or $o -match '2023') { "Green" } else { "Black" }
            
            # Add to collection with row color
            $gridData += [PSCustomObject]@{
                CN    = $cn
                O     = $o
                Color = $rowColor
            }
        }
        
        # Display in the DataGrid
        $GridControl.ItemsSource = $gridData
        
        # Apply color row by row via style
        $GridControl.Foreground = "Black"
        $GridControl.RowStyle = $null
        
        $style = New-Object System.Windows.Style([System.Windows.Controls.DataGridRow])
        $trigger = New-Object System.Windows.DataTrigger
        $trigger.Binding = New-Object System.Windows.Data.Binding("Color")
        $trigger.Value = "Green"
        $setter = New-Object System.Windows.Setter([System.Windows.Controls.Control]::ForegroundProperty, [System.Windows.Media.Brushes]::Green)
        $trigger.Setters.Add($setter)
        $setterBold = New-Object System.Windows.Setter([System.Windows.Controls.Control]::FontWeightProperty, [System.Windows.FontWeights]::Bold)
        $trigger.Setters.Add($setterBold)
        $style.Triggers.Add($trigger)
        $GridControl.RowStyle = $style
       
        return $true
    }
    catch {
        # Display error in the grid
        $errorData = @([PSCustomObject]@{ 
            CN = "ERROR" 
            O = $_.Exception.Message 
        })
        $GridControl.ItemsSource = $errorData
        return $false
    }
}
#endregion

#region Function to update the status label
function Update-StatusLabel {
    param (
        [string]$Message,
        [string]$Color = "Black"
    )
    
    $TxtStatus.Text = $Message
    $TxtStatus.Foreground = $Color
    $BorderStatus.BorderBrush = $Color
}
#endregion

#region Lookup table - AvailableUpdates
$AvailableUpdates_Table = [ordered]@{
    "0x0000" = "No Secure Boot key update are performed"
    "0x4000" = "Applied the Windows UEFI CA 2023 signed boot manager"
    "0x4004" = "A PK signed KEK, from the OEM isn't available."
    "0x4100" = "Applied the Microsoft Corporation KEK 2K CA 2023"
    "0x4104" = "Applied the Microsoft UEFI CA 2023 if needed"
    "0x5104" = "Applied the Microsoft Option ROM UEFI CA 2023 if needed"
    "0x5904" = "Applied the Windows UEFI CA 2023 successfully"
    "0x5944" = "Start - Deploy all needed certificates and update to the PCA2023 signed boot manager"
}
#endregion

#region Lookup table - UEFICA2023Status (REG_SZ)
$UEFICA2023Status_Table = [ordered]@{
    "NotStarted" = "The update has not yet run."
    "InProgress" = "The update is actively in progress."
    "Updated"    = "The update has completed successfully."
}
#endregion

#region Lookup table - WindowsUEFICA2023Capable (REG_DWORD)
$WindowsUEFICA2023Capable_Table = [ordered]@{
    "0x0000" = "Windows UEFI CA 2023 certificate is not in the DB"
    "0x0001" = "Windows UEFI CA 2023 certificate is in the DB"
    "0x0002" = "Windows UEFI CA 2023 certificate is in the DB and the system is starting from the 2023 signed boot manager"
}
#endregion

#region Function to read a registry value and populate controls
function Get-RegistryValue {
    <#
    .SYNOPSIS
        Reads a REG_DWORD value from the registry and populates two TextBlocks:
        the hex value and the corresponding text from a lookup table.
    .PARAMETER RegPath
        Registry key path
    .PARAMETER ValueName
        Value name to read
    .PARAMETER LookupTable
        Ordered hashtable: key = hex string, value = descriptive text
    .PARAMETER HexControl
        TextBlock to display the hex value read
    .PARAMETER DescControl
        TextBlock to display the corresponding text
    .PARAMETER IconControl
        TextBlock to display the ✔ icon (optional)
    .PARAMETER GoodValue
        Hex string value considered as "good" to display ✔ (optional)
    .PARAMETER DefaultDesc
        Text to display if the key is absent (optional)
    #>
    param (
        [Parameter(Mandatory=$true)]  [string]$RegPath,
        [Parameter(Mandatory=$true)]  [string]$ValueName,
        [Parameter(Mandatory=$true)]  [System.Collections.Specialized.OrderedDictionary]$LookupTable,
        [Parameter(Mandatory=$true)]  [System.Windows.Controls.TextBlock]$HexControl,
        [Parameter(Mandatory=$true)]  [System.Windows.Controls.TextBlock]$DescControl,
        [Parameter(Mandatory=$false)] [System.Windows.Controls.TextBlock]$IconControl = $null,
        [Parameter(Mandatory=$false)] [string]$GoodValue = "",
        [Parameter(Mandatory=$false)] [string]$DefaultDesc = ""
    )

    try {
        $regItem  = Get-ItemProperty -Path $RegPath -Name $ValueName -ErrorAction Stop
        $rawValue = $regItem.$ValueName
        $hexValue = "0x{0:X4}" -f $rawValue

        $HexControl.Text       = $hexValue
        $HexControl.Foreground = "Black"

        if ($LookupTable.Contains($hexValue)) {
            $DescControl.Text       = $LookupTable[$hexValue]
            $DescControl.Foreground = "Black"
        } else {
            $DescControl.Text       = "Unknown value"
            $DescControl.Foreground = "OrangeRed"
        }

        # Icon ✔ if expected value
        if ($null -ne $IconControl -and $GoodValue -ne "") {
            if ($hexValue -eq $GoodValue) {
                $IconControl.Text       = "✔"
                $IconControl.Foreground = "Green"
            } else {
                $IconControl.Text       = "…"
                $IconControl.Foreground = "Orange"
            }
        }
    }
    catch {
        $HexControl.Text       = "N/A"
        $HexControl.Foreground = "OrangeRed"
        if ($null -ne $IconControl) { $IconControl.Text = "" }
        if ($DefaultDesc -ne "") {
            $DescControl.Text       = $DefaultDesc
            $DescControl.Foreground = "Black"
        } else {
            $DescControl.Text       = $_.Exception.Message
            $DescControl.Foreground = "OrangeRed"
        }
    }
}
#endregion

#region Function to read a REG_SZ registry value and populate controls
function Get-RegistryStringValue {
    <#
    .SYNOPSIS
        Reads a REG_SZ value from the registry and populates two TextBlocks:
        the string value read and the corresponding description.
    .PARAMETER RegPath
        Registry key path
    .PARAMETER ValueName
        Value name to read
    .PARAMETER LookupTable
        Ordered hashtable: key = string, value = descriptive text
    .PARAMETER ValueControl
        TextBlock to display the string value read
    .PARAMETER DescControl
        TextBlock to display the corresponding text
    .PARAMETER IconControl
        TextBlock to display the ✔/✘ icon (optional)
    .PARAMETER GoodValue
        String value considered as "good" to display ✔ (optional)
    .PARAMETER DefaultDesc
        Text to display if the key is absent (optional)
    #>
    param (
        [Parameter(Mandatory=$true)]  [string]$RegPath,
        [Parameter(Mandatory=$true)]  [string]$ValueName,
        [Parameter(Mandatory=$true)]  [System.Collections.Specialized.OrderedDictionary]$LookupTable,
        [Parameter(Mandatory=$true)]  [System.Windows.Controls.TextBlock]$ValueControl,
        [Parameter(Mandatory=$true)]  [System.Windows.Controls.TextBlock]$DescControl,
        [Parameter(Mandatory=$false)] [System.Windows.Controls.TextBlock]$IconControl = $null,
        [Parameter(Mandatory=$false)] [string]$GoodValue = "",
        [Parameter(Mandatory=$false)] [string]$DefaultDesc = ""
    )

    try {
        $regItem  = Get-ItemProperty -Path $RegPath -Name $ValueName -ErrorAction Stop
        $strValue = $regItem.$ValueName

        $ValueControl.Text       = $strValue
        $ValueControl.Foreground = "Black"

        if ($LookupTable.Contains($strValue)) {
            $DescControl.Text       = $LookupTable[$strValue]
            $DescControl.Foreground = "Black"
        } else {
            $DescControl.Text       = "Unknown value"
            $DescControl.Foreground = "OrangeRed"
        }

        # Icon ✔ if expected value
        if ($null -ne $IconControl -and $GoodValue -ne "") {
            if ($strValue -eq $GoodValue) {
                $IconControl.Text       = "✔"
                $IconControl.Foreground = "Green"
            } else {
                $IconControl.Text       = "…"
                $IconControl.Foreground = "Orange"
            }
        }
    }
    catch {
        $ValueControl.Text       = "N/A"
        $ValueControl.Foreground = "OrangeRed"
        if ($null -ne $IconControl) { $IconControl.Text = "" }
        if ($DefaultDesc -ne "") {
            $DescControl.Text       = $DefaultDesc
            $DescControl.Foreground = "OrangeRed"
        } else {
            $DescControl.Text       = $_.Exception.Message
            $DescControl.Foreground = "OrangeRed"
        }
    }
}
#endregion

#region Retrieve Registry controls
$Reg1_HexValue    = Get-XamlControl -Name "Reg1_HexValue"
$Reg1_Description = Get-XamlControl -Name "Reg1_Description"
$Reg2_Value       = Get-XamlControl -Name "Reg2_Value"
$Reg2_Icon        = Get-XamlControl -Name "Reg2_Icon"
$Reg2_Description = Get-XamlControl -Name "Reg2_Description"
$Reg3_HexValue    = Get-XamlControl -Name "Reg3_HexValue"
$Reg3_Icon        = Get-XamlControl -Name "Reg3_Icon"
$Reg3_Description = Get-XamlControl -Name "Reg3_Description"
$Reg4_DecValue    = Get-XamlControl -Name "Reg4_DecValue"
$Reg4_Icon        = Get-XamlControl -Name "Reg4_Icon"

$Error_Num            = Get-XamlControl -Name "Error_Num"
$Error_Status         = Get-XamlControl -Name "Error_Status"
$Error_Icon           = Get-XamlControl -Name "Error_Icon"
$Error_Message        = Get-XamlControl -Name "Error_Message"
$WrapPanel_ErrorEvent = Get-XamlControl -Name "WrapPanel_ErrorEvent"

$_1808_Num     = Get-XamlControl -Name "_1808_Num"
$_1808_Status  = Get-XamlControl -Name "_1808_Status"
$_1808_Icon    = Get-XamlControl -Name "_1808_Icon"
$_1808_Message = Get-XamlControl -Name "_1808_Message"
#endregion

#region Function to read a REG_DWORD registry value and display its decimal value
function Get-RegistryDWordDecimal {
    <#
    .SYNOPSIS
        Reads a REG_DWORD value from the registry and displays its decimal value.
        Designed to be extended later (e.g. event lookup).
    .PARAMETER RegPath
        Registry key path
    .PARAMETER ValueName
        Value name to read
    .PARAMETER ValueControl
        TextBlock to display the decimal value read
    .PARAMETER IconControl
        TextBlock to display the ✔/✘ icon (optional)
    .PARAMETER DefaultText
        Text to display if the key is absent (optional)
    #>
    param (
        [Parameter(Mandatory=$true)]  [string]$RegPath,
        [Parameter(Mandatory=$true)]  [string]$ValueName,
        [Parameter(Mandatory=$true)]  [System.Windows.Controls.TextBlock]$ValueControl,
        [Parameter(Mandatory=$false)] [System.Windows.Controls.TextBlock]$IconControl = $null,
        [Parameter(Mandatory=$false)] [string]$DefaultText = "N/A"
    )

    try {
        $regItem  = Get-ItemProperty -Path $RegPath -Name $ValueName -ErrorAction Stop
        $rawValue = $regItem.$ValueName

        # Store decimal value for future use
        $script:Reg4_RawValue = $rawValue

        $ValueControl.Text       = "$rawValue"
        $ValueControl.Foreground = "Black"

        # Icon: error if value != 0
        if ($null -ne $IconControl) {
            if ($rawValue -eq 0) {
                $IconControl.Text       = "✔"
                $IconControl.Foreground = "Green"
            } else {
                $IconControl.Text       = "✘"
                $IconControl.Foreground = "Red"
            }
        }
    }
    catch {
        $script:Reg4_RawValue    = $null
        $ValueControl.Text       = $DefaultText
        $ValueControl.Foreground = if ($DefaultText -eq "No Error") { "Black" } else { "OrangeRed" }
        # Key absent = No Error = ✔
        if ($null -ne $IconControl) {
            $IconControl.Text       = "✔"
            $IconControl.Foreground = "Green"
        }
    }
}
#endregion

#region Function to retrieve the TPM-WMI event matching the Reg4 error code
function Get-TPMEventInfo {
    <#
    .SYNOPSIS
        Retrieves the latest TPM-WMI event matching the UEFICA2023ErrorEvent error code
    .PARAMETER EventID
        Event number retrieved from the registry (Reg4_RawValue)
    #>
    param (
        [Parameter(Mandatory=$true)] [int]$EventID
    )

    try {
        $event       = Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-TPM-WMI'; ID=$EventID} -MaxEvents 1
        $fullMessage = $event.Message
        $message     = ($fullMessage -split '\r?\n')[0].Trim()

        $Error_Num.Text           = "$EventID"
        $Error_Status.Text        = "Error"
        $Error_Status.Foreground  = "Red"
        $Error_Icon.Text          = "✘"
        $Error_Icon.Foreground    = "Red"
        $Error_Message.Text       = $message
        $Error_Message.Foreground = "Black"
    }
    catch {
        $Error_Num.Text           = "$EventID"
        $Error_Status.Text        = "Not Found"
        $Error_Status.Foreground  = "Orange"
        $Error_Icon.Text          = "…"
        $Error_Icon.Foreground    = "Orange"
        $Error_Message.Text       = ""
    }
}
#endregion

#region Function to retrieve TPM-WMI Event ID 1808 (Secure Boot keys updated)
function Get-TPMEvent1808 {
    try {
        $event1808 = Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-TPM-WMI'; ID=1808} -MaxEvents 1 -ErrorAction SilentlyContinue

        if ($event1808) {
            $fullMessage = $event1808.Message
            $message     = ($fullMessage -split '\r?\n')[0].Trim()
            $updateType  = if ($fullMessage -match 'UpdateType:\s*(.+)') { $matches[1].Trim() } else { "N/A" }

            $_1808_Num.Text           = "1808"
            $_1808_Status.Text        = "Present"
            $_1808_Status.Foreground  = "Green"
            $_1808_Icon.Text          = "✔"
            $_1808_Icon.Foreground    = "Green"
            $_1808_Message.Text       = "$message`nUpdateType : $updateType"
            $_1808_Message.Foreground = "Black"
        }
        else {
            $_1808_Num.Text           = "1808"
            $_1808_Status.Text        = "Missing"
            $_1808_Status.Foreground  = "Red"
            $_1808_Icon.Text          = "✘"
            $_1808_Icon.Foreground    = "Red"
            $_1808_Message.Text       = ""
        }
    }
    catch {
        $_1808_Num.Text           = "1808"
        $_1808_Status.Text        = "Missing"
        $_1808_Status.Foreground  = "Red"
        $_1808_Icon.Text          = "✘"
        $_1808_Icon.Foreground    = "Red"
        $_1808_Message.Text       = ""
    }
}
#endregion

function Invoke-MainAction {
    try {
        Update-StatusLabel -Message "Data retrieval..." -Color "Blue"

        # Query all configured databases
        $success = $true
        
        # PK Active
        if (-not (Get-UEFICertificates -DatabaseName "PK" -GridControl $PK_Grid)) {
            $success = $false
        }
        
        # PK Default
        if (-not (Get-UEFICertificates -DatabaseName "PKdefault" -GridControl $PKDefault_Grid)) {
            $success = $false
        }

        # KEK Active
        if (-not (Get-UEFICertificates -DatabaseName "KEK" -GridControl $KEK_Grid)) {
            $success = $false
        }
        
        # KEK Default
        if (-not (Get-UEFICertificates -DatabaseName "KEKdefault" -GridControl $KEKDefault_Grid)) {
            $success = $false
        }
        
        # DB Active
        if (-not (Get-UEFICertificates -DatabaseName "DB" -GridControl $DB_Grid)) {
            $success = $false
        }
        
        # DB Default
        if (-not (Get-UEFICertificates -DatabaseName "DBdefault" -GridControl $DBDefault_Grid)) {
            $success = $false
        }
        
        if ($success) {
            Update-StatusLabel -Message "Data retrieval completed successfully" -Color "Green"
        }
        else {
            Update-StatusLabel -Message "Data retrieval completed with errors" -Color "Orange"
        }

        # Registry : AvailableUpdates
        Get-RegistryValue       -RegPath    "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot" `
                                -ValueName  "AvailableUpdates" `
                                -LookupTable $AvailableUpdates_Table `
                                -HexControl  $Reg1_HexValue `
                                -DescControl $Reg1_Description

        # Registry : UEFICA2023Status
        Get-RegistryStringValue -RegPath      "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\Servicing" `
                                -ValueName    "UEFICA2023Status" `
                                -LookupTable  $UEFICA2023Status_Table `
                                -ValueControl $Reg2_Value `
                                -DescControl  $Reg2_Description `
                                -IconControl  $Reg2_Icon `
                                -GoodValue    "Updated"

        # Registry : WindowsUEFICA2023Capable
        Get-RegistryValue       -RegPath     "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\Servicing" `
                                -ValueName   "WindowsUEFICA2023Capable" `
                                -LookupTable $WindowsUEFICA2023Capable_Table `
                                -HexControl  $Reg3_HexValue `
                                -DescControl $Reg3_Description `
                                -IconControl $Reg3_Icon `
                                -GoodValue   "0x0002" `
                                -DefaultDesc "Windows UEFI CA 2023 certificate is not in the DB"

        # Registry : UEFICA2023ErrorEvent
        Get-RegistryDWordDecimal -RegPath     "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\Servicing" `
                                 -ValueName   "UEFICA2023ErrorEvent" `
                                 -ValueControl $Reg4_DecValue `
                                 -IconControl  $Reg4_Icon `
                                 -DefaultText  "No Error"

        # Event TPM-WMI : trigger only if an error is detected
        if ($script:Reg4_RawValue) {
            $WrapPanel_ErrorEvent.Visibility = [System.Windows.Visibility]::Visible
            Get-TPMEventInfo -EventID $script:Reg4_RawValue
        } else {
            $Error_Num.Text    = ""
            $Error_Status.Text = ""
            $Error_Icon.Text   = ""
            $Error_Message.Text = ""
            $WrapPanel_ErrorEvent.Visibility = [System.Windows.Visibility]::Collapsed
        }

        # Event TPM-WMI 1808 : Secure Boot keys updated
        Get-TPMEvent1808
    }
    catch {
        Update-StatusLabel -Message "Data retrieval error" -Color "Red"
        Write-Error $_
    }
}
#endregion

#region Event handlers
# Execute button
if ($btnExecute) {
    $btnExecute.Add_Click({
        Invoke-MainAction
        $btnExecute.Content = "Refresh"
    })
}

# Close button
if ($btnClose) {
    $btnClose.Add_Click({
        $window.Close()
    })
}

# Window loading event
$window.Add_Loaded({
    # Check Admin rights (warning only)
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
        Update-StatusLabel -Message "WARNING - Administrator rights required" -Color "Red"
    } else {
        Update-StatusLabel -Message "Ready to check" -Color "Green"
    }
    Get-SecureBootState -OutputControl $tbSecureBoot
    Get-WindowsVersionInfo -VerControl $WinVer -BuildControl $WinBuild
    Get-BiosInfo    -SystemFamilyControl $SystemFamily `
                    -MachineTypeControl $MachineType `
                    -BiosVersionControl $BiosVer `
                    -BiosDateControl $BiosDate
})

# Window closing event
$window.Add_Closing({
    Write-Host "Closing application..."
})
#endregion

#region Display window
$window.ShowDialog() | Out-Null
#endregion