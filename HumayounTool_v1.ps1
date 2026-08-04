#Requires -Version 5.1

# Self-elevate to Administrator
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

# ---------------------------------------------------------------------------
# Scoring helpers  (run on UI thread -- no runspace needed)
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
    param([double]$base, [double]$batPct, [double]$storScore, [double]$condScore)
    $diag  = ($batPct + $storScore) / 2
    $total = ($diag * 0.5 + $condScore * 0.5) / 100
    return @{
        Min        = [math]::Round($base * $total * 0.85, -2)
        Max        = [math]::Round($base * $total * 1.05, -2)
        OverallPct = [math]::Round($total * 100, 1)
    }
}

# ---------------------------------------------------------------------------
# XAML  -- pure black / white minimalist
# ---------------------------------------------------------------------------
[xml]$xaml = @'
<Window
  xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
  xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
  Title="Humayoun Tool"
  Width="960" Height="700"
  MinWidth="800" MinHeight="580"
  WindowStartupLocation="CenterScreen"
  Background="#080808"
  Foreground="#E0E0E0"
  FontFamily="Segoe UI"
  SnapsToDevicePixels="True"
  UseLayoutRounding="True">

  <Window.Resources>

    <Style x:Key="Card" TargetType="Border">
      <Setter Property="Background"       Value="#111111"/>
      <Setter Property="BorderBrush"      Value="#242424"/>
      <Setter Property="BorderThickness"  Value="1"/>
      <Setter Property="CornerRadius"     Value="10"/>
      <Setter Property="Padding"          Value="20"/>
    </Style>

    <Style x:Key="FieldLabel" TargetType="TextBlock">
      <Setter Property="FontSize"    Value="10"/>
      <Setter Property="FontWeight"  Value="SemiBold"/>
      <Setter Property="Foreground"  Value="#404040"/>
      <Setter Property="Margin"      Value="0,0,0,6"/>
    </Style>

    <Style x:Key="BigNum" TargetType="TextBlock">
      <Setter Property="FontSize"   Value="28"/>
      <Setter Property="FontWeight" Value="Bold"/>
      <Setter Property="Foreground" Value="#F0F0F0"/>
      <Setter Property="Margin"     Value="0,0,0,4"/>
    </Style>

    <Style x:Key="BodyText" TargetType="TextBlock">
      <Setter Property="FontSize"      Value="13"/>
      <Setter Property="Foreground"    Value="#C0C0C0"/>
      <Setter Property="TextWrapping"  Value="Wrap"/>
    </Style>

    <Style x:Key="PrimaryBtn" TargetType="Button">
      <Setter Property="Background"      Value="#E0E0E0"/>
      <Setter Property="Foreground"      Value="#080808"/>
      <Setter Property="FontWeight"      Value="SemiBold"/>
      <Setter Property="FontSize"        Value="13"/>
      <Setter Property="Padding"         Value="24,10"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Cursor"          Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border Name="Bd" Background="{TemplateBinding Background}" CornerRadius="6" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Bd" Property="Background" Value="#FFFFFF"/>
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter TargetName="Bd" Property="Background" Value="#B0B0B0"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter TargetName="Bd" Property="Background" Value="#1E1E1E"/>
                <Setter Property="Foreground" Value="#383838"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="DarkInput" TargetType="TextBox">
      <Setter Property="Background"     Value="#111111"/>
      <Setter Property="Foreground"     Value="#E0E0E0"/>
      <Setter Property="BorderBrush"    Value="#2A2A2A"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding"        Value="12,9"/>
      <Setter Property="FontSize"       Value="13"/>
      <Setter Property="CaretBrush"     Value="#E0E0E0"/>
    </Style>

    <Style x:Key="DarkCombo" TargetType="ComboBox">
      <Setter Property="Background"     Value="#111111"/>
      <Setter Property="Foreground"     Value="#E0E0E0"/>
      <Setter Property="BorderBrush"    Value="#2A2A2A"/>
      <Setter Property="FontSize"       Value="13"/>
      <Setter Property="Padding"        Value="10,8"/>
    </Style>

    <Style x:Key="SlimBar" TargetType="ProgressBar">
      <Setter Property="Background"       Value="#1E1E1E"/>
      <Setter Property="Foreground"       Value="#E0E0E0"/>
      <Setter Property="Height"           Value="4"/>
      <Setter Property="BorderThickness"  Value="0"/>
      <Setter Property="Maximum"          Value="100"/>
    </Style>

    <!-- Custom tab strip -->
    <Style TargetType="TabItem">
      <Setter Property="FontSize"    Value="13"/>
      <Setter Property="Foreground"  Value="#484848"/>
      <Setter Property="Padding"     Value="0"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="TabItem">
            <Border Name="Bd" Padding="20,12" BorderThickness="0,0,0,2" BorderBrush="Transparent" Background="Transparent">
              <ContentPresenter ContentSource="Header" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsSelected" Value="True">
                <Setter TargetName="Bd" Property="BorderBrush" Value="#E0E0E0"/>
                <Setter Property="Foreground" Value="#E0E0E0"/>
              </Trigger>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter Property="Foreground" Value="#909090"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Tab control chrome -->
    <Style TargetType="TabControl">
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="TabControl">
            <Grid>
              <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
              </Grid.RowDefinitions>
              <Border Grid.Row="0" Background="#0C0C0C" BorderBrush="#1E1E1E" BorderThickness="0,0,0,1">
                <TabPanel IsItemsHost="True" Background="Transparent" Margin="10,0,0,0"/>
              </Border>
              <Border Grid.Row="1" Background="#080808">
                <ContentPresenter ContentSource="SelectedContent"/>
              </Border>
            </Grid>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

  </Window.Resources>

  <Grid>
    <Grid.RowDefinitions>
      <RowDefinition Height="56"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="38"/>
    </Grid.RowDefinitions>

    <!-- Header -->
    <Border Grid.Row="0" Background="#0C0C0C" BorderBrush="#1E1E1E" BorderThickness="0,0,0,1">
      <Grid Margin="28,0">
        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
          <Border Width="30" Height="30" CornerRadius="7" Background="#1A1A1A" BorderBrush="#2E2E2E" BorderThickness="1" Margin="0,0,12,0">
            <TextBlock Text="H" FontSize="13" FontWeight="Bold" Foreground="#C0C0C0"
                       HorizontalAlignment="Center" VerticalAlignment="Center"/>
          </Border>
          <TextBlock Text="Humayoun Tool" FontSize="14" FontWeight="SemiBold" Foreground="#D0D0D0" VerticalAlignment="Center"/>
          <Border Background="#151515" CornerRadius="4" Margin="10,0,0,0" Padding="6,2" BorderBrush="#242424" BorderThickness="1">
            <TextBlock Text="v1" FontSize="10" Foreground="#484848" FontFamily="Consolas"/>
          </Border>
        </StackPanel>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
          <Ellipse Name="StatusDot" Width="6" Height="6" Fill="#303030" Margin="0,0,8,0"/>
          <TextBlock Name="StatusText" FontSize="12" Foreground="#484848" VerticalAlignment="Center"
                     Text="Ready -- click Run Full Scan"/>
        </StackPanel>
      </Grid>
    </Border>

    <!-- Main tabs -->
    <TabControl Grid.Row="1" Name="MainTabs">

      <!-- Overview -->
      <TabItem Header="Overview">
        <ScrollViewer VerticalScrollBarVisibility="Auto" Background="#080808">
          <StackPanel Margin="32,28,32,32">

            <TextBlock Text="System Overview" FontSize="20" FontWeight="Bold"
                       Foreground="#E8E8E8" Margin="0,0,0,24"/>

            <!-- CPU + GPU row -->
            <Grid Margin="0,0,0,12">
              <Grid.ColumnDefinitions>
                <ColumnDefinition/>
                <ColumnDefinition Width="12"/>
                <ColumnDefinition/>
              </Grid.ColumnDefinitions>
              <Border Grid.Column="0" Style="{StaticResource Card}">
                <StackPanel>
                  <TextBlock Text="PROCESSOR" Style="{StaticResource FieldLabel}"/>
                  <TextBlock Name="LblCPU" Style="{StaticResource BodyText}" Text="Not scanned yet"/>
                </StackPanel>
              </Border>
              <Border Grid.Column="2" Style="{StaticResource Card}">
                <StackPanel>
                  <TextBlock Text="GRAPHICS" Style="{StaticResource FieldLabel}"/>
                  <TextBlock Name="LblGPU" Style="{StaticResource BodyText}" Text="Not scanned yet"/>
                </StackPanel>
              </Border>
            </Grid>

            <!-- RAM + BIOS + OS row -->
            <Grid Margin="0,0,0,28">
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="0.6*"/>
                <ColumnDefinition Width="12"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="12"/>
                <ColumnDefinition Width="*"/>
              </Grid.ColumnDefinitions>
              <Border Grid.Column="0" Style="{StaticResource Card}">
                <StackPanel>
                  <TextBlock Text="RAM" Style="{StaticResource FieldLabel}"/>
                  <TextBlock Name="LblRAM" Style="{StaticResource BigNum}" Text="--"/>
                  <TextBlock Text="GB installed" FontSize="11" Foreground="#404040"/>
                </StackPanel>
              </Border>
              <Border Grid.Column="2" Style="{StaticResource Card}">
                <StackPanel>
                  <TextBlock Text="BIOS DATE" Style="{StaticResource FieldLabel}"/>
                  <TextBlock Name="LblBIOS" Style="{StaticResource BodyText}" Text="--"/>
                  <TextBlock Text="approx. manufacture date" FontSize="11" Foreground="#404040" Margin="0,4,0,0"/>
                </StackPanel>
              </Border>
              <Border Grid.Column="4" Style="{StaticResource Card}">
                <StackPanel>
                  <TextBlock Text="OPERATING SYSTEM" Style="{StaticResource FieldLabel}"/>
                  <TextBlock Name="LblOS" Style="{StaticResource BodyText}" Text="--"/>
                </StackPanel>
              </Border>
            </Grid>

            <Button Name="BtnScan" Content="Run Full Scan"
                    Style="{StaticResource PrimaryBtn}" HorizontalAlignment="Left"/>

          </StackPanel>
        </ScrollViewer>
      </TabItem>

      <!-- Battery -->
      <TabItem Header="Battery">
        <ScrollViewer VerticalScrollBarVisibility="Auto" Background="#080808">
          <StackPanel Margin="32,28,32,32">

            <TextBlock Text="Battery Health" FontSize="20" FontWeight="Bold"
                       Foreground="#E8E8E8" Margin="0,0,0,24"/>

            <Grid Margin="0,0,0,12">
              <Grid.ColumnDefinitions>
                <ColumnDefinition/>
                <ColumnDefinition Width="12"/>
                <ColumnDefinition/>
                <ColumnDefinition Width="12"/>
                <ColumnDefinition/>
              </Grid.ColumnDefinitions>

              <Border Grid.Column="0" Style="{StaticResource Card}">
                <StackPanel>
                  <TextBlock Text="HEALTH" Style="{StaticResource FieldLabel}"/>
                  <TextBlock Name="LblBatHealth" Style="{StaticResource BigNum}" Text="--"/>
                  <ProgressBar Name="BarBatHealth" Style="{StaticResource SlimBar}" Margin="0,8,0,0"/>
                </StackPanel>
              </Border>

              <Border Grid.Column="2" Style="{StaticResource Card}">
                <StackPanel>
                  <TextBlock Text="CYCLE COUNT" Style="{StaticResource FieldLabel}"/>
                  <TextBlock Name="LblCycles" Style="{StaticResource BigNum}" Text="--"/>
                  <TextBlock Text="charge cycles" FontSize="11" Foreground="#404040"/>
                </StackPanel>
              </Border>

              <Border Grid.Column="4" Style="{StaticResource Card}">
                <StackPanel>
                  <TextBlock Text="CAPACITY" Style="{StaticResource FieldLabel}"/>
                  <TextBlock Name="LblCapNow" FontSize="16" FontWeight="Bold" Foreground="#F0F0F0" Margin="0,0,0,4"/>
                  <TextBlock Text="current full charge" FontSize="11" Foreground="#404040"/>
                  <TextBlock Name="LblCapDesign" FontSize="11" Foreground="#404040" Margin="0,6,0,0"/>
                </StackPanel>
              </Border>
            </Grid>

            <Border Style="{StaticResource Card}">
              <StackPanel>
                <TextBlock Text="CONDITION SUMMARY" Style="{StaticResource FieldLabel}"/>
                <TextBlock Name="LblBatNote" Style="{StaticResource BodyText}"
                           Text="Run a scan to see battery health notes."/>
              </StackPanel>
            </Border>

          </StackPanel>
        </ScrollViewer>
      </TabItem>

      <!-- Storage -->
      <TabItem Header="Storage">
        <ScrollViewer VerticalScrollBarVisibility="Auto" Background="#080808">
          <StackPanel Name="StoragePanel" Margin="32,28,32,32">
            <TextBlock Text="Storage Health" FontSize="20" FontWeight="Bold"
                       Foreground="#E8E8E8" Margin="0,0,0,24"/>
            <TextBlock Name="LblStoragePH" Style="{StaticResource BodyText}"
                       Text="Run a scan to see storage details." Foreground="#404040"/>
          </StackPanel>
        </ScrollViewer>
      </TabItem>

      <!-- Condition Survey -->
      <TabItem Header="Condition Survey">
        <ScrollViewer VerticalScrollBarVisibility="Auto" Background="#080808">
          <StackPanel Margin="32,28,32,32">

            <TextBlock Text="Condition Survey" FontSize="20" FontWeight="Bold"
                       Foreground="#E8E8E8" Margin="0,0,0,6"/>
            <TextBlock Text="Answer honestly -- this affects your price estimate."
                       Style="{StaticResource BodyText}" Foreground="#505050" Margin="0,0,0,28"/>

            <Border Style="{StaticResource Card}" Margin="0,0,0,12">
              <Grid>
                <Grid.ColumnDefinitions>
                  <ColumnDefinition Width="*"/>
                  <ColumnDefinition Width="280"/>
                </Grid.ColumnDefinitions>
                <Grid.RowDefinitions>
                  <RowDefinition/><RowDefinition Height="16"/><RowDefinition/>
                  <RowDefinition Height="16"/><RowDefinition/>
                  <RowDefinition Height="16"/><RowDefinition/>
                  <RowDefinition Height="16"/><RowDefinition/>
                  <RowDefinition Height="16"/><RowDefinition/>
                </Grid.RowDefinitions>

                <!-- Screen -->
                <TextBlock Grid.Row="0" Grid.Column="0" Text="Screen" FontSize="13" Foreground="#C0C0C0" VerticalAlignment="Center"/>
                <ComboBox Grid.Row="0" Grid.Column="1" Name="CboScreen" Style="{StaticResource DarkCombo}">
                  <ComboBoxItem Content="Perfect -- no scratches, no dead pixels"   Tag="100" IsSelected="True"/>
                  <ComboBoxItem Content="Minor scratches -- barely visible"           Tag="85"/>
                  <ComboBoxItem Content="Noticeable scratches or light bleed"         Tag="65"/>
                  <ComboBoxItem Content="Crack or significant damage"                 Tag="30"/>
                </ComboBox>

                <!-- Body -->
                <TextBlock Grid.Row="2" Grid.Column="0" Text="Body / Chassis" FontSize="13" Foreground="#C0C0C0" VerticalAlignment="Center"/>
                <ComboBox Grid.Row="2" Grid.Column="1" Name="CboBody" Style="{StaticResource DarkCombo}">
                  <ComboBoxItem Content="Like new -- no dents or scratches"   Tag="100" IsSelected="True"/>
                  <ComboBoxItem Content="Light scratches, no dents"            Tag="85"/>
                  <ComboBoxItem Content="Visible dents or chips"               Tag="60"/>
                  <ComboBoxItem Content="Cracked or heavily damaged"           Tag="25"/>
                </ComboBox>

                <!-- Keyboard -->
                <TextBlock Grid.Row="4" Grid.Column="0" Text="Keyboard" FontSize="13" Foreground="#C0C0C0" VerticalAlignment="Center"/>
                <ComboBox Grid.Row="4" Grid.Column="1" Name="CboKeyboard" Style="{StaticResource DarkCombo}">
                  <ComboBoxItem Content="All keys work perfectly"              Tag="100" IsSelected="True"/>
                  <ComboBoxItem Content="Minor fade or slight sticking"        Tag="80"/>
                  <ComboBoxItem Content="1-2 keys faulty"                      Tag="55"/>
                  <ComboBoxItem Content="Multiple keys not working"            Tag="20"/>
                </ComboBox>

                <!-- Ports -->
                <TextBlock Grid.Row="6" Grid.Column="0" Text="Ports" FontSize="13" Foreground="#C0C0C0" VerticalAlignment="Center"/>
                <ComboBox Grid.Row="6" Grid.Column="1" Name="CboPorts" Style="{StaticResource DarkCombo}">
                  <ComboBoxItem Content="All ports functional"                  Tag="100" IsSelected="True"/>
                  <ComboBoxItem Content="One port loose or non-functional"      Tag="80"/>
                  <ComboBoxItem Content="Multiple ports faulty"                 Tag="50"/>
                </ComboBox>

                <!-- Webcam -->
                <TextBlock Grid.Row="8" Grid.Column="0" Text="Webcam" FontSize="13" Foreground="#C0C0C0" VerticalAlignment="Center"/>
                <ComboBox Grid.Row="8" Grid.Column="1" Name="CboWebcam" Style="{StaticResource DarkCombo}">
                  <ComboBoxItem Content="Works fine"                             Tag="100" IsSelected="True"/>
                  <ComboBoxItem Content="Slightly blurry / intermittent"         Tag="70"/>
                  <ComboBoxItem Content="Not working"                            Tag="40"/>
                  <ComboBoxItem Content="No webcam (desktop)"                   Tag="90"/>
                </ComboBox>

                <!-- Speakers -->
                <TextBlock Grid.Row="10" Grid.Column="0" Text="Speakers" FontSize="13" Foreground="#C0C0C0" VerticalAlignment="Center"/>
                <ComboBox Grid.Row="10" Grid.Column="1" Name="CboSpeakers" Style="{StaticResource DarkCombo}">
                  <ComboBoxItem Content="Clear sound, both speakers"             Tag="100" IsSelected="True"/>
                  <ComboBoxItem Content="Slight distortion at high volume"       Tag="80"/>
                  <ComboBoxItem Content="One speaker not working"                Tag="55"/>
                  <ComboBoxItem Content="No audio"                               Tag="20"/>
                </ComboBox>

              </Grid>
            </Border>

            <Button Name="BtnCondition" Content="Calculate Condition Score"
                    Style="{StaticResource PrimaryBtn}" HorizontalAlignment="Left"/>

          </StackPanel>
        </ScrollViewer>
      </TabItem>

      <!-- Price Estimate -->
      <TabItem Header="Price Estimate">
        <ScrollViewer VerticalScrollBarVisibility="Auto" Background="#080808">
          <StackPanel Margin="32,28,32,32">

            <TextBlock Text="Resale Price Estimate" FontSize="20" FontWeight="Bold"
                       Foreground="#E8E8E8" Margin="0,0,0,6"/>
            <TextBlock Text="Enter the typical used market price for this model in good condition."
                       Style="{StaticResource BodyText}" Foreground="#505050" Margin="0,0,0,24"/>

            <TextBlock Text="BASE MARKET PRICE (BDT)" Style="{StaticResource FieldLabel}"/>
            <TextBox Name="TxtBasePrice" Style="{StaticResource DarkInput}" Width="240"
                     HorizontalAlignment="Left" Margin="0,0,0,8"/>
            <TextBlock Text="Check Bikroy.com for comparable listings." FontSize="11"
                       Foreground="#383838" Margin="0,0,0,24"/>

            <Button Name="BtnPrice" Content="Calculate Price"
                    Style="{StaticResource PrimaryBtn}" HorizontalAlignment="Left" Margin="0,0,0,28"/>

            <!-- Result card -->
            <Border Name="PriceCard" Style="{StaticResource Card}" Visibility="Collapsed">
              <Grid>
                <Grid.ColumnDefinitions>
                  <ColumnDefinition/>
                  <ColumnDefinition Width="1"/>
                  <ColumnDefinition/>
                </Grid.ColumnDefinitions>

                <StackPanel Grid.Column="0" Margin="0,0,24,0">
                  <TextBlock Text="OVERALL SCORE" Style="{StaticResource FieldLabel}"/>
                  <TextBlock Name="LblScore" Style="{StaticResource BigNum}"/>
                  <TextBlock Name="LblScoreSub" FontSize="12" Foreground="#505050" Margin="0,4,0,0"/>
                </StackPanel>

                <Border Grid.Column="1" Background="#1E1E1E" Width="1"/>

                <StackPanel Grid.Column="2" Margin="24,0,0,0">
                  <TextBlock Text="FAIR RESALE RANGE" Style="{StaticResource FieldLabel}"/>
                  <TextBlock Name="LblPriceRange" FontSize="22" FontWeight="Bold" Foreground="#F0F0F0" Margin="0,0,0,8"/>
                  <TextBlock Name="LblPriceNote" FontSize="11" Foreground="#484848" TextWrapping="Wrap"/>
                </StackPanel>
              </Grid>
            </Border>

          </StackPanel>
        </ScrollViewer>
      </TabItem>

    </TabControl>

    <!-- Status bar -->
    <Border Grid.Row="2" Background="#0A0A0A" BorderBrush="#1A1A1A" BorderThickness="0,1,0,0" Padding="28,0">
      <TextBlock Name="FooterText" FontSize="11" Foreground="#303030" VerticalAlignment="Center"
                 Text="Humayoun Tool v1   Windows only   Open source"/>
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
$StatusDot     = $window.FindName('StatusDot')
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
$LblScoreSub   = $window.FindName('LblScoreSub')
$LblPriceRange = $window.FindName('LblPriceRange')
$LblPriceNote  = $window.FindName('LblPriceNote')

# Script-scope state
$script:BatInfo        = $null
$script:StorDrives     = $null
$script:SysInfo        = $null
$script:ConditionScore = -1
$script:dotCount       = 0

# ---------------------------------------------------------------------------
# Scan button  --  FIXED: uses PowerShell.Create() + BeginInvoke() + DispatcherTimer
#                  All diagnostic functions defined INLINE inside the scriptblock
#                  because the new runspace has no access to the outer session.
# ---------------------------------------------------------------------------
$BtnScan.Add_Click({
    $StatusText.Text       = 'Scanning hardware...'
    $StatusDot.Fill        = [Windows.Media.Brushes]::DimGray
    $BtnScan.IsEnabled     = $false
    $script:dotCount       = 0

    # Create a fresh PowerShell instance with its own runspace
    $script:scanPS = [System.Management.Automation.PowerShell]::Create()

    $null = $script:scanPS.AddScript({

        # -- Battery -------------------------------------------------------
        function Get-BatteryInfo {
            try {
                $tmp = "$env:TEMP\batreport_hktool.html"
                powercfg /batteryreport /output $tmp 2>$null | Out-Null
                if (Test-Path $tmp) {
                    $html   = Get-Content $tmp -Raw -ErrorAction Stop
                    $design = 0; $full = 0; $cycles = -1
                    if ($html -match 'DESIGN CAPACITY\s*</span>[^<]*<span[^>]*>\s*([\d,]+)\s*mWh')       { $design  = [int]($Matches[1] -replace ',','') }
                    if ($html -match 'FULL CHARGE CAPACITY\s*</span>[^<]*<span[^>]*>\s*([\d,]+)\s*mWh') { $full    = [int]($Matches[1] -replace ',','') }
                    if ($html -match 'CYCLE COUNT\s*</span>[^<]*<span[^>]*>\s*(\d+)')                    { $cycles  = [int]$Matches[1] }
                    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
                    $health = if ($design -gt 0) { [math]::Round($full / $design * 100, 1) } else { -1 }
                    return @{ DesignmWh=$design; FullmWh=$full; CycleCount=$cycles; HealthPct=$health }
                }
            } catch {}
            return @{ DesignmWh=0; FullmWh=0; CycleCount=-1; HealthPct=-1 }
        }

        # -- Storage -------------------------------------------------------
        function Get-StorageInfo {
            $drives = @()
            try {
                foreach ($d in (Get-PhysicalDisk -ErrorAction Stop)) {
                    $rel = $null
                    try { $rel = $d | Get-StorageReliabilityCounter -ErrorAction Stop } catch {}
                    $drives += @{
                        FriendlyName = $d.FriendlyName
                        MediaType    = $d.MediaType
                        Size         = [math]::Round($d.Size / 1GB, 0)
                        HealthStatus = $d.HealthStatus
                        WearLevel    = if ($rel -and $null -ne $rel.Wear)        { $rel.Wear }        else { -1 }
                        Temperature  = if ($rel -and $null -ne $rel.Temperature) { $rel.Temperature } else { -1 }
                    }
                }
            } catch {}
            return $drives
        }

        # -- System --------------------------------------------------------
        function Get-SystemInfo {
            $cpu  = (Get-CimInstance Win32_Processor       -ErrorAction SilentlyContinue | Select-Object -First 1).Name
            $gpus = (Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue).Name -join ', '
            $ram  = [math]::Round(
                (Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue |
                    Measure-Object -Property Capacity -Sum).Sum / 1GB, 0)
            $os   = (Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue).Caption
            $bios = (Get-CimInstance Win32_BIOS            -ErrorAction SilentlyContinue).ReleaseDate
            return @{
                CPU      = if ($cpu)  { $cpu }  else { 'Not detected' }
                GPU      = if ($gpus) { $gpus } else { 'Not detected' }
                RAM      = $ram
                OS       = if ($os)   { $os }   else { 'Unknown' }
                BIOSDate = if ($bios) { $bios.ToString('yyyy-MM-dd') } else { 'Unknown' }
            }
        }

        # Run all three and return a single object
        [PSCustomObject]@{
            Bat  = Get-BatteryInfo
            Stor = Get-StorageInfo
            Sys  = Get-SystemInfo
        }
    })

    # Start async
    $script:scanHandle = $script:scanPS.BeginInvoke()

    # Poll on the UI thread every 350ms using DispatcherTimer
    $script:scanTimer = [System.Windows.Threading.DispatcherTimer]::new()
    $script:scanTimer.Interval = [TimeSpan]::FromMilliseconds(350)
    $script:scanTimer.Add_Tick({

        # Animate status dots while running
        if (-not $script:scanHandle.IsCompleted) {
            $script:dotCount = ($script:dotCount % 3) + 1
            $StatusText.Text = 'Scanning hardware' + ('.' * $script:dotCount)
            return
        }

        # Scan done
        $script:scanTimer.Stop()

        try {
            $r = $script:scanPS.EndInvoke($script:scanHandle)[0]
            $script:BatInfo    = $r.Bat
            $script:StorDrives = $r.Stor
            $script:SysInfo    = $r.Sys

            # -- Overview --
            $LblCPU.Text  = $r.Sys.CPU
            $LblGPU.Text  = $r.Sys.GPU
            $LblRAM.Text  = if ($r.Sys.RAM -gt 0) { [string]$r.Sys.RAM } else { '--' }
            $LblBIOS.Text = $r.Sys.BIOSDate
            $LblOS.Text   = $r.Sys.OS

            # -- Battery --
            $bat = $r.Bat
            if ($bat.HealthPct -ge 0) {
                $LblBatHealth.Text  = "$($bat.HealthPct)%"
                $BarBatHealth.Value = [math]::Min($bat.HealthPct, 100)

                # Color-code health
                $bc = [Windows.Media.BrushConverter]::new()
                if ($bat.HealthPct -ge 80)      { $LblBatHealth.Foreground = $bc.ConvertFromString('#E0E0E0') }
                elseif ($bat.HealthPct -ge 60)  { $LblBatHealth.Foreground = $bc.ConvertFromString('#F0A030') }
                else                            { $LblBatHealth.Foreground = $bc.ConvertFromString('#FF4040') }

                $LblCycles.Text = if ($bat.CycleCount -ge 0) { [string]$bat.CycleCount } else { 'N/A' }
                $LblCapNow.Text    = if ($bat.FullmWh   -gt 0) { "$([math]::Round($bat.FullmWh/1000,1)) Wh" }   else { 'N/A' }
                $LblCapDesign.Text = if ($bat.DesignmWh -gt 0) { "Design capacity: $([math]::Round($bat.DesignmWh/1000,1)) Wh" } else { '' }

                $LblBatNote.Text = switch -exact ($true) {
                    ($bat.HealthPct -ge 90) { 'Excellent -- battery is in great shape.' }
                    ($bat.HealthPct -ge 75) { 'Good -- some degradation, still usable for most buyers.' }
                    ($bat.HealthPct -ge 50) { 'Fair -- reduced runtime. Consider disclosing this to the buyer.' }
                    default                 { 'Poor -- battery replacement likely needed. Disclose this clearly.' }
                }
            } else {
                $LblBatHealth.Text = 'N/A'
                $LblBatNote.Text   = 'No battery detected -- may be a desktop, or report could not be generated.'
            }

            # -- Storage -- remove old drive cards first
            $toRemove = [System.Collections.Generic.List[object]]::new()
            foreach ($child in $StoragePanel.Children) {
                if ($child -is [System.Windows.Controls.Border] -and $child.Tag -eq 'drivecard') {
                    $toRemove.Add($child)
                }
            }
            foreach ($c in $toRemove) { $null = $StoragePanel.Children.Remove($c) }

            if (-not $r.Stor -or $r.Stor.Count -eq 0) {
                $LblStoragePH.Text       = 'No drives detected (requires admin access).'
                $LblStoragePH.Visibility = 'Visible'
            } else {
                $LblStoragePH.Visibility = 'Collapsed'
                $bc = [Windows.Media.BrushConverter]::new()
                foreach ($d in $r.Stor) {
                    $card            = [Windows.Controls.Border]::new()
                    $card.Tag        = 'drivecard'
                    $card.Background = $bc.ConvertFromString('#111111')
                    $card.BorderBrush   = $bc.ConvertFromString('#242424')
                    $card.BorderThickness = [Windows.Thickness]::new(1)
                    $card.CornerRadius = [Windows.CornerRadius]::new(10)
                    $card.Padding    = [Windows.Thickness]::new(20)
                    $card.Margin     = [Windows.Thickness]::new(0, 0, 0, 12)

                    $sp = [Windows.Controls.StackPanel]::new()

                    $mkTb = {
                        param($text, $size, $color, $margin)
                        $tb             = [Windows.Controls.TextBlock]::new()
                        $tb.Text        = $text
                        $tb.FontSize    = $size
                        $tb.Foreground  = $bc.ConvertFromString($color)
                        $tb.TextWrapping = 'Wrap'
                        if ($margin) { $tb.Margin = $margin }
                        $tb
                    }

                    $null = $sp.Children.Add((&$mkTb $d.FriendlyName 14 '#D8D8D8' $null))

                    $sub1 = "$($d.MediaType)  |  $($d.Size) GB  |  Status: $($d.HealthStatus)"
                    $null = $sp.Children.Add((&$mkTb $sub1 12 '#484848' ([Windows.Thickness]::new(0,6,0,0))))

                    if ($d.WearLevel -ge 0) {
                        $tempStr = if ($d.Temperature -ge 0) { "$($d.Temperature) C" } else { 'N/A' }
                        $sub2    = "Wear level: $($d.WearLevel)%   |   Temperature: $tempStr"
                        $null = $sp.Children.Add((&$mkTb $sub2 12 '#404040' ([Windows.Thickness]::new(0,4,0,0))))
                    }

                    $card.Child = $sp
                    $null = $StoragePanel.Children.Add($card)
                }
            }

            # Update status
            $now              = Get-Date -Format 'HH:mm'
            $StatusText.Text  = "Scan complete  $now"
            $StatusDot.Fill   = $bc.ConvertFromString('#58D68D')
            $FooterText.Text  = "Humayoun Tool v1   Last scan: $now"

        } catch {
            $StatusText.Text = "Scan error: $($_.Exception.Message)"
            $StatusDot.Fill  = [Windows.Media.Brushes]::Firebrick
        } finally {
            $script:scanPS.Dispose()
            $BtnScan.IsEnabled = $true
        }
    })
    $script:scanTimer.Start()
})

# ---------------------------------------------------------------------------
# Condition survey
# ---------------------------------------------------------------------------
$BtnCondition.Add_Click({
    $combos = @($CboScreen, $CboBody, $CboKeyboard, $CboPorts, $CboWebcam, $CboSpeakers)
    $scores = foreach ($c in $combos) {
        if ($c.SelectedItem) { [int]$c.SelectedItem.Tag } else { 80 }
    }
    $script:ConditionScore  = [math]::Round(($scores | Measure-Object -Average).Average, 0)
    $StatusText.Text         = "Condition score: $($script:ConditionScore)/100   Now go to Price Estimate"
    $MainTabs.SelectedIndex  = 4
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
            'Enter a valid base price (numbers only, e.g. 45000).',
            'Input required', 'OK', 'Warning')
        return
    }
    if (-not $script:BatInfo) {
        [System.Windows.MessageBox]::Show(
            'Run a full scan first (Overview tab).',
            'Scan required', 'OK', 'Warning')
        return
    }
    if ($script:ConditionScore -lt 0) {
        [System.Windows.MessageBox]::Show(
            'Complete the Condition Survey first.',
            'Survey required', 'OK', 'Warning')
        return
    }

    $batPct    = if ($script:BatInfo.HealthPct -ge 0) { $script:BatInfo.HealthPct } else { 80 }
    $storScore = Calc-StorageScore $script:StorDrives
    $result    = Calc-Price $baseVal $batPct $storScore $script:ConditionScore

    $LblScore.Text      = "$($result.OverallPct)%"
    $LblScoreSub.Text   = "Battery $([math]::Round($batPct,0))%   Storage $storScore/100   Condition $($script:ConditionScore)/100"
    $LblPriceRange.Text = "Tk $("{0:N0}" -f $result.Min)  --  Tk $("{0:N0}" -f $result.Max)"
    $LblPriceNote.Text  = "Based on base price of Tk $("{0:N0}" -f $baseVal)"
    $PriceCard.Visibility = 'Visible'
    $StatusText.Text    = "Price estimate ready"
})

# ---------------------------------------------------------------------------
# Launch
# ---------------------------------------------------------------------------
$null = $window.ShowDialog()
