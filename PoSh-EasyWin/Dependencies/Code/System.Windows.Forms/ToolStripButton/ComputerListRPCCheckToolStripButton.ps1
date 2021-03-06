$ComputerListRPCCheckToolStripButtonAdd_Click = {
    Create-ComputerNodeCheckBoxArray

    if ($ComputerListProvideCredentialsCheckBox.Checked) { $Username = $script:Credential.UserName}
    else {$Username = $PoShEasyWinAccountLaunch }

    if ($script:ComputerTreeViewSelected.count -eq 0){
        [System.Windows.MessageBox]::Show('Error: You need to check at least one endpoint.','RPC Port Check')
    }
    else {
        if (Verify-Action -Title "Verification: RPC Port Check" -Question "Connecting Account:  $Username`n`nConduct a RPC Port Check to the following?" -Computer $($script:ComputerTreeViewSelected -join ', ')) {
            Check-Connection -CheckType "RPC Port Check" -MessageTrue "RPC Port 135 is Open" -MessageFalse "RPC Port 135 is Closed"
        }
        else {
            [system.media.systemsounds]::Exclamation.play()
            $StatusListBox.Items.Clear()
            $StatusListBox.Items.Add("RPC Port Check:  Cancelled")
        }
    }
}

<#
$ComputerListRPCCheckToolStripButtonAdd_MouseHover = {
    Show-ToolTip -Title "RPC Port Check" -Icon "Info" -Message @"
+  Unresponsive hosts can be removed from being nodes checked.
+  Command:
    function Test-Port {
        param ($ComputerName, $Port)
        begin { $tcp = New-Object Net.Sockets.TcpClient }
        process {
            try { $tcp.Connect($ComputerName, $Port) } catch {}
            if ($tcp.Connected) { $tcp.Close(); $open = $true }
            else { $open = $false }
            [PSCustomObject]@{ IP = $ComputerName; Port = $Port; Open = $open }
        }
    }
    $CheckCommand = Test-Port -ComputerName $target -Port 135 | Select-Object -ExpandProperty Open
+  Command Alternative (Sends Ping First):
    Test-NetConnection -Port 135 -ComputerName <target>`n`n
"@
}
#>


