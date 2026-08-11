#Requires -Version 5.1

# Self-elevate to Administrator
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

# ---------------------------------------------------------------------------
# XAML  -- Premium Modern UI
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
        Min        = [math]::Round(($base * $total * 0.85) / 100) * 100
        Max        = [math]::Round(($base * $total * 1.05) / 100) * 100
        OverallPct = [math]::Round($total * 100, 1)
    }
}

function Calc-HardwareBaseValue {
    param($sys, $storDrives)
    
    $cpu = $sys.CPU
    $ram = $sys.RAM
    $gpus = $sys.GPU
    $manuf = $sys.Manufacturer
    $type = $sys.SystemType
    $biosDate = $sys.BIOSDate

    $msrp = 25000 # Absolute minimum baseline MSRP for a new low-end PC

    # CPU Tier MSRP baseline
    if ($cpu -match 'i3|Ryzen 3') { $msrp = 45000 }
    elseif ($cpu -match 'i5|Ryzen 5') { $msrp = 65000 }
    elseif ($cpu -match 'i7|Ryzen 7') { $msrp = 95000 }
    elseif ($cpu -match 'i9|Ryzen 9') { $msrp = 150000 }
    elseif ($cpu -match 'Apple M1|Apple M2|Apple M3') { $msrp = 120000 }

    # RAM MSRP Premium (4k per 8GB over 8GB)
    if ($ram -gt 8) {
        $msrp += ([math]::Floor(($ram - 8) / 8) * 4000)
    }

    # Storage MSRP Premium
    $totalGB = 0
    $hasFast = $false
    if ($storDrives) {
        foreach ($d in $storDrives) {
            $totalGB += $d.Size
            if ($d.MediaType -match 'SSD|NVMe') { $hasFast = $true }
        }
    }
    if ($hasFast -and $totalGB -ge 500) { $msrp += 10000 }
    elseif ($hasFast) { $msrp += 5000 }
    
    # GPU MSRP Premium
    if ($gpus -match 'RTX 40') { $msrp += 90000 }
    elseif ($gpus -match 'RTX 30') { $msrp += 60000 }
    elseif ($gpus -match 'RTX 20') { $msrp += 35000 }
    elseif ($gpus -match 'GTX 16') { $msrp += 25000 }
    elseif ($gpus -match 'GTX 10') { $msrp += 15000 }
    elseif ($gpus -match 'RX 7\d{2}') { $msrp += 70000 }
    elseif ($gpus -match 'RX 6\d{2}') { $msrp += 40000 }
    elseif ($gpus -match 'GTX|RTX|Radeon RX|Dedicated') { $msrp += 15000 }

    # Round to nearest 500 Tk
    return [math]::Round($msrp / 500) * 500
}

# ---------------------------------------------------------------------------
[xml]$xaml = @'
<Window
  xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
  xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
  Title="Humayoun Kobir Tool"
  Width="1024" Height="768"
  MinWidth="900" MinHeight="650"
  WindowStartupLocation="CenterScreen"
  Background="{DynamicResource AppBg}"
  Foreground="{DynamicResource TextMain}"
  FontFamily="Segoe UI Variable Display, Segoe UI, sans-serif"
  SnapsToDevicePixels="True"
  UseLayoutRounding="True">

  <Window.Resources>
    <SolidColorBrush x:Key="AppBg" Color="#09090B"/>
    <SolidColorBrush x:Key="CardBg" Color="#18181B"/>
    <SolidColorBrush x:Key="BorderCol" Color="#27272A"/>
    <SolidColorBrush x:Key="TextMain" Color="#FAFAFA"/>
    <SolidColorBrush x:Key="TextSec" Color="#A1A1AA"/>
    <SolidColorBrush x:Key="TextMuted" Color="#71717A"/>
    <SolidColorBrush x:Key="TextDark" Color="#3F3F46"/>
    <SolidColorBrush x:Key="BtnBg" Color="#3B82F6"/>
    <SolidColorBrush x:Key="BtnHover" Color="#60A5FA"/>
    <SolidColorBrush x:Key="BtnPress" Color="#2563EB"/>
    <SolidColorBrush x:Key="BtnText" Color="#FFFFFF"/>
    <SolidColorBrush x:Key="PopupBg" Color="#18181B"/>
    <SolidColorBrush x:Key="PopupHover" Color="#27272A"/>
    <SolidColorBrush x:Key="BarBg" Color="#27272A"/>
    <SolidColorBrush x:Key="BarFg" Color="#3B82F6"/>
    <SolidColorBrush x:Key="AccentGreen" Color="#10B981"/>

    <Style x:Key="Card" TargetType="Border">
      <Setter Property="Background"       Value="{DynamicResource CardBg}"/>
      <Setter Property="BorderBrush"      Value="{DynamicResource BorderCol}"/>
      <Setter Property="BorderThickness"  Value="1"/>
      <Setter Property="CornerRadius"     Value="16"/>
      <Setter Property="Padding"          Value="28"/>
      <Setter Property="Effect">
        <Setter.Value>
          <DropShadowEffect BlurRadius="25" ShadowDepth="6" Direction="270" Color="#000000" Opacity="0.15"/>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="FieldLabel" TargetType="TextBlock">
      <Setter Property="FontSize"    Value="12"/>
      <Setter Property="FontWeight"  Value="SemiBold"/>
      <Setter Property="Foreground"  Value="{DynamicResource TextMuted}"/>
      <Setter Property="Margin"      Value="0,0,0,6"/>
    </Style>

    <Style x:Key="BigNum" TargetType="TextBlock">
      <Setter Property="FontSize"   Value="34"/>
      <Setter Property="FontWeight" Value="Bold"/>
      <Setter Property="Foreground" Value="{DynamicResource TextMain}"/>
      <Setter Property="Margin"     Value="0,0,0,4"/>
    </Style>

    <Style x:Key="BodyText" TargetType="TextBlock">
      <Setter Property="FontSize"      Value="15"/>
      <Setter Property="Foreground"    Value="{DynamicResource TextSec}"/>
      <Setter Property="TextWrapping"  Value="Wrap"/>
    </Style>

    <Style x:Key="PrimaryBtn" TargetType="Button">
      <Setter Property="Background"      Value="{DynamicResource BtnBg}"/>
      <Setter Property="Foreground"      Value="{DynamicResource BtnText}"/>
      <Setter Property="FontWeight"      Value="Bold"/>
      <Setter Property="FontSize"        Value="14"/>
      <Setter Property="Padding"         Value="32,14"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Cursor"          Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border Name="Bd" Background="{TemplateBinding Background}" CornerRadius="10" Padding="{TemplateBinding Padding}" RenderTransformOrigin="0.5,0.5">
              <Border.RenderTransform>
                <ScaleTransform ScaleX="1" ScaleY="1" />
              </Border.RenderTransform>
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
              <Border.Effect>
                 <DropShadowEffect BlurRadius="15" ShadowDepth="4" Opacity="0.25" Color="#000000" Direction="270" />
              </Border.Effect>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Bd" Property="Background" Value="{DynamicResource BtnHover}"/>
                <Trigger.EnterActions>
                  <BeginStoryboard>
                    <Storyboard>
                      <DoubleAnimation Storyboard.TargetName="Bd" Storyboard.TargetProperty="(Border.RenderTransform).(ScaleTransform.ScaleX)" To="1.03" Duration="0:0:0.15">
                         <DoubleAnimation.EasingFunction>
                            <QuadraticEase EasingMode="EaseOut"/>
                         </DoubleAnimation.EasingFunction>
                      </DoubleAnimation>
                      <DoubleAnimation Storyboard.TargetName="Bd" Storyboard.TargetProperty="(Border.RenderTransform).(ScaleTransform.ScaleY)" To="1.03" Duration="0:0:0.15">
                         <DoubleAnimation.EasingFunction>
                            <QuadraticEase EasingMode="EaseOut"/>
                         </DoubleAnimation.EasingFunction>
                      </DoubleAnimation>
                    </Storyboard>
                  </BeginStoryboard>
                </Trigger.EnterActions>
                <Trigger.ExitActions>
                  <BeginStoryboard>
                    <Storyboard>
                      <DoubleAnimation Storyboard.TargetName="Bd" Storyboard.TargetProperty="(Border.RenderTransform).(ScaleTransform.ScaleX)" To="1" Duration="0:0:0.15"/>
                      <DoubleAnimation Storyboard.TargetName="Bd" Storyboard.TargetProperty="(Border.RenderTransform).(ScaleTransform.ScaleY)" To="1" Duration="0:0:0.15"/>
                    </Storyboard>
                  </BeginStoryboard>
                </Trigger.ExitActions>
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter TargetName="Bd" Property="Background" Value="{DynamicResource BtnPress}"/>
                <Setter TargetName="Bd" Property="RenderTransform">
                  <Setter.Value>
                    <ScaleTransform ScaleX="0.97" ScaleY="0.97" />
                  </Setter.Value>
                </Setter>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter TargetName="Bd" Property="Background" Value="{DynamicResource BarBg}"/>
                <Setter Property="Foreground" Value="{DynamicResource TextDark}"/>
                <Setter TargetName="Bd" Property="Effect" Value="{x:Null}"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="DarkCombo" TargetType="ComboBox">
      <Setter Property="Background" Value="{DynamicResource CardBg}"/>
      <Setter Property="Foreground" Value="{DynamicResource TextMain}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource BorderCol}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="FontSize" Value="14"/>
      <Setter Property="Padding" Value="14,10"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ComboBox">
            <Grid>
              <ToggleButton x:Name="ToggleButton" 
                            Focusable="false"
                            IsChecked="{Binding Path=IsDropDownOpen,Mode=TwoWay,RelativeSource={RelativeSource TemplatedParent}}"
                            ClickMode="Press">
                <ToggleButton.Template>
                  <ControlTemplate TargetType="ToggleButton">
                    <Border x:Name="Bd" Background="{DynamicResource CardBg}" BorderBrush="{DynamicResource BorderCol}" BorderThickness="1" CornerRadius="8">
                      <Grid>
                        <Grid.ColumnDefinitions>
                          <ColumnDefinition />
                          <ColumnDefinition Width="36" />
                        </Grid.ColumnDefinitions>
                        <Path Grid.Column="1" HorizontalAlignment="Center" VerticalAlignment="Center" 
                              Data="M 0 0 L 5 5 L 10 0 Z" Fill="{DynamicResource TextMuted}" />
                      </Grid>
                    </Border>
                    <ControlTemplate.Triggers>
                      <Trigger Property="IsMouseOver" Value="True">
                        <Setter Property="Background" Value="{DynamicResource PopupHover}" TargetName="Bd" />
                        <Setter Property="BorderBrush" Value="{DynamicResource TextMuted}" TargetName="Bd" />
                      </Trigger>
                    </ControlTemplate.Triggers>
                  </ControlTemplate>
                </ToggleButton.Template>
              </ToggleButton>
              <ContentPresenter x:Name="ContentSite"
                                IsHitTestVisible="False" 
                                Content="{TemplateBinding SelectionBoxItem}"
                                ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"
                                ContentTemplateSelector="{TemplateBinding ItemTemplateSelector}"
                                Margin="14,10,36,10"
                                VerticalAlignment="Center"
                                HorizontalAlignment="Left" />
              <Popup x:Name="Popup" 
                     Placement="Bottom"
                     IsOpen="{TemplateBinding IsDropDownOpen}"
                     AllowsTransparency="True" 
                     Focusable="False"
                     PopupAnimation="Slide">
                <Grid x:Name="DropDown" SnapsToDevicePixels="True" MinWidth="{TemplateBinding ActualWidth}" MaxHeight="{TemplateBinding MaxDropDownHeight}">
                  <Border x:Name="DropDownBorder" Background="{DynamicResource PopupBg}" BorderThickness="1" BorderBrush="{DynamicResource BorderCol}" CornerRadius="8" Margin="0,4,0,12">
                    <Border.Effect>
                      <DropShadowEffect BlurRadius="20" ShadowDepth="8" Opacity="0.3" Color="#000000" Direction="270"/>
                    </Border.Effect>
                  </Border>
                  <ScrollViewer Margin="1,5,1,13" SnapsToDevicePixels="True">
                    <StackPanel IsItemsHost="True" KeyboardNavigation.DirectionalNavigation="Contained" />
                  </ScrollViewer>
                </Grid>
              </Popup>
            </Grid>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
      <Setter Property="ItemContainerStyle">
        <Setter.Value>
          <Style TargetType="ComboBoxItem">
            <Setter Property="Background" Value="{DynamicResource PopupBg}"/>
            <Setter Property="Foreground" Value="{DynamicResource TextMain}"/>
            <Setter Property="Padding" Value="14,12"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Style.Triggers>
              <Trigger Property="IsHighlighted" Value="True">
                <Setter Property="Background" Value="{DynamicResource PopupHover}"/>
              </Trigger>
            </Style.Triggers>
          </Style>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="SlimBar" TargetType="ProgressBar">
      <Setter Property="Background"       Value="{DynamicResource BarBg}"/>
      <Setter Property="Foreground"       Value="{DynamicResource BtnBg}"/>
      <Setter Property="Height"           Value="8"/>
      <Setter Property="BorderThickness"  Value="0"/>
      <Setter Property="Maximum"          Value="100"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ProgressBar">
            <Border Background="{TemplateBinding Background}" CornerRadius="4">
              <Grid>
                <Border Name="PART_Track"/>
                <Border Name="PART_Indicator" Background="{TemplateBinding Foreground}" CornerRadius="4" HorizontalAlignment="Left" />
              </Grid>
            </Border>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Custom tab strip -->
    <Style TargetType="TabItem">
      <Setter Property="FontSize"    Value="15"/>
      <Setter Property="FontWeight"  Value="SemiBold"/>
      <Setter Property="Foreground"  Value="{DynamicResource TextMuted}"/>
      <Setter Property="Padding"     Value="0"/>
      <Setter Property="Cursor"      Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="TabItem">
            <Border Name="Bd" Padding="24,16" BorderThickness="0,0,0,3" BorderBrush="Transparent" Background="Transparent" Margin="0,0,8,0">
              <ContentPresenter ContentSource="Header" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsSelected" Value="True">
                <Setter TargetName="Bd" Property="BorderBrush" Value="{DynamicResource BtnBg}"/>
                <Setter Property="Foreground" Value="{DynamicResource TextMain}"/>
              </Trigger>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter Property="Foreground" Value="{DynamicResource TextMain}"/>
                <Setter TargetName="Bd" Property="Background" Value="{DynamicResource PopupHover}"/>
                <Setter TargetName="Bd" Property="CornerRadius" Value="8,8,0,0"/>
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
              <Border Grid.Row="0" Background="{DynamicResource CardBg}" BorderBrush="{DynamicResource BorderCol}" BorderThickness="0,0,0,1">
                <TabPanel IsItemsHost="True" Background="Transparent" Margin="24,0,0,0"/>
              </Border>
              <Border Grid.Row="1" Background="Transparent">
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
      <RowDefinition Height="64"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="42"/>
    </Grid.RowDefinitions>

    <!-- Header -->
    <Border Grid.Row="0" Background="{DynamicResource CardBg}" BorderBrush="{DynamicResource BorderCol}" BorderThickness="0,0,0,1">
      <Grid Margin="32,0">
        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
          <Border Width="36" Height="36" CornerRadius="10" Margin="0,0,16,0">
            <Border.Effect>
              <DropShadowEffect BlurRadius="10" ShadowDepth="2" Opacity="0.3" Color="#000000"/>
            </Border.Effect>
            <Border.Background>
              <ImageBrush ImageSource="https://raw.githubusercontent.com/humayunk45423/HK-Tool/main/logo.png" Stretch="UniformToFill"/>
            </Border.Background>
          </Border>
          <TextBlock Text="Humayoun Kobir Tool" FontSize="18" FontWeight="Bold" Foreground="{DynamicResource TextMain}" VerticalAlignment="Center"/>
          <Border Background="{DynamicResource PopupBg}" CornerRadius="6" Margin="12,0,0,0" Padding="8,4" BorderBrush="{DynamicResource BorderCol}" BorderThickness="1">
            <TextBlock Text="v1.0" FontSize="11" FontWeight="Bold" Foreground="{DynamicResource TextMuted}" FontFamily="Consolas"/>
          </Border>
        </StackPanel>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
          <Button Name="BtnTheme" Content="&#xE706;" FontFamily="Segoe MDL2 Assets" FontSize="16" Width="36" Height="36" Background="{DynamicResource PopupBg}" BorderBrush="{DynamicResource BorderCol}" BorderThickness="1" Foreground="{DynamicResource TextMain}" Cursor="Hand" Margin="0,0,24,0" ToolTip="Toggle Light/Dark Theme">
            <Button.Template>
              <ControlTemplate TargetType="Button">
                <Border Name="Bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="18">
                  <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                </Border>
                <ControlTemplate.Triggers>
                  <Trigger Property="IsMouseOver" Value="True">
                    <Setter TargetName="Bd" Property="Background" Value="{DynamicResource PopupHover}"/>
                  </Trigger>
                </ControlTemplate.Triggers>
              </ControlTemplate>
            </Button.Template>
          </Button>
          <Ellipse Name="StatusDot" Width="8" Height="8" Fill="{DynamicResource TextMuted}" Margin="0,0,12,0"/>
          <TextBlock Name="StatusText" FontSize="14" FontWeight="SemiBold" Foreground="{DynamicResource TextMuted}" VerticalAlignment="Center"
                     Text="Ready -- click Run Full Scan" MaxWidth="420" TextTrimming="CharacterEllipsis"/>
        </StackPanel>
      </Grid>
    </Border>

    <!-- Main tabs -->
    <TabControl Grid.Row="1" Name="MainTabs">

      <!-- Overview -->
      <TabItem Header="Overview">
        <ScrollViewer VerticalScrollBarVisibility="Auto" Background="Transparent">
          <StackPanel Margin="48,40,48,48">

            <TextBlock Text="System Overview" FontSize="26" FontWeight="Bold"
                       Foreground="{DynamicResource TextMain}" Margin="0,0,0,32"/>

            <!-- CPU + GPU row -->
            <Grid Margin="0,0,0,16">
              <Grid.ColumnDefinitions>
                <ColumnDefinition/>
                <ColumnDefinition Width="16"/>
                <ColumnDefinition/>
              </Grid.ColumnDefinitions>
              <Border Grid.Column="0" Style="{StaticResource Card}">
                <StackPanel>
                  <TextBlock Text="PROCESSOR" Style="{StaticResource FieldLabel}"/>
                  <TextBlock Name="LblCPU" Style="{StaticResource BodyText}" Text="Not scanned yet" FontWeight="SemiBold" Foreground="{DynamicResource TextMain}"/>
                </StackPanel>
              </Border>
              <Border Grid.Column="2" Style="{StaticResource Card}">
                <StackPanel>
                  <TextBlock Text="GRAPHICS" Style="{StaticResource FieldLabel}"/>
                  <TextBlock Name="LblGPU" Style="{StaticResource BodyText}" Text="Not scanned yet" FontWeight="SemiBold" Foreground="{DynamicResource TextMain}"/>
                </StackPanel>
              </Border>
            </Grid>

            <!-- RAM + BIOS + OS row -->
            <Grid Margin="0,0,0,32">
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="0.6*"/>
                <ColumnDefinition Width="16"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="16"/>
                <ColumnDefinition Width="*"/>
              </Grid.ColumnDefinitions>
              <Border Grid.Column="0" Style="{StaticResource Card}">
                <StackPanel>
                  <TextBlock Text="RAM" Style="{StaticResource FieldLabel}"/>
                  <TextBlock Name="LblRAM" Style="{StaticResource BigNum}" Text="--"/>
                  <TextBlock Text="GB installed" FontSize="13" Foreground="{DynamicResource TextMuted}"/>
                </StackPanel>
              </Border>
              <Border Grid.Column="2" Style="{StaticResource Card}">
                <StackPanel>
                  <TextBlock Text="BIOS DATE" Style="{StaticResource FieldLabel}"/>
                  <TextBlock Name="LblBIOS" Style="{StaticResource BodyText}" Text="--" FontWeight="SemiBold" Foreground="{DynamicResource TextMain}"/>
                  <TextBlock Text="approx. manufacture date" FontSize="13" Foreground="{DynamicResource TextMuted}" Margin="0,6,0,0"/>
                </StackPanel>
              </Border>
              <Border Grid.Column="4" Style="{StaticResource Card}">
                <StackPanel>
                  <TextBlock Text="OPERATING SYSTEM" Style="{StaticResource FieldLabel}"/>
                  <TextBlock Name="LblOS" Style="{StaticResource BodyText}" Text="--" FontWeight="SemiBold" Foreground="{DynamicResource TextMain}"/>
                </StackPanel>
              </Border>
            </Grid>

            <Button Name="BtnScan" Content="Run Full Scan"
                    Style="{StaticResource PrimaryBtn}" HorizontalAlignment="Left"/>

          </StackPanel>
        </ScrollViewer>
      </TabItem>

      <!-- System Details (populated after scan) -->
      <TabItem Header="System Details" Name="TabSysDetails">
        <ScrollViewer VerticalScrollBarVisibility="Auto" Background="Transparent">
          <StackPanel Margin="48,40,48,48">
            <TextBlock Text="System Details" FontSize="26" FontWeight="Bold"
                       Foreground="{DynamicResource TextMain}" Margin="0,0,0,8"/>
            <TextBlock Text="Full hardware &amp; system summary collected from Windows."
                       Style="{StaticResource BodyText}" Foreground="{DynamicResource TextMuted}" Margin="0,0,0,32"/>
            <TextBlock Name="LblSysDetailsPH" Style="{StaticResource BodyText}"
                       Text="Run a scan first to see full system details." Foreground="{DynamicResource TextMuted}"/>
            <!-- Grid of info rows built in code -->
            <ItemsControl Name="SysDetailsPanel">
              <ItemsControl.ItemTemplate>
                <DataTemplate>
                  <Grid Margin="0,0,0,1">
                    <Grid.ColumnDefinitions>
                      <ColumnDefinition Width="260"/>
                      <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>
                    <TextBlock Grid.Column="0" Text="{Binding Key}" FontSize="13" FontWeight="SemiBold"
                               Foreground="{DynamicResource TextMuted}" Padding="0,10" TextWrapping="Wrap"/>
                    <TextBlock Grid.Column="1" Text="{Binding Value}" FontSize="13"
                               Foreground="{DynamicResource TextMain}" Padding="0,10" TextWrapping="Wrap"/>
                  </Grid>
                </DataTemplate>
              </ItemsControl.ItemTemplate>
            </ItemsControl>
          </StackPanel>
        </ScrollViewer>
      </TabItem>

      <!-- Battery -->
      <TabItem Header="Battery">
        <ScrollViewer VerticalScrollBarVisibility="Auto" Background="Transparent">
          <StackPanel Margin="48,40,48,48">

            <TextBlock Text="Battery Health" FontSize="26" FontWeight="Bold"
                       Foreground="{DynamicResource TextMain}" Margin="0,0,0,32"/>

            <Grid Margin="0,0,0,16">
              <Grid.ColumnDefinitions>
                <ColumnDefinition/>
                <ColumnDefinition Width="16"/>
                <ColumnDefinition/>
                <ColumnDefinition Width="16"/>
                <ColumnDefinition/>
              </Grid.ColumnDefinitions>

              <Border Grid.Column="0" Style="{StaticResource Card}">
                <StackPanel>
                  <TextBlock Text="HEALTH" Style="{StaticResource FieldLabel}"/>
                  <TextBlock Name="LblBatHealth" Style="{StaticResource BigNum}" Text="--"/>
                  <ProgressBar Name="BarBatHealth" Style="{StaticResource SlimBar}" Margin="0,12,0,0"/>
                </StackPanel>
              </Border>

              <Border Grid.Column="2" Style="{StaticResource Card}">
                <StackPanel>
                  <TextBlock Text="CYCLE COUNT" Style="{StaticResource FieldLabel}"/>
                  <TextBlock Name="LblCycles" Style="{StaticResource BigNum}" Text="--"/>
                  <TextBlock Text="charge cycles" FontSize="13" Foreground="{DynamicResource TextMuted}"/>
                </StackPanel>
              </Border>

              <Border Grid.Column="4" Style="{StaticResource Card}">
                <StackPanel>
                  <TextBlock Text="CAPACITY" Style="{StaticResource FieldLabel}"/>
                  <TextBlock Name="LblCapNow" FontSize="20" FontWeight="Bold" Foreground="{DynamicResource TextMain}" Margin="0,0,0,4"/>
                  <TextBlock Text="current full charge" FontSize="13" Foreground="{DynamicResource TextMuted}"/>
                  <TextBlock Name="LblCapDesign" FontSize="13" Foreground="{DynamicResource TextMuted}" Margin="0,8,0,0"/>
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
        <ScrollViewer VerticalScrollBarVisibility="Auto" Background="Transparent">
          <StackPanel Name="StoragePanel" Margin="48,40,48,48">
            <TextBlock Text="Storage Health" FontSize="26" FontWeight="Bold"
                       Foreground="{DynamicResource TextMain}" Margin="0,0,0,32"/>
            <TextBlock Name="LblStoragePH" Style="{StaticResource BodyText}"
                       Text="Run a scan to see storage details." Foreground="{DynamicResource TextMuted}"/>
          </StackPanel>
        </ScrollViewer>
      </TabItem>

      <!-- Condition Survey -->
      <TabItem Header="Condition Survey">
        <ScrollViewer VerticalScrollBarVisibility="Auto" Background="Transparent">
          <StackPanel Margin="48,40,48,48">

            <TextBlock Text="Condition Survey" FontSize="26" FontWeight="Bold"
                       Foreground="{DynamicResource TextMain}" Margin="0,0,0,8"/>
            <TextBlock Text="Answer honestly -- this affects your price estimate."
                       Style="{StaticResource BodyText}" Foreground="{DynamicResource TextMuted}" Margin="0,0,0,32"/>

            <Border Style="{StaticResource Card}" Margin="0,0,0,24">
              <Grid>
                <Grid.ColumnDefinitions>
                  <ColumnDefinition Width="*"/>
                  <ColumnDefinition Width="320"/>
                </Grid.ColumnDefinitions>
                <Grid.RowDefinitions>
                  <RowDefinition/><RowDefinition Height="20"/>
                  <RowDefinition/><RowDefinition Height="20"/>
                  <RowDefinition/><RowDefinition Height="20"/>
                  <RowDefinition/><RowDefinition Height="20"/>
                  <RowDefinition/><RowDefinition Height="20"/>
                  <RowDefinition/><RowDefinition Height="20"/>
                  <RowDefinition/><RowDefinition Height="20"/>
                  <RowDefinition/><RowDefinition Height="20"/>
                  <RowDefinition/><RowDefinition Height="20"/>
                  <RowDefinition/>
                </Grid.RowDefinitions>

                <!-- Age -->
                <TextBlock Grid.Row="0" Grid.Column="0" Text="Device Age" FontSize="15" FontWeight="SemiBold" Foreground="{DynamicResource TextMain}" VerticalAlignment="Center"/>
                <ComboBox Grid.Row="0" Grid.Column="1" Name="CboAge" Style="{StaticResource DarkCombo}">
                  <ComboBoxItem Content="Less than 6 Months"               Tag="95" IsSelected="True"/>
                  <ComboBoxItem Content="1 to 2 Years"                     Tag="75"/>
                  <ComboBoxItem Content="3 to 4 Years"                     Tag="50"/>
                  <ComboBoxItem Content="5+ Years"                         Tag="35"/>
                </ComboBox>

                <!-- Warranty -->
                <TextBlock Grid.Row="2" Grid.Column="0" Text="Warranty Status" FontSize="15" FontWeight="SemiBold" Foreground="{DynamicResource TextMain}" VerticalAlignment="Center"/>
                <ComboBox Grid.Row="2" Grid.Column="1" Name="CboWarranty" Style="{StaticResource DarkCombo}">
                  <ComboBoxItem Content="Valid Official Warranty"          Tag="100" IsSelected="True"/>
                  <ComboBoxItem Content="Shop Warranty Only"               Tag="90"/>
                  <ComboBoxItem Content="Expired / No Warranty"            Tag="85"/>
                </ComboBox>

                <!-- Accessories -->
                <TextBlock Grid.Row="4" Grid.Column="0" Text="Accessories" FontSize="15" FontWeight="SemiBold" Foreground="{DynamicResource TextMain}" VerticalAlignment="Center"/>
                <ComboBox Grid.Row="4" Grid.Column="1" Name="CboAccessories" Style="{StaticResource DarkCombo}">
                  <ComboBoxItem Content="Original Box &amp; Charger"           Tag="100" IsSelected="True"/>
                  <ComboBoxItem Content="Original Charger Only"            Tag="90"/>
                  <ComboBoxItem Content="Local / Aftermarket Charger"      Tag="80"/>
                  <ComboBoxItem Content="No Charger"                       Tag="70"/>
                </ComboBox>

                <!-- Battery Backup -->
                <TextBlock Grid.Row="6" Grid.Column="0" Text="Battery Backup" FontSize="15" FontWeight="SemiBold" Foreground="{DynamicResource TextMain}" VerticalAlignment="Center"/>
                <ComboBox Grid.Row="6" Grid.Column="1" Name="CboBattery" Style="{StaticResource DarkCombo}">
                  <ComboBoxItem Content="3+ Hours Backup"                  Tag="100" IsSelected="True"/>
                  <ComboBoxItem Content="1 to 2 Hours Backup"              Tag="85"/>
                  <ComboBoxItem Content="Less than 1 Hour"                 Tag="60"/>
                  <ComboBoxItem Content="Needs Replacement"                Tag="40"/>
                </ComboBox>

                <!-- Screen -->
                <TextBlock Grid.Row="8" Grid.Column="0" Text="Screen Display" FontSize="15" FontWeight="SemiBold" Foreground="{DynamicResource TextMain}" VerticalAlignment="Center"/>
                <ComboBox Grid.Row="8" Grid.Column="1" Name="CboScreen" Style="{StaticResource DarkCombo}">
                  <ComboBoxItem Content="Perfect (No scratches, no dead pixels)"   Tag="100" IsSelected="True"/>
                  <ComboBoxItem Content="Minor scratches (Barely visible)"           Tag="85"/>
                  <ComboBoxItem Content="Noticeable scratches or light bleed"         Tag="65"/>
                  <ComboBoxItem Content="Crack or significant damage"                 Tag="30"/>
                </ComboBox>

                <!-- Body -->
                <TextBlock Grid.Row="10" Grid.Column="0" Text="Body / Chassis" FontSize="15" FontWeight="SemiBold" Foreground="{DynamicResource TextMain}" VerticalAlignment="Center"/>
                <ComboBox Grid.Row="10" Grid.Column="1" Name="CboBody" Style="{StaticResource DarkCombo}">
                  <ComboBoxItem Content="Like new (No dents or scratches)"   Tag="100" IsSelected="True"/>
                  <ComboBoxItem Content="Light scratches, no dents"            Tag="85"/>
                  <ComboBoxItem Content="Visible dents or chips"               Tag="60"/>
                  <ComboBoxItem Content="Cracked or heavily damaged"           Tag="25"/>
                </ComboBox>

                <!-- Keyboard -->
                <TextBlock Grid.Row="12" Grid.Column="0" Text="Keyboard" FontSize="15" FontWeight="SemiBold" Foreground="{DynamicResource TextMain}" VerticalAlignment="Center"/>
                <ComboBox Grid.Row="12" Grid.Column="1" Name="CboKeyboard" Style="{StaticResource DarkCombo}">
                  <ComboBoxItem Content="All keys work perfectly"              Tag="100" IsSelected="True"/>
                  <ComboBoxItem Content="Minor fade or slight sticking"        Tag="80"/>
                  <ComboBoxItem Content="1-2 keys faulty"                      Tag="55"/>
                  <ComboBoxItem Content="Multiple keys not working"            Tag="20"/>
                </ComboBox>

                <!-- Ports -->
                <TextBlock Grid.Row="14" Grid.Column="0" Text="Ports" FontSize="15" FontWeight="SemiBold" Foreground="{DynamicResource TextMain}" VerticalAlignment="Center"/>
                <ComboBox Grid.Row="14" Grid.Column="1" Name="CboPorts" Style="{StaticResource DarkCombo}">
                  <ComboBoxItem Content="All ports functional"                  Tag="100" IsSelected="True"/>
                  <ComboBoxItem Content="One port loose or non-functional"      Tag="80"/>
                  <ComboBoxItem Content="Multiple ports faulty"                 Tag="50"/>
                </ComboBox>

                <!-- Webcam -->
                <TextBlock Grid.Row="16" Grid.Column="0" Text="Webcam" FontSize="15" FontWeight="SemiBold" Foreground="{DynamicResource TextMain}" VerticalAlignment="Center"/>
                <ComboBox Grid.Row="16" Grid.Column="1" Name="CboWebcam" Style="{StaticResource DarkCombo}">
                  <ComboBoxItem Content="Works fine"                             Tag="100" IsSelected="True"/>
                  <ComboBoxItem Content="Slightly blurry / intermittent"         Tag="70"/>
                  <ComboBoxItem Content="Not working"                            Tag="40"/>
                  <ComboBoxItem Content="No webcam (Desktop)"                   Tag="90"/>
                </ComboBox>

                <!-- Speakers -->
                <TextBlock Grid.Row="18" Grid.Column="0" Text="Speakers" FontSize="15" FontWeight="SemiBold" Foreground="{DynamicResource TextMain}" VerticalAlignment="Center"/>
                <ComboBox Grid.Row="18" Grid.Column="1" Name="CboSpeakers" Style="{StaticResource DarkCombo}">
                  <ComboBoxItem Content="Clear sound (Both speakers)"             Tag="100" IsSelected="True"/>
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
        <ScrollViewer VerticalScrollBarVisibility="Auto" Background="Transparent">
          <StackPanel Margin="48,40,48,48">

            <TextBlock Text="Resale Price Estimate" FontSize="26" FontWeight="Bold"
                       Foreground="{DynamicResource TextMain}" Margin="0,0,0,8"/>
            <TextBlock Text="Based on real-time automated hardware valuation."
                       Style="{StaticResource BodyText}" Foreground="{DynamicResource TextMuted}" Margin="0,0,0,32"/>

            <TextBlock Text="CALCULATED BASE HARDWARE VALUE (BDT)" Style="{StaticResource FieldLabel}"/>
            <TextBlock Name="LblBasePrice" FontSize="42" FontWeight="Bold" Text="-- Tk" Foreground="{DynamicResource TextMain}" Margin="0,4,0,4"/>
            <TextBlock Text="Automatically determined from CPU, RAM, Storage, and GPU." FontSize="13"
                       Foreground="{DynamicResource TextMuted}" Margin="0,0,0,32"/>

            <!-- Result card -->
            <Border Name="PriceCard" Style="{StaticResource Card}" Visibility="Collapsed">
              <Grid>
                <Grid.ColumnDefinitions>
                  <ColumnDefinition/>
                  <ColumnDefinition Width="1"/>
                  <ColumnDefinition/>
                </Grid.ColumnDefinitions>

                <StackPanel Grid.Column="0" Margin="0,0,32,0" VerticalAlignment="Center">
                  <TextBlock Text="OVERALL SCORE" Style="{StaticResource FieldLabel}"/>
                  <TextBlock Name="LblScore" Style="{StaticResource BigNum}" Foreground="{DynamicResource BtnBg}"/>
                  <TextBlock Name="LblScoreSub" FontSize="13" Foreground="{DynamicResource TextMuted}" Margin="0,8,0,0" TextWrapping="Wrap"/>
                </StackPanel>

                <Border Grid.Column="1" Background="{DynamicResource BorderCol}" Width="1"/>

                <StackPanel Grid.Column="2" Margin="32,0,0,0" VerticalAlignment="Center">
                  <TextBlock Text="FAIR RESALE RANGE" Style="{StaticResource FieldLabel}"/>
                  <TextBlock Name="LblPriceRange" FontSize="28" FontWeight="Bold" Foreground="{DynamicResource AccentGreen}" Margin="0,4,0,12"/>
                  <TextBlock Name="LblPriceNote" FontSize="13" Foreground="{DynamicResource TextMuted}" TextWrapping="Wrap"/>
                </StackPanel>
              </Grid>
            </Border>

            <Button Name="BtnExportJSON" Content="Export to JSON" Style="{StaticResource PrimaryBtn}" HorizontalAlignment="Left" Margin="0,24,0,0" Visibility="Collapsed"/>

          </StackPanel>
        </ScrollViewer>
      </TabItem>

    </TabControl>

    <!-- Status bar -->
    <Border Grid.Row="2" Background="{DynamicResource CardBg}" BorderBrush="{DynamicResource BorderCol}" BorderThickness="0,1,0,0" Padding="32,0">
      <TextBlock Name="FooterText" FontSize="12" Foreground="{DynamicResource TextMuted}" VerticalAlignment="Center" FontWeight="SemiBold"
                 Text="Humayoun Kobir Tool v1.0   Windows Only   Open Source"/>
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
$BtnTheme      = $window.FindName('BtnTheme')
$BtnScan       = $window.FindName('BtnScan')
$TabSysDetails   = $window.FindName('TabSysDetails')
$SysDetailsPanel = $window.FindName('SysDetailsPanel')
$LblSysDetailsPH = $window.FindName('LblSysDetailsPH')
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
$CboAge        = $window.FindName('CboAge')
$CboWarranty   = $window.FindName('CboWarranty')
$CboAccessories= $window.FindName('CboAccessories')
$CboBattery    = $window.FindName('CboBattery')
$CboScreen     = $window.FindName('CboScreen')
$CboBody       = $window.FindName('CboBody')
$CboKeyboard   = $window.FindName('CboKeyboard')
$CboPorts      = $window.FindName('CboPorts')
$CboWebcam     = $window.FindName('CboWebcam')
$CboSpeakers   = $window.FindName('CboSpeakers')
$BtnCondition  = $window.FindName('BtnCondition')
$LblBasePrice  = $window.FindName('LblBasePrice')
$PriceCard     = $window.FindName('PriceCard')
$LblScore      = $window.FindName('LblScore')
$LblScoreSub   = $window.FindName('LblScoreSub')
$LblPriceRange = $window.FindName('LblPriceRange')
$LblPriceNote  = $window.FindName('LblPriceNote')
$BtnExportJSON = $window.FindName('BtnExportJSON')

# Script-scope state
$script:BatInfo        = $null
$script:StorDrives     = $null
$script:SysInfo        = $null
$script:ConditionScore = -1
$script:dotCount       = 0
$script:BaseHardwareValue = 0
$script:scanDone       = $false

# ---------------------------------------------------------------------------
# Theme Toggle
# ---------------------------------------------------------------------------
$script:isDarkMode = $true
$BtnTheme.Add_Click({
    $script:isDarkMode = -not $script:isDarkMode
    
    # Smooth fade animation
    $anim = [Windows.Media.Animation.DoubleAnimation]::new(0.6, 1.0, [Windows.Duration]::new([TimeSpan]::FromMilliseconds(250)))
    $window.BeginAnimation([Windows.UIElement]::OpacityProperty, $anim)

    $bc = [Windows.Media.BrushConverter]::new()
    
    if ($script:isDarkMode) {
        $BtnTheme.Content = [char]0xE706
        $window.Resources['AppBg']       = $bc.ConvertFromString('#09090B')
        $window.Resources['CardBg']      = $bc.ConvertFromString('#18181B')
        $window.Resources['BorderCol']   = $bc.ConvertFromString('#27272A')
        $window.Resources['TextMain']    = $bc.ConvertFromString('#FAFAFA')
        $window.Resources['TextSec']     = $bc.ConvertFromString('#A1A1AA')
        $window.Resources['TextMuted']   = $bc.ConvertFromString('#71717A')
        $window.Resources['TextDark']    = $bc.ConvertFromString('#3F3F46')
        $window.Resources['BtnBg']       = $bc.ConvertFromString('#3B82F6')
        $window.Resources['BtnHover']    = $bc.ConvertFromString('#60A5FA')
        $window.Resources['BtnPress']    = $bc.ConvertFromString('#2563EB')
        $window.Resources['BtnText']     = $bc.ConvertFromString('#FFFFFF')
        $window.Resources['PopupBg']     = $bc.ConvertFromString('#18181B')
        $window.Resources['PopupHover']  = $bc.ConvertFromString('#27272A')
        $window.Resources['BarBg']       = $bc.ConvertFromString('#27272A')
        $window.Resources['BarFg']       = $bc.ConvertFromString('#3B82F6')
        $window.Resources['AccentGreen'] = $bc.ConvertFromString('#10B981')
    } else {
        $BtnTheme.Content = [char]0xE708
        $window.Resources['AppBg']       = $bc.ConvertFromString('#FAFAFA')
        $window.Resources['CardBg']      = $bc.ConvertFromString('#FFFFFF')
        $window.Resources['BorderCol']   = $bc.ConvertFromString('#E4E4E7')
        $window.Resources['TextMain']    = $bc.ConvertFromString('#09090B')
        $window.Resources['TextSec']     = $bc.ConvertFromString('#52525B')
        $window.Resources['TextMuted']   = $bc.ConvertFromString('#71717A')
        $window.Resources['TextDark']    = $bc.ConvertFromString('#A1A1AA')
        $window.Resources['BtnBg']       = $bc.ConvertFromString('#2563EB')
        $window.Resources['BtnHover']    = $bc.ConvertFromString('#3B82F6')
        $window.Resources['BtnPress']    = $bc.ConvertFromString('#1D4ED8')
        $window.Resources['BtnText']     = $bc.ConvertFromString('#FFFFFF')
        $window.Resources['PopupBg']     = $bc.ConvertFromString('#FFFFFF')
        $window.Resources['PopupHover']  = $bc.ConvertFromString('#F4F4F5')
        $window.Resources['BarBg']       = $bc.ConvertFromString('#E4E4E7')
        $window.Resources['BarFg']       = $bc.ConvertFromString('#2563EB')
        $window.Resources['AccentGreen'] = $bc.ConvertFromString('#10B981')
    }
})

# (BtnAdvancedInfo removed — inline System Details tab added instead)

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
    # Reset state so a second scan always gives fresh results
    $script:scanDone          = $false
    $script:BatInfo           = $null
    $script:StorDrives        = $null
    $script:SysInfo           = $null
    $script:ConditionScore    = -1
    $script:BaseHardwareValue = 0

    # Create a fresh PowerShell instance with its own runspace
    $script:scanPS = [System.Management.Automation.PowerShell]::Create()

    $null = $script:scanPS.AddScript({

        # -- Battery -------------------------------------------------------
        function Get-BatteryInfo {
            $design = 0; $full = 0; $cycles = -1; $health = -1

            # Primary: WMI root\wmi (fast, no file I/O)
            try {
                $staticData = Get-WmiObject -Namespace root\wmi -Class BatteryStaticData -ErrorAction Stop | Select-Object -First 1
                $fullCharge = Get-WmiObject -Namespace root\wmi -Class BatteryFullChargedCapacity -ErrorAction Stop | Select-Object -First 1
                $cycleObj   = Get-WmiObject -Namespace root\wmi -Class BatteryCycleCount -ErrorAction SilentlyContinue | Select-Object -First 1

                if ($staticData -and $staticData.DesignedCapacity -gt 0) {
                    $design = [int]$staticData.DesignedCapacity
                }
                if ($fullCharge -and $fullCharge.FullChargedCapacity -gt 0) {
                    $full = [int]$fullCharge.FullChargedCapacity
                }
                # CycleCount 0 = not reported by hardware (common ASUS/MSI firmware limitation)
                if ($cycleObj -and $null -ne $cycleObj.CycleCount -and [int]$cycleObj.CycleCount -gt 0) {
                    $cycles = [int]$cycleObj.CycleCount
                }
            } catch {}

            # Fallback: powercfg HTML report ONLY for fields still missing
            if ($design -le 0 -or $full -le 0 -or $cycles -lt 0) {
                try {
                    $tmp = "$env:TEMP\batreport_hktool.html"
                    powercfg /batteryreport /output $tmp 2>$null | Out-Null
                    if (Test-Path $tmp) {
                        $html = Get-Content $tmp -Raw -ErrorAction Stop
                        if ($design -le 0 -and $html -match 'DESIGN CAPACITY.*?(\d[\d,]+)\s*mWh')       { $design = [int]($Matches[1] -replace ',','') }
                        if ($full   -le 0 -and $html -match 'FULL CHARGE CAPACITY.*?(\d[\d,]+)\s*mWh') { $full   = [int]($Matches[1] -replace ',','') }
                        if ($cycles -lt 0 -and $html -match 'CYCLE COUNT.*?<td>\s*([1-9][0-9]*)')       { $cycles = [int]$Matches[1] }
                        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
                    }
                } catch {}
            }

            if ($design -gt 0 -and $full -gt 0) {
                $health = [math]::Round($full / $design * 100, 1)
                return @{ DesignmWh=$design; FullmWh=$full; CycleCount=$cycles; HealthPct=$health }
            }
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
            $cpu     = (Get-CimInstance Win32_Processor       -ErrorAction SilentlyContinue | Select-Object -First 1)
            $gpus    = (Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue).Name -join ', '
            $ramObjs = Get-CimInstance Win32_PhysicalMemory   -ErrorAction SilentlyContinue
            $ram     = [math]::Round(($ramObjs | Measure-Object -Property Capacity -Sum).Sum / 1GB, 0)
            $os      = Get-CimInstance Win32_OperatingSystem  -ErrorAction SilentlyContinue
            $bios    = Get-CimInstance Win32_BIOS             -ErrorAction SilentlyContinue
            $cs      = Get-CimInstance Win32_ComputerSystem   -ErrorAction SilentlyContinue
            $board   = Get-CimInstance Win32_BaseBoard        -ErrorAction SilentlyContinue
            $disks   = Get-CimInstance Win32_DiskDrive        -ErrorAction SilentlyContinue
            $net     = Get-CimInstance Win32_NetworkAdapterConfiguration -ErrorAction SilentlyContinue | Where-Object { $_.IPEnabled } | Select-Object -First 1

            $ramSlots = ($ramObjs | ForEach-Object { "$([math]::Round($_.Capacity/1GB,0)) GB $($_.Speed) MHz" }) -join ' | '
            $diskList = ($disks | ForEach-Object { "$($_.Model) ($([math]::Round($_.Size/1GB,0)) GB)" }) -join '; '

            return @{
                CPU         = if ($cpu.Name)  { $cpu.Name }  else { 'Not detected' }
                CPUCores    = if ($cpu.NumberOfCores) { "$($cpu.NumberOfCores) cores / $($cpu.NumberOfLogicalProcessors) threads" } else { 'N/A' }
                CPUSpeed    = if ($cpu.MaxClockSpeed) { "$([math]::Round($cpu.MaxClockSpeed/1000,2)) GHz max" } else { 'N/A' }
                GPU         = if ($gpus) { $gpus } else { 'Not detected' }
                RAM         = $ram
                RAMSlots    = if ($ramSlots) { $ramSlots } else { 'N/A' }
                OS          = if ($os.Caption) { $os.Caption } else { 'Unknown' }
                OSVersion   = if ($os.Version) { $os.Version } else { 'N/A' }
                OSBuild     = if ($os.BuildNumber) { "Build $($os.BuildNumber)" } else { 'N/A' }
                InstallDate = if ($os.InstallDate) { $os.InstallDate.ToString('yyyy-MM-dd') } else { 'N/A' }
                LastBoot    = if ($os.LastBootUpTime) { $os.LastBootUpTime.ToString('yyyy-MM-dd HH:mm') } else { 'N/A' }
                Uptime      = if ($os.LastBootUpTime) { $ts = (Get-Date) - $os.LastBootUpTime; "$($ts.Days)d $($ts.Hours)h $($ts.Minutes)m" } else { 'N/A' }
                SystemName  = if ($cs.Name) { $cs.Name } else { 'N/A' }
                Manufacturer = if ($cs.Manufacturer) { $cs.Manufacturer } else { 'N/A' }
                Model       = if ($cs.Model) { $cs.Model } else { 'N/A' }
                SystemType  = if ($cs.SystemType) { $cs.SystemType } else { 'N/A' }
                BIOSDate    = if ($bios.ReleaseDate) { $bios.ReleaseDate.ToString('yyyy-MM-dd') } else { 'Unknown' }
                BIOSVersion = if ($bios.SMBIOSBIOSVersion) { $bios.SMBIOSBIOSVersion } else { 'N/A' }
                BIOSManuf   = if ($bios.Manufacturer) { $bios.Manufacturer } else { 'N/A' }
                BoardManuf  = if ($board.Manufacturer) { $board.Manufacturer } else { 'N/A' }
                BoardModel  = if ($board.Product) { $board.Product } else { 'N/A' }
                Disks       = if ($diskList) { $diskList } else { 'N/A' }
                MACAddress  = if ($net.MACAddress) { $net.MACAddress } else { 'N/A' }
                IPAddress   = if ($net.IPAddress) { $net.IPAddress[0] } else { 'N/A' }
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
            $bcB = [Windows.Media.BrushConverter]::new()
            if ($bat.HealthPct -ge 0) {
                $LblBatHealth.Text  = "$($bat.HealthPct)%"
                $BarBatHealth.Value = [math]::Min($bat.HealthPct, 100)

                if ($bat.HealthPct -ge 80)     { $LblBatHealth.Foreground = $bcB.ConvertFromString('#10B981') }
                elseif ($bat.HealthPct -ge 60) { $LblBatHealth.Foreground = $bcB.ConvertFromString('#F59E0B') }
                else                           { $LblBatHealth.Foreground = $bcB.ConvertFromString('#EF4444') }

                if ($bat.CycleCount -ge 0) {
                    $LblCycles.Text     = [string]$bat.CycleCount
                    $LblCycles.FontSize = 34
                } else {
                    $LblCycles.Text     = 'Not reported'
                    $LblCycles.FontSize = 16
                }
                $LblCapNow.Text    = if ($bat.FullmWh   -gt 0) { "$([math]::Round($bat.FullmWh/1000,1)) Wh" } else { 'N/A' }
                $LblCapDesign.Text = if ($bat.DesignmWh -gt 0) { "Design: $([math]::Round($bat.DesignmWh/1000,1)) Wh" } else { '' }

                $LblBatNote.Text = switch -exact ($true) {
                    ($bat.HealthPct -ge 90) { 'Excellent -- battery is in great shape.' }
                    ($bat.HealthPct -ge 75) { 'Good -- some degradation, still usable for most buyers.' }
                    ($bat.HealthPct -ge 50) { 'Fair -- reduced runtime. Consider disclosing this to the buyer.' }
                    default                 { 'Poor -- battery replacement likely needed. Disclose this clearly.' }
                }
            } else {
                $LblBatHealth.Text = 'N/A'
                $LblBatNote.Text   = 'No battery detected -- may be a desktop, or report could not be generated.'
                $LblCycles.Text    = 'N/A'
                $LblCapNow.Text    = 'N/A'
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
                $bcS = [Windows.Media.BrushConverter]::new()
                foreach ($d in $r.Stor) {
                    $card               = [Windows.Controls.Border]::new()
                    $card.Tag           = 'drivecard'
                    $card.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, 'CardBg')
                    $card.SetResourceReference([System.Windows.Controls.Border]::BorderBrushProperty, 'BorderCol')
                    $card.BorderThickness = [Windows.Thickness]::new(1)
                    $card.CornerRadius  = [Windows.CornerRadius]::new(12)
                    $card.Padding       = [Windows.Thickness]::new(20)
                    $card.Margin        = [Windows.Thickness]::new(0, 0, 0, 12)

                    $sp = [Windows.Controls.StackPanel]::new()

                    $mkTb = {
                        param($text, $size, $colorKey, $margin)
                        $tb              = [System.Windows.Controls.TextBlock]::new()
                        $tb.Text         = $text
                        $tb.FontSize     = $size
                        $tb.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, $colorKey)
                        $tb.TextWrapping = 'Wrap'
                        if ($margin) { $tb.Margin = $margin }
                        $tb
                    }

                    $null = $sp.Children.Add((&$mkTb $d.FriendlyName 15 'TextMain' $null))

                    $sub1 = "$($d.MediaType)  |  $($d.Size) GB  |  Status: $($d.HealthStatus)"
                    $null = $sp.Children.Add((&$mkTb $sub1 13 'TextSec' ([Windows.Thickness]::new(0,6,0,0))))

                    if ($d.WearLevel -ge 0) {
                        $tempStr = if ($d.Temperature -ge 0) { "$($d.Temperature) C" } else { 'N/A' }
                        $sub2    = "Wear level: $($d.WearLevel)%   |   Temperature: $tempStr"
                        $null = $sp.Children.Add((&$mkTb $sub2 13 'TextMuted' ([Windows.Thickness]::new(0,4,0,0))))
                    }

                    $card.Child = $sp
                    $null = $StoragePanel.Children.Add($card)
                }
            }

            # Calculate Automated Base Price
            $script:BaseHardwareValue = Calc-HardwareBaseValue $r.Sys $r.Stor
            $LblBasePrice.Text = 'Tk ' + ('{0:N0}' -f $script:BaseHardwareValue)
            $script:scanDone = $true

            # -- Populate System Details tab --
            $LblSysDetailsPH.Visibility = 'Collapsed'
            $s = $r.Sys
            $rows = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
            @(
                [PSCustomObject]@{ Key='OS Name';              Value=$s.OS }
                [PSCustomObject]@{ Key='OS Version';           Value=$s.OSVersion }
                [PSCustomObject]@{ Key='OS Build';             Value=$s.OSBuild }
                [PSCustomObject]@{ Key='Install Date';         Value=$s.InstallDate }
                [PSCustomObject]@{ Key='Last Boot';            Value=$s.LastBoot }
                [PSCustomObject]@{ Key='Uptime';               Value=$s.Uptime }
                [PSCustomObject]@{ Key='';                     Value='' }
                [PSCustomObject]@{ Key='System Name';          Value=$s.SystemName }
                [PSCustomObject]@{ Key='Manufacturer';         Value=$s.Manufacturer }
                [PSCustomObject]@{ Key='Model';                Value=$s.Model }
                [PSCustomObject]@{ Key='System Type';          Value=$s.SystemType }
                [PSCustomObject]@{ Key='';                     Value='' }
                [PSCustomObject]@{ Key='Processor';            Value=$s.CPU }
                [PSCustomObject]@{ Key='CPU Cores / Threads';  Value=$s.CPUCores }
                [PSCustomObject]@{ Key='CPU Max Speed';        Value=$s.CPUSpeed }
                [PSCustomObject]@{ Key='Graphics';             Value=$s.GPU }
                [PSCustomObject]@{ Key='RAM Installed';        Value="$($s.RAM) GB" }
                [PSCustomObject]@{ Key='RAM Slots';            Value=$s.RAMSlots }
                [PSCustomObject]@{ Key='Storage Drives';       Value=$s.Disks }
                [PSCustomObject]@{ Key='';                     Value='' }
                [PSCustomObject]@{ Key='BIOS Version';         Value=$s.BIOSVersion }
                [PSCustomObject]@{ Key='BIOS Date';            Value=$s.BIOSDate }
                [PSCustomObject]@{ Key='BIOS Manufacturer';    Value=$s.BIOSManuf }
                [PSCustomObject]@{ Key='Motherboard';          Value="$($s.BoardManuf) $($s.BoardModel)" }
                [PSCustomObject]@{ Key='';                     Value='' }
                [PSCustomObject]@{ Key='MAC Address';          Value=$s.MACAddress }
                [PSCustomObject]@{ Key='IP Address';           Value=$s.IPAddress }
            ) | ForEach-Object { $rows.Add($_) }
            $SysDetailsPanel.ItemsSource = $rows

            # Update status
            $bcDone           = [Windows.Media.BrushConverter]::new()
            $now              = Get-Date -Format 'HH:mm'
            $StatusText.Text  = "Scan complete  $now"
            $StatusDot.Fill   = $bcDone.ConvertFromString('#10B981')
            $FooterText.Text  = "Humayoun Kobir Tool v1   Last scan: $now"

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
    if (-not $script:scanDone) {
        [System.Windows.MessageBox]::Show(
            'Run a full scan first (Overview tab) before calculating the estimate.',
            'Scan required', 'OK', 'Warning')
        return
    }

    $ageScore = if ($CboAge.SelectedItem) { [int]$CboAge.SelectedItem.Tag } else { 95 }
    $ageMultiplier = $ageScore / 100.0

    $combos = @($CboWarranty, $CboAccessories, $CboBattery, $CboScreen, $CboBody, $CboKeyboard, $CboPorts, $CboWebcam, $CboSpeakers)
    $scores = foreach ($c in $combos) {
        if ($c.SelectedItem) { [int]$c.SelectedItem.Tag } else { 100 }
    }
    $script:ConditionScore = [math]::Round(($scores | Measure-Object -Average).Average, 0)
    
    # Calculate Final Price
    # MSRP is depreciated heavily by the Age multiplier
    $ageDepreciatedValue = $script:BaseHardwareValue * $ageMultiplier

    $batPct    = if ($script:BatInfo.HealthPct -ge 0) { $script:BatInfo.HealthPct } else { 80 }
    $storScore = Calc-StorageScore $script:StorDrives

    # Final formula: diagnostic health (50%) + condition survey (50%)
    $diag  = ($batPct + $storScore) / 2
    $totalCondPct = ($diag * 0.5 + $script:ConditionScore * 0.5) / 100

    $result = @{
        Min        = [math]::Round(($ageDepreciatedValue * $totalCondPct * 0.85) / 100) * 100
        Max        = [math]::Round(($ageDepreciatedValue * $totalCondPct * 1.05) / 100) * 100
        OverallPct = [math]::Round($totalCondPct * 100, 1)
    }

    # Update UI
    $LblScore.Text      = ('{0}' -f $result.OverallPct) + '%'
    $LblScoreSub.Text   = "Battery $([math]::Round($batPct,0))%  |  Storage $storScore/100  |  Condition $($script:ConditionScore)/100"
    $LblPriceRange.Text = 'Tk ' + ('{0:N0}' -f $result.Min) + '  --  Tk ' + ('{0:N0}' -f $result.Max)
    $LblPriceNote.Text  = 'Based on hardware base value of Tk ' + ('{0:N0}' -f $baseVal)

    $PriceCard.Visibility = 'Visible'
    $BtnExportJSON.Visibility = 'Visible'
    $StatusText.Text    = 'Price estimate ready'
    $MainTabs.SelectedIndex = 5  # Price Estimate is now index 5 (SysDetails moved to 2nd)
})

# ---------------------------------------------------------------------------
# Export to JSON
# ---------------------------------------------------------------------------
$BtnExportJSON.Add_Click({
    if (-not $script:scanDone -or -not $script:BatInfo) {
        [System.Windows.MessageBox]::Show('Run a full scan first.', 'No data', 'OK', 'Warning')
        return
    }
    $report = [ordered]@{
        Timestamp = (Get-Date).ToString('o')
        System = $script:SysInfo
        Battery = $script:BatInfo
        Storage = $script:StorDrives
        ConditionScore = $script:ConditionScore
        BaseHardwareValue = $script:BaseHardwareValue
        PriceEstimate = @{
            OverallPct = $LblScore.Text
            Range = $LblPriceRange.Text
        }
    }
    $json = $report | ConvertTo-Json -Depth 5
    $path = "$([Environment]::GetFolderPath('Desktop'))\HKT_Report_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    try {
        $json | Out-File -FilePath $path -Encoding UTF8 -Force
        [System.Windows.MessageBox]::Show("Report exported successfully to:`n$path", "Export Complete", 'OK', 'Information')
    } catch {
        [System.Windows.MessageBox]::Show("Failed to export report:`n$($_.Exception.Message)", "Export Error", 'OK', 'Error')
    }
})

# ---------------------------------------------------------------------------
# Launch
# ---------------------------------------------------------------------------
$null = $window.ShowDialog()

