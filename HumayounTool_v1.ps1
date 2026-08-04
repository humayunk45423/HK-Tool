#Requires -Version 5.1

# Self-elevate to Administrator if not already
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

# ---------------------------------------------------------------------------
# Diagnostics
# ---------------------------------------------------------------------------

function Get-BatteryInfo {
    try {
        $tmpPath = "$env:TEMP\batreport_hktool.html"
        powercfg /batteryreport /output $tmpPath 2>$null | Out-Null
        if (Test-Path $tmpPath) {
            $html    = Get-Content $tmpPath -Raw -ErrorAction Stop
            $design  = 0
            $full    = 0
            $cycles  = -1
            if ($html -match 'DESIGN CAPACITY\s*</span>[^<]*<span[^>]*>\s*([\d,]+)\s*mWh')       { $design  = [int]($Matches[1] -replace ',','') }
            if ($html -match 'FULL CHARGE CAPACITY\s*</span>[^<]*<span[^>]*>\s*([\d,]+)\s*mWh') { $full    = [int]($Matches[1] -replace ',','') }
            if ($html -match 'CYCLE COUNT\s*</span>[^<]*<span[^>]*>\s*(\d+)')                    { $cycles  = [int]$Matches[1] }
            Remove-Item $tmpPath -Force -ErrorAction SilentlyContinue
            $health = if ($design -gt 0) { [math]::Round($full / $design * 100, 1) } else { -1 }
            return @{ DesignmWh = $design; FullmWh = $full; CycleCount = $cycles; HealthPct = $health }
        }
    } catch {}
    return @{ DesignmWh = 0; FullmWh = 0; CycleCount = -1; HealthPct = -1 }
}

function Get-StorageInfo {
    $drives = @()
    try {
        $disks = Get-PhysicalDisk -ErrorAction Stop
        foreach ($d in $disks) {
            $rel = $null
            try { $rel = $d | Get-StorageReliabilityCounter -ErrorAction Stop } catch {}
            $drives += @{
                FriendlyName = $d.FriendlyName
                MediaType    = $d.MediaType
                Size         = [math]::Round($d.Size / 1GB, 0)
                HealthStatus = $d.HealthStatus
                WearLevel    = if ($rel) { $rel.Wear }        else { -1 }
                Temperature  = if ($rel) { $rel.Temperature } else { -1 }
            }
        }
    } catch {}
    return $drives
}

function Get-SystemInfo {
    $cpu      = (Get-CimInstance Win32_Processor        -ErrorAction SilentlyContinue | Select-Object -First 1).Name
    $gpus     = (Get-CimInstance Win32_VideoController  -ErrorAction SilentlyContinue).Name -join ', '
    $ram      = [math]::Round((Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue |
                    Measure-Object -Property Capacity -Sum).Sum / 1GB, 0)
    $os       = (Get-CimInstance Win32_OperatingSystem  -ErrorAction SilentlyContinue).Caption
    $bios     = (Get-CimInstance Win32_BIOS             -ErrorAction SilentlyContinue).ReleaseDate
    $biosDate = if ($bios) { $bios.ToString('yyyy-MM-dd') } else { 'Unknown' }
    return @{ CPU = $cpu; GPU = $gpus; RAM = $ram; OS = $os; BIOSDate = $biosDate }
}

# ---------------------------------------------------------------------------
# Scoring
# ---------------------------------------------------------------------------

function Calc-StorageScore {
    param($drives)
    if (-not $drives -or $drives.Count -eq 0) { return 50 }
    $scores = foreach ($d in $drives) {
        if ($d.HealthStatus -eq 'Healthy') {
            if ($d.WearLevel -ge 0) { [math]::Max(0, 100 - $d.WearLevel) } else { 85 }
        } else { 30 }
    }
    return [math]::Round(($scores | Measure-Object -Average).Average, 0)
}

function Calc-Price {
    param([double]$basePrice, [double]$batteryPct, [double]$storageScore, [double]$conditionScore)
    $diagScore    = ($batteryPct + $storageScore) / 2
    $overallScore = ($diagScore * 0.5 + $conditionScore * 0.5) / 100
    $min = [math]::Round($basePrice * $overallScore * 0.85, -2)
    $max = [math]::Round($basePrice * $overallScore * 1.05, -2)
    return @{ Min = $min; Max = $max; OverallPct = [math]::Round($overallScore * 100, 1) }
}

function Get-BatteryNote {
    param([double]$pct)
    if ($pct -ge 90) { return 'Excellent -- battery is in great shape.' }
    if ($pct -ge 75) { return 'Good -- noticeable degradation, still usable.' }
    if ($pct -ge 50) { return 'Fair -- consider disclosing reduced runtime to the buyer.' }
    return 'Poor -- battery replacement expected soon. Disclose this.'
}

# ---------------------------------------------------------------------------
# XAML UI
# ---------------------------------------------------------------------------

[xml]$xaml = @'
<Window
  xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
  xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
  Title="Humayoun Tool v1 -- Resale Diagnostics"
  Width="820" Height="640"
  MinWidth="720" MinHeight="520"
  WindowStartupLocation="CenterScreen"
  Background="#111A14"
  Foreground="#EAF7EF"
  FontFamily="Segoe UI">

  <Window.Resources>

    <Style TargetType="TabItem">
      <Setter Property="Foreground" Value="#8AB8A0"/>
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Padding" Value="16,8"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="TabItem">
            <Border Name="Bd" Background="Transparent" Padding="16,9" Margin="0,0,2,0" CornerRadius="8,8,0,0">
              <ContentPresenter ContentSource="Header"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsSelected" Value="True">
                <Setter TargetName="Bd" Property="Background" Value="#1C3328"/>
                <Setter Property="Foreground" Value="#4ECC8B"/>
              </Trigger>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Bd" Property="Background" Value="#162A1F"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style TargetType="Button" x:Key="AccentBtn">
      <Setter Property="Background" Value="#1C7A54"/>
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Padding" Value="20,9"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border Background="{TemplateBinding Background}" CornerRadius="8" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter Property="Background" Value="#125C3E"/>
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter Property="Background" Value="#0D4530"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style TargetType="TextBox" x:Key="DarkInput">
      <Setter Property="Background" Value="#1A2A20"/>
      <Setter Property="Foreground" Value="#EAF7EF"/>
      <Setter Property="BorderBrush" Value="#2E4A3E"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="10,7"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="CaretBrush" Value="#4ECC8B"/>
    </Style>

    <Style TargetType="ProgressBar" x:Key="GreenBar">
      <Setter Property="Background" Value="#1A2A20"/>
      <Setter Property="Foreground" Value="#1C7A54"/>
      <Setter Property="Height" Value="8"/>
      <Setter Property="BorderThickness" Value="0"/>
    </Style>

    <Style TargetType="ComboBox" x:Key="DarkCombo">
      <Setter Property="Background" Value="#1A2A20"/>
      <Setter Property="Foreground" Value="#EAF7EF"/>
      <Setter Property="BorderBrush" Value="#2E4A3E"/>
      <Setter Property="Padding" Value="8,5"/>
      <Setter Property="FontSize" Value="13"/>
    </Style>

  </Window.Resources>

  <Grid>
    <Grid.RowDefinitions>
      <RowDefinition Height="52"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <!-- Header bar -->
    <Border Grid.Row="0" Background="#0D1710" BorderBrush="#1C3328" BorderThickness="0,0,0,1">
      <Grid Margin="20,0">
        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
          <Border Background="#1C7A54" CornerRadius="8" Width="32" Height="32" Margin="0,0,12,0">
            <TextBlock Text="H" FontSize="15" FontWeight="Bold"
                       HorizontalAlignment="Center" VerticalAlignment="Center" Foreground="White"/>
          </Border>
          <TextBlock Text="Humayoun Tool" FontSize="15" FontWeight="Bold" Foreground="White" VerticalAlignment="Center"/>
          <Border Background="#1A2A20" CornerRadius="999" Margin="10,0,0,0" Padding="6,2">
            <TextBlock Text="v1" FontSize="10" Foreground="#4ECC8B" FontFamily="Consolas"/>
          </Border>
        </StackPanel>
        <TextBlock Name="StatusText" HorizontalAlignment="Right" VerticalAlignment="Center"
                   FontSize="12" Foreground="#4B7A60" Text="Ready -- click Run Full Scan to begin"/>
      </Grid>
    </Border>

    <!-- Tab control -->
    <TabControl Grid.Row="1" Name="MainTabs" Background="#111A14" BorderThickness="0"
                Padding="0" TabStripPlacement="Top">

      <!-- Overview Tab -->
      <TabItem Header="Overview">
        <ScrollViewer VerticalScrollBarVisibility="Auto">
          <StackPanel Margin="28,24">
            <TextBlock Text="System Overview" FontSize="18" FontWeight="Bold" Foreground="White" Margin="0,0,0,20"/>

            <Grid Margin="0,0,0,14">
              <Grid.ColumnDefinitions>
                <ColumnDefinition/>
                <ColumnDefinition Width="14"/>
                <ColumnDefinition/>
              </Grid.ColumnDefinitions>
              <Border Grid.Column="0" Background="#141F19" CornerRadius="12" Padding="18">
                <StackPanel>
                  <TextBlock Text="PROCESSOR" FontSize="10" Foreground="#4B7A60" FontWeight="SemiBold" Margin="0,0,0,6"/>
                  <TextBlock Name="LblCPU" Text="Not scanned yet" FontSize="13" Foreground="#D0EED8" TextWrapping="Wrap"/>
                </StackPanel>
              </Border>
              <Border Grid.Column="2" Background="#141F19" CornerRadius="12" Padding="18">
                <StackPanel>
                  <TextBlock Text="GRAPHICS" FontSize="10" Foreground="#4B7A60" FontWeight="SemiBold" Margin="0,0,0,6"/>
                  <TextBlock Name="LblGPU" Text="Not scanned yet" FontSize="13" Foreground="#D0EED8" TextWrapping="Wrap"/>
                </StackPanel>
              </Border>
            </Grid>

            <Grid Margin="0,0,0,24">
              <Grid.ColumnDefinitions>
                <ColumnDefinition/>
                <ColumnDefinition Width="14"/>
                <ColumnDefinition/>
                <ColumnDefinition Width="14"/>
                <ColumnDefinition/>
              </Grid.ColumnDefinitions>
              <Border Grid.Column="0" Background="#141F19" CornerRadius="12" Padding="18">
                <StackPanel>
                  <TextBlock Text="RAM" FontSize="10" Foreground="#4B7A60" FontWeight="SemiBold" Margin="0,0,0,6"/>
                  <TextBlock Name="LblRAM" Text="--" FontSize="26" FontWeight="Bold" Foreground="White"/>
                  <TextBlock Text="GB installed" FontSize="11" Foreground="#4B7A60"/>
                </StackPanel>
              </Border>
              <Border Grid.Column="2" Background="#141F19" CornerRadius="12" Padding="18">
                <StackPanel>
                  <TextBlock Text="BIOS DATE" FontSize="10" Foreground="#4B7A60" FontWeight="SemiBold" Margin="0,0,0,6"/>
                  <TextBlock Name="LblBIOS" Text="--" FontSize="14" Foreground="#D0EED8"/>
                  <TextBlock Text="approx. manufacture date" FontSize="11" Foreground="#4B7A60"/>
                </StackPanel>
              </Border>
              <Border Grid.Column="4" Background="#141F19" CornerRadius="12" Padding="18">
                <StackPanel>
                  <TextBlock Text="OS" FontSize="10" Foreground="#4B7A60" FontWeight="SemiBold" Margin="0,0,0,6"/>
                  <TextBlock Name="LblOS" Text="--" FontSize="12" Foreground="#D0EED8" TextWrapping="Wrap"/>
                </StackPanel>
              </Border>
            </Grid>

            <Button Name="BtnScan" Content="Run Full Scan" Style="{StaticResource AccentBtn}"
                    HorizontalAlignment="Left" FontSize="13"/>
          </StackPanel>
        </ScrollViewer>
      </TabItem>

      <!-- Battery Tab -->
      <TabItem Header="Battery">
        <ScrollViewer VerticalScrollBarVisibility="Auto">
          <StackPanel Margin="28,24">
            <TextBlock Text="Battery Health" FontSize="18" FontWeight="Bold" Foreground="White" Margin="0,0,0,20"/>

            <Grid Margin="0,0,0,14">
              <Grid.ColumnDefinitions>
                <ColumnDefinition/>
                <ColumnDefinition Width="14"/>
                <ColumnDefinition/>
                <ColumnDefinition Width="14"/>
                <ColumnDefinition/>
              </Grid.ColumnDefinitions>
              <Border Grid.Column="0" Background="#141F19" CornerRadius="12" Padding="18">
                <StackPanel>
                  <TextBlock Text="HEALTH" FontSize="10" Foreground="#4B7A60" FontWeight="SemiBold" Margin="0,0,0,6"/>
                  <TextBlock Name="LblBatHealth" Text="--" FontSize="30" FontWeight="Bold" Foreground="White"/>
                  <ProgressBar Name="BarBatHealth" Style="{StaticResource GreenBar}" Margin="0,10,0,0" Maximum="100"/>
                </StackPanel>
              </Border>
              <Border Grid.Column="2" Background="#141F19" CornerRadius="12" Padding="18">
                <StackPanel>
                  <TextBlock Text="CYCLE COUNT" FontSize="10" Foreground="#4B7A60" FontWeight="SemiBold" Margin="0,0,0,6"/>
                  <TextBlock Name="LblCycles" Text="--" FontSize="30" FontWeight="Bold" Foreground="White"/>
                  <TextBlock Text="charge cycles" FontSize="11" Foreground="#4B7A60"/>
                </StackPanel>
              </Border>
              <Border Grid.Column="4" Background="#141F19" CornerRadius="12" Padding="18">
                <StackPanel>
                  <TextBlock Text="CAPACITY" FontSize="10" Foreground="#4B7A60" FontWeight="SemiBold" Margin="0,0,0,6"/>
                  <TextBlock Name="LblCapNow" Text="--" FontSize="16" FontWeight="Bold" Foreground="White"/>
                  <TextBlock Text="current full charge" FontSize="11" Foreground="#4B7A60"/>
                  <TextBlock Name="LblCapDesign" Text="--" FontSize="11" Foreground="#4B7A60" Margin="0,4,0,0"/>
                </StackPanel>
              </Border>
            </Grid>

            <Border Background="#141F19" CornerRadius="12" Padding="18">
              <StackPanel>
                <TextBlock Text="INTERPRETATION" FontSize="10" Foreground="#4B7A60" FontWeight="SemiBold" Margin="0,0,0,8"/>
                <TextBlock Name="LblBatNote" Text="Run a scan to see battery notes."
                           FontSize="13" Foreground="#8AB8A0" TextWrapping="Wrap"/>
              </StackPanel>
            </Border>
          </StackPanel>
        </ScrollViewer>
      </TabItem>

      <!-- Storage Tab -->
      <TabItem Header="Storage">
        <ScrollViewer VerticalScrollBarVisibility="Auto">
          <StackPanel Margin="28,24" Name="StoragePanel">
            <TextBlock Text="Storage Health" FontSize="18" FontWeight="Bold" Foreground="White" Margin="0,0,0,20"/>
            <TextBlock Name="LblStoragePH" Text="Run a scan to see storage details."
                       FontSize="13" Foreground="#4B7A60"/>
          </StackPanel>
        </ScrollViewer>
      </TabItem>

      <!-- Condition Survey Tab -->
      <TabItem Header="Condition Survey">
        <ScrollViewer VerticalScrollBarVisibility="Auto">
          <StackPanel Margin="28,24">
            <TextBlock Text="Physical Condition Survey" FontSize="18" FontWeight="Bold" Foreground="White" Margin="0,0,0,6"/>
            <TextBlock Text="Answer honestly -- this directly affects the price estimate."
                       FontSize="13" Foreground="#4B7A60" Margin="0,0,0,24"/>

            <TextBlock Text="SCREEN" FontSize="10" FontWeight="SemiBold" Foreground="#4B7A60" Margin="0,0,0,6"/>
            <ComboBox Name="CboScreen" Style="{StaticResource DarkCombo}" Margin="0,0,0,16">
              <ComboBoxItem Content="Perfect -- no scratches, no dead pixels" Tag="100"/>
              <ComboBoxItem Content="Minor scratches -- barely visible" Tag="85"/>
              <ComboBoxItem Content="Noticeable scratches or light bleed" Tag="65"/>
              <ComboBoxItem Content="Crack or significant damage" Tag="30"/>
            </ComboBox>

            <TextBlock Text="BODY / CHASSIS" FontSize="10" FontWeight="SemiBold" Foreground="#4B7A60" Margin="0,0,0,6"/>
            <ComboBox Name="CboBody" Style="{StaticResource DarkCombo}" Margin="0,0,0,16">
              <ComboBoxItem Content="Like new -- no dents or scratches" Tag="100"/>
              <ComboBoxItem Content="Light scratches, no dents" Tag="85"/>
              <ComboBoxItem Content="Visible dents or chips" Tag="60"/>
              <ComboBoxItem Content="Cracked or heavily damaged" Tag="25"/>
            </ComboBox>

            <TextBlock Text="KEYBOARD" FontSize="10" FontWeight="SemiBold" Foreground="#4B7A60" Margin="0,0,0,6"/>
            <ComboBox Name="CboKeyboard" Style="{StaticResource DarkCombo}" Margin="0,0,0,16">
              <ComboBoxItem Content="All keys work perfectly" Tag="100"/>
              <ComboBoxItem Content="Minor key fade / slight sticking" Tag="80"/>
              <ComboBoxItem Content="1-2 keys faulty" Tag="55"/>
              <ComboBoxItem Content="Multiple keys not working" Tag="20"/>
            </ComboBox>

            <TextBlock Text="PORTS" FontSize="10" FontWeight="SemiBold" Foreground="#4B7A60" Margin="0,0,0,6"/>
            <ComboBox Name="CboPorts" Style="{StaticResource DarkCombo}" Margin="0,0,0,16">
              <ComboBoxItem Content="All ports functional" Tag="100"/>
              <ComboBoxItem Content="One port loose or non-functional" Tag="80"/>
              <ComboBoxItem Content="Multiple ports faulty" Tag="50"/>
            </ComboBox>

            <TextBlock Text="WEBCAM" FontSize="10" FontWeight="SemiBold" Foreground="#4B7A60" Margin="0,0,0,6"/>
            <ComboBox Name="CboWebcam" Style="{StaticResource DarkCombo}" Margin="0,0,0,16">
              <ComboBoxItem Content="Works fine" Tag="100"/>
              <ComboBoxItem Content="Slightly blurry / intermittent" Tag="70"/>
              <ComboBoxItem Content="Not working" Tag="40"/>
              <ComboBoxItem Content="No webcam (desktop or removed)" Tag="90"/>
            </ComboBox>

            <TextBlock Text="SPEAKERS" FontSize="10" FontWeight="SemiBold" Foreground="#4B7A60" Margin="0,0,0,6"/>
            <ComboBox Name="CboSpeakers" Style="{StaticResource DarkCombo}" Margin="0,0,0,16">
              <ComboBoxItem Content="Clear sound, both speakers" Tag="100"/>
              <ComboBoxItem Content="Slight distortion at high volume" Tag="80"/>
              <ComboBoxItem Content="One speaker not working" Tag="55"/>
              <ComboBoxItem Content="No audio" Tag="20"/>
            </ComboBox>

            <Button Name="BtnCondition" Content="Calculate Condition Score"
                    Style="{StaticResource AccentBtn}" HorizontalAlignment="Left"
                    FontSize="13" Margin="0,8,0,0"/>
          </StackPanel>
        </ScrollViewer>
      </TabItem>

      <!-- Price Estimate Tab -->
      <TabItem Header="Price Estimate">
        <ScrollViewer VerticalScrollBarVisibility="Auto">
          <StackPanel Margin="28,24">
            <TextBlock Text="Resale Price Estimate" FontSize="18" FontWeight="Bold" Foreground="White" Margin="0,0,0,6"/>
            <TextBlock Text="Enter a base market price for this model, then calculate."
                       FontSize="13" Foreground="#4B7A60" Margin="0,0,0,24"/>

            <TextBlock Text="BASE MARKET PRICE (BDT)" FontSize="10" FontWeight="SemiBold" Foreground="#4B7A60" Margin="0,0,0,6"/>
            <TextBox Name="TxtBasePrice" Style="{StaticResource DarkInput}" Width="220"
                     HorizontalAlignment="Left" Margin="0,0,0,6"/>
            <TextBlock Text="Tip: check Bikroy.com for comparable listings in good condition."
                       FontSize="11" Foreground="#3A5E4A" Margin="0,0,0,20"/>

            <Button Name="BtnPrice" Content="Calculate Price" Style="{StaticResource AccentBtn}"
                    HorizontalAlignment="Left" FontSize="13" Margin="0,0,0,28"/>

            <Border Name="PriceCard" Background="#0D2B1C" CornerRadius="16" Padding="28" Visibility="Collapsed">
              <StackPanel>
                <TextBlock Text="OVERALL SCORE" FontSize="10" FontWeight="SemiBold" Foreground="#4B7A60" Margin="0,0,0,6"/>
                <TextBlock Name="LblScore" FontSize="32" FontWeight="Bold" Foreground="White" Margin="0,0,0,18"/>
                <TextBlock Text="FAIR RESALE RANGE" FontSize="10" FontWeight="SemiBold" Foreground="#4B7A60" Margin="0,0,0,6"/>
                <TextBlock Name="LblPriceRange" FontSize="26" FontWeight="Bold" Foreground="#C97A2E" Margin="0,0,0,8"/>
                <TextBlock Name="LblPriceNote" FontSize="12" Foreground="#4B7A60" TextWrapping="Wrap"/>
              </StackPanel>
            </Border>
          </StackPanel>
        </ScrollViewer>
      </TabItem>

    </TabControl>

    <!-- Footer status bar -->
    <Border Grid.Row="2" Background="#0D1710" BorderBrush="#1C3328" BorderThickness="0,1,0,0" Padding="20,8">
      <TextBlock Name="FooterText" FontSize="11" Foreground="#3A5E4A"
                 Text="Humayoun Tool v1  |  Windows only  |  Open source"/>
    </Border>
  </Grid>
</Window>
'@

# ---------------------------------------------------------------------------
# Load window
# ---------------------------------------------------------------------------

$reader = [System.Xml.XmlNodeReader]::new($xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

$MainTabs      = $window.FindName('MainTabs')
$StatusText    = $window.FindName('StatusText')
$FooterText    = $window.FindName('FooterText')
$BtnScan       = $window.FindName('BtnScan')
$LblCPU        = $window.FindName('LblCPU')
$LblGPU        = $window.FindName('LblGPU')
$LblRAM        = $window.FindName('LblRAM')
$LblBIOS       = $window.FindName('LblBIOS')
$LblOS         = $window.FindName('LblOS')
$LblBatHealth  = $window.FindName('LblBatHealth')
$BarBatHealth  = $window.FindName('BarBatHealth')
$LblCycles     = $window.FindName('LblCycles')
$LblCapNow     = $window.FindName('LblCapNow')
$LblCapDesign  = $window.FindName('LblCapDesign')
$LblBatNote    = $window.FindName('LblBatNote')
$StoragePanel  = $window.FindName('StoragePanel')
$LblStoragePH  = $window.FindName('LblStoragePH')
$CboScreen     = $window.FindName('CboScreen')
$CboBody       = $window.FindName('CboBody')
$CboKeyboard   = $window.FindName('CboKeyboard')
$CboPorts      = $window.FindName('CboPorts')
$CboWebcam     = $window.FindName('CboWebcam')
$CboSpeakers   = $window.FindName('CboSpeakers')
$BtnCondition  = $window.FindName('BtnCondition')
$TxtBasePrice  = $window.FindName('TxtBasePrice')
$BtnPrice      = $window.FindName('BtnPrice')
$PriceCard     = $window.FindName('PriceCard')
$LblScore      = $window.FindName('LblScore')
$LblPriceRange = $window.FindName('LblPriceRange')
$LblPriceNote  = $window.FindName('LblPriceNote')

# Default selections
foreach ($c in @($CboScreen, $CboBody, $CboKeyboard, $CboPorts, $CboWebcam, $CboSpeakers)) {
    $c.SelectedIndex = 0
}

# Script-scoped state
$script:BatInfo        = $null
$script:StorDrives     = $null
$script:SysInfo        = $null
$script:ConditionScore = -1

# ---------------------------------------------------------------------------
# Scan button
# ---------------------------------------------------------------------------

$BtnScan.Add_Click({
    $StatusText.Text   = 'Scanning hardware...'
    $BtnScan.IsEnabled = $false
    $disp = $window.Dispatcher

    $job = [System.Threading.Tasks.Task]::Run({
        $bat  = Get-BatteryInfo
        $stor = Get-StorageInfo
        $sys  = Get-SystemInfo
        return [PSCustomObject]@{ Bat = $bat; Stor = $stor; Sys = $sys }
    })

    $null = $job.ContinueWith({
        param($t)
        $r = $t.Result
        $disp.Invoke([Action]{

            $script:BatInfo    = $r.Bat
            $script:StorDrives = $r.Stor
            $script:SysInfo    = $r.Sys

            # Overview
            $LblCPU.Text  = if ($r.Sys.CPU)  { $r.Sys.CPU  } else { 'Not detected' }
            $LblGPU.Text  = if ($r.Sys.GPU)  { $r.Sys.GPU  } else { 'Not detected' }
            $LblRAM.Text  = if ($r.Sys.RAM)  { [string]$r.Sys.RAM } else { '--' }
            $LblBIOS.Text = if ($r.Sys.BIOSDate) { $r.Sys.BIOSDate } else { 'Unknown' }
            $LblOS.Text   = if ($r.Sys.OS)   { $r.Sys.OS   } else { 'Unknown' }

            # Battery
            $bat = $r.Bat
            if ($bat.HealthPct -ge 0) {
                $LblBatHealth.Text     = "$($bat.HealthPct)%"
                $BarBatHealth.Value    = [math]::Min($bat.HealthPct, 100)
                $LblBatNote.Text       = Get-BatteryNote $bat.HealthPct
                $LblCycles.Text        = if ($bat.CycleCount -ge 0) { [string]$bat.CycleCount } else { 'N/A' }
                $LblCapNow.Text        = if ($bat.FullmWh -gt 0)    { "$([math]::Round($bat.FullmWh/1000,1)) Wh" }    else { 'N/A' }
                $LblCapDesign.Text     = if ($bat.DesignmWh -gt 0)  { "$([math]::Round($bat.DesignmWh/1000,1)) Wh design" } else { '--' }
            } else {
                $LblBatHealth.Text = 'No battery'
                $LblBatNote.Text   = 'No battery detected -- may be a desktop or report could not be read.'
            }

            # Storage -- remove old dynamic cards first
            $toRemove = @()
            foreach ($child in $StoragePanel.Children) {
                if ($child -is [System.Windows.Controls.Border] -and $child.Tag -eq 'drive') {
                    $toRemove += $child
                }
            }
            foreach ($c in $toRemove) { $null = $StoragePanel.Children.Remove($c) }

            if (-not $r.Stor -or $r.Stor.Count -eq 0) {
                $LblStoragePH.Text = 'No drives detected (requires admin access).'
                $LblStoragePH.Visibility = 'Visible'
            } else {
                $LblStoragePH.Visibility = 'Collapsed'
                $bc = [Windows.Media.BrushConverter]::new()
                foreach ($d in $r.Stor) {
                    $card = [Windows.Controls.Border]::new()
                    $card.Tag          = 'drive'
                    $card.Background   = $bc.ConvertFromString('#141F19')
                    $card.CornerRadius = [Windows.CornerRadius]::new(12)
                    $card.Padding      = [Windows.Thickness]::new(18)
                    $card.Margin       = [Windows.Thickness]::new(0, 0, 0, 14)

                    $sp = [Windows.Controls.StackPanel]::new()

                    $t1 = [Windows.Controls.TextBlock]::new()
                    $t1.Text       = $d.FriendlyName
                    $t1.FontSize   = 14
                    $t1.FontWeight = [Windows.FontWeights]::SemiBold
                    $t1.Foreground = $bc.ConvertFromString('#D0EED8')
                    $t1.TextWrapping = 'Wrap'

                    $t2 = [Windows.Controls.TextBlock]::new()
                    $t2.Text       = "$($d.MediaType)   $($d.Size) GB   Status: $($d.HealthStatus)"
                    $t2.FontSize   = 12
                    $t2.Foreground = $bc.ConvertFromString('#4B7A60')
                    $t2.Margin     = [Windows.Thickness]::new(0, 4, 0, 0)

                    $null = $sp.Children.Add($t1)
                    $null = $sp.Children.Add($t2)

                    if ($d.WearLevel -ge 0) {
                        $t3 = [Windows.Controls.TextBlock]::new()
                        $tempStr = if ($d.Temperature -ge 0) { "$($d.Temperature) C" } else { 'N/A' }
                        $t3.Text       = "Wear level: $($d.WearLevel)%   Temperature: $tempStr"
                        $t3.FontSize   = 12
                        $t3.Foreground = $bc.ConvertFromString('#4B7A60')
                        $t3.Margin     = [Windows.Thickness]::new(0, 4, 0, 0)
                        $null = $sp.Children.Add($t3)
                    }

                    $card.Child = $sp
                    $null = $StoragePanel.Children.Add($card)
                }
            }

            $now = Get-Date -Format 'HH:mm'
            $StatusText.Text   = "Scan complete ($now)"
            $FooterText.Text   = "Humayoun Tool v1  |  Last scan: $now"
            $BtnScan.IsEnabled = $true
        })
    }, [System.Threading.Tasks.TaskScheduler]::Default)
})

# ---------------------------------------------------------------------------
# Condition survey
# ---------------------------------------------------------------------------

$BtnCondition.Add_Click({
    $combos = @($CboScreen, $CboBody, $CboKeyboard, $CboPorts, $CboWebcam, $CboSpeakers)
    $scores = foreach ($c in $combos) {
        if ($c.SelectedItem) { [int]$c.SelectedItem.Tag } else { 80 }
    }
    $script:ConditionScore = [math]::Round(($scores | Measure-Object -Average).Average, 0)
    $StatusText.Text = "Condition score: $($script:ConditionScore)/100 -- now go to Price Estimate"
    $MainTabs.SelectedIndex = 4
    $TxtBasePrice.Focus()
})

# ---------------------------------------------------------------------------
# Price calculation
# ---------------------------------------------------------------------------

$BtnPrice.Add_Click({
    $baseStr = $TxtBasePrice.Text -replace '[^\d]', ''
    $baseVal = 0
    if (-not $baseStr -or -not [int]::TryParse($baseStr, [ref]$baseVal) -or $baseVal -le 0) {
        [System.Windows.MessageBox]::Show(
            'Please enter a valid base price (numbers only, e.g. 45000).',
            'Input needed', 'OK', 'Warning')
        return
    }

    if (-not $script:BatInfo) {
        [System.Windows.MessageBox]::Show(
            'Run a full scan first (Overview tab > Run Full Scan).',
            'Scan needed', 'OK', 'Warning')
        return
    }

    if ($script:ConditionScore -lt 0) {
        [System.Windows.MessageBox]::Show(
            'Complete the Condition Survey first.',
            'Survey needed', 'OK', 'Warning')
        return
    }

    $batPct    = if ($script:BatInfo.HealthPct -ge 0) { $script:BatInfo.HealthPct } else { 80 }
    $storScore = Calc-StorageScore $script:StorDrives
    $result    = Calc-Price $baseVal $batPct $storScore $script:ConditionScore

    $LblScore.Text       = "$($result.OverallPct)% overall condition"
    $LblPriceRange.Text  = "Tk $("{0:N0}" -f $result.Min) -- Tk $("{0:N0}" -f $result.Max)"
    $LblPriceNote.Text   = "Battery health: $([math]::Round($batPct,0))%   Storage score: $storScore/100   Condition: $($script:ConditionScore)/100`nBase price used: Tk $("{0:N0}" -f $baseVal)"
    $PriceCard.Visibility = 'Visible'
    $StatusText.Text = "Price estimate ready"
})

# ---------------------------------------------------------------------------
# Launch
# ---------------------------------------------------------------------------

$null = $window.ShowDialog()
