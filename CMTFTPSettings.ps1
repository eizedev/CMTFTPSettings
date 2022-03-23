<#
    .SYNOPSIS
        Quickly modify the Configuration Manager TFTP settings.
    .DESCRIPTION
        GUI to change the TFTP settings and restart the PXE service.
    .NOTES (ORIGINAL)
        Version 1.0: Initial script
            - Jorgen Nilsson <https://www.ccmexec.com/>
    .NOTES
        Works with PowerShell 7.1+
    .NOTES
        Created By:   Cameron Kollwitz <cameron@kollwitz.us>
        Updated By:   Eizedev (github@eize.dev)
        Version:      1.2.1
        Date:         2022-03-23
        File Name:    CMTFTPSettings.ps1
#>

# Find correct service (PXE without WDS = SCCMPxe, with WDS = WDSServer)
$ServiceName = "WDSServer"
If ((Get-Service -Name SccmPxe -ErrorAction SilentlyContinue)) { $ServiceName = "SccmPxe" }
If ((Get-Service -Name WDSServer -ErrorAction SilentlyContinue)) { $ServiceName = $ServiceName }

$inputXML = @"
<Window x:Name="SCCM_TFTP_Changer" x:Class="WpfApplication1.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        xmlns:local="clr-namespace:WpfApplication1"
        mc:Ignorable="d"
        Title="ConfigMgr TFTP Settings" Height="267.52" Width="384.414">
    <Grid Margin="0,0,2,-3">
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="48*"/>
            <ColumnDefinition Width="7*"/>
            <ColumnDefinition Width="36*"/>
            <ColumnDefinition Width="246*"/>
        </Grid.ColumnDefinitions>
        <Button x:Name="Save" Content="Save" HorizontalAlignment="Left" Margin="62.8,139,0,0" VerticalAlignment="Top" Width="75" Grid.Column="3"/>
        <Label x:Name="label" Content="TFTP BlockSize value" HorizontalAlignment="Left" Margin="38,35,0,0" VerticalAlignment="Top" Width="177" Grid.ColumnSpan="4"/>
        <Button x:Name="Exit" Content="Exit" HorizontalAlignment="Left" Margin="152.8,139,0,0" VerticalAlignment="Top" Width="75" Grid.Column="3"/>
        <Button x:Name="Restart" Content="Restart $ServiceName" HorizontalAlignment="Left" Margin="38,139,0,0" VerticalAlignment="Top" Width="110" Grid.ColumnSpan="4"/>
        <Label x:Name="label1" Content="TFTP WindowsSize value" HorizontalAlignment="Left" Margin="38,76,0,0" VerticalAlignment="Top" Width="142" Grid.ColumnSpan="4"/>
        <ComboBox x:Name="TFTPBlockSize" Grid.Column="3" HorizontalAlignment="Left" Margin="105.8,39,0,0" VerticalAlignment="Top" Width="120" SelectedIndex="0">
            <ComboBoxItem Content="1024"/>
            <ComboBoxItem Content="1456"/>
            <ComboBoxItem Content="2048"/>
            <ComboBoxItem Content="4096"/>
            <ComboBoxItem Content="8192"/>
            <ComboBoxItem Content="16384"/>
        </ComboBox>
        <ComboBox x:Name="TFTPWindowsSize" Grid.Column="3" HorizontalAlignment="Left" Margin="105.8,76,0,0" VerticalAlignment="Top" Width="120" SelectedIndex="0">
            <ComboBoxItem Content="1"/>
            <ComboBoxItem Content="2"/>
            <ComboBoxItem Content="4"/>
            <ComboBoxItem Content="8"/>
            <ComboBoxItem Content="16"/>
        </ComboBox>
        <TextBox x:Name="textBox" Grid.ColumnSpan="4" HorizontalAlignment="Left" Height="23" Margin="38,182,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="284" IsReadOnly="True"/>
    </Grid>
</Window>
"@

$inputXML = $inputXML -replace 'mc:Ignorable="d"', '' -replace "x:N", 'N' -replace '^<Win.*', '<Window'

[void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework')
[xml]$XAML = $inputXML
#Read XAML

$reader = (New-Object System.Xml.XmlNodeReader $xaml)
try { $Form = [Windows.Markup.XamlReader]::Load( $reader ) }
catch { Write-Host "Unable to load Windows.Markup.XamlReader. Double-check syntax and ensure .net is installed." }

#===========================================================================
# Load XAML Objects In PowerShell
#===========================================================================

$xaml.SelectNodes("//*[@Name]") | ForEach-Object { Set-Variable -Name "WPF$($_.Name)" -Value $Form.FindName($_.Name) }

Function Get-FormVariables
{
    if ($global:ReadmeDisplay -ne $true)
    {
        Write-Host "If you need to reference this display again, run Get-FormVariables" -ForegroundColor Yellow
        $global:ReadmeDisplay = $true
    }
    Write-Host "Found the following interactable elements from our form" -ForegroundColor Cyan
    Get-Variable WPF*
}

# Getting current values from registry
Try
{
    $comboBlockSize = $Form.FindName("TFTPBlockSize")
    $comboWindowSize = $Form.FindName("TFTPWindowsSize")
    $windowSize = Get-ItemPropertyValue "HKLM:\SOFTWARE\Microsoft\SMS\DP" -Name "RamDiskTFTPWindowSize" -ErrorAction Stop
    $blockSize = Get-ItemPropertyValue "HKLM:\SOFTWARE\Microsoft\SMS\DP" -Name "RamDiskTFTPBlockSize" -ErrorAction Stop

    $comboBlockSize.text = $blockSize
    $comboWindowSize.text = $windowSize
    $WPFTextbox.Text = ("Shown values are the current values")
}
Catch
{
    #$WPFTextbox.Text = ("Cannot find current values, using defaults")
    $windowSize = 1
    $comboWindowSize.text = $windowSize
    $blockSize = 4096
    $comboBlockSize.text = $blockSize
}

$WPFExit.Add_Click( { $form.Close() })

$WPFRestart.Add_Click(
    {
        $WPFTextbox.Text = ("Service is restarting")
        Start-Job -scriptblock { Restart-Service $ServiceName }
        Start-Sleep -s 3
        WaitUntilServices $ServiceName "Running"
        $WPFTextbox.Text = ("$ServiceName Service Restarted")
    }
)

$WPFSave.Add_Click(
    {
        $WPFTextbox.Text = ("Write to registry completed")
        Try
        {
            New-ItemProperty "HKLM:\SOFTWARE\Microsoft\SMS\DP" -Name "RamDiskTFTPWindowSize" -Value $WPFTFTPWindowsSize.text -PropertyType Dword -Force -ErrorAction Stop
            New-ItemProperty "HKLM:\SOFTWARE\Microsoft\SMS\DP" -Name "RamDiskTFTPBlockSize" -Value $WPFTFTPBlocksize.text -PropertyType Dword -Force -ErrorAction Stop

        }
        Catch
        {
            $WPFTextbox.Text = ("Write to registry Failed! Check your permissions")
        }
    }
)

function WaitUntilServices($searchString, $status)
{
    # Get all services where Name matches $searchString and loop through each of them.
    foreach ($service in (Get-Service -Name $searchString))
    {
        # Wait for the service to reach the $status or a maximum of 30 seconds
        $service.WaitForStatus($status, '00:01:00')
    }
}
#===========================================================================
# Shows the form
#===========================================================================
# write-host "To show the form, run the following" -ForegroundColor Cyan
$Form.ShowDialog() | Out-Null
