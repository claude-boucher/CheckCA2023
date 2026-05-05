#Requires -Version 5.1
<#
.SYNOPSIS
    Application CheckCA2023 with XAML interface to read all the datas involved in the Windows UEFI CA 2023 update process.
.DESCRIPTION
    Read data from WMI BIOS, SecureBoot certificate databases, Registry, 
    and TPM-WMI events. Display results in a WPF window with a refresh button.
.NOTES
    Author  : Claude Boucher - sometools.eu
    Contact : checkca2023@sometools.eu
    Version : 1.5.0
    Date    : 2026-05-05
    License : MIT
    GitHub  : https://github.com/claude-boucher/CheckCA2023
#>

# Force run as Administrator (for testing) - Best practice is to run the script from an elevated PowerShell prompt, but this can help if launched via double-click.
# It will restart the script with admin rights if not already elevated.
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    $scriptPath = $MyInvocation.MyCommand.Path
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
    exit
}

# Hide PowerShell window (optional) - Associated with the above code to run as admin, can be uncommented if you want to hide the console window when running the script via double-click.
# Note that if you run the script from an already elevated PowerShell prompt, the console will remain visible.
 $consoleWindow = (Get-Process -Id $PID).MainWindowHandle
 if ($consoleWindow -ne 0) {
     Add-Type -Name Win -Namespace Console -MemberDefinition '
     [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);'
     [Console.Win]::ShowWindow($consoleWindow, 0)
 }

# Enable strict mode - uncommented for development to catch potential issues.
# Can be left commented in production for better resilience to minor issues in the code.
#Set-StrictMode -Version Latest

#region Loading assemblies
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Security
#endregion

#region Loading XAML
try {
    [xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="CheckCA2023" WindowStartupLocation="CenterScreen" Background="#FFE4EAF0"
        Width="1280" MinWidth="1280" MaxWidth="1280" 
        MinHeight="700" MaxHeight="900" >

    <Window.Resources>
        <Style x:Key="ConfirmBoxButton" TargetType="{x:Type Button}">
            <Setter Property="Background"      Value="White" />
            <Setter Property="FontSize"        Value="20" />
            <Setter Property="Width"           Value="140"/>
            <Setter Property="Height"          Value="50"/>
            <Setter Property="BorderBrush"     Value="Black"/>
            <Setter Property="BorderThickness" Value="2"/>
            <Setter Property="FontWeight"      Value="Bold"/>
            <Setter Property="Padding"         Value="0"/>
            <Setter Property="Foreground"      Value="Black"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="{x:Type Button}">
                        <Border CornerRadius="5" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" >
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" />
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Setter Property="Effect">
                <Setter.Value>
                    <DropShadowEffect Color="Black" 
                                  Opacity="0.5" 
                                  BlurRadius="10" 
                                  ShadowDepth="4" 
                                  Direction="315"/>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background"  Value="#FFCAE3FC" />
                    <Setter Property="BorderBrush" Value="Black" />
                    <Setter Property="Foreground"  Value="Black" />
                </Trigger>
                <Trigger Property="IsPressed" Value="True">
                    <Setter Property="Background"  Value="#FF3E8DDD" />
                    <Setter Property="BorderBrush" Value="#FF3E8DDD" />
                    <Setter Property="Foreground"  Value="White" />
                </Trigger>
            </Style.Triggers>
        </Style>
        <!-- Styles pour les boutons -->
        <Style x:Key="ButtonStyle" TargetType="Button">
            <Setter Property="Margin" Value="5,0,0,0"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Background" Value="White"/>
            <Setter Property="Foreground" Value="Black"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="{x:Type Button}">
                        <Border CornerRadius="3" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" >
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="0,0,0,0" />
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Setter Property="Effect">
                <Setter.Value>
                    <DropShadowEffect Color="Black" 
                                  Opacity="0.5" 
                                  BlurRadius="10" 
                                  ShadowDepth="4" 
                                  Direction="315"/>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background"  Value="#FFCAE3FC" />
                    <Setter Property="Foreground"  Value="Black" />
                </Trigger>
                <Trigger Property="IsPressed" Value="True">
                    <Setter Property="Background"  Value="#FF3E8DDD" />
                    <Setter Property="Foreground"  Value="White" />
                </Trigger>
            </Style.Triggers>
        </Style>
        <!-- DataGrid style -->
        <Style x:Key="DataGridStyle1" TargetType="{x:Type DataGrid}">
            <Setter Property="Margin" Value="0"/>
            <Setter Property="Padding" Value="0,-2,0,-2"/>
            <Setter Property="FontSize" Value="10" />
            <Setter Property="ColumnHeaderStyle" Value="{DynamicResource ColumnHeaderStyle1}"/>
            <Setter Property="AutoGenerateColumns" Value="False"/>
            <Setter Property="IsReadOnly" Value="True"/>
            <Setter Property="GridLinesVisibility" Value="None"/>
            <Setter Property="Background" Value="White"/>
            <Setter Property="RowBackground" Value="Transparent"/>
            <!--  <Setter Property="AlternatingRowBackground" Value="#c5c5c5"/>  -->
        </Style>
        <!-- DataGridColumnHeader style -->
        <Style x:Key="ColumnHeaderStyle1" TargetType="DataGridColumnHeader" >
            <Setter Property="Margin" Value="0,-6,0,-4"/>
            <Setter Property="Height" Value="25"/>
            <Setter Property="Padding" Value="0,0,0,0"/>
            <Setter Property="FontSize" Value="11" />
            <Setter Property="Background" Value="#FFE4EAF0"/>
            <Setter Property="Foreground" Value="#FF324873"/>
            <Setter Property="FontWeight" Value="Bold" />
            <Setter Property="HorizontalContentAlignment" Value="Left" />
        </Style>
        <!-- Style pour les TextBox -->
        <Style x:Key="TextBoxStyle" TargetType="TextBox">
            <Setter Property="Padding" Value="5"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="BorderBrush" Value="#CCCCCC"/>
            <Setter Property="BorderThickness" Value="1"/>
        </Style>

        <!-- ═══ STYLE TOOLTIP ═══ -->
        <Style x:Key="BitToolTipStyle" TargetType="ToolTip">
            <Setter Property="Background"      Value="#FFFEF3CD"/>
            <Setter Property="BorderBrush"     Value="#FFD4A017"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding"         Value="8,6,8,6"/>
            <Setter Property="MaxWidth"        Value="280"/>
            <Setter Property="HasDropShadow"   Value="True"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ToolTip">
                        <Border Background="{TemplateBinding Background}"
                        BorderBrush="{TemplateBinding BorderBrush}"
                        BorderThickness="{TemplateBinding BorderThickness}"
                        CornerRadius="6"
                        Padding="8,6,8,6">
                            <ContentPresenter/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ═══ STYLES DE BASE ═══ -->
        <Style x:Key="BitCellStyle" TargetType="TextBlock">
            <Setter Property="FontSize"          Value="10"/>
            <Setter Property="FontFamily"        Value="Segoe UI"/>
            <Setter Property="Foreground"        Value="#6C7086"/>
            <Setter Property="VerticalAlignment" Value="Center"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
        </Style>
        <Style x:Key="BitHexStyle" TargetType="TextBlock" BasedOn="{StaticResource BitCellStyle}">
            <Setter Property="FontSize"          Value="11"/>
            <Setter Property="FontFamily" Value="Consolas"/>
            <Setter Property="FontWeight" Value="Normal"/>
        </Style>
        <Style x:Key="BitHeaderStyle" TargetType="TextBlock">
            <Setter Property="FontSize"          Value="10"/>
            <Setter Property="FontFamily"        Value="Segoe UI"/>
            <Setter Property="FontWeight"        Value="Bold"/>
            <Setter Property="Background"        Value="#443E8DDD"/>
            <Setter Property="Foreground"        Value="#FF3E8DDD"/>
            <Setter Property="VerticalAlignment" Value="Center"/>
        </Style>

        <!-- ═══ STYLES PAR COLONNE — DONNÉES ═══ -->
        <Style x:Key="ColBitStyle" TargetType="TextBlock" BasedOn="{StaticResource BitHexStyle}">
            <Setter Property="TextAlignment" Value="Center"/>
        </Style>
        <Style x:Key="ColOrdStyle" TargetType="TextBlock" BasedOn="{StaticResource BitHexStyle}">
            <Setter Property="TextAlignment" Value="Center"/>
        </Style>
        <Style x:Key="ColDesignationStyle" TargetType="TextBlock" BasedOn="{StaticResource BitCellStyle}">
            <Setter Property="TextAlignment" Value="Left"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="ToolTipService.InitialShowDelay" Value="100"/>
        </Style>

        <!-- ═══ STYLES PAR COLONNE — HEADER ═══ -->
        <Style x:Key="ColHeaderBitStyle" TargetType="TextBlock" BasedOn="{StaticResource BitHeaderStyle}">
            <Setter Property="TextAlignment" Value="Center"/>
        </Style>
        <Style x:Key="ColHeaderOrdStyle" TargetType="TextBlock" BasedOn="{StaticResource BitHeaderStyle}">
            <Setter Property="TextAlignment" Value="Center"/>
        </Style>
        <Style x:Key="ColHeaderDesignationStyle" TargetType="TextBlock" BasedOn="{StaticResource BitHeaderStyle}">
            <Setter Property="TextAlignment" Value="Left"/>
        </Style>

    </Window.Resources>

    <!-- Conteneur principal avec marges -->
    <Grid Margin="10">
        <Grid.ColumnDefinitions>
            <!-- Colonne gauche : prend l'espace disponible -->
            <ColumnDefinition Width="715"/>
            <!-- Colonne droite : largeur fixe -->
            <ColumnDefinition Width="530"/>
        </Grid.ColumnDefinitions>

        <!-- ═══════════════════════════════════════════
             LEFT COLUMN
             3 rangées : hauteurs dynamiques
             Rangée 0 : s'étire pour remplir
             Rangée 1 : hauteur auto (contenu)
             Rangée 2 : hauteur auto (contenu)
        ═══════════════════════════════════════════ -->
        <Grid Grid.Column="0">
            <Grid.RowDefinitions>
                <!-- Rangée 0 : contrainte Min/Max, le reste va au ScrollViewer -->
                <RowDefinition Height="*" />
                <!-- Rangée 1 : prend tout l'espace restant -->
                <RowDefinition Height="Auto"/>
                <!-- Rangée 2 : hauteur selon contenu -->
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <!-- LEFT — Column 0 Row 0 - UEFI Certificate 2023 : -->
            <Grid Grid.Row="0">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>
                <StackPanel Orientation="Horizontal" Background="#FF3E8DDD" Height="26" Width="715">
                    <TextBlock Text="UEFI Certificate 2023 :" FontSize="18" FontWeight="SemiBold"
                        Foreground="White" Height="26" Padding="10,0,0,0" VerticalAlignment="Center"/>
                    <CheckBox x:Name="ChkShowGuid" Content="Show GUID" Foreground="White" FontSize="11"
                        VerticalAlignment="Center" Margin="20,0,0,0" IsChecked="False"/>
</StackPanel>
 <!--                <TextBlock Grid.Row="0" Text="UEFI Certificate 2023 :" Background="#FF3E8DDD" FontSize="18" FontWeight="SemiBold"   -->
 <!--                  Foreground="White" Height="26" Width="715" Padding="10,0,0,0" HorizontalAlignment="Left"/>   -->

                <ScrollViewer Grid.Row="1" Width="715" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
                    <WrapPanel >

                        <!-- PK Active -->
                        <StackPanel Orientation="Vertical">
                            <Label Content="PK Active (By OEM)" FontWeight="Bold" FontSize="12" Margin="0,0,0,-4" Foreground="BlueViolet"/>
                            <DataGrid x:Name="PK_Grid" 
          Style="{StaticResource DataGridStyle1}"
          Margin="0,0,8,0" 
          Width="335" >
                                <DataGrid.Columns>
                                    <DataGridTemplateColumn Header="Common Name (CN)" Width="205">
                                        <DataGridTemplateColumn.CellTemplate>
                                            <DataTemplate>
                                                <TextBlock Text="{Binding CN}" ToolTip="{Binding Tooltip}" TextTrimming="CharacterEllipsis" />
                                            </DataTemplate>
                                        </DataGridTemplateColumn.CellTemplate>
                                    </DataGridTemplateColumn>
                                    <DataGridTextColumn Header="Organization (O)" Binding="{Binding O}" Width="*"/>
                                </DataGrid.Columns>
                            </DataGrid>
                        </StackPanel>

                        <!-- PK Default -->
                        <StackPanel Orientation="Vertical">
                            <Label Content="PK Default (By OEM)" FontWeight="Bold" FontSize="12" Margin="10,0,0,-4" Foreground="BlueViolet"/>
                            <DataGrid x:Name="PKDefault_Grid" 
          Style="{StaticResource DataGridStyle1}"
          Margin="10,0,8,0" 
          Width="335" >
                                <DataGrid.Columns>
                                    <DataGridTemplateColumn Header="Common Name (CN)" Width="205">
                                        <DataGridTemplateColumn.CellTemplate>
                                            <DataTemplate>
                                                <TextBlock Text="{Binding CN}" ToolTip="{Binding Tooltip}" TextTrimming="CharacterEllipsis" />
                                            </DataTemplate>
                                        </DataGridTemplateColumn.CellTemplate>
                                    </DataGridTemplateColumn>
                                    <DataGridTextColumn Header="Organization (O)" Binding="{Binding O}" Width="*"/>
                                </DataGrid.Columns>
                            </DataGrid>
                        </StackPanel>

                        <!-- KEK Active -->
                        <StackPanel Orientation="Vertical">
                            <Label Content="KEK Active (By Microsoft)" FontWeight="Bold" FontSize="12" Margin="0,0,0,-4" Foreground="#FF3E8DDD"/>
                            <DataGrid x:Name="KEK_Grid" 
          Style="{StaticResource DataGridStyle1}"
          Margin="0,0,8,0" 
          Width="335" >
                                <DataGrid.Columns>
                                    <DataGridTemplateColumn Header="Common Name (CN)" Width="205">
                                        <DataGridTemplateColumn.CellTemplate>
                                            <DataTemplate>
                                                <TextBlock Text="{Binding CN}" ToolTip="{Binding Tooltip}" TextTrimming="CharacterEllipsis" />
                                            </DataTemplate>
                                        </DataGridTemplateColumn.CellTemplate>
                                    </DataGridTemplateColumn>
                                    <DataGridTextColumn Header="Organization (O)" Binding="{Binding O}" Width="*"/>
                                </DataGrid.Columns>
                            </DataGrid>
                        </StackPanel>

                        <!-- KEK Default -->
                        <StackPanel Orientation="Vertical">
                            <Label Content="KEK Default (By OEM)" FontWeight="Bold" FontSize="12" Margin="10,0,0,-4" Foreground="BlueViolet"/>
                            <DataGrid x:Name="KEKDefault_Grid" 
          Style="{StaticResource DataGridStyle1}"
          Margin="10,0,8,0" 
          Width="335" >
                                <DataGrid.Columns>
                                    <DataGridTemplateColumn Header="Common Name (CN)" Width="205">
                                        <DataGridTemplateColumn.CellTemplate>
                                            <DataTemplate>
                                                <TextBlock Text="{Binding CN}" ToolTip="{Binding Tooltip}" TextTrimming="CharacterEllipsis" />
                                            </DataTemplate>
                                        </DataGridTemplateColumn.CellTemplate>
                                    </DataGridTemplateColumn>
                                    <DataGridTextColumn Header="Organization (O)" Binding="{Binding O}" Width="*"/>
                                </DataGrid.Columns>
                            </DataGrid>
                        </StackPanel>

                        <!-- DB Active -->
                        <StackPanel Orientation="Vertical">
                            <Label Content="DB Active (By Microsoft)" FontWeight="Bold" FontSize="12" Margin="0,0,0,-4" Foreground="#FF3E8DDD"/>
                            <DataGrid x:Name="DB_Grid" 
         Style="{StaticResource DataGridStyle1}"
         Margin="0,0,8,0" 
         Width="335" >
                                <DataGrid.Columns>
                                    <DataGridTemplateColumn Header="Common Name (CN)" Width="205">
                                        <DataGridTemplateColumn.CellTemplate>
                                            <DataTemplate>
                                                <TextBlock Text="{Binding CN}" ToolTip="{Binding Tooltip}" TextTrimming="CharacterEllipsis" />
                                            </DataTemplate>
                                        </DataGridTemplateColumn.CellTemplate>
                                    </DataGridTemplateColumn>
                                    <DataGridTextColumn Header="Organization (O)" Binding="{Binding O}" Width="*"/>
                                </DataGrid.Columns>
                            </DataGrid>
                        </StackPanel>

                        <!-- DB Default -->
                        <StackPanel Orientation="Vertical">
                            <Label Content="DB Default (By OEM)" FontWeight="Bold" FontSize="12" Margin="10,0,0,-4" Foreground="BlueViolet"/>
                            <DataGrid x:Name="DBDefault_Grid" 
         Style="{StaticResource DataGridStyle1}"
         Margin="10,0,8,0" 
         Width="335" >
                                <DataGrid.Columns>
                                    <DataGridTemplateColumn Header="Common Name (CN)" Width="205">
                                        <DataGridTemplateColumn.CellTemplate>
                                            <DataTemplate>
                                                <TextBlock Text="{Binding CN}" ToolTip="{Binding Tooltip}" TextTrimming="CharacterEllipsis" />
                                            </DataTemplate>
                                        </DataGridTemplateColumn.CellTemplate>
                                    </DataGridTemplateColumn>
                                    <DataGridTextColumn Header="Organization (O)" Binding="{Binding O}" Width="*"/>
                                </DataGrid.Columns>
                            </DataGrid>
                        </StackPanel>

                        <!-- DBX Active -->
                        <StackPanel Orientation="Vertical">
                            <Label Content="DBX Active (By Microsoft)" FontWeight="Bold" FontSize="12" Margin="0,0,0,-4" Foreground="DarkBlue"/>
                            <DataGrid x:Name="DBX_Grid" 
         Style="{StaticResource DataGridStyle1}"
         Margin="0,0,8,0" 
         Width="335" >
                                <DataGrid.Columns>
                                    <DataGridTemplateColumn Header="Common Name (CN)" Width="205">
                                        <DataGridTemplateColumn.CellTemplate>
                                            <DataTemplate>
                                                <TextBlock Text="{Binding CN}" ToolTip="{Binding Tooltip}" TextTrimming="CharacterEllipsis" />
                                            </DataTemplate>
                                        </DataGridTemplateColumn.CellTemplate>
                                    </DataGridTemplateColumn>
                                    <DataGridTextColumn Header="Organization (O)" Binding="{Binding O}" Width="*"/>
                                </DataGrid.Columns>
                            </DataGrid>
                        </StackPanel>

                        <!-- DBX Default -->
                        <StackPanel Orientation="Vertical">
                            <Label Content="DBX Default (By OEM)" FontWeight="Bold" FontSize="12" Margin="10,0,0,-4" Foreground="DarkMagenta"/>
                            <DataGrid x:Name="DBXDefault_Grid" 
         Style="{StaticResource DataGridStyle1}"
         Margin="10,0,8,0" 
         Width="335" >
                                <DataGrid.Columns>
                                    <DataGridTemplateColumn Header="Common Name (CN)" Width="205">
                                        <DataGridTemplateColumn.CellTemplate>
                                            <DataTemplate>
                                                <TextBlock Text="{Binding CN}" ToolTip="{Binding Tooltip}" TextTrimming="CharacterEllipsis" />
                                            </DataTemplate>
                                        </DataGridTemplateColumn.CellTemplate>
                                    </DataGridTemplateColumn>
                                    <DataGridTextColumn Header="Organization (O)" Binding="{Binding O}" Width="*"/>
                                </DataGrid.Columns>
                            </DataGrid>
                        </StackPanel>

                    </WrapPanel>


                </ScrollViewer>
            </Grid>

            <!-- LEFT — Column 0 Row 1 - Registry : -->
            <WrapPanel Margin="0,0,0,10" Grid.Row="1"  >
                <TextBlock Text="Registry : " Background="#FF3E8DDD" FontSize="18" FontWeight="SemiBold"
                    Foreground="White" Height="26" Width="715" Padding="10,0,0,0" HorizontalAlignment="Left"/>
                <WrapPanel x:Name="Reg1" Orientation="Horizontal" VerticalAlignment="Center" Margin="0,2,0,0" Width="715">
                    <TextBlock Text="AvailableUpdates :" FontSize="10" FontWeight="SemiBold"  Width="145" 
                        Foreground="#FF324873" VerticalAlignment="Center" Margin="0,0,5,0" TextAlignment="Right"/>
                    <TextBlock x:Name="Reg1_HexValue" Text="" FontSize="10" FontWeight="Bold"
                        Foreground="Black" VerticalAlignment="Center" Margin="0,0,0,0" Width="40"/>
                    <TextBlock x:Name="Reg1_Description" Text="" FontSize="10" TextAlignment="Left"
                        Foreground="Black" VerticalAlignment="Center" Width="525" />
                </WrapPanel>
                <WrapPanel x:Name="Reg5" Orientation="Horizontal" Margin="0,2,0,0" Width="715">
                    <TextBlock Text="ConfidenceLevel :" FontSize="10" FontWeight="SemiBold" Width="145"
                        Foreground="#FF324873" VerticalAlignment="Top" Margin="0,0,5,0" TextAlignment="Right"/>
                    <TextBlock x:Name="Reg5_Value" Text="" FontSize="10" FontWeight="Bold"
                        Foreground="Black" VerticalAlignment="Center" Width="200"
                        ToolTipService.ShowDuration="30000" ToolTipService.InitialShowDelay="0" >
                        <TextBlock.ToolTip>
                            <TextBlock x:Name="Reg5_Description" Text="" FontSize="10" 
                            TextWrapping="Wrap" MaxWidth="400"/>
                        </TextBlock.ToolTip>
                    </TextBlock>
                    <WrapPanel x:Name="Reg2" Orientation="Horizontal" VerticalAlignment="Center" Margin="0,2,0,0"  Width="715">
                        <TextBlock Text="UEFICA2023Status :" FontSize="10" FontWeight="SemiBold" Width="145" 
                        Foreground="#FF324873" VerticalAlignment="Center" Margin="0,0,5,0" TextAlignment="Right"/>
                        <TextBlock x:Name="Reg2_Value" Text="" FontSize="10" FontWeight="Bold"
                        Foreground="Black" VerticalAlignment="Center" Margin="0,0,0,0" Width="55"/>
                        <TextBlock x:Name="Reg2_Icon" Text="" FontSize="12" TextAlignment="Center" 
                        VerticalAlignment="Center" Margin="0,-5,5,0" Width="17"  FontWeight="ExtraBlack" />
                        <TextBlock x:Name="Reg2_Description" Text="" FontSize="10" TextAlignment="Left"
                        Foreground="Black" VerticalAlignment="Center" Width="488" />
                    </WrapPanel>
                    <WrapPanel x:Name="Reg3" Orientation="Horizontal" VerticalAlignment="Center" Margin="0,2,0,0"  Width="715">
                        <TextBlock Text="WindowsUEFICA2023Capable :" FontSize="10" FontWeight="SemiBold" Width="145" 
                        Foreground="#FF324873" VerticalAlignment="Center" Margin="0,0,5,0" TextAlignment="Right"/>
                        <TextBlock x:Name="Reg3_HexValue" Text="" FontSize="10" FontWeight="Bold"
                        Foreground="Black" VerticalAlignment="Center" Margin="0,0,0,0" Width="55"/>
                        <TextBlock x:Name="Reg3_Icon" Text="" FontSize="12" TextAlignment="Center" 
                        VerticalAlignment="Center" Margin="0,-4,5,0" Width="17" FontWeight="Bold"/>
                        <TextBlock x:Name="Reg3_Description" Text="" FontSize="10" TextAlignment="Left"
                        Foreground="Black" VerticalAlignment="Center" Width="488" />
                    </WrapPanel>
                    <WrapPanel x:Name="Reg4" Orientation="Horizontal" VerticalAlignment="Top" Margin="0,2,0,0" MinWidth="700" Width="715">
                        <TextBlock Text="UEFICA2023ErrorEvent :" FontSize="10" FontWeight="SemiBold" Width="145"
                        Foreground="#FF324873" VerticalAlignment="Center" Margin="0,0,5,0" TextAlignment="Right"/>
                        <TextBlock x:Name="Reg4_DecValue" Text="" FontSize="10" FontWeight="Bold"
                        Foreground="Black" VerticalAlignment="Center" Width="55"/>
                        <TextBlock x:Name="Reg4_Icon" Text="" FontSize="12" TextAlignment="Center" 
                        VerticalAlignment="Center" Margin="0,-4,5,0" Width="17" FontWeight="Bold"/>
                    </WrapPanel>

                </WrapPanel>




            </WrapPanel>

            <!-- LEFT — Column 0 Row 2 - Event Viewer : -->
            <WrapPanel Margin="0,0,0,0" Grid.Row="2" >
                <WrapPanel Orientation="Horizontal" Width="715" Height="26"  Background="#FF3E8DDD" >
                    <TextBlock Text="Event Viewer : " FontSize="18" FontWeight="SemiBold"
                        Foreground="White" Height="26" Width="140" Padding="10,0,0,0" HorizontalAlignment="Center"/>
                    <TextBlock Text="Check TPM-WMI Event ID Error, ID 1808 (1799, 1801, 1802 and 1803 if exists)" Background="#FF3E8DDD" FontSize="11" FontWeight="SemiBold"
                        Foreground="White" Height="26" Width="571" Padding="0,8,0,0" HorizontalAlignment="Center"/>


                </WrapPanel>
                <WrapPanel Orientation="Horizontal" Margin="5,5,0,0"    Width="710"    Background="#443E8DDD">
                    <TextBlock x:Name="Event_Title"     Text="Event ID" FontSize="11"   FontWeight="SemiBold" Width="50"  Foreground="#FF324873"    Margin="0,0,0,0" TextAlignment="Center"/>
                    <TextBlock x:Name="Event_Status"    Text=""         FontSize="11"   FontWeight="SemiBold" Width="55"  Foreground="#FF324873"    Margin="0,0,0,0" TextAlignment="Center"/>
                    <TextBlock x:Name="Event_Icon"      Text=""         FontSize="11"   FontWeight="SemiBold" Width="30"  Foreground="#FF324873"    Margin="0,0,5,0" TextAlignment="Center"/>
                    <TextBlock x:Name="Event_Message"   Text="Message"  FontSize="11"   FontWeight="SemiBold" Width="565" Foreground="#FF324873" TextAlignment="Left" HorizontalAlignment="Right" />
                </WrapPanel>
                <WrapPanel Orientation="Horizontal" Margin="5,0,0,0"    Width="710"     x:Name="WrapPanel_ErrorEvent" Visibility="Collapsed">
                    <TextBlock x:Name="Error_Num"       Text="ERR N°"   FontSize="11"   FontWeight="SemiBold" Width="50"  Foreground="#FF324873"    Margin="0,0,0,0" TextAlignment="Center"/>
                    <TextBlock x:Name="Error_Status"    Text="???"      FontSize="11"   FontWeight="SemiBold" Width="55"  Foreground="Black"        Margin="0,0,0,0" TextAlignment="Center"/>
                    <TextBlock x:Name="Error_Icon"      Text=""         FontSize="11"   FontWeight="SemiBold" Width="30"  Foreground="Black"        Margin="0,0,5,0" TextAlignment="Center"/>
                    <TextBlock x:Name="Error_Message"   Text=""         FontSize="10"   FontWeight="SemiBold" Width="565" Foreground="Black"    TextAlignment="Left" TextWrapping="Wrap" />
                </WrapPanel>
                <WrapPanel Orientation="Horizontal" Margin="5,0,0,0"    Width="710"     x:Name="WrapPanel_1799" Visibility="Collapsed">
                    <TextBlock x:Name="_1799_Num"       Text="1799"     FontSize="11"   FontWeight="SemiBold" Width="50"  Foreground="Gray"    Margin="0,0,0,0" TextAlignment="Center"/>
                    <TextBlock x:Name="_1799_Status"    Text=""         FontSize="09"   FontWeight="SemiBold" Width="85"  Foreground="Gray"        Margin="0,2,5,0" TextAlignment="Center"/>
                    <TextBlock x:Name="_1799_Message"   Text=""         FontSize="10"   FontWeight="SemiBold" Width="565" Foreground="Gray"    TextAlignment="Left" TextWrapping="Wrap" />
                </WrapPanel>
                <WrapPanel Orientation="Horizontal" Margin="5,0,0,0"    Width="710"     x:Name="WrapPanel_1801" Visibility="Collapsed">
                    <TextBlock x:Name="_1801_Num"       Text="1801"     FontSize="11"   FontWeight="SemiBold" Width="50"  Foreground="Gray"    Margin="0,0,0,0" TextAlignment="Center"/>
                    <TextBlock x:Name="_1801_Status"    Text=""         FontSize="09"   FontWeight="SemiBold" Width="85"  Foreground="Gray"        Margin="0,2,5,0" TextAlignment="Center"/>
                    <TextBlock x:Name="_1801_Message"   Text=""         FontSize="10"   FontWeight="SemiBold" Width="565" Foreground="Gray"    TextAlignment="Left" TextWrapping="Wrap" />
                </WrapPanel>
                <WrapPanel Orientation="Horizontal" Margin="5,0,0,0"    Width="710"     x:Name="WrapPanel_1802" Visibility="Collapsed">
                    <TextBlock x:Name="_1802_Num"       Text="1802"     FontSize="11"   FontWeight="SemiBold" Width="50"  Foreground="Gray"    Margin="0,0,0,0" TextAlignment="Center"/>
                    <TextBlock x:Name="_1802_Status"    Text=""         FontSize="09"   FontWeight="SemiBold" Width="85"  Foreground="Gray"        Margin="0,2,5,0" TextAlignment="Center"/>
                    <TextBlock x:Name="_1802_Message"   Text=""         FontSize="10"   FontWeight="SemiBold" Width="565" Foreground="Gray"    TextAlignment="Left" TextWrapping="Wrap" />
                </WrapPanel>
                <WrapPanel Orientation="Horizontal" Margin="5,0,0,0"    Width="710"     x:Name="WrapPanel_1803" Visibility="Collapsed">
                    <TextBlock x:Name="_1803_Num"       Text="1803"     FontSize="11"   FontWeight="SemiBold" Width="50"  Foreground="Gray"    Margin="0,0,0,0" TextAlignment="Center"/>
                    <TextBlock x:Name="_1803_Status"    Text=""         FontSize="09"   FontWeight="SemiBold" Width="85"  Foreground="Gray"        Margin="0,2,5,0" TextAlignment="Center"/>
                    <TextBlock x:Name="_1803_Message"   Text=""         FontSize="10"   FontWeight="SemiBold" Width="565" Foreground="Gray"    TextAlignment="Left" TextWrapping="Wrap" />
                </WrapPanel>
                <WrapPanel Orientation="Horizontal" Margin="5,0,0,0"    Width="710"     x:Name="WrapPanel_1808" Visibility="Visible">
                    <TextBlock x:Name="_1808_Num"       Text="1808"     FontSize="11"   FontWeight="SemiBold" Width="50"  Foreground="#FF324873"    Margin="0,0,0,0" TextAlignment="Center"/>
                    <TextBlock x:Name="_1808_Status"    Text=""         FontSize="11"   FontWeight="SemiBold" Width="55"  Foreground="Black"        Margin="0,0,0,0" TextAlignment="Center"/>
                    <TextBlock x:Name="_1808_Icon"      Text=""         FontSize="11"   FontWeight="SemiBold" Width="30"  Foreground="Black"        Margin="0,0,5,0" TextAlignment="Center"/>
                    <TextBlock x:Name="_1808_Message"   Text=""         FontSize="10"   FontWeight="SemiBold" Width="565" Foreground="Black"    TextAlignment="Left" TextWrapping="Wrap" />
                </WrapPanel>
            </WrapPanel>

        </Grid>




        <!-- ═══════════════════════════════════════════
             COLUMN 2
             3 rangées à hauteur fixe ou auto selon contenu
        ═══════════════════════════════════════════ -->
        <Grid Grid.Column="1" Margin="9,0,0,0">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="250"/>
                <ColumnDefinition Width="270"/>
            </Grid.ColumnDefinitions>
            <Grid.RowDefinitions>
                <RowDefinition Height="55" />
                <RowDefinition Height="*" MinHeight="200" />
                <RowDefinition Height="*" MinHeight="280" />
                <RowDefinition Height="*" MaxHeight="110" />
            </Grid.RowDefinitions>

            <!-- Mid — Row 0 Column 0 - Logo -->
            <Border Grid.Row="0" Grid.Column="0" Background="#1A2B4A" Width="225" Margin="0,0,0,0" CornerRadius="8" >
                <Canvas Width="220" Height="55" >
                    <!-- Shield -->
                    <Path Data="M25,6 L43,12 L43,26 C43,36 35,44 25,48 C15,44 7,36 7,26 L7,12 Z"
                        Fill="#2E86DE" Stroke="#5BA3F5" StrokeThickness="3" />
                    <!-- Checkmark -->
                    <Polyline Points="18,25 25,35 35,17" Fill="Transparent" Stroke="#01D210" StrokeThickness="6"
                        StrokeStartLineCap="Round" StrokeEndLineCap="Round" StrokeLineJoin="Round" />
                    <!-- Check -->
                    <TextBlock Canvas.Left="60" Canvas.Top="1" Text="Check" FontFamily="Segoe UI" FontSize="20"
                        FontWeight="Bold" Foreground="White" />
                    <!-- CA -->
                    <TextBlock Canvas.Left="119" Canvas.Top="1" Text="CA" FontFamily="Segoe UI" FontSize="20"
                        FontWeight="Bold" Foreground="#2E86DE" />
                    <!-- 2023 -->
                    <TextBlock Canvas.Left="146" Canvas.Top="1" Text="2023" FontFamily="Segoe UI" FontSize="20"
                        FontWeight="Bold" Foreground="#5BA3F5" />
                    <!-- Subtitle -->
                    <TextBlock Canvas.Left="61" Canvas.Top="26" Text="UEFI Certificate Monitor" FontFamily="Segoe UI"
                        FontSize="9" Foreground="#8AAFD4" />
                    <!-- Version -->
                    <TextBlock Canvas.Left="61" Canvas.Top="38" Text="Version : 1.5.0" FontFamily="Segoe UI"
                        FontSize="10" FontWeight="Bold" Foreground="#8AAFD4" />
                </Canvas>
            </Border>
            <!-- Mid — Row 1 Column 0 - Configuration -->
            <WrapPanel Grid.Row="1" Grid.Column="0" Margin="0,15,0,0" >
                <TextBlock Text="Configuration : " Background="#FF3E8DDD" FontSize="18" FontWeight="SemiBold"
                       Foreground="White" Height="26" Width="240" Padding="10,0,0,0" HorizontalAlignment="Left"/>
                <Border Width="240" BorderThickness="1.5" BorderBrush="Gray" Background="#66D0D0D0" CornerRadius="0" Margin="0,5,0,0">
                    <WrapPanel Orientation="Horizontal" HorizontalAlignment="Left" Margin="5,0,0,0" >
                        <TextBox x:Name="WinVer" Width="230" FontWeight="SemiBold" Margin="-3,2,0,2" Text="Windows 11 Pro 24H2"
                                FontSize="12" Padding="0,0,0,0" IsReadOnly="True" BorderThickness="0"
                                Background="Transparent" IsTabStop="False" />
                        <StackPanel Orientation="Horizontal" Margin="0,0,0,0" HorizontalAlignment="Left">
                            <TextBlock FontWeight="SemiBold" Text="Build : " Margin="2,0,0,0" FontSize="12" Padding="0,4,0,4" />
                            <TextBox x:Name="WinBuild" FontWeight="SemiBold" Text="xxxx.yyyy" HorizontalContentAlignment="Center"
                                    FontSize="12" IsReadOnly="True" BorderThickness="0.5" Background="#EEE" IsTabStop="False"
                                    Margin="0,0,2,2" Padding="2,0,2,0" Height="18" />                            
                            <TextBlock x:Name="IcoBuild"    Text="✔" FontSize="14" Margin="0,0,5,0" Width="20" />
                            <TextBlock x:Name="MinBuildTxt" Text="Minimum Build" FontWeight="SemiBold" FontSize="12"
                                       Background="Transparent" Foreground="DarkRed" Margin="0,0,0,0" Height="18" Padding="0,4,0,0" />
                        </StackPanel>

                        <StackPanel Orientation="Horizontal" Margin="0,0,0,0" HorizontalAlignment="Left">
                            <TextBlock Text="Secure Boot : " Width="75" FontSize="12" Margin="2,0,0,2"  FontWeight="SemiBold" TextAlignment="Right" />
                            <TextBlock x:Name="tbSecureBoot"    Text="✔" FontSize="14" Margin="0,-4,0,2" Width="20" />
                            <TextBlock x:Name="MinBuildValue" Text="26100.6060" FontWeight="SemiBold" FontSize="12"
                                       Background="Transparent" Foreground="DarkRed" Margin="48,0,0,0" Height="18" Padding="0,0,0,0" />
                        </StackPanel>

                        <StackPanel Orientation="Horizontal" Margin="0,0,0,0" HorizontalAlignment="Left">
                            <TextBlock Text="BitLocker : " Width="75" FontSize="12" Margin="2,0,0,2"
                                    FontWeight="SemiBold" TextAlignment="Right" />
                            <TextBlock x:Name="BitLockerIcon" Width="16" FontSize="14" Margin="2,-5,0,2"
                                        FontWeight="SemiBold" TextAlignment="Center" />
                            <TextBlock x:Name="BitLockerStatus" Width="110" FontSize="12" Margin="10,0,0,2"
                                        FontWeight="SemiBold" TextAlignment="Left" />
                        </StackPanel>

                        <Border Width="200" BorderThickness="0,1.5,0,0" BorderBrush="Gray" Margin="15,3,0,3" />

                        <Grid Margin="0,0,0,0"  >
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="76"/>
                                <ColumnDefinition Width="155"/>
                            </Grid.ColumnDefinitions>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                            </Grid.RowDefinitions>

                            <TextBlock Grid.Column="0" Grid.Row="0" Text="System Family :"  FontSize="11"
                           Background="Transparent" HorizontalAlignment="Right" />
                            <TextBlock x:Name="SystemFamily" Grid.Column="1" Grid.Row="0" FontSize="11"
                           Margin="5,0,0,0" Background="Transparent" FontWeight="SemiBold"/>

                            <TextBlock Grid.Column="0" Grid.Row="1" Text="Model :"  FontSize="11"
                           Background="Transparent" HorizontalAlignment="Right" />
                            <TextBlock x:Name="MachineType" Grid.Column="1" Grid.Row="1" FontSize="11"
                           Margin="5,0,0,0" Background="Transparent" FontWeight="SemiBold"/>

                            <TextBlock Grid.Column="0" Grid.Row="2" Text="Bios Ver. :"  FontSize="11"
                           Background="Transparent" HorizontalAlignment="Right" />
                            <TextBlock x:Name="BiosVer" Grid.Column="1" Grid.Row="2" FontSize="11"
                           Margin="5,0,0,0" Background="Transparent" FontWeight="SemiBold"/>

                            <TextBlock Grid.Column="0" Grid.Row="3" Text="Bios Date :"  FontSize="11"
                           Background="Transparent" HorizontalAlignment="Right" Margin="0,0,0,3" />
                            <TextBlock x:Name="BiosDate" Grid.Column="1" Grid.Row="3" FontSize="11"
                           Margin="5,0,0,3" Background="Transparent" FontWeight="SemiBold"/>


                        </Grid>
                    </WrapPanel>


                </Border>

            </WrapPanel>
            <!-- Mid — Row 2 Column 0 - Command -->
            <WrapPanel Grid.Row="2" Grid.Column="0" Margin="0,0,0,0"  >
                <TextBlock Text="Command : " Background="#FF3E8DDD" FontSize="18" FontWeight="SemiBold"
                       Foreground="White" Height="26" Width="240" Padding="10,0,0,0" HorizontalAlignment="Left"/>
                <Button x:Name="btnExecute" Content="Check" Style="{StaticResource ConfirmBoxButton}" Margin="10,10,0,15" />
                <Button x:Name="btnMore" Content="LESS" Style="{StaticResource ButtonStyle}" Margin="15,24,0,15"
                        FontWeight="Bold" FontSize="14" Width="55" Height="36" />

                <Button x:Name="Set_Reg_To"     Content="▼  Set AvailableUpdates to  ▼"
                        Margin="10,0,0,3" Width="210" Height="24" FontWeight="SemiBold" FontSize="13" Style="{StaticResource ButtonStyle}"  />

                <ComboBox x:Name="Set_Reg_ComboBox" Width="210" Height="24" Margin="10,0,0,10"
                            FontSize="11" FontWeight="SemiBold" Foreground="#FF324873"/>

                <Button x:Name="Start_Task"     Content="Start &quot;Secure-Boot-Update&quot; Task"
                        Margin="10,0,0,10" Width="210" Height="24" FontWeight="SemiBold" FontSize="13" Style="{StaticResource ButtonStyle}"  />
                <Button x:Name="Log_CSV"       Content="Create/Append logs to CSV"
                        Margin="10,0,0,0" Width="210" Height="24" FontWeight="SemiBold" FontSize="13" Style="{StaticResource ButtonStyle}"  />
            </WrapPanel>
            <!-- Mid — Row 3 Column 0 - Status -->
            <Border Grid.Row="3" Grid.Column="0" Grid.ColumnSpan="2" x:Name="BorderStatus" VerticalAlignment="Bottom" HorizontalAlignment="Left" Margin="5,0,0,0" Width="515" 
                    Background="#F0F0F0" CornerRadius="12" BorderBrush="#FF324873" BorderThickness="2" Height="65" >
                <StackPanel Orientation="Vertical" Margin="0,0,-17,0" >
                    <Border Grid.Row="3" x:Name="BorderTitleStatus"     Width="120" Margin="15,-13,0,0" HorizontalAlignment="Left" Background="#FF324873" CornerRadius="12" BorderBrush="#FF324873" BorderThickness="0" >
                        <TextBlock x:Name="TitleStatus" Text="Status :" Width="90" Foreground="#F0F0F0" FontWeight="Bold" FontSize="20" Margin="0,-3,0,0" Padding="0,0,0,1" />
                    </Border>
                    <TextBlock x:Name="TxtStatus" Text="Data retrieval completed successfully" Foreground="#FF324873"  FontSize="16" 
                           FontWeight="Bold" Padding="0,3,0,0" Margin="5,0,5,0" TextWrapping="Wrap"  />
                </StackPanel>
            </Border>


            <!-- ══════ COLUMN 2 ═══════════════════════════════════════════ -->

            <!-- More —  Row 3 Column 0 - Status -->
            <WrapPanel Grid.Row="0" Grid.Column="1" Grid.RowSpan="3" Margin="5,1,0,0" >
                <TextBlock Text="AvailableUpdates details : " Background="#FF3E8DDD" FontSize="16" FontWeight="SemiBold"
                       Foreground="White" Height="26" Width="255" Padding="10,2,0,0" HorizontalAlignment="Left"/>
                <StackPanel  Orientation="Vertical" Margin="0,5,0,0" Width="255" >

                    <Grid x:Name="GridBits">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="45"/>
                            <ColumnDefinition Width="25"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>

                        <Grid.RowDefinitions>
                            <RowDefinition Height="16"/>
                            <RowDefinition Height="16"/>
                            <RowDefinition Height="16"/>
                            <RowDefinition Height="16"/>
                            <RowDefinition Height="16"/>
                            <RowDefinition Height="16"/>
                            <RowDefinition Height="16"/>
                            <RowDefinition Height="16"/>
                            <RowDefinition Height="16"/>
                            <RowDefinition Height="16"/>
                            <RowDefinition Height="16"/>
                            <RowDefinition Height="16"/>
                            <RowDefinition Height="16"/>
                            <RowDefinition Height="16"/>
                            <RowDefinition Height="16"/>
                        </Grid.RowDefinitions>

                        <!-- ═══ HEADER ═══ -->
                        <TextBlock Grid.Row="0" Grid.Column="0" Text="Bit"         Style="{StaticResource ColHeaderBitStyle}"/>
                        <TextBlock Grid.Row="0" Grid.Column="1" Text="#"           Style="{StaticResource ColHeaderOrdStyle}"/>
                        <TextBlock Grid.Row="0" Grid.Column="2" Text="Designation" Style="{StaticResource ColHeaderDesignationStyle}"/>

                        <!-- ═══ 0x0002 ═══ -->
                        <TextBlock x:Name="Bit0002_Hex"  Grid.Row="1" Grid.Column="0" Style="{StaticResource ColBitStyle}"         Text="0x0002"/>
                        <TextBlock x:Name="Bit0002_Ord"  Grid.Row="1" Grid.Column="1" Style="{StaticResource ColOrdStyle}"         Text=""/>
                        <TextBlock x:Name="Bit0002_Name" Grid.Row="1" Grid.Column="2" Style="{StaticResource ColDesignationStyle}"
                   Text="DBX update (apply latest revocations)">
                            <TextBlock.ToolTip>
                                <ToolTip Style="{StaticResource BitToolTipStyle}">
                                    <StackPanel>
                                        <TextBlock Text="DBX update (apply latest revocations)" FontWeight="Bold" FontSize="10" Margin="0,0,0,4"/>
                                        <TextBlock Text="Applies the latest DBX revocations to the Secure Boot forbidden signatures database." FontSize="10" TextWrapping="Wrap"/>
                                    </StackPanel>
                                </ToolTip>
                            </TextBlock.ToolTip>
                        </TextBlock>

                        <!-- ═══ 0x0004 ═══ -->
                        <TextBlock x:Name="Bit0004_Hex"  Grid.Row="2" Grid.Column="0" Style="{StaticResource ColBitStyle}"         Text="0x0004"/>
                        <TextBlock x:Name="Bit0004_Ord"  Grid.Row="2" Grid.Column="1" Style="{StaticResource ColOrdStyle}"         Text="4"/>
                        <TextBlock x:Name="Bit0004_Name" Grid.Row="2" Grid.Column="2" Style="{StaticResource ColDesignationStyle}"
                   Text="Microsoft Corp. KEK 2K CA 2023 update">
                            <TextBlock.ToolTip>
                                <ToolTip Style="{StaticResource BitToolTipStyle}">
                                    <StackPanel>
                                        <TextBlock Text="Microsoft Corp. KEK 2K CA 2023 update" FontWeight="Bold" FontSize="10" Margin="0,0,0,4"/>
                                        <TextBlock Text="Adds the Microsoft Corporation KEK 2K CA 2023 to the KEK store. Requires an OEM-signed KEK, delivered via cumulative updates and validated against the device's Platform Key (PK) managed by the OEM." FontSize="10" TextWrapping="Wrap"/>
                                    </StackPanel>
                                </ToolTip>
                            </TextBlock.ToolTip>
                        </TextBlock>

                        <!-- ═══ 0x0008 ═══ -->
                        <TextBlock x:Name="Bit0008_Hex"  Grid.Row="3" Grid.Column="0" Style="{StaticResource ColBitStyle}"         Text="0x0008"/>
                        <TextBlock x:Name="Bit0008_Ord"  Grid.Row="3" Grid.Column="1" Style="{StaticResource ColOrdStyle}"         Text=""/>
                        <TextBlock x:Name="Bit0008_Name" Grid.Row="3" Grid.Column="2" Style="{StaticResource ColDesignationStyle}"
                   Text="Unknown">
                            <TextBlock.ToolTip>
                                <ToolTip Style="{StaticResource BitToolTipStyle}">
                                    <StackPanel>
                                        <TextBlock Text="Unknown" FontWeight="Bold" FontSize="10" Margin="0,0,0,4"/>
                                        <TextBlock Text="Undocumented bit." FontSize="10" TextWrapping="Wrap"/>
                                    </StackPanel>
                                </ToolTip>
                            </TextBlock.ToolTip>
                        </TextBlock>

                        <!-- ═══ 0x0010 ═══ -->
                        <TextBlock x:Name="Bit0010_Hex"  Grid.Row="4" Grid.Column="0" Style="{StaticResource ColBitStyle}"         Text="0x0010"/>
                        <TextBlock x:Name="Bit0010_Ord"  Grid.Row="4" Grid.Column="1" Style="{StaticResource ColOrdStyle}"         Text=""/>
                        <TextBlock x:Name="Bit0010_Name" Grid.Row="4" Grid.Column="2" Style="{StaticResource ColDesignationStyle}"
                   Text="Unknown">
                            <TextBlock.ToolTip>
                                <ToolTip Style="{StaticResource BitToolTipStyle}">
                                    <StackPanel>
                                        <TextBlock Text="Unknown" FontWeight="Bold" FontSize="10" Margin="0,0,0,4"/>
                                        <TextBlock Text="Undocumented bit." FontSize="10" TextWrapping="Wrap"/>
                                    </StackPanel>
                                </ToolTip>
                            </TextBlock.ToolTip>
                        </TextBlock>

                        <!-- ═══ 0x0020 ═══ -->
                        <TextBlock x:Name="Bit0020_Hex"  Grid.Row="5" Grid.Column="0" Style="{StaticResource ColBitStyle}"         Text="0x0020"/>
                        <TextBlock x:Name="Bit0020_Ord"  Grid.Row="5" Grid.Column="1" Style="{StaticResource ColOrdStyle}"         Text=""/>
                        <TextBlock x:Name="Bit0020_Name" Grid.Row="5" Grid.Column="2" Style="{StaticResource ColDesignationStyle}"
                   Text="SkuSiPolicy update (VBS anti-rollback)">
                            <TextBlock.ToolTip>
                                <ToolTip Style="{StaticResource BitToolTipStyle}">
                                    <StackPanel>
                                        <TextBlock Text="SkuSiPolicy update" FontWeight="Bold" FontSize="10" Margin="0,0,0,4"/>
                                        <TextBlock Text="Applies the Microsoft-signed revocation policy (SkuSiPolicy.p7b) for VBS (Virtualization-based Security) anti-rollback protection." FontSize="10" TextWrapping="Wrap"/>
                                    </StackPanel>
                                </ToolTip>
                            </TextBlock.ToolTip>
                        </TextBlock>

                        <!-- ═══ 0x0040 ═══ -->
                        <TextBlock x:Name="Bit0040_Hex"  Grid.Row="6" Grid.Column="0" Style="{StaticResource ColBitStyle}"         Text="0x0040"/>
                        <TextBlock x:Name="Bit0040_Ord"  Grid.Row="6" Grid.Column="1" Style="{StaticResource ColOrdStyle}"         Text="1"/>
                        <TextBlock x:Name="Bit0040_Name" Grid.Row="6" Grid.Column="2" Style="{StaticResource ColDesignationStyle}"
                   Text="Windows UEFI CA 2023 &#x2192; DB">
                            <TextBlock.ToolTip>
                                <ToolTip Style="{StaticResource BitToolTipStyle}">
                                    <StackPanel>
                                        <TextBlock Text="Windows UEFI CA 2023 &#x2192; DB" FontWeight="Bold" FontSize="10" Margin="0,0,0,4"/>
                                        <TextBlock Text="Adds the Windows UEFI CA 2023 certificate to the Secure Boot DB, allowing Windows to trust boot managers signed by this certificate." FontSize="10" TextWrapping="Wrap"/>
                                    </StackPanel>
                                </ToolTip>
                            </TextBlock.ToolTip>
                        </TextBlock>

                        <!-- ═══ 0x0080 ═══ -->
                        <TextBlock x:Name="Bit0080_Hex"  Grid.Row="7" Grid.Column="0" Style="{StaticResource ColBitStyle}"         Text="0x0080"/>
                        <TextBlock x:Name="Bit0080_Ord"  Grid.Row="7" Grid.Column="1" Style="{StaticResource ColOrdStyle}"         Text=""/>
                        <TextBlock x:Name="Bit0080_Name" Grid.Row="7" Grid.Column="2" Style="{StaticResource ColDesignationStyle}"
                   Text="Windows Production PCA 2011 &#x2192; DBX">
                            <TextBlock.ToolTip>
                                <ToolTip Style="{StaticResource BitToolTipStyle}">
                                    <StackPanel>
                                        <TextBlock Text="Windows Production PCA 2011 &#x2192; DBX" FontWeight="Bold" FontSize="10" Margin="0,0,0,4"/>
                                        <TextBlock Text="Adds the Microsoft Windows Production PCA 2011 certificate to the DBX, revoking trust in the older boot manager signing chain." FontSize="10" TextWrapping="Wrap"/>
                                    </StackPanel>
                                </ToolTip>
                            </TextBlock.ToolTip>
                        </TextBlock>

                        <!-- ═══ 0x0100 ═══ -->
                        <TextBlock x:Name="Bit0100_Hex"  Grid.Row="8" Grid.Column="0" Style="{StaticResource ColBitStyle}"         Text="0x0100"/>
                        <TextBlock x:Name="Bit0100_Ord"  Grid.Row="8" Grid.Column="1" Style="{StaticResource ColOrdStyle}"         Text="5"/>
                        <TextBlock x:Name="Bit0100_Name" Grid.Row="8" Grid.Column="2" Style="{StaticResource ColDesignationStyle}"
                   Text="Apply boot manager with UEFI CA 2023">
                            <TextBlock.ToolTip>
                                <ToolTip Style="{StaticResource BitToolTipStyle}">
                                    <StackPanel>
                                        <TextBlock Text="Apply boot manager with UEFI CA 2023" FontWeight="Bold" FontSize="10" Margin="0,0,0,4"/>
                                        <TextBlock Text="Replaces the current boot manager (signed by Windows PCA 2011) with a new one signed by Windows UEFI CA 2023." FontSize="10" TextWrapping="Wrap"/>
                                    </StackPanel>
                                </ToolTip>
                            </TextBlock.ToolTip>
                        </TextBlock>

                        <!-- ═══ 0x0200 ═══ -->
                        <TextBlock x:Name="Bit0200_Hex"  Grid.Row="9" Grid.Column="0" Style="{StaticResource ColBitStyle}"         Text="0x0200"/>
                        <TextBlock x:Name="Bit0200_Ord"  Grid.Row="9" Grid.Column="1" Style="{StaticResource ColOrdStyle}"         Text=""/>
                        <TextBlock x:Name="Bit0200_Name" Grid.Row="9" Grid.Column="2" Style="{StaticResource ColDesignationStyle}"
                   Text="SVN firmware update">
                            <TextBlock.ToolTip>
                                <ToolTip Style="{StaticResource BitToolTipStyle}">
                                    <StackPanel>
                                        <TextBlock Text="SVN firmware update" FontWeight="Bold" FontSize="10" Margin="0,0,0,4"/>
                                        <TextBlock Text="Increments the Secure Version Number (SVN) in counter in UEFI/Secure Boot firmware, preventing rollback to older boot managers." FontSize="10" TextWrapping="Wrap"/>
                                    </StackPanel>
                                </ToolTip>
                            </TextBlock.ToolTip>
                        </TextBlock>

                        <!-- ═══ 0x0400 ═══ -->
                        <TextBlock x:Name="Bit0400_Hex"  Grid.Row="10" Grid.Column="0" Style="{StaticResource ColBitStyle}"         Text="0x0400"/>
                        <TextBlock x:Name="Bit0400_Ord"  Grid.Row="10" Grid.Column="1" Style="{StaticResource ColOrdStyle}"         Text=""/>
                        <TextBlock x:Name="Bit0400_Name" Grid.Row="10" Grid.Column="2" Style="{StaticResource ColDesignationStyle}"
                   Text="SBAT firmware update">
                            <TextBlock.ToolTip>
                                <ToolTip Style="{StaticResource BitToolTipStyle}">
                                    <StackPanel>
                                        <TextBlock Text="SBAT firmware update" FontWeight="Bold" FontSize="10" Margin="0,0,0,4"/>
                                        <TextBlock Text="Applies a Secure Boot Advanced Targeting (SBAT) update to UEFI/Linux firmware, enabling metadata-based revocation of vulnerable bootloaders." FontSize="10" TextWrapping="Wrap"/>
                                    </StackPanel>
                                </ToolTip>
                            </TextBlock.ToolTip>
                        </TextBlock>

                        <!-- ═══ 0x0800 ═══ -->
                        <TextBlock x:Name="Bit0800_Hex"  Grid.Row="11" Grid.Column="0" Style="{StaticResource ColBitStyle}"         Text="0x0800"/>
                        <TextBlock x:Name="Bit0800_Ord"  Grid.Row="11" Grid.Column="1" Style="{StaticResource ColOrdStyle}"         Text="2"/>
                        <TextBlock x:Name="Bit0800_Name" Grid.Row="11" Grid.Column="2" Style="{StaticResource ColDesignationStyle}"
                   Text="MS Option ROM UEFI CA 2023 &#x2192; DB">
                            <TextBlock.ToolTip>
                                <ToolTip Style="{StaticResource BitToolTipStyle}">
                                    <StackPanel>
                                        <TextBlock Text="Microsoft Option ROM UEFI CA 2023 &#x2192; DB" FontWeight="Bold" FontSize="10" Margin="0,0,0,4"/>
                                        <TextBlock Text="Adds the Microsoft Option ROM UEFI CA 2023 to the DB. If 0x4000 is set, only applied when UEFI CA 2011 is already present in DB." FontSize="10" TextWrapping="Wrap"/>
                                    </StackPanel>
                                </ToolTip>
                            </TextBlock.ToolTip>
                        </TextBlock>

                        <!-- ═══ 0x1000 ═══ -->
                        <TextBlock x:Name="Bit1000_Hex"  Grid.Row="12" Grid.Column="0" Style="{StaticResource ColBitStyle}"         Text="0x1000"/>
                        <TextBlock x:Name="Bit1000_Ord"  Grid.Row="12" Grid.Column="1" Style="{StaticResource ColOrdStyle}"         Text="3"/>
                        <TextBlock x:Name="Bit1000_Name" Grid.Row="12" Grid.Column="2" Style="{StaticResource ColDesignationStyle}"
                   Text="MS UEFI CA 2023 &#x2192; DB">
                            <TextBlock.ToolTip>
                                <ToolTip Style="{StaticResource BitToolTipStyle}">
                                    <StackPanel>
                                        <TextBlock Text="Microsoft UEFI CA 2023 &#x2192; DB" FontWeight="Bold" FontSize="10" Margin="0,0,0,4"/>
                                        <TextBlock Text="Adds the Microsoft UEFI CA 2023 to the DB. If 0x4000 is set, only applied when UEFI CA 2011 is already present in DB." FontSize="10" TextWrapping="Wrap"/>
                                    </StackPanel>
                                </ToolTip>
                            </TextBlock.ToolTip>
                        </TextBlock>

                        <!-- ═══ 0x4000 ═══ -->
                        <TextBlock x:Name="Bit4000_Hex"  Grid.Row="13" Grid.Column="0" Style="{StaticResource ColBitStyle}"         Text="0x4000"/>
                        <TextBlock x:Name="Bit4000_Ord"  Grid.Row="13" Grid.Column="1" Style="{StaticResource ColOrdStyle}"         Text="2+3"/>
                        <TextBlock x:Name="Bit4000_Name" Grid.Row="13" Grid.Column="2" Style="{StaticResource ColDesignationStyle}"
                   Text="Conditional CA 2023 application">
                            <TextBlock.ToolTip>
                                <ToolTip Style="{StaticResource BitToolTipStyle}">
                                    <StackPanel>
                                        <TextBlock Text="Conditional CA 2023 application" FontWeight="Bold" FontSize="10" Margin="0,0,0,4"/>
                                        <TextBlock Text="Modifies bits 0x0800 and 0x1000: CA 2023 certificates are only added if Microsoft Corporation UEFI CA 2011 is already present in the DB, preserving the device's existing security profile." FontSize="10" TextWrapping="Wrap"/>
                                    </StackPanel>
                                </ToolTip>
                            </TextBlock.ToolTip>
                        </TextBlock>


                        <!-- ═══ Total_Hex ═══ -->
                        <Border Grid.Row="14" Grid.Column="0" Margin="0,1,0,0"
                                BorderBrush="Black" BorderThickness="0,1,0,0" />
                        <TextBlock x:Name="Total_Hex"   Grid.Row="14" Grid.Column="0" Style="{StaticResource ColBitStyle}"
                                   Text=""        Foreground="Black" FontSize="13" FontWeight="Bold"   />
                        <TextBlock x:Name="Total_Ord"   Grid.Row="14" Grid.Column="1" Style="{StaticResource ColOrdStyle}"
                                   Text=":"             Foreground="Black" FontSize="13" FontWeight="Bold"  />
                        <TextBlock x:Name="Total_Name"  Grid.Row="14" Grid.Column="2" Style="{StaticResource ColDesignationStyle}"
                                   Text="Actual State (Sum)"  Foreground="Black" FontSize="12" FontWeight="Bold"  >
                            <TextBlock.ToolTip>
                                <ToolTip Style="{StaticResource BitToolTipStyle}">
                                    <StackPanel>
                                        <TextBlock Text="ACTUAL STATE (Sum)" FontWeight="Bold" FontSize="10" Margin="0,0,0,4"/>
                                        <TextBlock Text="Sum of flags set - Typical start value is 0x5944 with all relevant bits set. Progression: 0x5944 → 0x5904 → 0x5104 → 0x4104 → 0x4100 → 0x4000." FontSize="10" TextWrapping="Wrap"/>
                                    </StackPanel>
                                </ToolTip>
                            </TextBlock.ToolTip>
                        </TextBlock>

                    </Grid>

                </StackPanel>

                <WrapPanel Height="120" Width="265" Margin="0,25,0,0">
                    
                    
                </WrapPanel>
            </WrapPanel>


            <WrapPanel Grid.Row="2" Grid.Column="1" Margin="5,0,0,0" >
                <TextBlock Text="Bootloader certificates : " Background="#FF3E8DDD" FontSize="16" FontWeight="SemiBold"
                       Foreground="White" Height="26" Width="255" Padding="10,2,0,0" HorizontalAlignment="Left"/>
                <StackPanel x:Name="BootLoadCert" Orientation="Vertical" Margin="5,5,0,0" Width="255">
                    <!-- ── Système ─────────────────────────────────────────── -->
                    <Border Background="#443E8DDD" CornerRadius="5" Margin="0,0,0,2" Width="245" HorizontalAlignment="Left">
                        <TextBlock Text="Système  C:\Windows\Boot\EFI\bootmgfw.efi" 
                   FontSize="11" FontWeight="SemiBold" Foreground="#FF324873"
                   Margin="5,2,4,2"/>
                    </Border>
                    <StackPanel Orientation="Horizontal" Margin="14,1,0,0">
                        <TextBlock Text="Certificat : " 
                   FontSize="11" FontWeight="SemiBold" Foreground="#FF324873"/>
                        <TextBlock x:Name="TxtBootSysLabel" Text="..." FontWeight="Bold"
                   FontSize="11" Foreground="#FF324873"/>
                    </StackPanel>
                    
                    <StackPanel Orientation="Horizontal" Margin="14,1,0,0">
                        <TextBlock Text="SVN : " 
                   FontSize="11" FontWeight="SemiBold" Foreground="#FF324873"/>
                        <TextBlock x:Name="TxtBootSysSVN" Text="..." FontWeight="Bold"
                   FontSize="11" Foreground="#FF324873"/>
                    </StackPanel>

                    <StackPanel Orientation="Horizontal" Margin="14,1,0,0">
                        <TextBlock Text="Thumbprint : " 
                   FontSize="10" FontWeight="SemiBold" Foreground="#FF324873"/>
                        <TextBlock x:Name="TxtBootSysThumb" Text="..."
                   FontSize="10" Foreground="#FF324873"
                   ToolTip="{Binding ElementName=TxtBootSysThumb, Path=Tag}"/>
                    </StackPanel>
                    <StackPanel Orientation="Horizontal" Margin="14,1,0,4">
                        <TextBlock Text="Version : " 
                   FontSize="10" FontWeight="SemiBold" Foreground="#FF324873"/>
                        <TextBlock x:Name="TxtBootSysVersion" Text="..."
                   FontSize="10" Foreground="#FF324873" TextWrapping="Wrap" Width="140"/>
                    </StackPanel>
                    <!-- ── ESP ─────────────────────────────────────────────── -->
                    <Border Background="#443E8DDD" CornerRadius="5" Margin="0,2,0,2" Width="245" HorizontalAlignment="Left">
                        <TextBlock Text="ESP  \EFI\Microsoft\Boot\bootmgfw.efi" 
                   FontSize="11" FontWeight="SemiBold" Foreground="#FF324873"
                   Margin="5,2,4,2"/>
                    </Border>


                    <Grid Margin="14,2,0,4">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>

                        <!-- Row 0 : Certificat -->
                        <StackPanel Grid.Row="0" Grid.Column="0" Orientation="Horizontal">
                        <TextBlock Text="Certificat : " 
                   FontSize="11" FontWeight="SemiBold" Foreground="#FF324873"/>
                        <TextBlock x:Name="TxtBootEspLabel" Text="..." FontWeight="Bold"
                   FontSize="11" Foreground="#FF324873"/>
                    </StackPanel>

                        <!-- Row 1 : SVN -->
                        <StackPanel Grid.Row="1" Grid.Column="0" Orientation="Horizontal" Margin="0,1,0,0">
                            <TextBlock Text="SVN : " FontSize="11" FontWeight="SemiBold" Foreground="#FF324873"/>
                            <TextBlock x:Name="TxtBootEspSVN" Text="..." FontWeight="Bold" FontSize="11" Foreground="#FF324873"/>
                    </StackPanel>

                        <!-- Row 2 : Thumbprint -->
                        <StackPanel Grid.Row="2" Grid.Column="0" Orientation="Horizontal" Margin="0,1,0,0">
                            <TextBlock Text="Thumbprint : " FontSize="10" FontWeight="SemiBold" Foreground="#FF324873"/>
                            <TextBlock x:Name="TxtBootEspThumb" Text="..." FontSize="10" Foreground="#FF324873"
                   ToolTip="{Binding ElementName=TxtBootEspThumb, Path=Tag}"/>
                        </StackPanel>

                        <!-- Bouton : colonne droite, sur les 3 premières lignes -->
                        <Button Grid.Row="0" Grid.RowSpan="3" Grid.Column="1"
        x:Name="BtnRollback"
        Style="{StaticResource ButtonStyle}"
        Padding="4,2"
        VerticalAlignment="Center"
        IsEnabled="False"
        ToolTipService.ShowOnDisabled="True"
        ToolTipService.InitialShowDelay="100" Margin="0,0,25,0">
                            <Button.ToolTip>
                                <ToolTip Style="{StaticResource BitToolTipStyle}">
                                    <StackPanel>
                                        <TextBlock Text="Rollback to PCA 2011 Bootloader" FontWeight="Bold" FontSize="10" Margin="0,0,0,4"/>
                                        <TextBlock Text="Overwrites ESP bootloader with C:\Windows\Boot\EFI\bootmgfw.efi (PCA 2011)." FontSize="10" TextWrapping="Wrap"/>
                                        <TextBlock Text="For diagnostic / test rollback only." FontSize="10" FontStyle="Italic" Margin="0,4,0,0" TextWrapping="Wrap"/>
                                    </StackPanel>
                                </ToolTip>
                            </Button.ToolTip>
                            <TextBlock TextAlignment="Center" LineHeight="11" FontSize="10" Padding="8,1" >
        Rollback to<LineBreak/>PCA 2011<LineBreak/>Bootloader
                            </TextBlock>
                        </Button>

                        <!-- Row 3 : Version (pleine largeur sous le bouton) -->
                        <StackPanel Grid.Row="3" Grid.Column="0" Grid.ColumnSpan="2" Orientation="Horizontal" Margin="0,1,0,0">
                            <TextBlock Text="Version : " FontSize="10" FontWeight="SemiBold" Foreground="#FF324873"/>
                            <TextBlock x:Name="TxtBootEspVersion" Text="..." FontSize="10" Foreground="#FF324873" TextWrapping="Wrap" Width="140"/>
                        </StackPanel>
                    </Grid>



                    <!--<StackPanel Orientation="Horizontal" Margin="14,2,0,0">
                        <TextBlock Text="Certificat : " 
                               FontSize="11" FontWeight="SemiBold" Foreground="#FF324873" Margin="0,18,0,0" />
                        <TextBlock x:Name="TxtBootEspLabel" Text="..." FontWeight="Bold"
                               FontSize="11" Foreground="#FF324873" Margin="0,18,0,0" />
                        <Button x:Name="BtnRollback" HorizontalAlignment="Right"
                                FontSize="10" Padding="4,2"
                                IsEnabled="False"
                                ToolTip="Overwrites ESP bootloader with C:\Windows\Boot\EFI\bootmgfw.efi (PCA 2011). For diagnostic / test rollback only."
                                ToolTipService.ShowOnDisabled="True"  Margin="40,0,0,0" >
                            <TextBlock TextAlignment="Center" LineHeight="12">
                                Rollback to<LineBreak/>PCA 2011 Bootloader
                            </TextBlock>
                        </Button>
                    </StackPanel>

                    <StackPanel Orientation="Horizontal" Margin="14,1,0,0">
                        <TextBlock Text="SVN : "  FontSize="11" FontWeight="SemiBold" Foreground="#FF324873"/>
                        <TextBlock x:Name="TxtBootEspSVN" Text="..." FontWeight="Bold" FontSize="11" Foreground="#FF324873"/>
                    </StackPanel>

                    <StackPanel Orientation="Horizontal" Margin="14,1,0,0">
                        <TextBlock Text="Thumbprint : "  FontSize="10" FontWeight="SemiBold" Foreground="#FF324873"/>
                        <TextBlock x:Name="TxtBootEspThumb" Text="..." FontSize="10" Foreground="#FF324873"
                   ToolTip="{Binding ElementName=TxtBootEspThumb, Path=Tag}"/>
                    </StackPanel>
                    <StackPanel Orientation="Horizontal" Margin="14,1,0,4">
                        <TextBlock Text="Version : " FontSize="10" FontWeight="SemiBold" Foreground="#FF324873"/>
                        <TextBlock x:Name="TxtBootEspVersion" Text="..." FontSize="10" Foreground="#FF324873" TextWrapping="Wrap" Width="140"/>
                    </StackPanel>-->
                    
                </StackPanel>

                <Border Grid.Row="3" Grid.Column="1" Margin="20,5,0,0" Padding="4,0" 
                        Background="#FFFEF3CD" BorderBrush="#FFD4A017" BorderThickness="2"
                        CornerRadius="5" HorizontalAlignment="Left" Width="230" Height="26"  >
                    <StackPanel Orientation="Horizontal">
                        <TextBlock Text="Last refresh : " FontSize="14" FontWeight="SemiBold" Foreground="#FFAC9149"/>
                        <TextBlock x:Name="TxtLastRefresh" Text="—" FontSize="14" Foreground="#FFAC9149"/>
                    </StackPanel>
                </Border>




            </WrapPanel>
            
            
        </Grid>
    </Grid>
</Window>
"@
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
#$colExtra = Get-XamlControl -Name "ColExtra"

$colExtraActions = $window.FindName("ColExtraActions")

$btnExecute     = Get-XamlControl -Name "btnExecute"
$btnMore        = Get-XamlControl -Name "btnMore"
$ChkShowGuid    = Get-XamlControl -Name "ChkShowGuid"

$BitLockerStatus = Get-XamlControl -Name "BitLockerStatus"
$BitLockerIcon   = Get-XamlControl -Name "BitLockerIcon"
$BitLockerStatus = Get-XamlControl -Name "BitLockerStatus"

$Set_Reg_To        = Get-XamlControl -Name "Set_Reg_To"
$Set_Reg_ComboBox  = Get-XamlControl -Name "Set_Reg_ComboBox"

$Start_Task     = Get-XamlControl -Name "Start_Task"
$Log_CSV        = Get-XamlControl -Name "Log_CSV"

$PK_Grid         = Get-XamlControl -Name "PK_Grid"
$PKDefault_Grid  = Get-XamlControl -Name "PKDefault_Grid"
$KEK_Grid        = Get-XamlControl -Name "KEK_Grid"
$KEKDefault_Grid = Get-XamlControl -Name "KEKDefault_Grid"
$DB_Grid         = Get-XamlControl -Name "DB_Grid"
$DBDefault_Grid  = Get-XamlControl -Name "DBDefault_Grid"
$DBX_Grid         = Get-XamlControl -Name "DBX_Grid"
$DBXDefault_Grid  = Get-XamlControl -Name "DBXDefault_Grid"

$TxtStatus      = Get-XamlControl -Name "TxtStatus"
$BorderStatus   = Get-XamlControl -Name "BorderStatus"
$BorderTitleStatus   = Get-XamlControl -Name "BorderTitleStatus"

$tbSecureBoot   = Get-XamlControl -Name "tbSecureBoot"
$WinVer         = Get-XamlControl -Name "WinVer"
$WinBuild       = Get-XamlControl -Name "WinBuild"

$IcoBuild       = Get-XamlControl -Name "IcoBuild"
$MinBuildTxt    = Get-XamlControl -Name "MinBuildTxt"
$MinBuildValue  = Get-XamlControl -Name "MinBuildValue"

$SystemFamily   = Get-XamlControl -Name "SystemFamily"
$MachineType    = Get-XamlControl -Name "MachineType"
$BiosVer        = Get-XamlControl -Name "BiosVer"
$BiosDate       = Get-XamlControl -Name "BiosDate"

$script:EspDriveLetter = "S"
$TxtBootSysLabel  = Get-XamlControl -Name "TxtBootSysLabel"
$TxtBootSysThumb  = Get-XamlControl -Name "TxtBootSysThumb"
$TxtBootSysVersion = Get-XamlControl -Name "TxtBootSysVersion"

$TxtBootEspLabel  = Get-XamlControl -Name "TxtBootEspLabel"
$TxtBootEspThumb  = Get-XamlControl -Name "TxtBootEspThumb"
$TxtBootEspVersion = Get-XamlControl -Name "TxtBootEspVersion"

$BtnRollback     = Get-XamlControl -Name "BtnRollback"

$TxtLastRefresh = Get-XamlControl -Name "TxtLastRefresh"

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
        $OutputControl.Foreground = "OrangeRed"
    }
    catch {
        $OutputControl.Text       = "?"
        $OutputControl.Foreground = "OrangeRed"
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

        $VerControl.Text   = "$($os.Caption) $($reg.DisplayVersion)"
        $BuildControl.Text = "$($reg.CurrentBuild).$($reg.UBR)"

        $build = [int]$reg.CurrentBuild
        $ubr   = [int]$reg.UBR

        if ($build -ge 28000) {
            $IcoBuild.Text            = "✔"
            $IcoBuild.Foreground      = "Green"
            $MinBuildTxt.Visibility   = [System.Windows.Visibility]::Hidden
            $MinBuildValue.Visibility = [System.Windows.Visibility]::Hidden
            $MinBuildValue.Text       = ""
        }
        elseif (($build -eq 26200 -or $build -eq 26100) -and $ubr -ge 6899) {
            $IcoBuild.Text            = "✔"
            $IcoBuild.Foreground      = "Green"
            $MinBuildTxt.Visibility   = [System.Windows.Visibility]::Hidden
            $MinBuildValue.Visibility = [System.Windows.Visibility]::Hidden
            $MinBuildValue.Text       = ""
        }
        elseif (($build -eq 26200 -or $build -eq 26100) -and $ubr -lt 6899) {
            $IcoBuild.Text            = "✘"
            $IcoBuild.Foreground      = "Red"
            $MinBuildTxt.Visibility   = [System.Windows.Visibility]::Visible
            $MinBuildValue.Visibility = [System.Windows.Visibility]::Visible
            $MinBuildValue.Text       = "$build.6899"
        }
        elseif (($build -eq 22621 -or $build -eq 22631) -and $ubr -ge 6060) {
            $IcoBuild.Text            = "✔"
            $IcoBuild.Foreground      = "Green"
            $MinBuildTxt.Visibility   = [System.Windows.Visibility]::Hidden
            $MinBuildValue.Visibility = [System.Windows.Visibility]::Hidden
            $MinBuildValue.Text       = ""
        }
        elseif (($build -eq 22621 -or $build -eq 22631) -and $ubr -lt 6060) {
            $IcoBuild.Text            = "✘"
            $IcoBuild.Foreground      = "Red"
            $MinBuildTxt.Visibility   = [System.Windows.Visibility]::Visible
            $MinBuildValue.Visibility = [System.Windows.Visibility]::Visible
            $MinBuildValue.Text       = "$build.6060"
        }
        elseif (($build -eq 19044 -or $build -eq 19045) -and $ubr -ge 6456) {
            $IcoBuild.Text            = "✔"
            $IcoBuild.Foreground      = "Green"
            $MinBuildTxt.Visibility   = [System.Windows.Visibility]::Hidden
            $MinBuildValue.Visibility = [System.Windows.Visibility]::Hidden
            $MinBuildValue.Text       = ""
        }
        elseif (($build -eq 19044 -or $build -eq 19045) -and $ubr -lt 6456) {
            $IcoBuild.Text            = "✘"
            $IcoBuild.Foreground      = "Red"
            $MinBuildTxt.Visibility   = [System.Windows.Visibility]::Visible
            $MinBuildValue.Visibility = [System.Windows.Visibility]::Visible
            $MinBuildValue.Text       = "$build.6456"
        }
        else {
            $IcoBuild.Text            = "✘"
            $IcoBuild.Foreground      = "OrangeRed"
            $MinBuildTxt.Visibility   = [System.Windows.Visibility]::Visible
            $MinBuildValue.Visibility = [System.Windows.Visibility]::Visible
            $MinBuildValue.Text       = "Version ?"
        }
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
        $machineType = $csp.Name
        
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
#region Generic function to retrieve and display UEFI certificates in a DataGrid
function Get-UEFICertificates {
    <#
    .SYNOPSIS
        Retrieves X509 certificates from a UEFI Secure Boot database and displays them in a DataGrid.
        Uses Get-SecureBootUEFI (native Windows) with manual ESL binary parsing — no external module required.
        Text turns green+bold if "2023" is detected in CN or O.
        Tooltip on CN cell shows: Issuer CN (BN), Country+State, validity period.
    .PARAMETER DatabaseName
        UEFI database name (PK, PKdefault, KEK, KEKdefault, DB, DBdefault, DBX, DBXdefault)
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

    # --- Helper : extract a single field from a DN string ---
    function Parse-DnField {
        param([string]$Dn, [string]$Field)
        if ($Dn -match "(?:^|,)\s*$Field=([^,]+)") { return $matches[1].Trim() }
        return ""
    }

    # --- ESL binary parser : returns list of X509 cert objects (hashes silently ignored) ---
    function ConvertFrom-EfiSignatureList {
        param([byte[]]$Bytes)

        $EFI_CERT_X509_GUID = [Guid]'a5c059a1-94e4-4aa7-87b5-ab155c2bf072'
        $results = New-Object System.Collections.Generic.List[object]

        $ms = New-Object System.IO.MemoryStream
        $ms.Write($Bytes, 0, $Bytes.Length) | Out-Null
        $ms.Position = 0
        $br = New-Object System.IO.BinaryReader($ms)

        try {
            while ($br.BaseStream.Position -lt $br.BaseStream.Length) {

                if (($br.BaseStream.Length - $br.BaseStream.Position) -lt 28) { break }

                $listStartPos = $br.BaseStream.Position
                $sigTypeBytes = $br.ReadBytes(16)
                $listSize     = $br.ReadUInt32()
                $headerSize   = $br.ReadUInt32()
                $sigSize      = $br.ReadUInt32()

                if ($listSize -lt 28 -or $sigSize -lt 16) { break }

                $listEndPos = $listStartPos + $listSize
                if ($listEndPos -gt $br.BaseStream.Length) { break }

                $sigTypeGuid = [Guid]::new($sigTypeBytes)

                if ($headerSize -gt 0) { $null = $br.ReadBytes($headerSize) }

                $bytesForEntries = $listEndPos - $br.BaseStream.Position
                if ($bytesForEntries -lt $sigSize) {
                    $br.BaseStream.Position = $listEndPos
                    continue
                }

                $entryCount = [Math]::Floor($bytesForEntries / $sigSize)

                for ($i = 0; $i -lt $entryCount; $i++) {
                    $ownerGuidBytes = $br.ReadBytes(16)
                    if ($ownerGuidBytes.Length -ne 16) { break }

                    $dataLen = $sigSize - 16
                    $sigData = $br.ReadBytes($dataLen)
                    if ($sigData.Length -ne $dataLen) { break }

                    # X509 only — hashes and unknowns silently ignored
                    if ($sigTypeGuid -eq $EFI_CERT_X509_GUID) {
                        try {
                            $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList @(,$sigData)

                        $results.Add([pscustomobject]@{
                            CN             = Parse-DnField -Dn $cert.Subject -Field 'CN'
                            O              = Parse-DnField -Dn $cert.Subject -Field 'O'
                            C              = Parse-DnField -Dn $cert.Subject -Field 'C'
                            ST             = Parse-DnField -Dn $cert.Subject -Field 'S'
                            IssuerCN       = Parse-DnField -Dn $cert.Issuer  -Field 'CN'
                            IssuerS        = Parse-DnField -Dn $cert.Issuer  -Field 'S'
                            IssuerC        = Parse-DnField -Dn $cert.Issuer  -Field 'C'
                            NotBefore      = $cert.NotBefore
                            NotAfter       = $cert.NotAfter
                            SignatureOwner = [Guid]::new($ownerGuidBytes)
})
                        }
                        catch {
                            # Invalid X509 data — silently ignored
                        }
                    }
                }

                $br.BaseStream.Position = $listEndPos
            }
        }
        finally {
            $br.Close()
            $ms.Close()
        }

        return $results
    }

    # --- Main body ---
    try {
        $v = Get-SecureBootUEFI -Name $DatabaseName -ErrorAction Stop

        if (-not $v.Bytes -or $v.Bytes.Count -eq 0) {
            $GridControl.ItemsSource = @([PSCustomObject]@{ CN = "Database '$DatabaseName' empty or inaccessible"; O = "" })
            return $false
        }

        [byte[]]$raw  = $v.Bytes
        $certs        = ConvertFrom-EfiSignatureList -Bytes $raw

        if ($certs.Count -eq 0) {
            $GridControl.ItemsSource = @([PSCustomObject]@{ CN = "No X509 certificate found in '$DatabaseName'"; O = "" })
            return $True
        }

# Constante SignatureOwner Microsoft
$MS_OWNER_GUID = [Guid]'77fa9abd-0359-4d32-bd60-28f4e78f784b'

# Build grid data with tooltip content
$gridData = @()
foreach ($c in $certs) {
    $cn = if ($c.CN) { $c.CN } else { "N/A" }
    $o  = if ($c.O)  { $c.O  } else { "N/A" }

    # Tooltip line 1 : Issuer CN (BN)
    $ttLine1 = if ($c.IssuerCN) { $c.IssuerCN } else { "" }

    # Tooltip line 2 : C ST (empty line if both absent)
    $ttLine2 = (($c.C, $c.ST | Where-Object { $_ -ne "" }) -join " ")

    # Tooltip line 3 : validity period
    $ttLine3 = "$($c.NotBefore.ToString('yyyy-MM-dd'))  ->  $($c.NotAfter.ToString('yyyy-MM-dd'))"

    $tooltip = "$ttLine1`n$ttLine2`n$ttLine3"

    $rowColor = if ($cn -match '2023' -or $o -match '2023') { "Green" } else { "Black" }

    # Ligne certificat normale
    $gridData += [PSCustomObject]@{
        CN        = $cn
        O         = $o
        Tooltip   = $tooltip
        Color     = $rowColor
        IsGuidRow = $false
        GuidColor = ""
    }

    # Ligne GUID — ajoutée uniquement si checkbox cochée
    if ($ChkShowGuid.IsChecked -and $DatabaseName -notmatch "DBX") {
        $guidColor = if ($c.SignatureOwner -eq $MS_OWNER_GUID) { "Blue" } else { "BlueViolet" }
        $gridData += [PSCustomObject]@{
            CN        = "  ↳ SignatureOwner : $($c.SignatureOwner)"
            O         = ""
            Tooltip   = ""
            Color     = $guidColor
            IsGuidRow = $true
            GuidColor = $guidColor
        }
    }
}

        $GridControl.ItemsSource = $gridData

        # Row style : green + bold if Color = "Green"
        $GridControl.RowStyle = $null
        $style = New-Object System.Windows.Style([System.Windows.Controls.DataGridRow])

        # Trigger : vert + gras si certificat 2023
        $triggerGreen = New-Object System.Windows.DataTrigger
        $triggerGreen.Binding = New-Object System.Windows.Data.Binding("Color")
        $triggerGreen.Value   = "Green"
        $triggerGreen.Setters.Add((New-Object System.Windows.Setter([System.Windows.Controls.Control]::ForegroundProperty, [System.Windows.Media.Brushes]::Green)))
        $triggerGreen.Setters.Add((New-Object System.Windows.Setter([System.Windows.Controls.Control]::FontWeightProperty, [System.Windows.FontWeights]::Bold)))
        $style.Triggers.Add($triggerGreen)

        # Trigger : bleu si GUID Microsoft
        $triggerBlue = New-Object System.Windows.DataTrigger
        $triggerBlue.Binding = New-Object System.Windows.Data.Binding("Color")
        $triggerBlue.Value   = "Blue"
        $triggerBlue.Setters.Add((New-Object System.Windows.Setter([System.Windows.Controls.Control]::ForegroundProperty, [System.Windows.Media.Brushes]::Blue)))
        $triggerBlue.Setters.Add((New-Object System.Windows.Setter([System.Windows.Controls.Control]::FontSizeProperty, [double]9)))
        $style.Triggers.Add($triggerBlue)

        # Trigger : violet si GUID OEM
        $triggerViolet = New-Object System.Windows.DataTrigger
        $triggerViolet.Binding = New-Object System.Windows.Data.Binding("Color")
        $triggerViolet.Value   = "BlueViolet"
        $triggerViolet.Setters.Add((New-Object System.Windows.Setter([System.Windows.Controls.Control]::ForegroundProperty, [System.Windows.Media.Brushes]::BlueViolet)))
        $triggerViolet.Setters.Add((New-Object System.Windows.Setter([System.Windows.Controls.Control]::FontSizeProperty, [double]9)))
        $style.Triggers.Add($triggerViolet)

        $GridControl.RowStyle = $style

        return $true
    }
    catch {
        $GridControl.ItemsSource = @([PSCustomObject]@{
            CN = "ERROR"
            O  = $_.Exception.Message
        })
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
#    $BorderTitleStatus.BorderBrush = $Color
    $BorderTitleStatus.Background = $Color
}
#endregion

#region Lookup table - AvailableUpdates
$AvailableUpdates_Table = [ordered]@{
    # Séquence de progression Microsoft
    "0x0000" = "No Secure Boot key updates are scheduled"
    "0x4004" = "Pending: KEK update — OEM-signed KEK not yet available"
    "0x4100" = "Pending: Boot manager update — KEK 2K CA 2023 applied"
    "0x4104" = "Pending: Option ROM CA 2023 — Microsoft UEFI CA 2023 applied"
    "0x5104" = "Pending: Microsoft UEFI CA 2023 — Option ROM CA 2023 applied"
    "0x5904" = "Pending: DB/KEK/BootMgr updates — Windows UEFI CA 2023 applied"
    "0x5944" = "Pending: DB, KEK, Boot Manager and CA 2023 updates"
    # Bits individuels (valeurs intermédiaires possibles)
    "0x0002" = "Pending: DBX revocation update"
    "0x0004" = "Pending: Add Microsoft Corporation KEK 2K CA 2023 to KEK"
    "0x0020" = "Pending: SkuSiPolicy revocation policy update"
    "0x0040" = "Pending: Add Windows UEFI CA 2023 to DB"
    "0x0080" = "Pending: Add Windows Production PCA 2011 to DBX"
    "0x0100" = "Pending: Apply PCA2023-signed boot manager"
    "0x0200" = "Pending: SVN (Secure Version Number) firmware update"
    "0x0400" = "Pending: SBAT (Secure Boot Advanced Targeting) firmware update"
    "0x0800" = "Pending: Add Microsoft Option ROM UEFI CA 2023 to DB"
    "0x1000" = "Pending: Add Microsoft UEFI CA 2023 to DB"
    "0x4000" = "Pending: Conditional CA 2023 application (guard bit)"
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

#region Lookup table - ConfidenceLevel (REG_SZ)
$ConfidenceLevel_Table = [ordered]@{
    "High Confidence"                    = "Devices in this group have demonstrated, through observed data, that they can successfully update firmware using the new Secure Boot certificates."
    "Temporarily Paused"                 = "Devices in this group are affected by a known issue. To reduce risk, Secure Boot certificate updates are temporarily paused while Microsoft and partners work toward a supported resolution. This may require a firmware update. Look for an 1802 event for more details."
    "Not Supported – Known Limitation"   = "Devices in this group do not support the automated Secure Boot certificate update path due to hardware or firmware limitations. No supported automatic resolution is currently available for this configuration."
    "Under Observation - More Data Needed" = "Devices in this group are not currently blocked, but there is not yet enough data to classify them as high confidence. Secure Boot certificate updates may be deferred until sufficient data is available."
    "No Data Observed - Action Required" = "Microsoft has not observed this device in Secure Boot update data. As a result, automatic certificate updates cannot be evaluated for this device, and administrator action is likely required."
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
        [Parameter(Mandatory=$false)] [System.Windows.Controls.TextBlock]$ExtraHexControl = $null,
        [Parameter(Mandatory=$false)] [string]$GoodValue = "",
        [Parameter(Mandatory=$false)] [string]$DefaultDesc = ""
    )

    try {
        $regItem  = Get-ItemProperty -Path $RegPath -Name $ValueName -ErrorAction Stop
        $rawValue = $regItem.$ValueName
        $hexValue = "0x{0:X4}" -f $rawValue

        $HexControl.Text       = $hexValue
        $HexControl.Foreground = "Black"

         # Optionally mirror the hex value to a second control (e.g. Total_Hex in GridBits)
        if ($null -ne $ExtraHexControl) {
            $ExtraHexControl.Text       = $hexValue
            $ExtraHexControl.Foreground = "Black"
        }

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
                $IconControl.Foreground = "OrangeRed"
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
                $IconControl.Foreground = "OrangeRed"
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

$Reg5_Value       = Get-XamlControl -Name "Reg5_Value"
$Reg5_Description = Get-XamlControl -Name "Reg5_Description"

$Error_Num            = Get-XamlControl -Name "Error_Num"
$Error_Status         = Get-XamlControl -Name "Error_Status"
$Error_Icon           = Get-XamlControl -Name "Error_Icon"
$Error_Message        = Get-XamlControl -Name "Error_Message"
$WrapPanel_ErrorEvent = Get-XamlControl -Name "WrapPanel_ErrorEvent"

$_1808_Num     = Get-XamlControl -Name "_1808_Num"
$_1808_Status  = Get-XamlControl -Name "_1808_Status"
$_1808_Icon    = Get-XamlControl -Name "_1808_Icon"
$_1808_Message = Get-XamlControl -Name "_1808_Message"

$_1799_Num        = Get-XamlControl -Name "_1799_Num"
$_1799_Status     = Get-XamlControl -Name "_1799_Status"
$_1799_Message    = Get-XamlControl -Name "_1799_Message"
$WrapPanel_1799   = Get-XamlControl -Name "WrapPanel_1799"

$_1801_Num        = Get-XamlControl -Name "_1801_Num"
$_1801_Status     = Get-XamlControl -Name "_1801_Status"
$_1801_Message    = Get-XamlControl -Name "_1801_Message"
$WrapPanel_1801   = Get-XamlControl -Name "WrapPanel_1801"

$_1802_Num        = Get-XamlControl -Name "_1802_Num"
$_1802_Status     = Get-XamlControl -Name "_1802_Status"
$_1802_Message    = Get-XamlControl -Name "_1802_Message"
$WrapPanel_1802   = Get-XamlControl -Name "WrapPanel_1802"

$_1803_Num        = Get-XamlControl -Name "_1803_Num"
$_1803_Status     = Get-XamlControl -Name "_1803_Status"
$_1803_Message    = Get-XamlControl -Name "_1803_Message"
$WrapPanel_1803   = Get-XamlControl -Name "WrapPanel_1803"
#endregion

#region Retrieve Registry controls
$Total_Hex    = Get-XamlControl -Name "Total_Hex"

$Bit0002_Hex  = Get-XamlControl -Name "Bit0002_Hex"
$Bit0002_Ord  = Get-XamlControl -Name "Bit0002_Ord"
$Bit0002_Name = Get-XamlControl -Name "Bit0002_Name"

$Bit0004_Hex  = Get-XamlControl -Name "Bit0004_Hex"
$Bit0004_Ord  = Get-XamlControl -Name "Bit0004_Ord"
$Bit0004_Name = Get-XamlControl -Name "Bit0004_Name"

$Bit0008_Hex  = Get-XamlControl -Name "Bit0008_Hex"
$Bit0008_Ord  = Get-XamlControl -Name "Bit0008_Ord"
$Bit0008_Name = Get-XamlControl -Name "Bit0008_Name"

$Bit0010_Hex  = Get-XamlControl -Name "Bit0010_Hex"
$Bit0010_Ord  = Get-XamlControl -Name "Bit0010_Ord"
$Bit0010_Name = Get-XamlControl -Name "Bit0010_Name"

$Bit0020_Hex  = Get-XamlControl -Name "Bit0020_Hex"
$Bit0020_Ord  = Get-XamlControl -Name "Bit0020_Ord"
$Bit0020_Name = Get-XamlControl -Name "Bit0020_Name"

$Bit0040_Hex  = Get-XamlControl -Name "Bit0040_Hex"
$Bit0040_Ord  = Get-XamlControl -Name "Bit0040_Ord"
$Bit0040_Name = Get-XamlControl -Name "Bit0040_Name"

$Bit0080_Hex  = Get-XamlControl -Name "Bit0080_Hex"
$Bit0080_Ord  = Get-XamlControl -Name "Bit0080_Ord"
$Bit0080_Name = Get-XamlControl -Name "Bit0080_Name"

$Bit0100_Hex  = Get-XamlControl -Name "Bit0100_Hex"
$Bit0100_Ord  = Get-XamlControl -Name "Bit0100_Ord"
$Bit0100_Name = Get-XamlControl -Name "Bit0100_Name"

$Bit0200_Hex  = Get-XamlControl -Name "Bit0200_Hex"
$Bit0200_Ord  = Get-XamlControl -Name "Bit0200_Ord"
$Bit0200_Name = Get-XamlControl -Name "Bit0200_Name"

$Bit0400_Hex  = Get-XamlControl -Name "Bit0400_Hex"
$Bit0400_Ord  = Get-XamlControl -Name "Bit0400_Ord"
$Bit0400_Name = Get-XamlControl -Name "Bit0400_Name"

$Bit0800_Hex  = Get-XamlControl -Name "Bit0800_Hex"
$Bit0800_Ord  = Get-XamlControl -Name "Bit0800_Ord"
$Bit0800_Name = Get-XamlControl -Name "Bit0800_Name"

$Bit1000_Hex  = Get-XamlControl -Name "Bit1000_Hex"
$Bit1000_Ord  = Get-XamlControl -Name "Bit1000_Ord"
$Bit1000_Name = Get-XamlControl -Name "Bit1000_Name"

$Bit4000_Hex  = Get-XamlControl -Name "Bit4000_Hex"
$Bit4000_Ord  = Get-XamlControl -Name "Bit4000_Ord"
$Bit4000_Name = Get-XamlControl -Name "Bit4000_Name"

$Total_Ord    = Get-XamlControl -Name "Total_Ord"
$Total_Name   = Get-XamlControl -Name "Total_Name"
#endregion

# Mémorise la valeur d'AvailableUpdates avant le dernier refresh
$script:PreviousAvailableUpdates = $null

#region Function to color the GridBits rows based on AvailableUpdates value
function Update-BitColors {

    $ColorInactive  = [System.Windows.Media.Brushes]::Gray    # absent, non planifié
    $ColorScheduled = [System.Windows.Media.Brushes]::Black   # présent, planifié
    $ColorDone      = [System.Windows.Media.Brushes]::Green   # traité depuis dernier refresh

    if ([string]::IsNullOrEmpty($Total_Hex.Text) -or $Total_Hex.Text -eq "N/A") { return }
    $current  = [Convert]::ToInt32($Total_Hex.Text.Replace("0x",""), 16)
    $previous = $script:PreviousAvailableUpdates

    $BitMap = @(
        @{ Bit = 0x0002; Controls = @($Bit0002_Hex, $Bit0002_Ord, $Bit0002_Name) },
        @{ Bit = 0x0004; Controls = @($Bit0004_Hex, $Bit0004_Ord, $Bit0004_Name) },
        @{ Bit = 0x0008; Controls = @($Bit0008_Hex, $Bit0008_Ord, $Bit0008_Name) },
        @{ Bit = 0x0010; Controls = @($Bit0010_Hex, $Bit0010_Ord, $Bit0010_Name) },
        @{ Bit = 0x0020; Controls = @($Bit0020_Hex, $Bit0020_Ord, $Bit0020_Name) },
        @{ Bit = 0x0040; Controls = @($Bit0040_Hex, $Bit0040_Ord, $Bit0040_Name) },
        @{ Bit = 0x0080; Controls = @($Bit0080_Hex, $Bit0080_Ord, $Bit0080_Name) },
        @{ Bit = 0x0100; Controls = @($Bit0100_Hex, $Bit0100_Ord, $Bit0100_Name) },
        @{ Bit = 0x0200; Controls = @($Bit0200_Hex, $Bit0200_Ord, $Bit0200_Name) },
        @{ Bit = 0x0400; Controls = @($Bit0400_Hex, $Bit0400_Ord, $Bit0400_Name) },
        @{ Bit = 0x0800; Controls = @($Bit0800_Hex, $Bit0800_Ord, $Bit0800_Name) },
        @{ Bit = 0x1000; Controls = @($Bit1000_Hex, $Bit1000_Ord, $Bit1000_Name) },
        @{ Bit = 0x4000; Controls = @($Bit4000_Hex, $Bit4000_Ord, $Bit4000_Name) }
    )

    foreach ($entry in $BitMap) {
        $bit      = $entry.Bit
        $controls = $entry.Controls

        $isActive  = ($current  -band $bit) -ne 0
        $wasActive = ($null -ne $previous) -and (($previous -band $bit) -ne 0)

        if ($isActive) {
            $color = $ColorScheduled   # planifié
        } elseif ($wasActive) {
            $color = $ColorDone        # réalisé depuis le dernier refresh
        } else {
            $color = $ColorInactive    # inactif
        }

        foreach ($ctrl in $controls) {
            if ($null -ne $ctrl) { $ctrl.Foreground = $color }
        }
    }

    # Ligne Total toujours en noir
    foreach ($ctrl in @($Total_Hex, $Total_Ord, $Total_Name)) {
        if ($null -ne $ctrl) { $ctrl.Foreground = [System.Windows.Media.Brushes]::Black }
    }
}
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
        $Error_Status.Foreground  = "OrangeRed"
        $Error_Icon.Text          = "…"
        $Error_Icon.Foreground    = "OrangeRed"
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
            $updateType  = $event1808.Properties[3].Value

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

#region Generic function to retrieve a TPM-WMI event by ID
function Get-TPMEventByID {
    param (
        [Parameter(Mandatory=$true)] [int]$EventID,
        [Parameter(Mandatory=$true)] [System.Windows.Controls.TextBlock]$NumControl,
        [Parameter(Mandatory=$true)] [System.Windows.Controls.TextBlock]$StatusControl,
        [Parameter(Mandatory=$true)] [System.Windows.Controls.TextBlock]$MessageControl,
        [Parameter(Mandatory=$true)] [System.Windows.Controls.WrapPanel]$WrapPanelControl
    )

    try {
        $event = Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-TPM-WMI'; ID=$EventID} -MaxEvents 1 -ErrorAction SilentlyContinue

        if ($event) {
            $WrapPanelControl.Visibility     = [System.Windows.Visibility]::Visible
            $NumControl.Text                 = "$EventID"
            $StatusControl.Text             = $event.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
            $StatusControl.Foreground       = "Gray"
            $MessageControl.Text            = ($event.Message -split '\r?\n')[0].Trim()
            $MessageControl.Foreground      = "Gray"
        }
        else {
            $WrapPanelControl.Visibility     = [System.Windows.Visibility]::Collapsed
        }
    }
    catch {
        $WrapPanelControl.Visibility         = [System.Windows.Visibility]::Collapsed
    }
}
#endregion

function Get-CertLabel ($subject) {
    if ($null -eq $subject)                              { return $null }
    if ($subject -match "Windows UEFI CA 2023")          { return "CA 2023" }
    if ($subject -match "Windows Production PCA 2011")   { return "PCA 2011" }
    return "Unknown"
}

function Read-EfiCertInfo {
    param([string]$FilePath)
    try {
        if (-not (Test-Path $FilePath)) { return @{ Error = "File not found" } }

        $sig = Get-AuthenticodeSignature -FilePath $FilePath
        $fileVersion = (Get-Item -Path $FilePath).VersionInfo.FileVersion
        if ($sig.Status -ne "Valid" -and $sig.Status -ne "UnknownError") {
            return @{ Error = "Invalid signature : $($sig.Status)" }
        }

        # Lire le PE et extraire le PKCS#7 embarqué
        $bytes    = [System.IO.File]::ReadAllBytes($FilePath)
        $cms      = New-Object System.Security.Cryptography.Pkcs.SignedCms
        
        # Localiser le security directory dans le PE header
        # Offset 0x3C = offset du PE header
        $peOffset = [BitConverter]::ToInt32($bytes, 0x3C)
        # Magic : 0x10B = PE32, 0x20B = PE32+
        $magic    = [BitConverter]::ToUInt16($bytes, $peOffset + 24)
        $certTableOffset = if ($magic -eq 0x20B) {
            [BitConverter]::ToInt32($bytes, $peOffset + 168)  # PE32+
        } else {
            [BitConverter]::ToInt32($bytes, $peOffset + 152)  # PE32
        }

        if ($certTableOffset -eq 0) { return @{ Error = "No signature found in the executable" } }

        # Structure WIN_CERTIFICATE : dwLength(4) + wRevision(2) + wCertificateType(2) + bCertificate(n)
        $certLen  = [BitConverter]::ToInt32($bytes, $certTableOffset)
        $certData = $bytes[($certTableOffset + 8)..($certTableOffset + $certLen - 1)]

        $cms.Decode($certData)

        # Parcourir tous les certificats embarqués dans le PKCS#7
        $target = $cms.Certificates | Where-Object {
            $_.Subject -match "UEFI CA 2023" -or
            $_.Subject -match "PCA 2011"
        } | Select-Object -First 1

        if ($target) {
            return @{
                Subject    = $target.Subject
                Thumbprint = $target.Thumbprint
                Version    = $fileVersion
                Error      = $null
            }
        }

        # Fallback : retourner l'issuer du feuille
        return @{
            Subject    = $sig.SignerCertificate.Issuer
            Thumbprint = $sig.SignerCertificate.Thumbprint
            Version    = $fileVersion
            Error      = $null
        }
    }
    catch {
        return @{ Error = "Error : $_" }
        return @{ Error = "File not found"; Version = $null }
        return @{ Error = "Invalid signature : ..."; Version = $null }
        return @{ Error = "Error : $_"; Version = $null }
    }
}

function Get-BootloaderCertInfo {
    $result = [PSCustomObject]@{
        System_Subject    = $null
        System_Thumbprint = $null
        System_Version    = $null
        System_Error      = $null
        ESP_Subject       = $null
        ESP_Thumbprint    = $null
        ESP_Version       = $null
        ESP_Error         = $null
    }

    # ── Fichier système ───────────────────────────────────────
    $r = Read-EfiCertInfo -FilePath "C:\Windows\Boot\EFI\bootmgfw.efi"
    $result.System_Subject    = $r.Subject
    $result.System_Thumbprint = $r.Thumbprint
    $result.System_Version    = $r.Version
    $result.System_Error      = $r.Error

    # ── Fichier ESP ───────────────────────────────────────────
    $espDrive   = "$($script:EspDriveLetter):"
    $espMounted = $false
    try {
        if (Test-Path $espDrive) {
            $result.ESP_Error = "Drive letter $espDrive already in use"
        } else {
            $mountOut = & mountvol $espDrive /S 2>&1
            if ($LASTEXITCODE -ne 0) {
                $result.ESP_Error = "ESP not mountable"
            } else {
                $espMounted = $true
                $r = Read-EfiCertInfo -FilePath "$espDrive\EFI\Microsoft\Boot\bootmgfw.efi"
                $result.ESP_Subject    = $r.Subject
                $result.ESP_Thumbprint = $r.Thumbprint
                $result.ESP_Version    = $r.Version
                $result.ESP_Error      = $r.Error
            }
        }
    } catch {
        $result.ESP_Error = "ESP read error : $_"
    } finally {
        if ($espMounted) { mountvol $espDrive /D | Out-Null }
    }

    return $result
}

function Get-BitLockerStatus {
    try {
        $bl = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop

        $protectors = $bl.KeyProtector | 
                      Where-Object { $_.KeyProtectorType -ne "RecoveryPassword" } |
                      Select-Object -ExpandProperty KeyProtectorType

        $protectorLabel = switch ($true) {
            ($protectors -contains "TpmPin")   { "TPM+PIN" }
            ($protectors -contains "TpmKey")   { "TPM+Key" }
            ($protectors -contains "Tpm")      { "TPM" }
            ($protectors -contains "Password") { "Password" }
            default                            { "Unknown" }
        }

        switch ($bl.ProtectionStatus) {
            "On"  {
                $BitLockerIcon.Text       = "✔"
                $BitLockerIcon.Foreground = "Green"
                $BitLockerStatus.Text       = "On ($protectorLabel)"
                $BitLockerStatus.Foreground = "Green"
            }
            "Off" {
                $BitLockerIcon.Text       = "✘"
                $BitLockerIcon.Foreground = "Gray"
                $BitLockerStatus.Text       = "Off"
                $BitLockerStatus.Foreground = "Gray"
            }
            default {
                $BitLockerIcon.Text       = "?"
                $BitLockerIcon.Foreground = "OrangeRed"
                $BitLockerStatus.Text       = $bl.ProtectionStatus
                $BitLockerStatus.Foreground = "OrangeRed"
            }
        }
    }
    catch {
        $BitLockerIcon.Text       = "?"
        $BitLockerIcon.Foreground = "OrangeRed"
        $BitLockerStatus.Text       = "N/A"
        $BitLockerStatus.Foreground = "OrangeRed"
    }
}


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

        # DBX Active
        if (-not (Get-UEFICertificates -DatabaseName "DBX" -GridControl $DBX_Grid)) {
            $success = $false
        }
        
        # DBX Default
        if (-not (Get-UEFICertificates -DatabaseName "DBXdefault" -GridControl $DBXDefault_Grid)) {
            $success = $false
        }
        
        if ($success) {
            Update-StatusLabel -Message "Data retrieval completed successfully" -Color "Green"
        }
        else {
            Update-StatusLabel -Message "Data retrieval completed with errors" -Color "DarkRed"
        }

        # Registry : AvailableUpdates
        # Mémorise la valeur courante avant de la remplacer (pour comparer après le prochain refresh)
        if (-not [string]::IsNullOrEmpty($Total_Hex.Text) -and $Total_Hex.Text -ne "N/A") {
            $script:PreviousAvailableUpdates = [Convert]::ToInt32($Total_Hex.Text.Replace("0x",""), 16)
        }
        Get-RegistryValue       -RegPath    "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot" `
                                -ValueName  "AvailableUpdates" `
                                -LookupTable $AvailableUpdates_Table `
                                -HexControl  $Reg1_HexValue `
                                -DescControl $Reg1_Description `
                                -ExtraHexControl $Total_Hex
        Update-BitColors

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
        Get-RegistryDWordDecimal -RegPath       "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\Servicing" `
                                 -ValueName     "UEFICA2023ErrorEvent" `
                                 -ValueControl  $Reg4_DecValue `
                                 -IconControl   $Reg4_Icon `
                                 -DefaultText   "No Error"

        # Registry : ConfidenceLevel
        Get-RegistryStringValue -RegPath      "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\Servicing" `
                                -ValueName    "ConfidenceLevel" `
                                -LookupTable  $ConfidenceLevel_Table `
                                -ValueControl $Reg5_Value `
                                -DescControl  $Reg5_Description

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

        # Bootloader certificates (System + ESP)
        $bootInfo = Get-BootloaderCertInfo

        # Système
        if ($bootInfo.System_Error) {
            $TxtBootSysLabel.Text = $bootInfo.System_Error
            $TxtBootSysThumb.Text = ""
            $TxtBootSysThumb.Tag  = $null
            $TxtBootSysVersion.Text = ""
        } else {
            $TxtBootSysLabel.Text       = Get-CertLabel $bootInfo.System_Subject
            $TxtBootSysLabel.Foreground = if ($bootInfo.System_Subject -match "UEFI CA 2023") { "Green" } else { "#FF324873" }
            $TxtBootSysThumb.Tag  = $bootInfo.System_Thumbprint
            $TxtBootSysThumb.Text = $bootInfo.System_Thumbprint.Substring(0,8) + "…"
            $TxtBootSysVersion.Text = $bootInfo.System_Version
        }

        # ESP
        if ($bootInfo.ESP_Error) {
            $TxtBootEspLabel.Text = $bootInfo.ESP_Error
            $TxtBootEspThumb.Text = ""
            $TxtBootEspThumb.Tag  = $null
            $TxtBootEspVersion.Text = ""
        } else {
            $TxtBootEspLabel.Text       = Get-CertLabel $bootInfo.ESP_Subject
            $TxtBootEspLabel.Foreground = if ($bootInfo.ESP_Subject -match "UEFI CA 2023") { "Green" } else { "#FF324873" }
            $TxtBootEspThumb.Tag  = $bootInfo.ESP_Thumbprint
            $TxtBootEspThumb.Text = $bootInfo.ESP_Thumbprint.Substring(0,8) + "…"
            $TxtBootEspVersion.Text = $bootInfo.ESP_Version
        }

        # Active Rollback uniquement si le système est PCA 2011 et l'ESP est CA 2023
        if ($BtnRollback) {
            $BtnRollback.IsEnabled = (
                $TxtBootSysLabel.Text -eq "PCA 2011" -and
                $TxtBootEspLabel.Text -eq "CA 2023"
                )
            }

        # Event TPM-WMI : 1799, 1801, 1802, 1803 if exists
        Get-TPMEventByID -EventID 1799 -NumControl $_1799_Num -StatusControl $_1799_Status -MessageControl $_1799_Message -WrapPanelControl $WrapPanel_1799
        Get-TPMEventByID -EventID 1801 -NumControl $_1801_Num -StatusControl $_1801_Status -MessageControl $_1801_Message -WrapPanelControl $WrapPanel_1801
        Get-TPMEventByID -EventID 1802 -NumControl $_1802_Num -StatusControl $_1802_Status -MessageControl $_1802_Message -WrapPanelControl $WrapPanel_1802
        Get-TPMEventByID -EventID 1803 -NumControl $_1803_Num -StatusControl $_1803_Status -MessageControl $_1803_Message -WrapPanelControl $WrapPanel_1803

        # Last refresh timestamp
        $TxtLastRefresh.Text = Get-Date -Format "yyyy-MM-dd  HH:mm:ss"
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

# Execute button
if ($btnMore) {
    $btnMore.Add_Click({
        if ($btnMore.Content -eq "MORE") {
            $btnMore.Content = "LESS"
            $window.MinWidth = 1280
            $window.MaxWidth = 1280
            $window.Width    = 1280
            $BorderStatus.Width = 515
            $BorderStatus.Height = 65
        } elseif ($btnMore.Content -eq "LESS") {
            $btnMore.Content = "MORE"
            $window.MinWidth = 1000
            $window.MaxWidth = 1000
            $window.Width    = 1000
            $BorderStatus.Width = 235
            $BorderStatus.Height = 90
        }
    })
}

# Set AvailableUpdates to selected value
if ($Set_Reg_To) {
    $Set_Reg_To.Add_Click({
        try {
            $selected = $Set_Reg_ComboBox.SelectedItem
            if (-not $selected) {
                Update-StatusLabel -Message "No value selected" -Color "OrangeRed"
                return
            }

            $hexStr   = $selected.Tag
            $rawValue = [Convert]::ToInt32($hexStr.Replace("0x",""), 16)

            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot" `
                             -Name "AvailableUpdates" `
                             -Value $rawValue `
                             -Type DWord -Force

            Update-StatusLabel -Message "AvailableUpdates set to $hexStr" -Color "Green"
            $Reg1_HexValue.Text = $hexStr
            $Total_Hex.Text     = $hexStr
            # Mémorise la valeur de départ pour comparer après le prochain refresh
            $script:PreviousAvailableUpdates = $rawValue
            Update-BitColors
        }
        catch {
            Update-StatusLabel -Message "Error setting AvailableUpdates : $_" -Color "Red"
        }
    })
}

# Start Task "\Microsoft\Windows\PI\Secure-Boot-Update"
if ($Start_Task) {
    $Start_Task.Add_Click({
        try {
            Start-ScheduledTask -TaskName "\Microsoft\Windows\PI\Secure-Boot-Update"
            Update-StatusLabel -Message "Task started successfully" -Color "Green"
        }
        catch {
            Update-StatusLabel -Message "Error starting task : $_" -Color "Red"
        }
    })
}

# Create or Append log in CSV format with current data (one line per click)
if ($Log_CSV) {
    $Log_CSV.Add_Click({
        try {
            $csvPath = Join-Path -Path $PSScriptRoot -ChildPath "Log_CheckCA2023.csv"

            # Nettoyer SystemFamily : supprimer "Think" si présent
            $systemFamilyClean = $SystemFamily.Text -replace "ThinkPad", "" -replace "ThinkCentre", "" -replace "ThinkStation", "" -replace "ThinkBook", "" -replace "^\s+|\s+$", ""

            # Construire la ligne de données
            $row = [PSCustomObject]@{
                "Machine Type"             = $MachineType.Text
                "System Family"            = $systemFamilyClean
                "Bios Version"             = $BiosVer.Text
                "Bios Date"                = $BiosDate.Text
                "MS Build"                 = $WinBuild.Text
                "AvailableUpdates"         = $Reg1_HexValue.Text
                "UEFICA2023Status"         = $Reg2_Value.Text
                "WindowsUEFICA2023Capable" = $Reg3_HexValue.Text
                "UEFICA2023ErrorEvent"     = $Reg4_DecValue.Text
                "1808 Event"               = $_1808_Status.Text
                "Date/Time"                = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            }

            # Créer ou ajouter au CSV
            if (Test-Path $csvPath) {
                $row | Export-Csv -Path $csvPath -Append -NoTypeInformation -Encoding UTF8 -Delimiter ";"
            } else {
                $row | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8 -Delimiter ";"
            }

            Update-StatusLabel -Message "Log saved : $csvPath" -Color "Green"
        }
        catch {
            Update-StatusLabel -Message "Error saving log : $_" -Color "Red"
        }
    })
}

# Rollback ESP bootloader to PCA 2011 (diagnostic / test use)
if ($BtnRollback) {
    $BtnRollback.Add_Click({
        $msg = "This will overwrite the ESP bootloader with C:\Windows\Boot\EFI\bootmgfw.efi (PCA 2011 signed).`n`n" +
               "Prerequisites (operator's responsibility):`n" +
               " - BitLocker suspended`n" +
               " - PCA 2011 still present in Secure Boot db`n" +
               " - SBAT revision compatible`n`n" +
               "Proceed with rollback?"

        $confirm = [System.Windows.MessageBox]::Show(
            $msg,
            "Rollback Bootloader to PCA 2011",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Warning
        )
        if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) {
            Update-StatusLabel -Message "Rollback cancelled by user" -Color "OrangeRed"
            return
        }

        $espDrive   = "$($script:EspDriveLetter):"
        $espMounted = $false
        $src        = "C:\Windows\Boot\EFI\bootmgfw.efi"
        $dst        = "$espDrive\EFI\Microsoft\Boot\bootmgfw.efi"

        try {
            if (-not (Test-Path $src)) {
                Update-StatusLabel -Message "Source not found : $src" -Color "Red"
                return
            }

            if (Test-Path $espDrive) {
                Update-StatusLabel -Message "Drive $espDrive already in use, cannot mount ESP" -Color "Red"
                return
            }

            & mountvol $espDrive /S 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Update-StatusLabel -Message "ESP mount failed (run as Administrator)" -Color "Red"
                return
            }
            $espMounted = $true

            Copy-Item -Path $src -Destination $dst -Force -ErrorAction Stop
            Update-StatusLabel -Message "Rollback done : $dst overwritten with PCA 2011 binary" -Color "Green"
        }
        catch {
            Update-StatusLabel -Message "Rollback error : $_" -Color "Red"
        }
        finally {
            if ($espMounted) { mountvol $espDrive /D | Out-Null }
        }

        # Refresh UI to reflect new state
        Invoke-MainAction
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

    # Alimenter le ComboBox AvailableUpdates
    foreach ($entry in $AvailableUpdates_Table.GetEnumerator()) {
        $item = New-Object System.Windows.Controls.ComboBoxItem
        $item.Content = "$($entry.Key)  —  $($entry.Value)"
        $item.Tag     = $entry.Key
        $Set_Reg_ComboBox.Items.Add($item) | Out-Null
        }
    # Sélectionner 0x5944 par défaut
    $default = $Set_Reg_ComboBox.Items | Where-Object { $_.Tag -eq "0x5944" }
    if ($default) { $Set_Reg_ComboBox.SelectedItem = $default }

    # Check Bit Locker Status
    Get-BitLockerStatus

})

# Window closing event
$window.Add_Closing({
    Write-Host "Closing application..."
})
#endregion

#region Display window
$window.ShowDialog() | Out-Null
#endregion