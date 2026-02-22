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

#region XAML
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Check CA 2023"  Width="830" MaxWidth="830" MinWidth="830" Height="710" MaxHeight="800" MinHeight="710" Background="#FFE4EAF0" >

    <Window.Resources>
        <Style x:Key="ConfirmBoxButton" TargetType="{x:Type Button}">
            <Setter Property="Background"      Value="White" />
            <Setter Property="FontSize"        Value="16" />
            <Setter Property="Width"           Value="80"/>
            <Setter Property="Height"          Value="50"/>
            <Setter Property="BorderBrush"     Value="Black"/>
            <Setter Property="BorderThickness" Value="2"/>
            <Setter Property="FontWeight"      Value="Bold"/>
            <Setter Property="Padding"         Value="0"/>
            <Setter Property="Foreground"      Value="Black"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="{x:Type Button}">
                        <Border CornerRadius="1" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" >
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" />
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Setter Property="Effect">
                <Setter.Value>
                    <DropShadowEffect Color="Black" 
                                  Opacity="0.3" 
                                  BlurRadius="4" 
                                  ShadowDepth="2" 
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
                        <Border CornerRadius="1" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" >
                            <ContentPresenter HorizontalAlignment="Left" VerticalAlignment="Center" Margin="5,0,0,0" />
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Setter Property="Effect">
                <Setter.Value>
                    <DropShadowEffect Color="Black" 
                                  Opacity="0.3" 
                                  BlurRadius="4" 
                                  ShadowDepth="2" 
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
    </Window.Resources>

    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto" />
            <RowDefinition Height="325"  />
            <RowDefinition Height="Auto" />
            <RowDefinition Height="Auto" />
            <RowDefinition Height="*" />
        </Grid.RowDefinitions>

        <!-- Info - Model - Buttons -->
        <WrapPanel Grid.Row="0" HorizontalAlignment="Left" Margin="10,10,0,0" Orientation="Horizontal"  >
            <Border BorderThickness="1" BorderBrush="Gray" Background="#66D0D0D0" CornerRadius="5">
                <WrapPanel Orientation="Horizontal" HorizontalAlignment="Left" Width="240" Margin="5,2,0,0" >
                    <TextBox x:Name="WinVer" FontWeight="SemiBold" Margin="0,0,0,3" Text="Windows 11 Pro 24H2"
                       FontSize="12" Padding="0,0,0,0"
                       IsReadOnly="True"
                       BorderThickness="0"
                       Background="Transparent"
                       IsTabStop="False" Width="237" />
                    <TextBlock FontWeight="SemiBold" Text="Build : " Margin="0,0,0,0" FontSize="12"  />
                    <TextBox x:Name="WinBuild" FontWeight="SemiBold" Text="xxxx.yyyy" HorizontalContentAlignment="Center"
                            FontSize="12" IsReadOnly="True" BorderThickness="0.5" Background="#EEE" IsTabStop="False"
                            Width="80" Margin="0,0,110,0" />
                    <TextBlock  Text="Secure Boot : "   FontSize="12" Margin="0,0,0,4"  FontWeight="SemiBold" />
                    <TextBlock x:Name="tbSecureBoot"    FontSize="14" Margin="0,-4,0,0" Width="30" />
                </WrapPanel>
            </Border>
            <Border BorderThickness="1" BorderBrush="Gray" Background="#66D0D0D0" CornerRadius="5" Margin="10,0,0,0">
                <Grid Margin="5,0,0,4.5">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="70"/>
                        <ColumnDefinition Width="150"/>
                    </Grid.ColumnDefinitions>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>

                    <TextBlock Grid.Column="0" Grid.Row="0" Text="System Family :"  FontSize="10"
                       Background="Transparent" HorizontalAlignment="Right" />
                    <TextBlock x:Name="SystemFamily" Grid.Column="1" Grid.Row="0" FontSize="10"
                       Margin="10,0,0,0" Background="Transparent" FontWeight="SemiBold"/>

                    <TextBlock Grid.Column="0" Grid.Row="1" Text="Machine Type :"  FontSize="10"
                       Background="Transparent" HorizontalAlignment="Right" />
                    <TextBlock x:Name="MachineType" Grid.Column="1" Grid.Row="1" FontSize="10"
                       Margin="10,0,0,0" Background="Transparent" FontWeight="SemiBold"/>

                    <TextBlock Grid.Column="0" Grid.Row="2" Text="Bios Ver. :"  FontSize="10"
                       Background="Transparent" HorizontalAlignment="Right" />
                    <TextBlock x:Name="BiosVer" Grid.Column="1" Grid.Row="2" FontSize="10"
                       Margin="10,0,0,0" Background="Transparent" FontWeight="SemiBold"/>

                    <TextBlock Grid.Column="0" Grid.Row="3" Text="Bios Date :"  FontSize="10"
                       Background="Transparent" HorizontalAlignment="Right" />
                    <TextBlock x:Name="BiosDate" Grid.Column="1" Grid.Row="3" FontSize="10"
                       Margin="10,0,0,0" Background="Transparent" FontWeight="SemiBold"/>


                </Grid>
            </Border>
            <Button x:Name="btnExecute" Content="Check" Style="{StaticResource ConfirmBoxButton}" Margin="15,0,0,0" />
            <WrapPanel Orientation="Vertical" Width="190" Margin="20,0,00,0">
                <Button x:Name="Set_Reg_0x5944" Content="SET AvailableUpdates to 0x5944"             Margin="0,0,0,3" Width="190" Height="18" FontWeight="SemiBold" Style="{StaticResource ButtonStyle}"  />
                <Button x:Name="Start_Task"     Content="Start &quot;Secure-Boot-Update&quot; Task"  Margin="0,0,0,3" Width="190" Height="18" FontWeight="SemiBold" Style="{StaticResource ButtonStyle}"  />
                <Button x:Name="Log_CSV"       Content="Create/Append logs to CSV"                  Margin="0,0,0,0" Width="190" Height="18" FontWeight="SemiBold" Style="{StaticResource ButtonStyle}"  />
            </WrapPanel>
        </WrapPanel>




        <!-- Zone de sortie avec DataGrid -->
        <ScrollViewer Grid.Row="1" Margin="10,10,10,0" VerticalScrollBarVisibility="Auto">

            <WrapPanel >
                <TextBlock Text="UEFI Certificat 2023 :" Background="#FF3E8DDD" FontSize="18" FontWeight="SemiBold"
                       Foreground="White" Height="26" Width="737" Padding="10,0,0,0" HorizontalAlignment="Left"/>
                <!-- PK Active -->
                <StackPanel Orientation="Vertical">
                    <Label Content="PK Active (By OEM)" FontWeight="Bold" FontSize="12" Margin="0,0,0,-4" Foreground="BlueViolet"/>
                    <DataGrid x:Name="PK_Grid" 
                              Style="{StaticResource DataGridStyle1}"
                              Margin="0,0,8,00" 
                              Width="360" >
                        <DataGrid.Columns>
                            <DataGridTextColumn Header="Common Name (CN)" Binding="{Binding CN}" Width="220"/>
                            <DataGridTextColumn Header="Organization (O)" Binding="{Binding O}" Width="*"/>
                        </DataGrid.Columns>
                    </DataGrid>
                </StackPanel>
                <!-- PK Default -->
                <StackPanel Orientation="Vertical">
                    <Label Content="PK Default (By OEM)" FontWeight="Bold" FontSize="12" Margin="10,0,0,-4" Foreground="BlueViolet"/>
                    <DataGrid x:Name="PKDefault_Grid" 
                              Style="{StaticResource DataGridStyle1}"
                              Margin="10,0,8,00" 
                              Width="360" >
                        <DataGrid.Columns>
                            <DataGridTextColumn Header="Common Name (CN)" Binding="{Binding CN}" Width="220"/>
                            <DataGridTextColumn Header="Organization (O)" Binding="{Binding O}" Width="*"/>
                        </DataGrid.Columns>
                    </DataGrid>
                </StackPanel>
                <!-- KEK Active -->
                <StackPanel Orientation="Vertical">
                    <Label Content="KEK Active (By Microsoft)" FontWeight="Bold" FontSize="12" Margin="0,0,0,-4" Foreground="#FF3E8DDD"/>
                    <DataGrid x:Name="KEK_Grid" 
                              Style="{StaticResource DataGridStyle1}"
                              Margin="0,0,8,00" 
                              Width="360" >
                        <DataGrid.Columns>
                            <DataGridTextColumn Header="Common Name (CN)" Binding="{Binding CN}" Width="220"/>
                            <DataGridTextColumn Header="Organization (O)" Binding="{Binding O}" Width="*"/>
                        </DataGrid.Columns>
                    </DataGrid>
                </StackPanel>
                <!-- KEK Default -->
                <StackPanel Orientation="Vertical">
                    <Label Content="KEK Default (By OEM)" FontWeight="Bold" FontSize="12" Margin="10,0,0,-4" Foreground="BlueViolet"/>
                    <DataGrid x:Name="KEKDefault_Grid" 
                              Style="{StaticResource DataGridStyle1}"
                              Margin="10,0,8,00" 
                              Width="360" >
                        <DataGrid.Columns>
                            <DataGridTextColumn Header="Common Name (CN)" Binding="{Binding CN}" Width="220"/>
                            <DataGridTextColumn Header="Organization (O)" Binding="{Binding O}" Width="*"/>
                        </DataGrid.Columns>
                    </DataGrid>
                </StackPanel>
                <!-- DB Active -->
                <StackPanel Orientation="Vertical">
                    <Label Content="DB Active (By Microsoft)" FontWeight="Bold" FontSize="12" Margin="0,0,0,-4" Foreground="#FF3E8DDD"/>
                    <DataGrid x:Name="DB_Grid" 
                             Style="{StaticResource DataGridStyle1}"
                             Margin="0,0,8,00" 
                             Width="360" >
                        <DataGrid.Columns>
                            <DataGridTextColumn Header="Common Name (CN)" Binding="{Binding CN}" Width="220"/>
                            <DataGridTextColumn Header="Organization (O)" Binding="{Binding O}" Width="*"/>
                        </DataGrid.Columns>
                    </DataGrid>
                </StackPanel>
                <!-- DB Default -->
                <StackPanel Orientation="Vertical">
                    <Label Content="DB Default (By OEM)" FontWeight="Bold" FontSize="12" Margin="10,0,0,-4" Foreground="BlueViolet"/>
                    <DataGrid x:Name="DBDefault_Grid" 
                             Style="{StaticResource DataGridStyle1}"
                             Margin="10,0,8,00" 
                             Width="360" >
                        <DataGrid.Columns>
                            <DataGridTextColumn Header="Common Name (CN)" Binding="{Binding CN}" Width="220"/>
                            <DataGridTextColumn Header="Organization (O)" Binding="{Binding O}" Width="*"/>
                        </DataGrid.Columns>
                    </DataGrid>
                </StackPanel>
            </WrapPanel>

        </ScrollViewer>

        <WrapPanel Margin="10,10,10,0" Grid.Row="2" Visibility="Visible" >
            <TextBlock Text="Registry : " Background="#FF3E8DDD" FontSize="18" FontWeight="SemiBold"
                       Foreground="White" Height="26" Width="737" Padding="10,0,0,0" HorizontalAlignment="Left"/>
            <WrapPanel x:Name="Reg1" Orientation="Horizontal" VerticalAlignment="Center" Margin="0,2,0,0" Width="730">
                <TextBlock Text="AvailableUpdates :" FontSize="10" FontWeight="SemiBold"  Width="145" 
                           Foreground="#FF324873" VerticalAlignment="Center" Margin="0,0,5,0" TextAlignment="Right"/>
                <TextBlock x:Name="Reg1_HexValue" Text="" FontSize="10" FontWeight="Bold"
                           Foreground="Black" VerticalAlignment="Center" Margin="0,0,0,0" Width="40"/>
                <TextBlock x:Name="Reg1_Description" Text="" FontSize="10" TextAlignment="Left"
                           Foreground="Black" VerticalAlignment="Center" Width="530" />
            </WrapPanel>

            <WrapPanel x:Name="Reg2" Orientation="Horizontal" VerticalAlignment="Center" Margin="0,2,0,0"  Width="730">
                <TextBlock Text="UEFICA2023Status :" FontSize="10" FontWeight="SemiBold" Width="145" 
                           Foreground="#FF324873" VerticalAlignment="Center" Margin="0,0,5,0" TextAlignment="Right"/>
                <TextBlock x:Name="Reg2_Value" Text="" FontSize="10" FontWeight="Bold"
                           Foreground="Black" VerticalAlignment="Center" Margin="0,0,0,0" Width="55"/>
                <TextBlock x:Name="Reg2_Icon" Text="" FontSize="12" TextAlignment="Center" 
                           VerticalAlignment="Center" Margin="0,-5,5,0" Width="17"  FontWeight="ExtraBlack" />
                <TextBlock x:Name="Reg2_Description" Text="" FontSize="10" TextAlignment="Left"
                           Foreground="Black" VerticalAlignment="Center" Width="500" />
            </WrapPanel>

            <WrapPanel x:Name="Reg3" Orientation="Horizontal" VerticalAlignment="Center" Margin="0,2,0,0"  Width="730">
                <TextBlock Text="WindowsUEFICA2023Capable :" FontSize="10" FontWeight="SemiBold" Width="145" 
                           Foreground="#FF324873" VerticalAlignment="Center" Margin="0,0,5,0" TextAlignment="Right"/>
                <TextBlock x:Name="Reg3_HexValue" Text="" FontSize="10" FontWeight="Bold"
                           Foreground="Black" VerticalAlignment="Center" Margin="0,0,0,0" Width="55"/>
                <TextBlock x:Name="Reg3_Icon" Text="" FontSize="12" TextAlignment="Center" 
                           VerticalAlignment="Center" Margin="0,-4,5,0" Width="17" FontWeight="Bold"/>
                <TextBlock x:Name="Reg3_Description" Text="" FontSize="10" TextAlignment="Left"
                           Foreground="Black" VerticalAlignment="Center" Width="500" />
            </WrapPanel>

            <WrapPanel x:Name="Reg4" Orientation="Horizontal" VerticalAlignment="Center" Margin="0,2,0,0" MinWidth="700">
                <TextBlock Text="UEFICA2023ErrorEvent :" FontSize="10" FontWeight="SemiBold" Width="145"
                           Foreground="#FF324873" VerticalAlignment="Center" Margin="0,0,5,0" TextAlignment="Right"/>
                <TextBlock x:Name="Reg4_DecValue" Text="" FontSize="10" FontWeight="Bold"
                           Foreground="Black" VerticalAlignment="Center" Width="55"/>
                <TextBlock x:Name="Reg4_Icon" Text="" FontSize="12" TextAlignment="Center" 
                           VerticalAlignment="Center" Margin="0,-4,5,0" Width="17" FontWeight="Bold"/>
            </WrapPanel>
        </WrapPanel>

        <WrapPanel Margin="10,10,10,0" Grid.Row="3" Visibility="Visible" >
            <TextBlock Text="Event Viewer : " Background="#FF3E8DDD" FontSize="18" FontWeight="SemiBold"
                       Foreground="White" Height="26" Width="737" Padding="10,0,0,0" HorizontalAlignment="Left"/>
            <WrapPanel Orientation="Horizontal" Margin="10,10,0,0"  Width="727"   Background="#443E8DDD">
                <TextBlock x:Name="Event_Title"     Text="Event ID" FontSize="12" FontWeight="SemiBold" Width="60"  Foreground="#FF324873" Margin="0,0,0,0" TextAlignment="Center"/>
                <TextBlock x:Name="Event_Status"    Text="Status"   FontSize="12" FontWeight="SemiBold" Width="50"  Foreground="#FF324873" Margin="0,0,0,0" TextAlignment="Right"/>
                <TextBlock x:Name="Event_Icon"      Text=""         FontSize="12" FontWeight="SemiBold" Width="30"  Foreground="#FF324873" Margin="0,0,0,0" TextAlignment="Center"/>
                <TextBlock x:Name="Event_Message"   Text="Message"  FontSize="12" FontWeight="SemiBold" Width="500" Foreground="#FF324873" TextAlignment="Left" />
            </WrapPanel>
            <WrapPanel Orientation="Horizontal" Margin="10,0,0,0"   Width="727"   x:Name="WrapPanel_ErrorEvent" Visibility="Collapsed">
                <TextBlock x:Name="Error_Num"       Text=""         FontSize="12" FontWeight="SemiBold" Width="60"  Foreground="Black"  Margin="0,0,0,0" TextAlignment="Center"/>
                <TextBlock x:Name="Error_Status"    Text=""         FontSize="12" FontWeight="SemiBold" Width="50"  Foreground="Black"  Margin="0,0,0,0" TextAlignment="Right"/>
                <TextBlock x:Name="Error_Icon"      Text=""         FontSize="12" FontWeight="SemiBold" Width="30"  Foreground="Black"  Margin="0,0,0,0" TextAlignment="Center"/>
                <TextBlock x:Name="Error_Message"   Text=""         FontSize="11" FontWeight="Normal"   Width="578" Foreground="Black"  TextAlignment="Left" TextWrapping="Wrap" />
            </WrapPanel>
            <WrapPanel Orientation="Horizontal" Margin="10,0,0,0"       Width="727" >
                <TextBlock x:Name="_1808_Num"       Text="1808"         FontSize="12" FontWeight="SemiBold" Width="60"  Foreground="Black"  Margin="0,0,0,0" TextAlignment="Center"/>
                <TextBlock x:Name="_1808_Status"    Text="???         " FontSize="12" FontWeight="SemiBold" Width="50"  Foreground="Black"  Margin="0,0,0,0" TextAlignment="Right"/>
                <TextBlock x:Name="_1808_Icon"      Text=""             FontSize="12" FontWeight="SemiBold" Width="30"  Foreground="Black"  Margin="0,0,0,0" TextAlignment="Center"/>
                <TextBlock x:Name="_1808_Message"   Text=""             FontSize="12" FontWeight="SemiBold" Width="578" Foreground="Black"  TextAlignment="Left" TextWrapping="Wrap" />
            </WrapPanel>
        </WrapPanel>

        <!-- Barre de statut -->

        <StackPanel Grid.Row="4" Orientation="Horizontal" HorizontalAlignment="Left" Width="820">

            <Border x:Name="BorderStatus" Width="500" VerticalAlignment="Bottom" HorizontalAlignment="Left" Margin="20,10,0,17" Height="40"
                    Background="#F0F0F0" CornerRadius="10" BorderBrush="#FF324873" BorderThickness="1.5" >
                <StackPanel Orientation="Horizontal">
                    <TextBlock Text="Info :" FontWeight="Bold" FontSize="20" Margin="10,0,10,0" Padding="0,5,0,0" />
                    <TextBlock x:Name="TxtStatus" Text="Data retrieval completed successfully" Foreground="#FF324873"  FontSize="20" 
                           FontWeight="Bold" Padding="0,5,0,0" Margin="0,0,0,0" Width="400" />
                </StackPanel>
            </Border>

            <StackPanel x:Name="Cmd_Button" Grid.Row="4" Orientation="Horizontal"   VerticalAlignment="Bottom" Margin="60,0,0,10" Background="Transparent"  >
                <Border Background="#1A2B4A" Width="225" Height="55" Margin="0,0,0,0" CornerRadius="8" >
                    <Canvas Width="220" Height="55">

                        <!-- Shield -->
                        <Path Data="M25,6 L43,12 L43,26 C43,36 35,44 25,48 C15,44 7,36 7,26 L7,12 Z"
              Fill="#2E86DE" Stroke="#5BA3F5" StrokeThickness="3"/>

                        <!-- Checkmark -->
                        <Polyline Points="24,21 34,32 50,15"
                  Fill="Transparent" Stroke="#01D210" StrokeThickness="6"
                  StrokeStartLineCap="Round" StrokeEndLineCap="Round"
                  StrokeLineJoin="Round"/>

                        <!-- Check -->
                        <TextBlock Canvas.Left="60" Canvas.Top="1"
                   Text="Check" FontFamily="Segoe UI" FontSize="20"
                   FontWeight="Bold" Foreground="White"/>
                        <!-- CA -->
                        <TextBlock Canvas.Left="119" Canvas.Top="1"
                   Text="CA" FontFamily="Segoe UI" FontSize="20"
                   FontWeight="Bold" Foreground="#2E86DE"/>
                        <!-- 2023 -->
                        <TextBlock Canvas.Left="146" Canvas.Top="1"
                   Text="2023" FontFamily="Segoe UI" FontSize="20"
                   FontWeight="Bold" Foreground="#5BA3F5"/>
                        <!-- Subtitle -->
                        <TextBlock Canvas.Left="61" Canvas.Top="26"
                   Text="UEFI Certificate Monitor" FontFamily="Segoe UI"
                   FontSize="9" Foreground="#8AAFD4"/>
                        <!-- Version -->
                        <TextBlock Canvas.Left="61" Canvas.Top="38"
                   Text="Version : 1.1.0" FontFamily="Segoe UI"
                   FontSize="10" FontWeight="Bold" Foreground="#8AAFD4"/>
                    </Canvas>
                </Border>

            </StackPanel>
        </StackPanel>
    </Grid>
</Window>


"@
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)
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
$Set_Reg_0x5944 = Get-XamlControl -Name "Set_Reg_0x5944"
$Start_Task     = Get-XamlControl -Name "Start_Task"
$Log_CSV        = Get-XamlControl -Name "Log_CSV"

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

# Set AvailableUpdates to 0x5944
if ($Set_Reg_0x5944) {
    $Set_Reg_0x5944.Add_Click({
        try {
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot" `
                             -Name "AvailableUpdates" `
                             -Value 0x5944 `
                             -Type DWord -Force
            Update-StatusLabel -Message "AvailableUpdates set to 0x5944" -Color "Green"
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