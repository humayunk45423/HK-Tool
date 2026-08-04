$ErrorActionPreference = 'Stop'
try {
    [xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
  <Window.Resources>
    <Style x:Key="DarkCombo" TargetType="ComboBox">
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ComboBox">
            <Grid>
              <ToggleButton x:Name="ToggleButton" Focusable="false" ClickMode="Press">
                <ToggleButton.Template>
                  <ControlTemplate TargetType="ToggleButton">
                    <Border x:Name="Bd" Background="#111111" />
                    <ControlTemplate.Triggers>
                      <Trigger Property="IsMouseOver" Value="True">
                        <Setter Property="Background" Value="#1A1A1A" TargetName="Bd" />
                      </Trigger>
                    </ControlTemplate.Triggers>
                  </ControlTemplate>
                </ToggleButton.Template>
              </ToggleButton>
            </Grid>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>
</Window>
'@
    Add-Type -AssemblyName PresentationFramework
    $reader = [System.Xml.XmlNodeReader]::new($xaml)
    $win = [Windows.Markup.XamlReader]::Load($reader)
    Write-Host 'XAML IS PERFECT'
} catch {
    Write-Host 'XAML ERROR: ' $_.Exception.Message
}
