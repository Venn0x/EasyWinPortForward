Import-Module NetSecurity

# Ensure we're running as an administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrator)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Import required assemblies
Add-Type -AssemblyName PresentationFramework

# Path to the CSV file where rules will be saved
$CsvFilePath = "$env:USERPROFILE\port_forwarding_rules.csv"

# Function to save the data
function Save-PortForwardingRules {
    $IpPortList | Export-Csv -Path $CsvFilePath -NoTypeInformation -Force
}

# Function to load the data
function Load-PortForwardingRules {
    if (Test-Path $CsvFilePath) {
        Import-Csv $CsvFilePath
    } else {
        @()
    }
}

# Function to refresh the port proxy list
function Refresh-PortProxyList {
    $IpPortList.Clear()

    # Load saved rules
    $savedRules = Load-PortForwardingRules

    # Fetch current port proxy rules
    $rules = netsh interface portproxy show all v4tov4
    $rules -split "`r?`n" | ForEach-Object {
        if ($_ -match '^\s*(\S+)\s+(\d+)\s+(\S+)\s+(\d+)') {
            $match = $savedRules | Where-Object {
                $_.ListenAddress -eq $matches[1] -and
                $_.ListenPort -eq $matches[2] -and
                $_.ConnectAddress -eq $matches[3] -and
                $_.ConnectPort -eq $matches[4]
            }
            $IpPortList.Add([pscustomobject]@{
                ListenAddress  = $matches[1]
                ListenPort     = $matches[2]
                ConnectAddress = $matches[3]
                ConnectPort    = $matches[4]
                Name           = if ($match) { $match.Name } else { "" }
            })
        }
    }
}

# XAML for the main window
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Port Forwarding Manager | v4tov4" Height="450" Width="600" WindowStartupLocation="CenterScreen" WindowStyle="SingleBorderWindow" ShowInTaskbar="True">
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/> <!-- Footer row -->
        </Grid.RowDefinitions>

        <DataGrid x:Name="IpPortTable" Grid.Row="0" AutoGenerateColumns="False" CanUserAddRows="False" IsReadOnly="True">
            <DataGrid.Columns>
                <DataGridTextColumn Header="Name" Binding="{Binding Path=Name}" Width="*" />
                <DataGridTextColumn Header="Listen Address" Binding="{Binding Path=ListenAddress}" Width="*" />
                <DataGridTextColumn Header="Listen Port" Binding="{Binding Path=ListenPort}" Width="*" />
                <DataGridTextColumn Header="Connect Address" Binding="{Binding Path=ConnectAddress}" Width="*" />
                <DataGridTextColumn Header="Connect Port" Binding="{Binding Path=ConnectPort}" Width="*" />
            </DataGrid.Columns>
        </DataGrid>

        <StackPanel Grid.Row="1" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,10,0,0">
            <Button x:Name="AddPortButton" Width="75" Margin="5,0">Add Port</Button>
            <Button x:Name="RemovePortButton" Width="75" Margin="5,0">Remove Port</Button>
        </StackPanel>

        <TextBlock Grid.Row="2" x:Name="WslIpText" Margin="5,0" VerticalAlignment="Center" HorizontalAlignment="Center"/>

        <StackPanel Grid.Row="3" Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,10,0,10">
            <TextBlock Margin="5,0" VerticalAlignment="Center">
                <Run Text="© Mihai Badea 2024" />
                <Run Text=" | " />
                <Hyperlink NavigateUri="http://mihaibadea.com">mihaibadea.com</Hyperlink>
                <Run Text=" | " />
                <Hyperlink NavigateUri="https://github.com/Venn0x">github.com/Venn0x</Hyperlink>
            </TextBlock>
        </StackPanel>
    </Grid>
</Window>
"@

# Load XAML as a WPF window
$reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
$Window = [Windows.Markup.XamlReader]::Load($reader)

# Get the controls from the XAML
$IpPortTable = $Window.FindName("IpPortTable")
$AddPortButton = $Window.FindName("AddPortButton")
$RemovePortButton = $Window.FindName("RemovePortButton")
$WslIpText = $Window.FindName("WslIpText")

# Retrieve the WSL IP address
$remoteport = bash.exe -c "ifconfig eth0 | grep 'inet '"
$found = $remoteport -match '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}'
$wslIp = if ($found) { $matches[0] } else { "WSL IP not found" }

# Set the WSL IP text
$WslIpText.Text = "WSL IP: $wslIp"

# Initialize the observable collection
$IpPortList = New-Object System.Collections.ObjectModel.ObservableCollection[PSCustomObject]

# Set the data source of the DataGrid
$IpPortTable.ItemsSource = $IpPortList

# Load the current port proxy list
Refresh-PortProxyList

# Event handler for Add Port button
$AddPortButton.Add_Click({
    # XAML for the input window
    $inputXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Add Port Forwarding Rule" Height="300" Width="400" WindowStartupLocation="CenterOwner" WindowStyle="SingleBorderWindow" ShowInTaskbar="False">
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/> <!-- Name -->
            <RowDefinition Height="Auto"/> <!-- Listen Address -->
            <RowDefinition Height="Auto"/> <!-- Listen Port -->
            <RowDefinition Height="Auto"/> <!-- Connect Address -->
            <RowDefinition Height="Auto"/> <!-- Connect Port -->
            <RowDefinition Height="Auto"/> <!-- Autofill Button -->
            <RowDefinition Height="*"/>    <!-- Submit and Cancel Buttons -->
        </Grid.RowDefinitions>

        <TextBlock Grid.Row="0" Text="Name:" VerticalAlignment="Center" Margin="0,5,10,5"/>
        <TextBox x:Name="NameInput" Grid.Row="0" Margin="120,5,0,5" Width="200" HorizontalAlignment="Left" />

        <TextBlock Grid.Row="1" Text="Listen Address:" VerticalAlignment="Center" Margin="0,5,10,5"/>
        <TextBox x:Name="ListenAddressInput" Grid.Row="1" Margin="120,5,0,5" Width="200" HorizontalAlignment="Left" />

        <TextBlock Grid.Row="2" Text="Listen Port:" VerticalAlignment="Center" Margin="0,5,10,5"/>
        <TextBox x:Name="ListenPortInput" Grid.Row="2" Margin="120,5,0,5" Width="200" HorizontalAlignment="Left" />

        <TextBlock Grid.Row="3" Text="Connect Address:" VerticalAlignment="Center" Margin="0,5,10,5"/>
        <TextBox x:Name="ConnectAddressInput" Grid.Row="3" Margin="120,5,0,5" Width="200" HorizontalAlignment="Left" />

        <TextBlock Grid.Row="4" Text="Connect Port:" VerticalAlignment="Center" Margin="0,5,10,5"/>
        <TextBox x:Name="ConnectPortInput" Grid.Row="4" Margin="120,5,0,5" Width="200" HorizontalAlignment="Left" />

        <Button x:Name="AutoFillIpButton" Grid.Row="5" Width="150" Margin="120,5,0,5" HorizontalAlignment="Left">
            Autofill WSL Forwarding
        </Button>

        <StackPanel Grid.Row="6" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,10,0,0">
            <Button x:Name="SubmitButton" Width="75" Margin="5,0">Submit</Button>
            <Button x:Name="CancelButton" Width="75" Margin="5,0">Cancel</Button>
        </StackPanel>
    </Grid>
</Window>
"@

    # Load XAML for the input window
    $inputReader = New-Object System.Xml.XmlNodeReader ([xml]$inputXaml)
    $InputWindow = [Windows.Markup.XamlReader]::Load($inputReader)

    # Get the controls from the input window XAML
    $NameInput = $InputWindow.FindName("NameInput")
    $ListenAddressInput = $InputWindow.FindName("ListenAddressInput")
    $ListenPortInput = $InputWindow.FindName("ListenPortInput")
    $ConnectAddressInput = $InputWindow.FindName("ConnectAddressInput")
    $ConnectPortInput = $InputWindow.FindName("ConnectPortInput")
    $AutoFillIpButton = $InputWindow.FindName("AutoFillIpButton")
    $SubmitButton = $InputWindow.FindName("SubmitButton")
    $CancelButton = $InputWindow.FindName("CancelButton")

    # Event handler for Autofill button
    $AutoFillIpButton.Add_Click({
        $ListenAddressInput.Text = "0.0.0.0"
        $ConnectAddressInput.Text = $wslIp
    })

    # Event handler for Submit button
    $SubmitButton.Add_Click({
        $name = $NameInput.Text
        $addr = $ListenAddressInput.Text
        $port = $ListenPortInput.Text
        $remoteaddr = $ConnectAddressInput.Text
        $remoteport = $ConnectPortInput.Text

        if ($name -and $addr -and $port -and $remoteaddr -and $remoteport) {
            # Remove existing rule
            iex "netsh interface portproxy delete v4tov4 listenport=$port listenaddress=$addr"
            # Add new rule
            iex "netsh interface portproxy add v4tov4 listenport=$port listenaddress=$addr connectport=$remoteport connectaddress=$remoteaddr"

            # Add firewall rules with custom names
            $inboundRuleName = "EasyWinPortForward Inbound - $name - $port"
            $outboundRuleName = "EasyWinPortForward Outbound - $name - $port"
        
            iex "New-NetFireWallRule -DisplayName '$inboundRuleName' -Direction Inbound -LocalPort $port -Action Allow -Protocol TCP"
            iex "New-NetFireWallRule -DisplayName '$outboundRuleName' -Direction Outbound -LocalPort $port -Action Allow -Protocol TCP"

            # Add the rule to the list and save it
            $IpPortList.Add([pscustomobject]@{
                Name           = $name
                ListenAddress  = $addr
                ListenPort     = $port
                ConnectAddress = $remoteaddr
                ConnectPort    = $remoteport
            })

            Save-PortForwardingRules
            Refresh-PortProxyList

            $InputWindow.Close()
        } else {
            [System.Windows.MessageBox]::Show("Please fill in all fields.")
        }
    })


    # Event handler for Cancel button
    $CancelButton.Add_Click({
        $InputWindow.Close()
    })

    $InputWindow.ShowDialog() | Out-Null
})

# Event handler for Remove Port button
$RemovePortButton.Add_Click({
    $selectedItem = $IpPortTable.SelectedItem
    if ($selectedItem) {
        # Generate the names of the firewall rules to remove
        $inboundRuleName = "EasyWinPortForward Inbound - $($selectedItem.Name) - $($selectedItem.ListenPort)"
        $outboundRuleName = "EasyWinPortForward Outbound - $($selectedItem.Name) - $($selectedItem.ListenPort)"

        # Remove the port proxy rule
        iex "netsh interface portproxy delete v4tov4 listenport=$($selectedItem.ListenPort) listenaddress=$($selectedItem.ListenAddress)"
        
        # Remove the corresponding firewall rules
        iex "Remove-NetFirewallRule -DisplayName '$inboundRuleName'"
        iex "Remove-NetFirewallRule -DisplayName '$outboundRuleName'"

        # Remove the item from the list and save the changes
        $IpPortList.Remove($selectedItem)
        Save-PortForwardingRules

        Refresh-PortProxyList
    } else {
        [System.Windows.MessageBox]::Show("Please select an item to remove.")
    }
})


# Show the main window
$Window.ShowDialog() | Out-Null
