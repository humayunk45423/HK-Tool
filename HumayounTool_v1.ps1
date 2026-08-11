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
[xml]$xaml = @'
<Window
  xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
  xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
  Title="Humayoun Tool"
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
          <Border Width="36" Height="36" CornerRadius="10" Background="{DynamicResource BtnBg}" Margin="0,0,16,0">
            <Border.Effect>
              <DropShadowEffect BlurRadius="10" ShadowDepth="2" Opacity="0.3" Color="#000000"/>
            </Border.Effect>
            <TextBlock Text="H" FontSize="18" FontWeight="Bold" Foreground="#FFFFFF"
                       HorizontalAlignment="Center" VerticalAlignment="Center"/>
          </Border>
          <TextBlock Text="Humayoun Tool" FontSize="18" FontWeight="Bold" Foreground="{DynamicResource TextMain}" VerticalAlignment="Center"/>
          <Border Background="{DynamicResource PopupBg}" CornerRadius="6" Margin="12,0,0,0" Padding="8,4" BorderBrush="{DynamicResource BorderCol}" BorderThickness="1">
            <TextBlock Text="v1.0" FontSize="11" FontWeight="Bold" Foreground="{DynamicResource TextMuted}" FontFamily="Consolas"/>
          </Border>
        </StackPanel>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
          <Button Name="BtnTheme" Content="ðŸŒ—" Width="36" Height="36" Background="{DynamicResource PopupBg}" BorderBrush="{DynamicResource BorderCol}" BorderThickness="1" Foreground="{DynamicResource TextMain}" Cursor="Hand" Margin="0,0,24,0" ToolTip="Toggle Light/Dark Theme">
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
                     Text="Ready -- click Run Full Scan"/>
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
                  <RowDefinition/><RowDefinition Height="20"/><RowDefinition/>
                  <RowDefinition Height="20"/><RowDefinition/>
                  <RowDefinition Height="20"/><RowDefinition/>
                  <RowDefinition Height="20"/><RowDefinition/>
                  <RowDefinition Height="20"/><RowDefinition/>
                </Grid.RowDefinitions>

                <!-- Screen -->
                <TextBlock Grid.Row="0" Grid.Column="0" Text="Screen Display" FontSize="15" FontWeight="SemiBold" Foreground="{DynamicResource TextMain}" VerticalAlignment="Center"/>
                <ComboBox Grid.Row="0" Grid.Column="1" Name="CboScreen" Style="{StaticResource DarkCombo}">
                  <ComboBoxItem Content="Perfect (No scratches, no dead pixels)"   Tag="100" IsSelected="True"/>
                  <ComboBoxItem Content="Minor scratches (Barely visible)"           Tag="85"/>
                  <ComboBoxItem Content="Noticeable scratches or light bleed"         Tag="65"/>
                  <ComboBoxItem Content="Crack or significant damage"                 Tag="30"/>
                </ComboBox>

                <!-- Body -->
                <TextBlock Grid.Row="2" Grid.Column="0" Text="Body / Chassis" FontSize="15" FontWeight="SemiBold" Foreground="{DynamicResource TextMain}" VerticalAlignment="Center"/>
                <ComboBox Grid.Row="2" Grid.Column="1" Name="CboBody" Style="{StaticResource DarkCombo}">
                  <ComboBoxItem Content="Like new (No dents or scratches)"   Tag="100" IsSelected="True"/>
                  <ComboBoxItem Content="Light scratches, no dents"            Tag="85"/>
                  <ComboBoxItem Content="Visible dents or chips"               Tag="60"/>
                  <ComboBoxItem Content="Cracked or heavily damaged"           Tag="25"/>
                </ComboBox>

                <!-- Keyboard -->
                <TextBlock Grid.Row="4" Grid.Column="0" Text="Keyboard" FontSize="15" FontWeight="SemiBold" Foreground="{DynamicResource TextMain}" VerticalAlignment="Center"/>
                <ComboBox Grid.Row="4" Grid.Column="1" Name="CboKeyboard" Style="{StaticResource DarkCombo}">
                  <ComboBoxItem Content="All keys work perfectly"              Tag="100" IsSelected="True"/>
                  <ComboBoxItem Content="Minor fade or slight sticking"        Tag="80"/>
                  <ComboBoxItem Content="1-2 keys faulty"                      Tag="55"/>
                  <ComboBoxItem Content="Multiple keys not working"            Tag="20"/>
                </ComboBox>

                <!-- Ports -->
                <TextBlock Grid.Row="6" Grid.Column="0" Text="Ports" FontSize="15" FontWeight="SemiBold" Foreground="{DynamicResource TextMain}" VerticalAlignment="Center"/>
                <ComboBox Grid.Row="6" Grid.Column="1" Name="CboPorts" Style="{StaticResource DarkCombo}">
                  <ComboBoxItem Content="All ports functional"                  Tag="100" IsSelected="True"/>
                  <ComboBoxItem Content="One port loose or non-functional"      Tag="80"/>
                  <ComboBoxItem Content="Multiple ports faulty"                 Tag="50"/>
                </ComboBox>

                <!-- Webcam -->
                <TextBlock Grid.Row="8" Grid.Column="0" Text="Webcam" FontSize="15" FontWeight="SemiBold" Foreground="{DynamicResource TextMain}" VerticalAlignment="Center"/>
                <ComboBox Grid.Row="8" Grid.Column="1" Name="CboWebcam" Style="{StaticResource DarkCombo}">
                  <ComboBoxItem Content="Works fine"                             Tag="100" IsSelected="True"/>
                  <ComboBoxItem Content="Slightly blurry / intermittent"         Tag="70"/>
                  <ComboBoxItem Content="Not working"                            Tag="40"/>
                  <ComboBoxItem Content="No webcam (Desktop)"                   Tag="90"/>
                </ComboBox>

                <!-- Speakers -->
                <TextBlock Grid.Row="10" Grid.Column="0" Text="Speakers" FontSize="15" FontWeight="SemiBold" Foreground="{DynamicResource TextMain}" VerticalAlignment="Center"/>
                <ComboBox Grid.Row="10" Grid.Column="1" Name="CboSpeakers" Style="{StaticResource DarkCombo}">
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
                 Text="Humayoun Tool v1.0   Windows Only   Open Source"/>
    </Border>

  </Grid>
</Window>

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

# ---------------------------------------------------------------------------
# Theme Toggle
# ---------------------------------------------------------------------------
$script:isDarkMode = $true
$BtnTheme.Add_Click({
    $script:isDarkMode = -not $script:isDarkMode
    $bc = [Windows.Media.BrushConverter]::new()
    
    if ($script:isDarkMode) {
        $window.Resources['AppBg'].Color       = $bc.ConvertFromString('#080808').Color
        $window.Resources['CardBg'].Color      = $bc.ConvertFromString('#111111').Color
        $window.Resources['BorderCol'].Color   = $bc.ConvertFromString('#2A2A2A').Color
        $window.Resources['TextMain'].Color    = $bc.ConvertFromString('#E0E0E0').Color
        $window.Resources['TextSec'].Color     = $bc.ConvertFromString('#C0C0C0').Color
        $window.Resources['TextMuted'].Color   = $bc.ConvertFromString('#505050').Color
        $window.Resources['TextDark'].Color    = $bc.ConvertFromString('#383838').Color
        $window.Resources['BtnBg'].Color       = $bc.ConvertFromString('#E0E0E0').Color
        $window.Resources['BtnHover'].Color    = $bc.ConvertFromString('#FFFFFF').Color
        $window.Resources['BtnPress'].Color    = $bc.ConvertFromString('#B0B0B0').Color
        $window.Resources['BtnText'].Color     = $bc.ConvertFromString('#080808').Color
        $window.Resources['PopupBg'].Color     = $bc.ConvertFromString('#1A1A1A').Color
        $window.Resources['PopupHover'].Color  = $bc.ConvertFromString('#333333').Color
        $window.Resources['BarBg'].Color       = $bc.ConvertFromString('#1E1E1E').Color
        $window.Resources['BarFg'].Color       = $bc.ConvertFromString('#E0E0E0').Color
        $window.Resources['AccentGreen'].Color = $bc.ConvertFromString('#58D68D').Color
    } else {
        $window.Resources['AppBg'].Color       = $bc.ConvertFromString('#F4F6F8').Color
        $window.Resources['CardBg'].Color      = $bc.ConvertFromString('#FFFFFF').Color
        $window.Resources['BorderCol'].Color   = $bc.ConvertFromString('#E2E8F0').Color
        $window.Resources['TextMain'].Color    = $bc.ConvertFromString('#0F172A').Color
        $window.Resources['TextSec'].Color     = $bc.ConvertFromString('#334155').Color
        $window.Resources['TextMuted'].Color   = $bc.ConvertFromString('#64748B').Color
        $window.Resources['TextDark'].Color    = $bc.ConvertFromString('#94A3B8').Color
        $window.Resources['BtnBg'].Color       = $bc.ConvertFromString('#0F172A').Color
        $window.Resources['BtnHover'].Color    = $bc.ConvertFromString('#1E293B').Color
        $window.Resources['BtnPress'].Color    = $bc.ConvertFromString('#334155').Color
        $window.Resources['BtnText'].Color     = $bc.ConvertFromString('#F8FAFC').Color
        $window.Resources['PopupBg'].Color     = $bc.ConvertFromString('#FFFFFF').Color
        $window.Resources['PopupHover'].Color  = $bc.ConvertFromString('#F1F5F9').Color
        $window.Resources['BarBg'].Color       = $bc.ConvertFromString('#E2E8F0').Color
        $window.Resources['BarFg'].Color       = $bc.ConvertFromString('#0F172A').Color
        $window.Resources['AccentGreen'].Color = $bc.ConvertFromString('#16A34A').Color
    }
})

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
                if ($bat.HealthPct -ge 80)      { $LblBatHealth.Foreground = $bc.ConvertFromString('#10B981') }
                elseif ($bat.HealthPct -ge 60)  { $LblBatHealth.Foreground = $bc.ConvertFromString('#F59E0B') }
                else                            { $LblBatHealth.Foreground = $bc.ConvertFromString('#EF4444') }

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
                    $card.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, 'CardBg')
                    $card.SetResourceReference([System.Windows.Controls.Border]::BorderBrushProperty, 'BorderCol')
                    $card.BorderThickness = [Windows.Thickness]::new(1)
                    $card.CornerRadius = [Windows.CornerRadius]::new(12)
                    $card.Padding    = [Windows.Thickness]::new(20)
                    $card.Margin     = [Windows.Thickness]::new(0, 0, 0, 12)

                    $sp = [Windows.Controls.StackPanel]::new()

                    $mkTb = {
                        param($text, $size, $resKey, $margin)
                        $tb             = [System.Windows.Controls.TextBlock]::new()
                        $tb.Text        = $text
                        $tb.FontSize    = $size
                        $tb.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, $resKey)
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
            $script:BaseHardwareValue = Calc-HardwareBaseValue $r.Sys.CPU $r.Sys.RAM $r.Sys.GPU $r.Stor
            $LblBasePrice.Text = "$("{0:N0}" -f $script:BaseHardwareValue) Tk"

            # Update status
            $now              = Get-Date -Format 'HH:mm'
            $StatusText.Text  = "Scan complete  $now"
                        $StatusDot.Fill   = $bc.ConvertFromString('#10B981')
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
    if (-not $script:BatInfo) {
        [System.Windows.MessageBox]::Show(
            'Run a full scan first (Overview tab) before calculating the estimate.',
            'Scan required', 'OK', 'Warning')
        return
    }

    $combos = @($CboScreen, $CboBody, $CboKeyboard, $CboPorts, $CboWebcam, $CboSpeakers)
    $scores = foreach ($c in $combos) {
        if ($c.SelectedItem) { [int]$c.SelectedItem.Tag } else { 80 }
    }
    $script:ConditionScore = [math]::Round(($scores | Measure-Object -Average).Average, 0)
    
    # Calculate Final Price
    $batPct    = if ($script:BatInfo.HealthPct -ge 0) { $script:BatInfo.HealthPct } else { 80 }
    $storScore = Calc-StorageScore $script:StorDrives
    $baseVal   = $script:BaseHardwareValue

    $result    = Calc-Price $baseVal $batPct $storScore $script:ConditionScore

    # Update UI
    $LblScore.Text      = "$($result.OverallPct)%"
    $LblScoreSub.Text   = "Battery $([math]::Round($batPct,0))%   Storage $storScore/100   Condition $($script:ConditionScore)/100"
    $LblPriceRange.Text = "Tk $("{0:N0}" -f $result.Min)  --  Tk $("{0:N0}" -f $result.Max)"
    $LblPriceNote.Text  = "Based on automated hardware base value of Tk $("{0:N0}" -f $baseVal)"
    
    $PriceCard.Visibility = 'Visible'
    $BtnExportJSON.Visibility = 'Visible'
    $StatusText.Text    = "Price estimate ready"
    $MainTabs.SelectedIndex  = 4
})

# ---------------------------------------------------------------------------
# Export to JSON
# ---------------------------------------------------------------------------
$BtnExportJSON.Add_Click({
    if (-not $script:BatInfo) { return }
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
    $path = "$([Environment]::GetFolderPath('Desktop'))\HumayounTool_Report_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
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

