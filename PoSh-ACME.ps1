﻿<#
    .SYNOPSIS  
     _______             ____  __               _____     ____  ___    __  _____ 
     |   _  \           /  __||  |             /  _  \   / ___\ |  \  /  | | ___|
     |  |_)  | _____   |  (   |  |___   ____  |  (_)  | / /     |   \/   | | |_  
     |   ___/ /  _  \   \  \  |   _  \ |____| |   _   || |      | |\  /| | |  _| 
     |  |    |  (_)  | __)  | |  | |  |       |  | |  | \ \____ | | \/ | | | |__ 
     |__|     \_____/ |____/  |__| |__|       |__| |__|  \____/ |_|    |_| |____|
     ============================================================================
     PowerShell-Analyst's Collection Made Easy (ACME) for Security Professionals. 
     ACME: The point at which something is the Best, Perfect, or Most Successful! 
     ============================================================================
     File Name      : PoSh-ACME.ps1
     Version        : v.2.3 Beta

     Author         : high101bro
     Email          : high101bro@gmail.com
     Website        : https://github.com/high101bro/PoSH-ACME

     Requirements   : PowerShell v3 or Higher
                    : WinRM  (Default Port 5986)
     Optional       : PSExec.exe, Procmon.exe, Autoruns.exe 
        		    : Can run standalone, but works best with the Resources folder!
     Updated        : 19 Dec 18
     Created        : 21 Aug 18

    PoSh-ACME is a tool that allows you to run any number of queries against any number
    of hosts. The queries primarily consist of one liner commands, but several are made
    of scripts that allows for obtaining data on older systems like Server 2008 R2 where
    newer commands are not supported. PoSh-ACME consists of queries speicific for hosts
    and servers, workgroups and domains, registry and Event Logs. It provides a simple
    way to view data in CSV format using PowerShell's built in Out-GridView, as well as
    displays the data in various chart formats. Other add-on features includes a spread
    of external applications like various Sysinternals tools, and basic reference info
    for quick use when not on the web.

    As the name indicates, PoSh-ACME is writen in PowerShell. The GUI utilizes the .net 
    frame work to access Windows built in WinForms.

    Troubleshooting remote connection failures
        about_Remote_Troubleshooting
        about_Remote
        about_Remote_Requirements
                        
    .EXAMPLE
        This will run PoSh-ACME.ps1 and provide prompts that will tailor your collection.
             PowerShell.exe -ExecutionPolicy ByPass -NoProfile -File .\PoSh-ACME.ps1

    .Link
        https://github.com/high101bro/PoSH-ACME
        http://lmgtfy.com/?q=high101bro+PoSH-ACME

    .NOTES  
        Remember this is a script, not a program. So when it's conducting its queries the 
        GUI will be unresponsive to user interaction even though you are able to view 
        status and timer updates.

        In order to run the script:
        - Update locally
            Open a PowerShell terminal with Administrator privledges
              - Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process
              - Get-ExecutionPolicy -List

        - Update via GPO
            Open the GPO for editing. In the GPO editor, select:
              - Computer Configuration > Policies > Administrative Templates > Windows Components > Windows PowerShell
              - Right-click "Turn on script execution", then select "Edit"
              - In the winodws that appears, click on "Enabled" radio button
              - Under "Execution Policy", select "Allow All Scripts"
              - Click on "Ok", then close the GPO Editor
              - Push out GPO Updates, or on the computer's powershell/cmd terminal, type in `"gpupdate /force"
#>


# Check if the script is running with Administrator Privlieges, if not it will attempt to re-run and prompt for credentials
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.VisualBasic")
    $verify = [Microsoft.VisualBasic.Interaction]::MsgBox(`
        "Attention Under-Privileged User!`n   $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)`n`nThe queries executed to remotely collect data require elevated credentials. You can either run this script with elevated privileges or provide them later by selecting the checkbox 'Use Credentials'.",`
        'YesNoCancel,Question',`
        "PoSH-ACME")
    switch ($verify) {
    'Yes'{
        $arguments = "& '" + $myinvocation.mycommand.definition + "'"
        Start-Process powershell -WindowStyle Hidden -Verb runAs -ArgumentList $arguments
        exit
    }
    'No'     {continue}
    'Cancel' {exit}
    }
}


#============================================================================================================================================================
# Variables
#============================================================================================================================================================

# Universally sets the ErrorActionPreference to Silently Continue
$ErrorActionPreference = "SilentlyContinue"
   
# Location PoSh-ACME will save files
$PoShHome = Split-Path -parent $MyInvocation.MyCommand.Definition

    # Files
    $LogFile                             = "$PoShHome\Log File.txt"
    $IPListFile                          = "$PoShHome\iplist.txt"
    $ComputerListTreeViewFileTemp        = "$PoShHome\Computer List TreeView (temp).csv"
    $ComputerListTreeViewFileSaved       = "$PoShHome\Computer List TreeView (Saved).csv"

    $OpNotesFile                         = "$PoShHome\OpNotes.txt"
    $OpNotesWriteOnlyFile                = "$PoShHome\OpNotes (Write Only).txt"

    # Name of Collected Data Directory
    $CollectedDataDirectory              = "$PoShHome\Collected Data"
        # Location of separate queries
        $CollectedDataTimeStampDirectory = "$CollectedDataDirectory\$((Get-Date).ToString('yyyy-MM-dd @ HHmm ss'))"
        # Location of Uncompiled Results
        $IndividualHostResults           = "$CollectedDataTimeStampDirectory\Individual Host Results"
    
    # Location of Resources directory
    $ResourcesDirectory = "$PoShHome\Resources"
        # Location of Host Commands directory
        $CommandsHostDirectory           = "$ResourcesDirectory\Commands - Host"
        # Location of Event Logs Commands directory
        $CommandsEventLogsDirectory      = "$ResourcesDirectory\Commands - Event Logs"
        # Location of Active Directory Commands directory
        $CommandsActiveDirectory         = "$ResourcesDirectory\Commands - Active Directory"
        # Location of External Programs directory
        $ExternalPrograms                = "$ResourcesDirectory\External Programs"

# Logs what account ran the script and when
$LogMessage = "$((Get-Date).ToString('yyyy/MM/dd HH:mm:ss')) - PoSh-ACME executed by: $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)"
$LogMessage | Add-Content -Path $LogFile

# Sets the thread priority for queries for the script
$ThreadPriority = {
    # AvaiLabel priority values: Low, BelowNormal, Normal, AboveNormal, High, RealTime
    [System.Threading.Thread]::CurrentThread.Priority = 'High'
    ([System.Diagnostics.Process]::GetCurrentProcess()).PriorityClass = 'High'
}

# The Font Used
$Font = "Courier"

$SleepTime = 5

# Number of jobs simultaneously when collecting data
$ThrottleLimit = 32

# Clears out Computer List variable
$ComputerList = ""

# Credentials will be stored in this variable
$Credential = ""

#============================================================================================================================================================
# Function Name 'ListComputers' - Takes entered domain and lists all computers
#============================================================================================================================================================

Function ListComputers([string]$Choice,[string]$Script:Domain) {
    $DN = ""
    $Response = ""
    $DNSName = ""
    $DNSArray = ""
    $objSearcher = ""
    $colProplist = ""
    $objComputer = ""
    $objResults = ""
    $colResults = ""
    $Computer = ""
    $comp = ""
    New-Item -type file -force "$Script:Folder_Path\Computer_List$Script:curDate.txt" | Out-Null
    $Script:Compute = "$Script:Folder_Path\Computer_List$Script:curDate.txt"
    $strCategory = "(ObjectCategory=Computer)"
       
    If($Choice -eq "Auto" -or $Choice -eq "" ) {
        $DNSName = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().Name
        If($DNSName -ne $Null) {
            $DNSArray = $DNSName.Split(".") 
            for ($x = 0; $x -lt $DNSArray.Length ; $x++) {  
                if ($x -eq ($DNSArray.Length - 1)){$Separator = ""}else{$Separator =","} 
                [string]$DN += "DC=" + $DNSArray[$x] + $Separator  } }
        $Script:Domain = $DN
        echo "Pulled computers from: "$Script:Domain 
        $objSearcher = New-Object System.DirectoryServices.DirectorySearcher("LDAP://$Script:Domain")
        $objSearcher.Filter = $strCategory
        $objSearcher.PageSize = 100000
        $objSearcher.SearchScope = "SubTree"
        $colProplist = "name"
        foreach ($i in $colPropList) {
            $objSearcher.propertiesToLoad.Add($i) }
        $colResults = $objSearcher.FindAll()
        foreach ($objResult in $colResults) {
            $objComputer = $objResult.Properties
            $comp = $objComputer.name
            echo $comp | Out-File $Script:Compute -Append }
        $Script:ComputerList = (Get-Content $Script:Compute) | Sort-Object
    }
	elseif($Choice -eq "Manual")
    {
        $objOU = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$Script:Domain")
        $objSearcher = New-Object System.DirectoryServices.DirectorySearcher
        $objSearcher.SearchRoot = $objOU
        $objSearcher.Filter = $strCategory
        $objSearcher.PageSize = 100000
        $objSearcher.SearchScope = "SubTree"
        $colProplist = "name"
        foreach ($i in $colPropList) { $objSearcher.propertiesToLoad.Add($i) }
        $colResults = $objSearcher.FindAll()
        foreach ($objResult in $colResults) {
            $objComputer = $objResult.Properties
            $comp = $objComputer.name
            echo $comp | Out-File $Script:Compute -Append }
        $Script:ComputerList = (Get-Content $Script:Compute) | Sort-Object
    }
    else {
        Write-Host "You did not supply a correct response, Please select a response." -foregroundColor Red
        . ListComputers }
}


#============================================================================================================================================================
# Function Name 'ListTextFile' - Enumerates Computer Names in a text file
# Create a text file and enter the names of each computer. One computer
# name per line. Supply the path to the text file when prompted.
#============================================================================================================================================================
Function ListTextFile 
{
  $file_Dialog = ""
    $file_Name = ""
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    $file_Dialog = New-Object system.windows.forms.openfiledialog
    $file_Dialog.InitialDirectory = "$env:USERPROFILE\Desktop"
    $file_Dialog.MultiSelect = $false
    $file_Dialog.showdialog()
    $file_Name = $file_Dialog.filename
    $Comps = Get-Content $file_Name
    If ($Comps -eq $Null) {
        $MainListBox.Items.Clear()
        $MainListBox.Items.Add("Your file was empty. You must select a file with at least one computer in it.")        
        $file_Dialog.Close()
        #. ListTextFile 
        }
    Else
    {
        $Script:ComputerList = @()
        ForEach ($Comp in $Comps)
        {
            If ($Comp -match "\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/\d{1,2}")
            {
                $Temp = $Comp.Split("/")
                $IP = $Temp[0]
                $Mask = $Temp[1]
                . Get-Subnet-Range $IP $Mask
                $Script:ComputerList += $Script:IPList
            }
            Else
            {
                $Script:ComputerList += $Comp
            }
        }
    }
}

Function Get-Subnet-Range {
    #.Synopsis
    # Lists all IPs in a subnet.
    #.Example
    # Get-Subnet-Range -IP 192.168.1.0 -Netmask /24
    #.Example
    # Get-Subnet-Range -IP 192.168.1.128 -Netmask 255.255.255.128
    Param(
        [string]
        $IP,
        [string]
        $netmask
    )  
    Begin {
        $IPs = New-Object System.Collections.ArrayList

        Function Get-NetworkAddress {
            #.Synopsis
            # Get the network address of a given lan segment
            #.Example
            # Get-NetworkAddress -IP 192.168.1.36 -mask 255.255.255.0
            Param (
                [string]
                $IP,
                [string]
                $Mask,
                [switch]
                $Binary
            )
            Begin {
                $NetAdd = $null
            }
            Process {
                $BinaryIP = ConvertTo-BinaryIP $IP
                $BinaryMask = ConvertTo-BinaryIP $Mask
                0..34 | %{
                    $IPBit = $BinaryIP.Substring($_,1)
                    $MaskBit = $BinaryMask.Substring($_,1)
                    IF ($IPBit -eq '1' -and $MaskBit -eq '1') {
                        $NetAdd = $NetAdd + "1"
                    } elseif ($IPBit -eq ".") {
                        $NetAdd = $NetAdd +'.'
                    } else {
                        $NetAdd = $NetAdd + "0"
                    }
                }
                if ($Binary) {
                    return $NetAdd
                } else {
                    return ConvertFrom-BinaryIP $NetAdd
                }
            }
        }
       
        Function ConvertTo-BinaryIP {
            #.Synopsis
            # Convert an IP address to binary
            #.Example
            # ConvertTo-BinaryIP -IP 192.168.1.1
            Param (
                [string]
                $IP
            )
            Process {
                $out = @()
                Foreach ($octet in $IP.split('.')) {
                    $strout = $null
                    0..7|% {
                        IF (($octet - [math]::pow(2,(7-$_)))-ge 0) {
                            $octet = $octet - [math]::pow(2,(7-$_))
                            [string]$strout = $strout + "1"
                        } else {
                            [string]$strout = $strout + "0"
                        }  
                    }
                    $out += $strout
                }
                return [string]::join('.',$out)
            }
        }
 
 
        Function ConvertFrom-BinaryIP {
            #.Synopsis
            # Convert from Binary to an IP address
            #.Example
            # Convertfrom-BinaryIP -IP 11000000.10101000.00000001.00000001
            Param (
                [string]
                $IP
            )
            Process {
                $out = @()
                Foreach ($octet in $IP.split('.')) {
                    $strout = 0
                    0..7|% {
                        $bit = $octet.Substring(($_),1)
                        IF ($bit -eq 1) {
                            $strout = $strout + [math]::pow(2,(7-$_))
                        }
                    }
                    $out += $strout
                }
                return [string]::join('.',$out)
            }
        }

        Function ConvertTo-MaskLength {
            #.Synopsis
            # Convert from a netmask to the masklength
            #.Example
            # ConvertTo-MaskLength -Mask 255.255.255.0
            Param (
                [string]
                $mask
            )
            Process {
                $out = 0
                Foreach ($octet in $Mask.split('.')) {
                    $strout = 0
                    0..7|% {
                        IF (($octet - [math]::pow(2,(7-$_)))-ge 0) {
                            $octet = $octet - [math]::pow(2,(7-$_))
                            $out++
                        }
                    }
                }
                return $out
            }
        }
 
        Function ConvertFrom-MaskLength {
            #.Synopsis
            # Convert from masklength to a netmask
            #.Example
            # ConvertFrom-MaskLength -Mask /24
            #.Example
            # ConvertFrom-MaskLength -Mask 24
            Param (
                [int]
                $mask
            )
            Process {
                $out = @()
                [int]$wholeOctet = ($mask - ($mask % 8))/8
                if ($wholeOctet -gt 0) {
                    1..$($wholeOctet) |%{
                        $out += "255"
                    }
                }
                $subnet = ($mask - ($wholeOctet * 8))
                if ($subnet -gt 0) {
                    $octet = 0
                    0..($subnet - 1) | %{
                         $octet = $octet + [math]::pow(2,(7-$_))
                    }
                    $out += $octet
                }
                for ($i=$out.count;$i -lt 4; $I++) {
                    $out += 0
                }
                return [string]::join('.',$out)
            }
        }

        Function Get-IPRange {
            #.Synopsis
            # Given an Ip and subnet, return every IP in that lan segment
            #.Example
            # Get-IPRange -IP 192.168.1.36 -Mask 255.255.255.0
            #.Example
            # Get-IPRange -IP 192.168.5.55 -Mask /23
            Param (
                [string]
                $IP,
               
                [string]
                $netmask
            )
            Process {
                iF ($netMask.length -le 3) {
                    $masklength = $netmask.replace('/','')
                    $Subnet = ConvertFrom-MaskLength $masklength
                } else {
                    $Subnet = $netmask
                    $masklength = ConvertTo-MaskLength -Mask $netmask
                }
                $network = Get-NetworkAddress -IP $IP -Mask $Subnet
               
                [int]$FirstOctet,[int]$SecondOctet,[int]$ThirdOctet,[int]$FourthOctet = $network.split('.')
                $TotalIPs = ([math]::pow(2,(32-$masklength)) -2)
                $blocks = ($TotalIPs - ($TotalIPs % 256))/256
                if ($Blocks -gt 0) {
                    1..$blocks | %{
                        0..255 |%{
                            if ($FourthOctet -eq 255) {
                                If ($ThirdOctet -eq 255) {
                                    If ($SecondOctet -eq 255) {
                                        $FirstOctet++
                                        $secondOctet = 0
                                    } else {
                                        $SecondOctet++
                                        $ThirdOctet = 0
                                    }
                                } else {
                                    $FourthOctet = 0
                                    $ThirdOctet++
                                }  
                            } else {
                                $FourthOctet++
                            }
                            Write-Output ("{0}.{1}.{2}.{3}" -f `
                            $FirstOctet,$SecondOctet,$ThirdOctet,$FourthOctet)
                        }
                    }
                }
                $sBlock = $TotalIPs - ($blocks * 256)
                if ($sBlock -gt 0) {
                    1..$SBlock | %{
                        if ($FourthOctet -eq 255) {
                            If ($ThirdOctet -eq 255) {
                                If ($SecondOctet -eq 255) {
                                    $FirstOctet++
                                    $secondOctet = 0
                                } else {
                                    $SecondOctet++
                                    $ThirdOctet = 0
                                }
                            } else {
                                $FourthOctet = 0
                                $ThirdOctet++
                            }  
                        } else {
                            $FourthOctet++
                        }
                        Write-Output ("{0}.{1}.{2}.{3}" -f `
                        $FirstOctet,$SecondOctet,$ThirdOctet,$FourthOctet)
                    }
                }
            }
        }
    }
    Process {
        #get every ip in scope
        Get-IPRange $IP $netmask | %{
        [void]$IPs.Add($_)
        }
        $Script:IPList = $IPs
    }
}

#============================================================================================================================================================
# Function Name 'SingleEntry' - Enumerates Computer from user input
#============================================================================================================================================================
Function SingleEntry {
    $Comp = $SingleHostIPTextBox.Text
    If ($Comp -eq $Null) { . SingleEntry } 
    ElseIf ($Comp -match "\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/\d{1,2}")
    {
        $Temp = $Comp.Split("/")
        $IP = $Temp[0]
        $Mask = $Temp[1]
        . Get-Subnet-Range $IP $Mask
        $Script:ComputerList = $Script:IPList
    }
    Else
    { $Script:ComputerList = $Comp}
}

# Used with the Listbox features to select one host from a list
Function SelectListBoxEntry {
    $Comp = $ComputerListBox.SelectedItems
    If ($Comp -eq $Null) { . SelectListBoxEntry } 
    ElseIf ($Comp -match "\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/\d{1,2}")
    {
        $Temp = $Comp.Split("/")
        $IP = $Temp[0]
        $Mask = $Temp[1]
        . Get-Subnet-Range $IP $Mask
        $Script:ComputerList = $Script:IPList
    }
    Else
    { $Script:ComputerList = $Comp}
}

#============================================================================================================================================================
# Create Directory and Files
#============================================================================================================================================================
New-Item -ItemType Directory -Path "$PoShHome" -Force | Out-Null 

#============================================================================================================================================================
# PoSh-ACME Form
#============================================================================================================================================================

# This fuction is what generates the who GUI and contains the majority of the script
function PoSh-ACME_GUI {
    [reflection.assembly]::loadwithpartialname("System.Windows.Forms") | Out-Null
    [reflection.assembly]::loadwithpartialname("System.Drawing") | Out-Null

$OnLoadForm_StateCorrection= {
    # Correct the initial state of the form to prevent the .Net maximized form issue
    $PoShACME.WindowState = $InitialFormWindowState
}


#============================================================================================================================================================
# This is the overall window for PoSh-ACME
#============================================================================================================================================================
# Varables for overall windows
$PoShACMERightPosition = 10
$PoShACMEDownPosition  = 10
$PoShACMEBoxWidth      = 1223
$PoShACMEBoxHeight     = 635

$PoShACME               = New-Object System.Windows.Forms.Form
$PoShACME.Text          = "PoSh-ACME   [$([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)]"
$PoShACME.Name          = "PoSh-ACME"
$PoShACME.Icon          = [System.Drawing.Icon]::ExtractAssociatedIcon("$ResourcesDirectory\favicon.ico")
$PoShACME.Location      = New-Object System.Drawing.Size($PoShACMERightPosition,$PoShACMEDownPosition) 
$PoShACME.Size          = New-Object System.Drawing.Size($PoShACMEBoxWidth,$PoShACMEBoxHeight)
$PoShACME.StartPosition = "CenterScreen"
$PoShACME.ClientSize    = $System_Drawing_Size
#$PoShACME.Topmost = $true
$PoShACME.Top = $true
$PoShACME.BackColor     = "fff5ff"
$PoShACME.FormBorderStyle =  "fixed3d"
#$InitialFormWindowState = New-Object System.Windows.Forms.FormWindowState


##############################################################################################################################################################
##############################################################################################################################################################
##
## Section 1 Tab Control
##
##############################################################################################################################################################
##############################################################################################################################################################

# Varables to Control Section 1 Tab Control
$Section1TabControlRightPosition  = 5
$Section1TabControlDownPosition   = 5
$Section1TabControlBoxWidth       = 460
$Section1TabControlBoxHeight      = 590

$Section1TabControl               = New-Object System.Windows.Forms.TabControl
$Section1TabControl.Name          = "Main Tab Window"
$Section1TabControl.SelectedIndex = 0
$Section1TabControl.ShowToolTips  = $True
$Section1TabControl.Location      = New-Object System.Drawing.Size($Section1TabControlRightPosition,$Section1TabControlDownPosition) 
$Section1TabControl.Size          = New-Object System.Drawing.Size($Section1TabControlBoxWidth,$Section1TabControlBoxHeight) 
$PoShACME.Controls.Add($Section1TabControl)

##############################################################################################################################################################
##
## Section 1 Collections SubTab
##
##############################################################################################################################################################

$Section1CollectionsTab          = New-Object System.Windows.Forms.TabPage
$Section1CollectionsTab.Text     = "Collections"
$Section1CollectionsTab.Name     = "Collections Tab"
$Section1CollectionsTab.UseVisualStyleBackColor = $True
$Section1TabControl.Controls.Add($Section1CollectionsTab)

# Variable Sizes
$TabRightPosition     = 3
$TabhDownPosition     = 3
$TabAreaWidth         = 446
$TabAreaHeight        = 557

$TextBoxRightPosition = -2 
$TextBoxDownPosition  = -2
$TextBoxWidth         = 442
$TextBoxHeight        = 536

#============================================================================================================================================================
# Functions used for commands/queries
#============================================================================================================================================================
function Conduct-PreCommandExecution {
    param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName)

    # Creates variables used for saving files
    $Global:CollectionDirectory = $CollectionName
    $Global:CollectionShortName = $CollectionName -replace ' ',''

    # Creates directory for the collection
    New-Item -ItemType Directory "$IndividualHostResults\$CollectionName" -Force | Out-Null

    # Provides updates to the status and main listbox
    $StatusListBox.Items.Clear()
    $StatusListBox.Items.Add("Collecting Data: $CollectionName")
    $MainListBox.Items.Insert(0,"")
    $MainListBox.Items.Insert(0,"$((Get-Date).ToString('yyyy/MM/dd HH:mm:ss'))  $CollectionName")
}

function Conduct-PreCommandCheck {
    param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionDirectory,$CollectionName,$TargetComputer)

    # If the file already exists in the directory (happens if you rerun the scan without updating the folder name/timestamp) it will delete it.
    # Removes the individual results
    Remove-Item "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -Force -ErrorAction SilentlyContinue
    # Removes the compiled results
    Remove-Item "$CollectedDataTimeStampDirectory\$CollectionName.csv" -Force -ErrorAction SilentlyContinue
}

function Create-LogEntry {
    param($LogFile)

    # Creates a log entry to an external file
    $LogMessage = "$((Get-Date).ToString('yyyy/MM/dd HH:mm:ss'))  $CollectionName"
    $LogMessage | Add-Content -Path $LogFile
}


function Conduct-PostCommandExecution {
    param($CollectionName)

    # Provides updates to the status and main listbox
    $MainListBox.Items.RemoveAt(0)
    $MainListBox.Items.RemoveAt(0)
    $MainListBox.Items.Insert(0,"$((Get-Date).ToString('yyyy/MM/dd HH:mm:ss'))  Completed: $CollectionName")
    $StatusListBox.Items.Clear()
    $StatusListBox.Items.Add("Finished Collecting Data!")
}

#####################################################################################################################################
##
## Section 1 Collections TabControl
##
#####################################################################################################################################

# The TabControl controls the tabs within it
$Section1CollectionsTabControl               = New-Object System.Windows.Forms.TabControl
$Section1CollectionsTabControl.Name          = "Collections TabControl"
$Section1CollectionsTabControl.Location      = New-Object System.Drawing.Size($TabRightPosition,$TabhDownPosition)
$Section1CollectionsTabControl.Size          = New-Object System.Drawing.Size($TabAreaWidth,$TabAreaHeight) 
$Section1CollectionsTabControl.ShowToolTips  = $True
$Section1CollectionsTabControl.SelectedIndex = 0
$Section1CollectionsTab.Controls.Add($Section1CollectionsTabControl)

############################################################################################################
# Section 1 Queries SubTab
############################################################################################################

# Varables for positioning checkboxes
$QueriesRightPosition     = 5
$QueriesDownPositionStart = 10
$QueriesDownPosition      = 10
$QueriesDownPositionShift = 25

$QueriesBoxWidth          = 410
$QueriesBoxHeight         = 25


#-------------
# Queries Tab
#-------------

$Section1QueriesTab          = New-Object System.Windows.Forms.TabPage
$Section1QueriesTab.Location = $System_Drawing_Point
$Section1QueriesTab.Text     = "Host Queries"

$Section1QueriesTab.Location  = New-Object System.Drawing.Size($Column1RightPosition,$Column1DownPosition) 
$Section1QueriesTab.Size      = New-Object System.Drawing.Size($Column1BoxWidth,$Column1BoxHeight) 
$Section1QueriesTab.UseVisualStyleBackColor = $True
$Section1CollectionsTabControl.Controls.Add($Section1QueriesTab)

#============================================================================================================================================================
# Column 1
#============================================================================================================================================================
# Varables to Control Column 1
$Column1RightPosition     = 3
$Column1DownPositionStart = 0      
$Column1DownPosition      = 0
$Column1DownPositionShift = 17
$Column1BoxWidth          = 220
$Column1BoxHeight         = 20


#------------------------------
# Quck Pick Label
#------------------------------

$QuickPickLabel           = New-Object System.Windows.Forms.Label
$QuickPickLabel.Location  = New-Object System.Drawing.Size($Column1RightPosition,($Column1DownPosition + 5)) 
$QuickPickLabel.Size      = New-Object System.Drawing.Size(180,$Column1BoxHeight) 
$QuickPickLabel.Text      = "Quick Selection"
$QuickPickLabel.Font = New-Object System.Drawing.Font("$Font",13,1,2,1)
$QuickPickLabel.ForeColor = "Blue"
$Section1QueriesTab.Controls.Add($QuickPickLabel)

#============================================================================================================================================================
# Commands Quick Pick Checkedlistbox 
#============================================================================================================================================================

$CommandsQuickPickCheckedlistbox          = New-Object -TypeName System.Windows.Forms.CheckedListBox
$CommandsQuickPickCheckedlistbox.Name     = "New Checklistbox"
$CommandsQuickPickCheckedlistbox.Text     = "$($CommandsQuickPickCheckedlistbox.Name)"
$CommandsQuickPickCheckedlistbox.Location = New-Object System.Drawing.Size($Column1RightPosition,($QuickPickLabel.Location.Y + $QuickPickLabel.Size.Height + 3)) 
$CommandsQuickPickCheckedlistbox.Size     = New-Object System.Drawing.Size(430,80)
$CommandsQuickPickCheckedlistbox.ScrollAlwaysVisible = $true
$CommandsQuickPickCheckedlistbox.Items.Add("Clear")
$CommandsQuickPickCheckedlistbox.Items.Add("Select All")
$CommandsQuickPickCheckedlistbox.Items.Add("WMI Commands")
$CommandsQuickPickCheckedlistbox.Items.Add("Hardware Info")
$CommandsQuickPickCheckedlistbox.Items.Add("Hunt the Bad Stuff")
$CommandsQuickPickCheckedlistbox.Add_Click({
    If ($CommandsQuickPickCheckedlistbox.SelectedItem -eq 'Clear') {
        # Checks only the desired quick boxes
        $CommandsQuickPickCheckedlistbox.SetItemchecked(0,$True)
        $CommandsQuickPickCheckedlistbox.SetItemchecked(1,$False)
        $CommandsQuickPickCheckedlistbox.SetItemchecked(2,$False)
        $CommandsQuickPickCheckedlistbox.SetItemchecked(3,$False)
        $CommandsQuickPickCheckedlistbox.SetItemchecked(4,$False)
        # Clears the commands selected
        For ($i=0;$i -lt $CommandsSelectionCheckedlistbox.Items.count;$i++) {
            $CommandsSelectionCheckedlistbox.SetSelected($i,$False)
            $CommandsSelectionCheckedlistbox.SetItemChecked($i,$False)
            $CommandsSelectionCheckedlistbox.SetItemCheckState($i,$False)
        }
    }
    If ($CommandsQuickPickCheckedlistbox.SelectedItem -eq 'Select All') {
        # Checks only the desired quick boxes
        $CommandsQuickPickCheckedlistbox.SetItemchecked(0,$False)
        $CommandsQuickPickCheckedlistbox.SetItemchecked(1,$True)
        $CommandsQuickPickCheckedlistbox.SetItemchecked(2,$False)
        $CommandsQuickPickCheckedlistbox.SetItemchecked(3,$False)
        $CommandsQuickPickCheckedlistbox.SetItemchecked(4,$False)
        # Selects all the commands
        For ($i=0;$i -lt $CommandsSelectionCheckedlistbox.Items.count;$i++) {
            $CommandsSelectionCheckedlistbox.SetSelected($i,$True)
            $CommandsSelectionCheckedlistbox.SetItemChecked($i,$True)
            $CommandsSelectionCheckedlistbox.SetItemCheckState($i,$True)
        }
    }
    If ($CommandsQuickPickCheckedlistbox.SelectedItem -eq 'WMI Commands') {
        # Checks only the desired quick boxes
        $CommandsQuickPickCheckedlistbox.SetItemchecked(0,$False)
        $CommandsQuickPickCheckedlistbox.SetItemchecked(1,$False)
        $CommandsQuickPickCheckedlistbox.SetItemchecked(2,$True)
        $CommandsQuickPickCheckedlistbox.SetItemchecked(3,$False)
        $CommandsQuickPickCheckedlistbox.SetItemchecked(4,$False)

        # Initially clears the command list
        For ($i=0;$i -lt $CommandsSelectionCheckedlistbox.Items.count;$i++) {
            $CommandsSelectionCheckedlistbox.SetSelected($i,$False)
            $CommandsSelectionCheckedlistbox.SetItemChecked($i,$False)
            $CommandsSelectionCheckedlistbox.SetItemCheckState($i,$False)
        }
        $CommandsSelectionCheckedlistbox.SetItemChecked(0,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(2,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(3,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(4,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(5,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(6,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(9,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(11,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(12,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(15,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(16,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(19,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(20,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(21,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(22,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(23,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(24,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(27,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(36,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(41,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(42,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(45,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(46,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(47,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(48,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(49,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(50,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(52,$True)
    }
    If ($CommandsQuickPickCheckedlistbox.SelectedItem -eq 'Hardware Info') {
        # Checks only the desired quick boxes
        $CommandsQuickPickCheckedlistbox.SetItemchecked(0,$False)
        $CommandsQuickPickCheckedlistbox.SetItemchecked(1,$False)
        $CommandsQuickPickCheckedlistbox.SetItemchecked(2,$False)
        $CommandsQuickPickCheckedlistbox.SetItemchecked(3,$True)
        $CommandsQuickPickCheckedlistbox.SetItemchecked(4,$False)

        # Initially clears the command list
        For ($i=0;$i -lt $CommandsSelectionCheckedlistbox.Items.count;$i++) {
            $CommandsSelectionCheckedlistbox.SetSelected($i,$False)
            $CommandsSelectionCheckedlistbox.SetItemChecked($i,$False)
            $CommandsSelectionCheckedlistbox.SetItemCheckState($i,$False)
        }
        $CommandsSelectionCheckedlistbox.SetItemChecked(2,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(3,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(6,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(9,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(20,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(22,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(24,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(36,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(42,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(51,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(52,$True)
    }
    If ($CommandsQuickPickCheckedlistbox.SelectedItem -eq 'Hunt the Bad Stuff') {
        # Checks only the desired quick boxes
        $CommandsQuickPickCheckedlistbox.SetItemchecked(0,$False)
        $CommandsQuickPickCheckedlistbox.SetItemchecked(1,$False)
        $CommandsQuickPickCheckedlistbox.SetItemchecked(2,$False)
        $CommandsQuickPickCheckedlistbox.SetItemchecked(3,$False)
        $CommandsQuickPickCheckedlistbox.SetItemchecked(4,$True)

        # Initially clears the command list
        For ($i=0;$i -lt $CommandsSelectionCheckedlistbox.Items.count;$i++) {
            $CommandsSelectionCheckedlistbox.SetSelected($i,$False)
            $CommandsSelectionCheckedlistbox.SetItemChecked($i,$False)
            $CommandsSelectionCheckedlistbox.SetItemCheckState($i,$False)
        }
        # Selects only specific commands
        $CommandsSelectionCheckedlistbox.SetItemChecked(0,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(13,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(14,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(15,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(16,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(25,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(26,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(37,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(41,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(46,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(47,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(48,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(49,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(50,$True)
        $CommandsSelectionCheckedlistbox.SetItemChecked(51,$True)
    }

})
$Section1QueriesTab.Controls.Add($CommandsQuickPickCheckedlistbox)

#============================================================================================================================================================
# Commands Selection
#============================================================================================================================================================

#--------------------
# Host Queries Label
#--------------------
$HostQueriesLabel           = New-Object System.Windows.Forms.Label
$HostQueriesLabel.Location  = New-Object System.Drawing.Size($Column1RightPosition,($CommandsQuickPickCheckedlistbox.Location.Y + $CommandsQuickPickCheckedlistbox.Size.Height + 4)) 
$HostQueriesLabel.Size      = New-Object System.Drawing.Size(95,$Column1BoxHeight) 
$HostQueriesLabel.Text      = "Host Queries"
$HostQueriesLabel.Font      = New-Object System.Drawing.Font("$Font",13,1,2,1)
$HostQueriesLabel.ForeColor = "Blue"
$Section1QueriesTab.Controls.Add($HostQueriesLabel)

$QueryLabel2           = New-Object System.Windows.Forms.Label
$QueryLabel2.Location  = New-Object System.Drawing.Size(($Column1RightPosition + 95),($CommandsQuickPickCheckedlistbox.Location.Y + $CommandsQuickPickCheckedlistbox.Size.Height + 6)) 
$QueryLabel2.Size      = New-Object System.Drawing.Size(400,($Column1BoxHeight - 4)) 
$QueryLabel2.Text      = "* = Uses WMI for backwards compatibility (Server 2008 R2 + Windows 7)"
$QueryLabel2.Font      = New-Object System.Drawing.Font("$Font",10,0,2,0)
$QueryLabel2.ForeColor = "Blue"
$Section1QueriesTab.Controls.Add($QueryLabel2) 

#-----------------------------------
# Commands Selection Checkedlistbox
#-----------------------------------
$CommandsSelectionCheckedlistbox          = New-Object -TypeName System.Windows.Forms.CheckedListBox
$CommandsSelectionCheckedlistbox.Name     = "Command Selection"
#$CommandsSelectionCheckedlistbox.Text     = "$($CommandsSelectionCheckedlistbox.Name)"
$CommandsSelectionCheckedlistbox.Location = New-Object System.Drawing.Size($Column1RightPosition,($HostQueriesLabel.Location.Y + $HostQueriesLabel.Size.Height + 3)) 
$CommandsSelectionCheckedlistbox.Size     = New-Object System.Drawing.Size(430,405)
$CommandsSelectionCheckedlistbox.checked = $true
$CommandsSelectionCheckedlistbox.ScrollAlwaysVisible = $true
$CommandsSelectionCheckedlistbox.Items.Add('Accounts - Local  *')
$CommandsSelectionCheckedlistbox.Items.Add('ARP Cache')
$CommandsSelectionCheckedlistbox.Items.Add('BIOS Info  *')
$CommandsSelectionCheckedlistbox.Items.Add('Computer Info  *')
$CommandsSelectionCheckedlistbox.Items.Add('Dates - Install, Bootup, System  *')
$CommandsSelectionCheckedlistbox.Items.Add('Disk - Logical Info  *')
$CommandsSelectionCheckedlistbox.Items.Add('Disk - Physical Info  *')
$CommandsSelectionCheckedlistbox.Items.Add('DLLs Loaded by Processes')
$CommandsSelectionCheckedlistbox.Items.Add('DNS Cache')
$CommandsSelectionCheckedlistbox.Items.Add('Drivers - Detailed  *')
$CommandsSelectionCheckedlistbox.Items.Add('Drivers - Signed Info')
$CommandsSelectionCheckedlistbox.Items.Add('Drivers - Valid Signatures  *')
$CommandsSelectionCheckedlistbox.Items.Add('Environmental Variables  *')
$CommandsSelectionCheckedlistbox.Items.Add('Firewall Rules')
$CommandsSelectionCheckedlistbox.Items.Add('Firewall Status')
$CommandsSelectionCheckedlistbox.Items.Add('Groups - Local  *')
$CommandsSelectionCheckedlistbox.Items.Add('Logon Info  *')
$CommandsSelectionCheckedlistbox.Items.Add('Logon Sessions')
$CommandsSelectionCheckedlistbox.Items.Add('Logon User Status')
$CommandsSelectionCheckedlistbox.Items.Add('Mapped Drives  *')
$CommandsSelectionCheckedlistbox.Items.Add('Memory - Capacity Info  *')
$CommandsSelectionCheckedlistbox.Items.Add('Memory - Performance Data  *')
$CommandsSelectionCheckedlistbox.Items.Add('Memory - Physical Info  *')
$CommandsSelectionCheckedlistbox.Items.Add('Memory - Utilization  *')
$CommandsSelectionCheckedlistbox.Items.Add('Motherboard Info  *')
$CommandsSelectionCheckedlistbox.Items.Add('Network Connections TCP')
$CommandsSelectionCheckedlistbox.Items.Add('Network Connections UDP')
$CommandsSelectionCheckedlistbox.Items.Add('Network Settings  *')
$CommandsSelectionCheckedlistbox.Items.Add('Network Statistics IPv4 All')
$CommandsSelectionCheckedlistbox.Items.Add('Network Statistics IPv4 TCP')
$CommandsSelectionCheckedlistbox.Items.Add('Network Statistics IPv4 UDP')
$CommandsSelectionCheckedlistbox.Items.Add('Network Statistics IPv4 ICMP')
$CommandsSelectionCheckedlistbox.Items.Add('Network Statistics IPv6 All')
$CommandsSelectionCheckedlistbox.Items.Add('Network Statistics IPv6 TCP')
$CommandsSelectionCheckedlistbox.Items.Add('Network Statistics IPv6 UDP')
$CommandsSelectionCheckedlistbox.Items.Add('Network Statistics IPv6 ICMP')
$CommandsSelectionCheckedlistbox.Items.Add('Plug and Play Devices  *')
$CommandsSelectionCheckedlistbox.Items.Add('Port Proxy Rules')
$CommandsSelectionCheckedlistbox.Items.Add('Prefetch Files')
$CommandsSelectionCheckedlistbox.Items.Add('Process Tree - Lineage')
$CommandsSelectionCheckedlistbox.Items.Add('Processes - Enhanced with Hashes')
$CommandsSelectionCheckedlistbox.Items.Add('Processes - Standard  *')
$CommandsSelectionCheckedlistbox.Items.Add('Processor - CPU Info  *')
$CommandsSelectionCheckedlistbox.Items.Add('Remote Capability Check')
$CommandsSelectionCheckedlistbox.Items.Add('Scheduled Tasks - schtasks')
$CommandsSelectionCheckedlistbox.Items.Add('Screen Saver Info  *')
$CommandsSelectionCheckedlistbox.Items.Add('Security Patches  *')
$CommandsSelectionCheckedlistbox.Items.Add('Services  *')
$CommandsSelectionCheckedlistbox.Items.Add('Shares  *')
$CommandsSelectionCheckedlistbox.Items.Add('Software Installed *')
$CommandsSelectionCheckedlistbox.Items.Add('Startup Commands  *')
$CommandsSelectionCheckedlistbox.Items.Add('System Info')
$CommandsSelectionCheckedlistbox.Items.Add('USB Controller Devices  *')
$CommandsSelectionCheckedlistbox.Add_Click({
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'Accounts - Local') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\Accounts - Local.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'ARP Cache') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\ARP Cache.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'BIOS Info') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\BIOS Info.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'Computer Info') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\Computer Info.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'Dates - Install, Bootup, System') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\Dates - Install, Bootup, System.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'Disk - Logical Info') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\Disk - Logical Info.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'Disk - Physical Info') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\Disk - Physical Info.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'DLLs Loaded by Processes') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\DLLs Loaded by Processes.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'DNS Cache') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\DNS Cache.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'Drivers - Detailed') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\Drivers - Detailed.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'Drivers - Signed Info') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\Drivers - Signed Info.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'Drivers - Valid Signatures') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\Drivers - Valid Signatures.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'Environmental Variables') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\Environmental Variables.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'Firewall Rules') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\Firewall Rules.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'Firewall Status') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\Firewall Status.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'Groups - Local') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\Groups - Local.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'Logon Info') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\Logon Info.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'Logon Sessions') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\Logon Sessions.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'Logon User Status') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\Logon User Status.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'Mapped Drives') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\Mapped Drives.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'Memory - Capacity Info') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\Memory - Capacity Info.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'Memory - Physical Info') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\Memory - Physical Info.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'Memory - Performance Data') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\Memory - Performance Data.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'Memory - Utilization') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\Memory - Utilization.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'Motherboard Info') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\Motherboard Info.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'Network Connections TCP') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\Network Connections TCP.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'Network Connections UDP') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\Network Connections UDP.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'Network Settings') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\Network Settings.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'Network Statistics IPv4 All') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\Network Statistics IPv4 All.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'Network Statistics IPv4 TCP') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\Network Statistics IPv4 TCP.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'Network Statistics IPv4 UDP') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\Network Statistics IPv4 UDP.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'Network Statistics IPv4 ICMP') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\Network Statistics IPv4 ICMP.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'Network Statistics IPv6 All') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\Network Statistics IPv6 All.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'Network Statistics IPv6 TCP') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\Network Statistics IPv6 TCP.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'Network Statistics IPv6 UDP') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\Network Statistics IPv6 UDP.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'Network Statistics IPv6 ICMP') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\Network Statistics IPv6 ICMP.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'Plug and Play Devices') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\Plug and Play Devices.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'Port Proxy Rules') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\Port Proxy Rules.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'Prefetch Files') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\Prefetch Files.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'Process Tree - Lineage') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\Process Tree - Lineage.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'Processes - Enhanced with Hashes') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\Processes - Enhanced with Hashes.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'Processes - Standard') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\Processes - Standard.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'Processor - CPU Info') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\Processor - CPU Info.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'Remote Capability Check') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\Remote Capability Check.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'Scheduled Tasks - schtasks') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\Scheduled Tasks - schtasks.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'Screen Saver Info') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\Screen Saver Info.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'Security Patches') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\Security Patches.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'Services') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\Services.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'Shares') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\Shares.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'Software Installed') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\Software Installed.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'Startup Commands') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\Startup Commands.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'System Info') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\System Info.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($CommandsSelectionCheckedlistbox.SelectedItem -match 'USB Controller Devices') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsHostDirectory\USB Controller Devices.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
})

$Section1QueriesTab.Controls.Add($CommandsSelectionCheckedlistbox)

# Shift the Text and Button's Locaiton
$Column1DownPosition   += $Column1DownPositionShift

#============================================================================================================================================================
# Accounts - Local
#============================================================================================================================================================

function AccountsLocalCommand {
    $CollectionName = "Accounts - Local"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority                               
                                            
                Get-WmiObject -Credential $Credential -Class Win32_UserAccount -Filter "LocalAccount='True'" -ComputerName $TargetComputer `
                | Select-Object -Property PSComputerName, Name, Disabled, AccountType, Lockout, PasswordChangeable, PasswordRequired, SID, SIDType, LocalAccount, Domain, Caption, Description `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                           
                Get-WmiObject -Class Win32_UserAccount -Filter "LocalAccount='True'" -ComputerName $TargetComputer `
                | Select-Object -Property PSComputerName, Name, Disabled, AccountType, Lockout, PasswordChangeable, PasswordRequired, SID, SIDType, LocalAccount, Domain, Caption, Description `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# ARP Cache 
#============================================================================================================================================================

function ARPCacheCommand {
    $CollectionName = "ARP Cache"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }            
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                
                Invoke-Command -Credential $Credential -ComputerName $TargetComputer -ScriptBlock {
                    cmd /c arp -a
                } -ArgumentList @($null) | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"

                if ((Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt") -eq $null) {
                    Remove-Item "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"
                }
                else {                                           
                    # Imports the text file
                    $ARPCache = (Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt") 

                    # Creates the fields that become the file headers
                    $ARPCacheHeader = "Interface,Internet Address,Physical Address,Type"

                    # Extracts the data 
                    $ARPCacheData = @()
                    $ARPCacheInterface = ""
                    foreach ($line in $ARPCache) {
                        if ($line -match "---") {
                            $ARPCacheInterface = $line
                        }
                        if (($line -notmatch "---") -and ($line -notmatch "Type") -and ($line -match "  ")) {
                            $ARPCacheData += "$ARPCacheInterface   $line"
                        }
                    }
                    #Combines the File Header and Data
                    $ARPCacheCombined = @()
                    $ARPCacheCombined += $ARPCacheHeader
                    $ARPCacheCombined += $ARPCacheData
        
                    # Converts to CSV and removes unneeded data
                    $ARPCacheBuffer = @()

                    foreach ($line in $ARPCacheCombined) {
                        $ARPCacheBuffer += $line -replace " {2,}","," -replace ",$","" -replace "Interface: ",""
                    }
                    $ARPCacheBuffer | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"
        
                    # Add PSComputerName header and host/ip name
                    $ARPCacheFile = Import-Csv "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"
                    $ARPCacheFile | Add-Member -MemberType NoteProperty -Name "PSComputerName" -Value "$TargetComputer"
                    $ARPCacheFile | Select-Object "PSComputerName",*| Export-Csv "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation
                }
            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                
                Invoke-Command -ComputerName $TargetComputer -ScriptBlock {
                    cmd /c arp -a
                } -ArgumentList @($null) | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"

                if ((Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt") -eq $null) {
                    Remove-Item "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"
                }
                else {                                           
                    # Imports the text file
                    $ARPCache = (Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt") 

                    # Creates the fields that become the file headers
                    $ARPCacheHeader = "Interface,Internet Address,Physical Address,Type"

                    # Extracts the data 
                    $ARPCacheData = @()
                    $ARPCacheInterface = ""
                    foreach ($line in $ARPCache) {
                        if ($line -match "---") {
                            $ARPCacheInterface = $line
                        }
                        if (($line -notmatch "---") -and ($line -notmatch "Type") -and ($line -match "  ")) {
                            $ARPCacheData += "$ARPCacheInterface   $line"
                        }
                    }
                    #Combines the File Header and Data
                    $ARPCacheCombined = @()
                    $ARPCacheCombined += $ARPCacheHeader
                    $ARPCacheCombined += $ARPCacheData
        
                    # Converts to CSV and removes unneeded data
                    $ARPCacheBuffer = @()

                    foreach ($line in $ARPCacheCombined) {
                        $ARPCacheBuffer += $line -replace " {2,}","," -replace ",$","" -replace "Interface: ",""
                    }
                    $ARPCacheBuffer | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"
        
                    # Add PSComputerName header and host/ip name
                    $ARPCacheFile = Import-Csv "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"
                    $ARPCacheFile | Add-Member -MemberType NoteProperty -Name "PSComputerName" -Value "$TargetComputer"
                    $ARPCacheFile | Select-Object "PSComputerName",*| Export-Csv "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation
                }
            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
    Remove-DuplicateCsvHeaders
}

#============================================================================================================================================================
# BIOS Information
#============================================================================================================================================================

function BIOSInfoCommand {
    $CollectionName = "BIOS Info"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                            
                Get-WmiObject -Credential $Credential -Class Win32_BIOS -ComputerName $TargetComputer `
                | Select-Object -Property PSComputerName,  SMBIOSBIOSVersion, Name, Manufacturer, SerialNumber, Version, Description, ReleaseDate, InstallDate `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                            
                Get-WmiObject -Class Win32_BIOS -ComputerName $TargetComputer `
                | Select-Object -Property PSComputerName,  SMBIOSBIOSVersion, Name, Manufacturer, SerialNumber, Version, Description, ReleaseDate, InstallDate `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Computer Information
#============================================================================================================================================================

function ComputerInfoCommand {
    $CollectionName = "Computer Info"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                            
                Get-WmiObject -Credential $Credential -Class Win32_ComputerSystem -ComputerName $TargetComputer `
                | Select-Object PSComputerName, Description, Manufacturer, Model, SystemType, NumberOfProcessors, TotalPhysicalMemory, EnableDaylightSavingsTime, BootupState, PartOfDomain, Domain, Username, PrimaryOwnerName `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                            
                Get-WmiObject -Class Win32_ComputerSystem -ComputerName $TargetComputer `
                | Select-Object PSComputerName, Description, Manufacturer, Model, SystemType, NumberOfProcessors, TotalPhysicalMemory, EnableDaylightSavingsTime, BootupState, PartOfDomain, Domain, Username, PrimaryOwnerName `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Dates - Install, Bootup, System
#============================================================================================================================================================

function DatesCommand {
    $CollectionName = "Dates - Install, Bootup, System"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                            
                function CollectDateTimes {
                    $DateTimes=Get-WmiObject -Credential $Credential -Class Win32_OperatingSystem -ComputerName $TargetComputer `
                    | Select-Object PSComputerName, InstallDate, LastBootUpTime, LocalDateTime
                    foreach ($time in $DateTimes) {
                        $InstallDate=[System.Management.ManagementDateTimeConverter]::ToDateTime($time.InstallDate)
                        $LastBootUpTime=[System.Management.ManagementDateTimeConverter]::ToDateTime($time.LastBootUpTime)
                        $LocalDateTime=[System.Management.ManagementDateTimeConverter]::ToDateTime($time.LocalDateTime)
                        $DateTimeOutput=@()
                        $DateTimeOutput += New-Object psobject -Property @{PSComputerName=$TargetComputer
                        InstallDate=$InstallDate
                        LastBootUpTime=$LastBootUpTime
                        LocalDateTime=$LocalDateTime}
                        $DateTimeOutput
                    }
                }
                CollectDateTimes | Select-Object -Property PSComputerName, * | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation
            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                            
                function CollectDateTimes {
                    $DateTimes=Get-WmiObject -class Win32_OperatingSystem -ComputerName $TargetComputer `
                    | Select-Object PSComputerName, InstallDate, LastBootUpTime, LocalDateTime
                    foreach ($time in $DateTimes) {
                        $InstallDate=[System.Management.ManagementDateTimeConverter]::ToDateTime($time.InstallDate)
                        $LastBootUpTime=[System.Management.ManagementDateTimeConverter]::ToDateTime($time.LastBootUpTime)
                        $LocalDateTime=[System.Management.ManagementDateTimeConverter]::ToDateTime($time.LocalDateTime)
                        $DateTimeOutput=@()
                        $DateTimeOutput += New-Object psobject -Property @{PSComputerName=$TargetComputer
                        InstallDate=$InstallDate
                        LastBootUpTime=$LastBootUpTime
                        LocalDateTime=$LocalDateTime}
                        $DateTimeOutput
                    }
                }
                CollectDateTimes | Select-Object -Property PSComputerName, * | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation
            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Disk - Logical Information
#============================================================================================================================================================

function DiskLogicalInfoCommand {
    $CollectionName = "Disk - Logical Info"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                            
                Get-WmiObject -Credential $Credential -Class Win32_LogicalDisk -ComputerName $TargetComputer `
                | Select-Object PSComputerName, DeviceID, Description, ProviderName, FreeSpace, Size, DriveType `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                            
                Get-WmiObject -Class Win32_LogicalDisk -ComputerName $TargetComputer `
                | Select-Object PSComputerName, DeviceID, Description, ProviderName, FreeSpace, Size, DriveType `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Disk - Physical Information
#============================================================================================================================================================

function DiskPhysicalInfoCommand {
    $CollectionName = "Disk - Physical Info"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                            
                Get-WmiObject -Credential $Credential -Class Win32_DiskDrive -ComputerName $TargetComputer `
                | Select-Object PSComputerName, Status, Name, Caption, Description, Model, Manufacturer, SerialNumber, Signature, InterfaceType, MediaType, FirmwareRevision, SectorsPerTrack, Size, TotalCylinders, TotalHeads, TotalSectors, TotalTracks, TracksPerCylinder `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                            
                Get-WmiObject -Class Win32_DiskDrive -ComputerName $TargetComputer `
                | Select-Object PSComputerName, Status, Name, Caption, Description, Model, Manufacturer, SerialNumber, Signature, InterfaceType, MediaType, FirmwareRevision, SectorsPerTrack, Size, TotalCylinders, TotalHeads, TotalSectors, TotalTracks, TracksPerCylinder `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# DLLs Loaded by Processes
#============================================================================================================================================================

function DLLsLoadedByProcessesCommand {
    $CollectionName = "DLLs Loaded by Processes"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                            
                Invoke-Command -Credential $Credential -ComputerName $TargetComputer -ScriptBlock {
                    param($TargetComputer)
                    function Get-FileHash{
                        param ([string] $Path ) $HashAlgorithm = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
                        $Hash=[System.BitConverter]::ToString($hashAlgorithm.ComputeHash([System.IO.File]::ReadAllBytes($Path)))
                        $Properties=@{"Algorithm" = "MD5"
                        "Path" = $Path
                        "Hash" = $Hash.Replace("-", "")
                        }
                    $Ret=New-Object –TypeName PSObject –Prop $Properties
                    return $Ret
                    }

                    $LoadedModules = "PSComputerName,ProcessName,Path,Hash,Algorithm`r`n"
                    Get-Process | foreach {
                        $ProcessName = $_.ProcessName
                        $Modules = $_ | Select-Object -ExpandProperty Modules | foreach {Get-FileHash $_.Filename}
                        foreach ($Module in $Modules) {
                            $LoadedModules += "$TargetComputer," + "$ProcessName," + "$($Module -replace '@{','' -replace 'Path=','' -replace '; ',',' -replace '}','')" + "`r`n"        
                        }
                    }
                    $LoadedModules 
                } -ArgumentList @($TargetComputer) | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"
                if ((Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv") -eq $null) {
                    Remove-Item "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"
                }
            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                
                Invoke-Command -ComputerName $TargetComputer -ScriptBlock {
                    param($TargetComputer)
                    function Get-FileHash{
                        param ([string] $Path ) $HashAlgorithm = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
                        $Hash=[System.BitConverter]::ToString($hashAlgorithm.ComputeHash([System.IO.File]::ReadAllBytes($Path)))
                        $Properties=@{"Algorithm" = "MD5"
                        "Path" = $Path
                        "Hash" = $Hash.Replace("-", "")
                        }
                    $Ret=New-Object –TypeName PSObject -Property $Properties
                    return $Ret
                    }

                    $LoadedModules = "PSComputerName,ProcessName,Path,Hash,Algorithm`r`n"
                    Get-Process | foreach {
                        $ProcessName = $_.ProcessName
                        $Modules = $_ | Select-Object -ExpandProperty Modules | foreach {Get-FileHash $_.Filename}
                        foreach ($Module in $Modules) {
                            $LoadedModules += "$TargetComputer," + "$ProcessName," + "$($Module -replace '@{','' -replace 'Path=','' -replace '; ',',' -replace '}','')" + "`r`n"        
                        }
                    }
                    $LoadedModules 
                } -ArgumentList @($TargetComputer) | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"
                if ((Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv") -eq $null) {
                    Remove-Item "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"
                }
            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# DNS Cache 
#============================================================================================================================================================

function DNSCacheCommand {
    $CollectionName = "DNS Cache"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                
                Invoke-Command -Credential $Credential -ComputerName $TargetComputer -ScriptBlock {
                    cmd /c ipconfig /displaydns
                } -ArgumentList @($null) | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"

                if ((Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt") -eq $null) {
                    Remove-Item "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"
                }
                else {
                    # Imports the text file
                    $DNSCache = (Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt") 

                    # Creates the fields that become the file headers
                    $DNSCacheHeader = "RecordName,RecordType,TimeToLive,DataLength,Section,A(Host)/CNAMERecord"
        
                    # Extracts the data 
                    $DNSCacheData = ""
                    $DNSCacheInterface = ""
                    $RecordName = ""
                    foreach ($line in $DNSCache) {
                        if ($line -match "---"){
                            $DNSCacheData += $line -replace "-{2,}","`n"
                        }
                        if ($line -match ':'){
                            if ($line -match "Record Name") {
                                if ($(($line -split ':')[1]) -eq $RecordName) {
                                    $DNSCacheData += "`n$(($line -split ':')[1] -replace `"^ | $`",`"`"),"
                                }
                                else {
                                    $RecordName = ($line -split ':')[1]
                                    $DNSCacheData += "$(($line -split ':')[1] -replace `"^ | $`",`"`"),"
                                }    
                            }
                            if ($line -match "Record Type") {
                                $DNSCacheData += "$(($line -split ':')[1] -replace `"^ | $`",`"`"),"
                            }
                            if ($line -match "Time To Live") {
                                $DNSCacheData += "$(($line -split ':')[1] -replace `"^ | $`",`"`"),"
                            }
                            if (($line -match "Data") -and ($line -match "Length")) {
                                $DNSCacheData += "$(($line -split ':')[1] -replace `"^ | $`",`"`"),"
                            }
                            if ($line -match "Section") {
                                $DNSCacheData += "$(($line -split ':')[1] -replace `"^ | $`",`"`"),"
                            }
                            if (($line -match "Host") -and ($line -match "Record")) {
                                $DNSCacheData += "$(($line -split ':')[1] -replace `"^ | $`",`"`")"
                            }
                            if (($line -match "CNAME") -and ($line -match "Record")) {
                                $DNSCacheData += "$(($line -split ':')[1] -replace `"^ | $`",`"`")"
                            }
                        }
                    }
                    #Combines the File Header and Data
                    $DNSCacheCombined = @()
                    $DNSCacheCombined += $DNSCacheHeader
                    $DNSCacheCombined += $DNSCacheData
        
                    # Converts to CSV
                    $DNSCacheBuffer = @()
                    foreach ($line in $DNSCacheCombined) {
                        $DNSCacheBuffer += $line 
                    }
                    $DNSCacheBuffer | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"
   
                    # Add PSComputerName header and host/ip name
                    $DNSCacheFile = Import-Csv "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" | Select-Object -Skip 1 | Where-Object {$_.PSObject.Properties.Value -ne $null}
                    $DNSCacheFile | Add-Member -MemberType NoteProperty -Name "PSComputerName" -Value "$TargetComputer"
                    $DNSCacheFile | Select-Object "PSComputerName",* | Export-Csv "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation
                }
            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                
                Invoke-Command -ComputerName $TargetComputer -ScriptBlock {
                    cmd /c ipconfig /displaydns
                } -ArgumentList @($null) | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"

                if ((Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt") -eq $null) {
                    Remove-Item "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"
                }
                else {
                    # Imports the text file
                    $DNSCache = (Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt") 

                    # Creates the fields that become the file headers
                    $DNSCacheHeader = "RecordName,RecordType,TimeToLive,DataLength,Section,A(Host)/CNAMERecord"
        
                    # Extracts the data 
                    $DNSCacheData = ""
                    $DNSCacheInterface = ""
                    $RecordName = ""
                    foreach ($line in $DNSCache) {
                        if ($line -match "---"){
                            $DNSCacheData += $line -replace "-{2,}","`n"
                        }
                        if ($line -match ':'){
                            if ($line -match "Record Name") {
                                if ($(($line -split ':')[1]) -eq $RecordName) {
                                    $DNSCacheData += "`n$(($line -split ':')[1] -replace `"^ | $`",`"`"),"
                                }
                                else {
                                    $RecordName = ($line -split ':')[1]
                                    $DNSCacheData += "$(($line -split ':')[1] -replace `"^ | $`",`"`"),"
                                }    
                            }
                            if ($line -match "Record Type") {
                                $DNSCacheData += "$(($line -split ':')[1] -replace `"^ | $`",`"`"),"
                            }
                            if ($line -match "Time To Live") {
                                $DNSCacheData += "$(($line -split ':')[1] -replace `"^ | $`",`"`"),"
                            }
                            if (($line -match "Data") -and ($line -match "Length")) {
                                $DNSCacheData += "$(($line -split ':')[1] -replace `"^ | $`",`"`"),"
                            }
                            if ($line -match "Section") {
                                $DNSCacheData += "$(($line -split ':')[1] -replace `"^ | $`",`"`"),"
                            }
                            if (($line -match "Host") -and ($line -match "Record")) {
                                $DNSCacheData += "$(($line -split ':')[1] -replace `"^ | $`",`"`")"
                            }
                            if (($line -match "CNAME") -and ($line -match "Record")) {
                                $DNSCacheData += "$(($line -split ':')[1] -replace `"^ | $`",`"`")"
                            }
                        }
                    }
                    #Combines the File Header and Data
                    $DNSCacheCombined = @()
                    $DNSCacheCombined += $DNSCacheHeader
                    $DNSCacheCombined += $DNSCacheData
        
                    # Converts to CSV
                    $DNSCacheBuffer = @()
                    foreach ($line in $DNSCacheCombined) {
                        $DNSCacheBuffer += $line 
                    }
                    $DNSCacheBuffer | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"
   
                    # Add PSComputerName header and host/ip name
                    $DNSCacheFile = Import-Csv "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" | Select-Object -Skip 1 | Where-Object {$_.PSObject.Properties.Value -ne $null}
                    $DNSCacheFile | Add-Member -MemberType NoteProperty -Name "PSComputerName" -Value "$TargetComputer"
                    $DNSCacheFile | Select-Object "PSComputerName",* | Export-Csv "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation
                }
            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Drivers - Detailed
#============================================================================================================================================================

function DriversDetailedCommand {
    $CollectionName = "Drivers - Detailed"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                            
                Get-WmiObject -Credential $Credential -Class Win32_Systemdriver -ComputerName $TargetComputer `
                | Select-Object PSComputerName, State, Status, Started, StartMode, Name, DisplayName, PathName, ExitCode, AcceptPause, AcceptStop, Caption, CreationClassName, Description, DesktopInteract, ErrorControl, InstallDate, ServiceType `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                            
                Get-WmiObject -Class Win32_Systemdriver -ComputerName $TargetComputer `
                | Select-Object PSComputerName, State, Status, Started, StartMode, Name, DisplayName, PathName, ExitCode, AcceptPause, AcceptStop, Caption, CreationClassName, Description, DesktopInteract, ErrorControl, InstallDate, ServiceType `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Drivers - Signed Info
#============================================================================================================================================================

function DriversSignedCommand {
    $CollectionName = "Drivers - Signed Info"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                
                Invoke-Command -Credential $Credential -ComputerName $TargetComputer -ScriptBlock {
                    cmd /c driverquery /si /FO CSV
                } -ArgumentList @($null) | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"

                if ((Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv") -eq $null) {
                    Remove-Item "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"
                }
                else {
                    $DriverSignedInfo = (Import-Csv "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv") 
                    $DriverSignedInfo | Add-Member -MemberType NoteProperty -Name "PSComputerName" -Value "$TargetComputer"
                    $DriverSignedInfo | Select-Object PSComputerName, IsSigned, Manufacturer, DeviceName, InfName | Export-Csv "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation
                }
            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                            
                Invoke-Command -ComputerName $TargetComputer -ScriptBlock {
                    cmd /c driverquery /si /FO CSV
                } -ArgumentList @($null) | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"

                if ((Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv") -eq $null) {
                    Remove-Item "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"
                }
                else {
                    $DriverSignedInfo = (Import-Csv "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv") 
                    $DriverSignedInfo | Add-Member -MemberType NoteProperty -Name "PSComputerName" -Value "$TargetComputer"
                    $DriverSignedInfo | Select-Object PSComputerName, IsSigned, Manufacturer, DeviceName, InfName | Export-Csv "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation
                }
            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }  
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Drivers - Valid Signatures
#============================================================================================================================================================

function DriversValidSignaturesCommand {
    $CollectionName = "Drivers - Valid Signatures"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                            
                Get-WmiObject -Credential $Credential -Class Win32_SystemDriver -ComputerName $TargetComputer `
                | ForEach-Object {
                    $Buffer = Get-AuthenticodeSignature $_.pathname
                    $Buffer | Add-Member -MemberType NoteProperty -Name PSComputerName -Value $TargetComputer
                    #$Buffer
                    } `
                | Select-Object PSComputerName, Status, Path, @{Name="SignerCertificate";Expression={$_.SignerCertificate -join "; "}} `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                
                # Old
                #Get-WmiObject -Class Win32_SystemDriver -ComputerName $TargetComputer `
                #| ForEach-Object {Get-AuthenticodeSignature $_.pathname} `
                #| Select-Object PSComputerName, Status, Path, @{Name="SignerCertificate";Expression={$_.SignerCertificate -join "; "}} `
                #| Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation                            
                
                Get-WmiObject -Class Win32_SystemDriver -ComputerName $TargetComputer `
                | ForEach-Object {
                    $SystemDrivers = Get-AuthenticodeSignature $_.pathname
                    $SystemDrivers | Add-Member -MemberType NoteProperty -Name PSComputerName -Value $TargetComputer
                    $SystemDrivers
                    } `
                | Select-Object PSComputerName, Status, Path, @{Name="SignerCertificate";Expression={$_.SignerCertificate -join "; "}} `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation


            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Environmental Variables
#============================================================================================================================================================

function EnvironmentalVariablesCommand {
    $CollectionName = "Environmental Variables"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                            
                Get-WmiObject -Credential $Credential -Class Win32_Environment -ComputerName $TargetComputer `
                | Select-Object PSComputerName, UserName, Name, VariableValue `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                            
                Get-WmiObject -Class Win32_Environment -ComputerName $TargetComputer `
                | Select-Object PSComputerName, UserName, Name, VariableValue `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}


#============================================================================================================================================================
# Firewall Rules
#============================================================================================================================================================

function FirewallRulesCommand {
    $CollectionName = "Firewall Rules"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                
                Invoke-Command -Credential $Credential -ComputerName $TargetComputer -ScriptBlock {
                    cmd /c netsh advfirewall firewall show rule name=all
                } -ArgumentList @($null) | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"

                if ((Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt") -eq $null) {
                    Remove-Item  "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"
                }
                elseif ((Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt").Length -le 5) {
                    Remove-Item      "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"
                }
                else {                            
                    $FirewallRules = (Get-Content -Path "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt") -replace '-{2,}','' -replace ',',';' -replace '^ {3,}',':  ' | Where-Object {$_.trim() -ne ''} 

                    $FileHeader = "Rule Name,Enabled,Direction,Profiles,Grouping,LocalIP,RemoteIP,Protocol,LocalPort,RemotePort,Edge Traversal,Action"

                    # Extracts the data 
                    $FileData = ""
                    foreach ($line in ($FirewallRules)) {$FileData += "$(($line -replace ' {2,}','' -replace "Allow","Allow;;" -replace "Block","Block;;" -replace "Bypass","Bypass;;" -split ':')[1]),"}
                    $FileData = $FileData -split ';;' -replace "^,|,$|","" -replace " ,|, ","," | Where-Object {$_.trim() -ne ""}

                    # Adds computer names/ips to data
                    $ConvertedToCsv = ""
                    $ConvertedToCsv += "PSComputerName,$FileHeader`n"
                    foreach ($Rule in $FileData) {$ConvertedToCsv += "$TargetComputer,$Rule`n"}
                    $ConvertedToCsv | Where-Object {$_.trim() -ne ""} | Where-Object {$_.PSComputerName -ne ""}| Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"
                }
            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                            
                Invoke-Command -ComputerName $TargetComputer -ScriptBlock {
                    cmd /c netsh advfirewall firewall show rule name=all
                } -ArgumentList @($null) | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"

                if ((Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt") -eq $null) {
                    Remove-Item  "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"
                }
                elseif ((Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt").Length -le 5) {
                    Remove-Item      "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"
                }
                else {                            
                    $FirewallRules = (Get-Content -Path "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt") -replace '-{2,}','' -replace ',',';' -replace '^ {3,}',':  ' | Where-Object {$_.trim() -ne ''} 

                    $FileHeader = "Rule Name,Enabled,Direction,Profiles,Grouping,LocalIP,RemoteIP,Protocol,LocalPort,RemotePort,Edge Traversal,Action"

                    # Extracts the data 
                    $FileData = ""
                    foreach ($line in ($FirewallRules)) {$FileData += "$(($line -replace ' {2,}','' -replace "Allow","Allow;;" -replace "Block","Block;;" -replace "Bypass","Bypass;;" -split ':')[1]),"}
                    $FileData = $FileData -split ';;' -replace "^,|,$|","" -replace " ,|, ","," | Where-Object {$_.trim() -ne ""}

                    # Adds computer names/ips to data
                    $ConvertedToCsv = ""
                    $ConvertedToCsv += "PSComputerName,$FileHeader`n"
                    foreach ($Rule in $FileData) {$ConvertedToCsv += "$TargetComputer,$Rule`n"}
                    $ConvertedToCsv | Where-Object {$_.trim() -ne ""} | Where-Object {$_.PSComputerName -ne ""}| Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"
                }
            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Firewall Status
#============================================================================================================================================================

function FirewallStatusCommand {
    $CollectionName = "Firewall Status"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                            
                Invoke-Command -Credential $Credential -ComputerName $TargetComputer -ScriptBlock {
                    cmd /c netsh advfirewall show allprofiles state
                } -ArgumentList @($null) | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"
                
                if ((Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt") -eq $null) {
                    Remove-Item "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"
                }
                else {
                    $FirewallStatus = (Get-Content -Path "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt") -replace '-{2,}','' -replace ',',';' -replace '^ {3,}',':  ' | Where-Object {$_.trim() -ne ''} 

                    # Creates the fields that become the file headers
                    $FileHeader = "Firewall Profile,State"
                    # Extracts the data 
                    $FileData = $(($FirewallStatus | Out-String) -replace '-{2,}','' -replace ' {2,}','' -replace "`r|`n","" -replace ":","," -replace "State","" -creplace "ON","ON`n" -creplace "OFF","OFF`n" -replace 'Ok.','' -replace "^ | $","") -split "`n" | Where-Object {$_.trim() -ne ""}
    
                    #Combines the File Header and Data
                    $Combined = @()
                    $Combined += $FileHeader
                    $Combined += $FileData
                    $Combined | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"

                    # Add PSComputerName header and host/ip name
                    $AddTargetHost = (Import-Csv "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv")
                    $AddTargetHost | Add-Member -MemberType NoteProperty "PSComputerName" -Value "$TargetComputer"
                    $AddTargetHost | Select-Object -Property PSComputerName, * | Export-Csv "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation
                }
            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                            
                Invoke-Command -ComputerName $TargetComputer -ScriptBlock {
                    cmd /c netsh advfirewall show allprofiles state
                } -ArgumentList @($null) | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"

                if ((Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt") -eq $null) {
                    Remove-Item "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"
                }
                else {
                    $FirewallStatus = (Get-Content -Path "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt") -replace '-{2,}','' -replace ',',';' -replace '^ {3,}',':  ' | Where-Object {$_.trim() -ne ''} 

                    # Creates the fields that become the file headers
                    $FileHeader = "Firewall Profile,State"
                    # Extracts the data 
                    $FileData = $(($FirewallStatus | Out-String) -replace '-{2,}','' -replace ' {2,}','' -replace "`r|`n","" -replace ":","," -replace "State","" -creplace "ON","ON`n" -creplace "OFF","OFF`n" -replace 'Ok.','' -replace "^ | $","") -split "`n" | Where-Object {$_.trim() -ne ""}
    
                    #Combines the File Header and Data
                    $Combined = @()
                    $Combined += $FileHeader
                    $Combined += $FileData
                    $Combined | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"

                    # Add PSComputerName header and host/ip name
                    $AddTargetHost = (Import-Csv "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv")
                    $AddTargetHost | Add-Member -MemberType NoteProperty "PSComputerName" -Value "$TargetComputer"
                    $AddTargetHost | Select-Object -Property PSComputerName, * | Export-Csv "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation
                }
            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Groups - Local
#============================================================================================================================================================

function GroupLocalCommand {
    $CollectionName = "Groups - Local"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                            
                Get-WmiObject -Credential $Credential -Class Win32_Group -Filter "LocalAccount='True'" -ComputerName $TargetComputer `
                | Select-Object PSComputerName, Name, LocalAccount, Domain, SID, SIDType, Caption, Description `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                            
                Get-WmiObject -Class Win32_Group -filter "LocalAccount='True'" -ComputerName $TargetComputer `
                | Select-Object PSComputerName, Name, LocalAccount, Domain, SID, SIDType, Caption, Description `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Logon Information
#============================================================================================================================================================

function LogonInfoCommand {
    $CollectionName = "Logon Info"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                            
                Get-WmiObject -Credential $Credential -Class Win32_NetworkLoginProfile -ComputerName $TargetComputer `
                | Select-Object PSComputerName, Name, LastLogon, LastLogoff, NumberOfLogons, PasswordAge `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                            
                Get-WmiObject -Class Win32_NetworkLoginProfile -ComputerName $TargetComputer `
                | Select-Object PSComputerName, Name, LastLogon, LastLogoff, NumberOfLogons, PasswordAge `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Logon Sessions
#============================================================================================================================================================

function LogonSessionsCommand {
    $CollectionName = "Logon Sessions"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                            
                Invoke-Command -Credential $Credential -ComputerName $TargetComputer -ScriptBlock {
                    cmd /c query session
                } -ArgumentList @($null) | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"

                if ((Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt") -eq $null) {
                    Remove-Item "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"
                }
                else {
                    # Processes collection to format it from txt to csv
                    $LogonStatusInfo   = Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"
                    $LogonStatusBuffer = @()
                    foreach ($line in $LogonStatusInfo) { 
                        $LogonStatusBuffer += $line -replace " {2,}",","
                    }
                    $LogonStatusBuffer | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"

                    # Add PSComputerName header and host/ip name
                    $AddTargetHost = (Import-Csv "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv")
                    $AddTargetHost | Add-Member -MemberType NoteProperty "PSComputerName" -Value "$TargetComputer"
                    $AddTargetHost | Select-Object -Property PSComputerName, * | Export-Csv "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation
                }
            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                            
                Invoke-Command -ComputerName $TargetComputer -ScriptBlock {
                    cmd /c query session
                } -ArgumentList @($null) | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"

                if ((Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt") -eq $null) {
                    Remove-Item "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"
                }
                else {
                    # Processes collection to format it from txt to csv
                    $LogonStatusInfo   = Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"
                    $LogonStatusBuffer = @()
                    foreach ($line in $LogonStatusInfo) { 
                        $LogonStatusBuffer += $line -replace " {2,}",","
                    }
                    $LogonStatusBuffer | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"

                    # Add PSComputerName header and host/ip name
                    $AddTargetHost = (Import-Csv "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv")
                    $AddTargetHost | Add-Member -MemberType NoteProperty "PSComputerName" -Value "$TargetComputer"
                    $AddTargetHost | Select-Object -Property PSComputerName, * | Export-Csv "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation
                }
            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
    Remove-DuplicateCsvHeaders
}

#============================================================================================================================================================
# Logon User Status
#============================================================================================================================================================

function LogonUserStatusCommand {
    $CollectionName = "Logon User Status"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                            
                Invoke-Command -Credential $Credential -ComputerName $TargetComputer -ScriptBlock {
                    cmd /c query user
                } -ArgumentList @($null) | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"

                if ((Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt") -eq $null) {
                    Remove-Item "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"
                }
                else {
                    # Processes collection to format it from txt to csv
                    $LogonStatusInfo   = Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"
                    $LogonStatusBuffer = @()
                    foreach ($line in $LogonStatusInfo) { 
                        $LogonStatusBuffer += $line -replace " {2,}",","
                    }
                    $LogonStatusBuffer | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"

                    # Add PSComputerName header and host/ip name
                    $AddTargetHost = (Import-Csv "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv")
                    $AddTargetHost | Add-Member -MemberType NoteProperty "PSComputerName" -Value "$TargetComputer"
                    $AddTargetHost | Select-Object -Property PSComputerName, * | Export-Csv "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation
                }
            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                                   
                Invoke-Command -ComputerName $TargetComputer -ScriptBlock {
                    cmd /c query user
                } -ArgumentList @($null) | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"

                if ((Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt") -eq $null) {
                    Remove-Item "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"
                }
                else {
                    # Processes collection to format it from txt to csv
                    $LogonStatusInfo   = Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"
                    $LogonStatusBuffer = @()
                    foreach ($line in $LogonStatusInfo) { 
                        $LogonStatusBuffer += $line -replace " {2,}",","
                    }
                    $LogonStatusBuffer | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"

                    # Add PSComputerName header and host/ip name
                    $AddTargetHost = (Import-Csv "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv")
                    $AddTargetHost | Add-Member -MemberType NoteProperty "PSComputerName" -Value "$TargetComputer"
                    $AddTargetHost | Select-Object -Property PSComputerName, * | Export-Csv "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation
                }
            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
    Remove-DuplicateCsvHeaders
}

#============================================================================================================================================================
# Mapped Drives
#============================================================================================================================================================

function MappedDrivesCommand {
    $CollectionName = "Mapped Drives"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                            
                Get-WmiObject -Credential $Credential -Class Win32_MappedLogicalDisk -ComputerName $TargetComputer `
                | Select-Object PSComputerName, Name, ProviderName, FileSystem, Size, FreeSpace, Compressed `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                            
                Get-WmiObject -Class Win32_MappedLogicalDisk -ComputerName $TargetComputer `
                | Select-Object PSComputerName, Name, ProviderName, FileSystem, Size, FreeSpace, Compressed `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Memory - Capacity Info
#============================================================================================================================================================

function MemoryCapacityInfoCommand {
    $CollectionName = "Memory - Capacity Info"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                         
                Get-WmiObject -Credential $Credential -Class Win32_PhysicalMemoryArray -ComputerName $TargetComputer `
                | Select-Object PSComputerName, Model, Name, MaxCapacity, MemoryDevices `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                            
                Get-WmiObject -Class Win32_PhysicalMemoryArray -ComputerName $TargetComputer `
                | Select-Object PSComputerName, Model, Name, MaxCapacity, MemoryDevices `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Memory - Physical Information
#============================================================================================================================================================

function MemoryPhysicalInfoCommand {
    $CollectionName = "Memory - Physical Info"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                            
                Get-WmiObject -Credential $Credential -Class Win32_PhysicalMemory -ComputerName $TargetComputer `
                | Select-Object PSComputerName, Tag, Capacity, Speed, Manufacturer, PartNumber, SerialNumber `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                            
                Get-WmiObject -Class Win32_PhysicalMemory -ComputerName $TargetComputer `
                | Select-Object PSComputerName, Tag, Capacity, Speed, Manufacturer, PartNumber, SerialNumber `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }  
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Memory - Utilization
#============================================================================================================================================================

function MemoryUtilizationCommand {
    $CollectionName = "Memory - Utilization"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                            
                Get-WmiObject -Credential $Credential -Class Win32_OperatingSystem -ComputerName $TargetComputer `
                | Select-Object -Property PSComputerName, FreePhysicalMemory, TotalVisibleMemorySize, FreeVirtualMemory, TotalVirtualMemorySize `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                    
                Get-WmiObject -Class Win32_OperatingSystem -ComputerName $TargetComputer `
                | Select-Object -Property PSComputerName, FreePhysicalMemory, TotalVisibleMemorySize, FreeVirtualMemory, TotalVirtualMemorySize `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Memory Performance Monitoring Data
#============================================================================================================================================================

function MemoryPerformanceDataCommand {
    $CollectionName = "Memory - Performance Data"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                            
                Get-WmiObject -Credential $Credential -Class Win32_PerfRawData_PerfOS_Memory -ComputerName $TargetComputer `
                | Select-Object -Property PSComputerName, AvaiLabelBytes, AvaiLabelKBytes, AvaiLabelMBytes, CacheBytes, CacheBytesPeak, CacheFaultsPersec, Caption, CommitLimit, CommittedBytes, DemandZeroFaultsPersec, FreeAndZeroPageListBytes, FreeSystemPageTableEntries, Frequency_Object, Frequency_PerfTime, Frequency_Sys100NS, LongTermAverageStandbyCacheLifetimes, ModifiedPageListBytes, PageFaultsPersec, PageReadsPersec, PagesInputPersec, PagesOutputPersec, PagesPersec, PageWritesPersec, PercentCommittedBytesInUse, PercentCommittedBytesInUse_Base, PoolNonpagedAllocs, PoolNonpagedBytes, PoolPagedAllocs, PoolPagedBytes, PoolPagedResidentBytes, StandbyCacheCoreBytes, StandbyCacheNormalPriorityBytes, StandbyCacheReserveBytes, SystemCacheResidentBytes, SystemCodeResidentBytes, SystemCodeTotalBytes, SystemDriverResidentBytes, SystemDriverTotalBytes, Timestamp_Object, Timestamp_PerfTime, Timestamp_Sys100NS, TransitionFaultsPersec, TransitionPagesRePurposedPersec, WriteCopiesPersec `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                            
                Get-WmiObject -Class Win32_PerfRawData_PerfOS_Memory -ComputerName $TargetComputer `
                | Select-Object -Property PSComputerName, AvaiLabelBytes, AvaiLabelKBytes, AvaiLabelMBytes, CacheBytes, CacheBytesPeak, CacheFaultsPersec, Caption, CommitLimit, CommittedBytes, DemandZeroFaultsPersec, FreeAndZeroPageListBytes, FreeSystemPageTableEntries, Frequency_Object, Frequency_PerfTime, Frequency_Sys100NS, LongTermAverageStandbyCacheLifetimes, ModifiedPageListBytes, PageFaultsPersec, PageReadsPersec, PagesInputPersec, PagesOutputPersec, PagesPersec, PageWritesPersec, PercentCommittedBytesInUse, PercentCommittedBytesInUse_Base, PoolNonpagedAllocs, PoolNonpagedBytes, PoolPagedAllocs, PoolPagedBytes, PoolPagedResidentBytes, StandbyCacheCoreBytes, StandbyCacheNormalPriorityBytes, StandbyCacheReserveBytes, SystemCacheResidentBytes, SystemCodeResidentBytes, SystemCodeTotalBytes, SystemDriverResidentBytes, SystemDriverTotalBytes, Timestamp_Object, Timestamp_PerfTime, Timestamp_Sys100NS, TransitionFaultsPersec, TransitionPagesRePurposedPersec, WriteCopiesPersec `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}


#============================================================================================================================================================
# Motherboard Info
#============================================================================================================================================================

function MotherboardInfoCommand {
    $CollectionName = "Motherboard Info"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                            
                Get-WmiObject -Credential $Credential -Class Win32_BaseBoard -ComputerName $TargetComputer `
                | Select-Object -Property PSComputerName, Manufacturer, Model, Name, SerialNumber, SKU, Product `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                            
                Get-WmiObject -Class Win32_BaseBoard -ComputerName $TargetComputer `
                | Select-Object -Property PSComputerName, Manufacturer, Model, Name, SerialNumber, SKU, Product `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Network Connections TCP
#============================================================================================================================================================

function NetworkConnectionsTCPCommand {
    $CollectionName = "Network Connections TCP"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                
                Invoke-Command -Credential $Credential -ComputerName $TargetComputer -ScriptBlock {
                    cmd /c netstat -anob -p tcp
                } -ArgumentList @($null) | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"
                
                if ((Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt") -eq $null) {
                    Remove-Item "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"
                }
                else {                
                    # Processes collection to format it from txt to csv
                    $Connections = Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt" | Select-Object -skip 3
                    $TCPdata = @()
                    $Connections.trim() | Out-String | ForEach-Object {$TCPdata += $_ -replace "`r`n",";;" -replace ";;;;",";;" -creplace ";;TCP","`r`nTCP" -replace ";;","  " -replace " {2,}","," -creplace "PID","PID,Executed Process" -replace "^,|,$",""}
                    $format = $TCPdata -split "`r`n" -replace " {1,1}",""
                    $TCPnetstatTxt =@()
                    # This section combines two specific csv fields together for easier viewing
                    foreach ($line in $format) {
                        if ($line -match "\d,\[") {$TCPnetstatTxt += $line}
                        if ($line -notmatch "\d,\[") {$TCPnetstatTxt += $line -replace ",\["," ["}
                    }
                    $TCPnetstatTxt | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer-temp.csv"
                    $TCPnetstatCsv = (Import-Csv "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer-temp.csv")
                    Remove-Item "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer-temp.csv"
                    $TCPnetstatCsv | Add-Member -MemberType NoteProperty -Name "PSComputerName" -Value "$TargetComputer"
                    $TCPnetstatCsv | Select-Object -Property PSComputerName, * | Export-Csv "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation
                }
            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                
                Invoke-Command -ComputerName $TargetComputer -ScriptBlock {
                    cmd /c netstat -anob -p tcp
                } -ArgumentList @($null) | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"

                if ((Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt") -eq $null) {
                    Remove-Item "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"
                }
                else {                
                    # Processes collection to format it from txt to csv
                    $Connections = Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt" | Select-Object -skip 3
                    $TCPdata = @()
                    $Connections.trim() | Out-String | ForEach-Object {$TCPdata += $_ -replace "`r`n",";;" -replace ";;;;",";;" -creplace ";;TCP","`r`nTCP" -replace ";;","  " -replace " {2,}","," -creplace "PID","PID,Executed Process" -replace "^,|,$",""}
                    $format = $TCPdata -split "`r`n" -replace " {1,1}",""
                    $TCPnetstatTxt =@()
                    # This section combines two specific csv fields together for easier viewing
                    foreach ($line in $format) {
                        if ($line -match "\d,\[") {$TCPnetstatTxt += $line}
                        if ($line -notmatch "\d,\[") {$TCPnetstatTxt += $line -replace ",\["," ["}
                    }
                    $TCPnetstatTxt | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer-temp.csv"
                    $TCPnetstatCsv = (Import-Csv "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer-temp.csv")
                    Remove-Item "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer-temp.csv"
                    $TCPnetstatCsv | Add-Member -MemberType NoteProperty -Name "PSComputerName" -Value "$TargetComputer"
                    $TCPnetstatCsv | Select-Object -Property PSComputerName, * | Export-Csv "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation
                }
            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Network Connections UDP
#============================================================================================================================================================

function NetworkConnectionsUDPCommand {
    $CollectionName = "Network Connections UDP"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                            
                Invoke-Command -Credential $Credential -ComputerName $TargetComputer -ScriptBlock {
                    cmd /c netstat -anob -p udp
                } -ArgumentList @($null) | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"

                if ((Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt") -eq $null) {
                    Remove-Item "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"
                }
                else {                
                    # Processes collection to format it from txt to csv
                    $Connections = Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt" | Select-Object -skip 3
                    $UDPdata = @()
                    $Connections.trim()  | Out-String |   ForEach-Object {$UDPdata += $_ -replace "`r`n",";;" -replace ";;;;",";;" -creplace ";;UDP","`r`nUDP" -replace ";;","  " -replace " {2,}","," -replace "State,","" -creplace "PID","PID,Executed Process" -replace "^,|,$",""}

                    $format = $UDPdata -split "`r`n"
                    $UDPnetstat =@()
                    # This section is needed to combine two specific csv fields together for easier viewing
                    foreach ($line in $format) {
                        if ($line -match "\d,\[") {$UDPnetstat += $line}
                        if ($line -notmatch "\d,\[") {$UDPnetstat += $line -replace ",\["," ["}
                    }
                    $UDPnetstat | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"

                    # Add PSComputerName header and host/ip name
                    $AddTargetHost = (Import-Csv "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv")
                    $AddTargetHost | Add-Member -MemberType NoteProperty "PSComputerName" -Value "$TargetComputer"
                    $AddTargetHost | Select-Object -Property PSComputerName, * | Export-Csv "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation
                }
            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                            
                Invoke-Command -ComputerName $TargetComputer -ScriptBlock {
                    cmd /c netstat -anob -p udp
                } -ArgumentList @($null) | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"

                if ((Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt") -eq $null) {
                    Remove-Item "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"
                }
                else {                
                    # Processes collection to format it from txt to csv
                    $Connections = Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt" | Select-Object -skip 3
                    $UDPdata = @()
                    $Connections.trim()  | Out-String |   ForEach-Object {$UDPdata += $_ -replace "`r`n",";;" -replace ";;;;",";;" -creplace ";;UDP","`r`nUDP" -replace ";;","  " -replace " {2,}","," -replace "State,","" -creplace "PID","PID,Executed Process" -replace "^,|,$",""}

                    $format = $UDPdata -split "`r`n"
                    $UDPnetstat =@()
                    # This section is needed to combine two specific csv fields together for easier viewing
                    foreach ($line in $format) {
                        if ($line -match "\d,\[") {$UDPnetstat += $line}
                        if ($line -notmatch "\d,\[") {$UDPnetstat += $line -replace ",\["," ["}
                    }
                    $UDPnetstat | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"

                    # Add PSComputerName header and host/ip name
                    $AddTargetHost = (Import-Csv "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv")
                    $AddTargetHost | Add-Member -MemberType NoteProperty "PSComputerName" -Value "$TargetComputer"
                    $AddTargetHost | Select-Object -Property PSComputerName, * | Export-Csv "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation
                }
            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Network Settings
#============================================================================================================================================================

function NetworkSettingsCommand {
    $CollectionName = "Network Settings"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                            
                Get-WmiObject -Credential $Credential -Class Win32_NetworkAdapterConfiguration -ComputerName $TargetComputer `
                | Select-Object -Property `
                    PSComputerName, MACAddress, `
                    @{Name="IPAddress";Expression={$_.IPAddress -join "; "}}, `
                    @{Name="IpSubnet";Expression={$_.IpSubnet -join "; "}}, `
                    @{Name="DefaultIPGateway";Expression={$_.DefaultIPgateway -join "; "}}, `
                    Description, ServiceName, IPEnabled, DHCPEnabled, DNSHostname, `
                    @{Name="DNSDomainSuffixSearchOrder";Expression={$_.DNSDomainSuffixSearchOrder -join "; "}}, `
                    DNSEnabledForWINSResolution, DomainDNSRegistrationEnabled, FullDNSRegistrationEnabled, `
                    @{Name="DNSServerSearchOrder";Expression={$_.DNSServerSearchOrder -join "; "}}, `
                    @{Name="WinsPrimaryServer";Expression={$_.WinsPrimaryServer -join "; "}}, `
                    @{Name="WINSSecondaryServer";Expression={$_.WINSSecondaryServer -join "; "}} `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                            
                Get-WmiObject -Class Win32_NetworkAdapterConfiguration -ComputerName $TargetComputer `
                | Select-Object -Property `
                    PSComputerName, MACAddress, `
                    @{Name="IPAddress";Expression={$_.IPAddress -join "; "}}, `
                    @{Name="IpSubnet";Expression={$_.IpSubnet -join "; "}}, `
                    @{Name="DefaultIPGateway";Expression={$_.DefaultIPgateway -join "; "}}, `
                    Description, ServiceName, IPEnabled, DHCPEnabled, DNSHostname, `
                    @{Name="DNSDomainSuffixSearchOrder";Expression={$_.DNSDomainSuffixSearchOrder -join "; "}}, `
                    DNSEnabledForWINSResolution, DomainDNSRegistrationEnabled, FullDNSRegistrationEnabled, `
                    @{Name="DNSServerSearchOrder";Expression={$_.DNSServerSearchOrder -join "; "}}, `
                    @{Name="WinsPrimaryServer";Expression={$_.WinsPrimaryServer -join "; "}}, `
                    @{Name="WINSSecondaryServer";Expression={$_.WINSSecondaryServer -join "; "}} `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation
            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Network Statistics IPv4
#============================================================================================================================================================

function NetworkStatisticsIPv4Command {
    $CollectionName             = "Network Statistics IPv4 All"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                            
                Invoke-Command -Credential $Credential -ComputerName $TargetComputer -ScriptBlock {
                    cmd /c netstat -e -p ip
                } -ArgumentList @($null) | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"
   
                if ((Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt") -eq $null) {
                    Remove-Item "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"
                }
                else {
                    # Processes collection to format it from txt to csv
                    $Statistics = (Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt") | Select-Object -skip 4 -First 6
                
                    # This data is formated differently the the others for TCP and UDP as it as sent and recieve metrics in columns
                    $StatisticsData = $Statistics -replace " {2,}","," -replace "^,|,$",""

                    # Extracts the fields that become the file headers
                    $FileHeader = ""
                    foreach ($line in $StatisticsData) {$FileHeader += "$($($line -split ',')[0]) (Rx/Tx),"}
            
                    # Extracts the fields that contain data
                    $FileData = ""
                    foreach ($line in $StatisticsData) {$FileData += "$($($line -split ',')[1])/$($($line -split ',')[2]),"}
                    $ConvertedToCsv = ""
                    $ConvertedToCsv += "PSComputerName,"  + $FileHeader -replace ",$","`r`n"
                    $ConvertedToCsv += "$TargetComputer," + $FileData   -replace ",$",""
                    $ConvertedToCsv | Out-File -FilePath "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"   
                }
            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                            
                Invoke-Command -ComputerName $TargetComputer -ScriptBlock {
                    cmd /c netstat -e -p ip
                } -ArgumentList @($null) | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"
   
                if ((Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt") -eq $null) {
                    Remove-Item "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"
                }
                else {
                    # Processes collection to format it from txt to csv
                    $Statistics = (Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt") | Select-Object -skip 4 -First 6
                
                    # This data is formated differently the the others for TCP and UDP as it as sent and recieve metrics in columns
                    $StatisticsData = $Statistics -replace " {2,}","," -replace "^,|,$",""

                    # Extracts the fields that become the file headers
                    $FileHeader = ""
                    foreach ($line in $StatisticsData) {$FileHeader += "$($($line -split ',')[0]) (Rx/Tx),"}
            
                    # Extracts the fields that contain data
                    $FileData = ""
                    foreach ($line in $StatisticsData) {$FileData += "$($($line -split ',')[1])/$($($line -split ',')[2]),"}
                    $ConvertedToCsv = ""
                    $ConvertedToCsv += "PSComputerName,"  + $FileHeader -replace ",$","`r`n"
                    $ConvertedToCsv += "$TargetComputer," + $FileData   -replace ",$",""
                    $ConvertedToCsv | Out-File -FilePath "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"   
                }
            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Network Statistics IPv4 TCP
#============================================================================================================================================================

function NetworkStatisticsIPv4TCPCommand {
    $CollectionName             = "Network Statistics IPv4 TCP"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                            
                Invoke-Command -Credential $Credential -ComputerName $TargetComputer -ScriptBlock {
                    cmd /c netstat -e -p tcp
                } -ArgumentList @($null) | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"

                if ((Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt") -eq $null) {
                    Remove-Item "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"
                }
                else {
                    # Processes collection to format it from txt to csv
                    $Statistics = Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt" | Select-Object -skip 4 -First 6
                
                    # This data is formated differently the the others for TCP and UDP as it as sent and recieve metrics in columns
                    $StatisticsData = $Statistics -replace " {2,}","," -replace "^,|,$",""

                    # Extracts the fields that become the file headers
                    $FileHeader = ""
                    foreach ($line in $StatisticsData) {$FileHeader += "$($($line -split ',')[0]) (Rx/Tx),"}
            
                    # Extracts the fields that contain data
                    $FileData = ""
                    foreach ($line in $StatisticsData) {$FileData += "$($($line -split ',')[1])/$($($line -split ',')[2]),"}
                    $ConvertedToCsv = ""
                    $ConvertedToCsv += "PSComputerName,"  + $FileHeader -replace ",$","`r`n"
                    $ConvertedToCsv += "$TargetComputer," + $FileData   -replace ",$",""
                    $ConvertedToCsv | Out-File -FilePath "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"                         
                }
            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                            
                Invoke-Command -ComputerName $TargetComputer -ScriptBlock {
                    cmd /c netstat -e -p tcp
                } -ArgumentList @($null) | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"

                if ((Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt") -eq $null) {
                     Remove-Item "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"
                }
                else {
                    # Processes collection to format it from txt to csv
                    $Statistics = Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt" | Select-Object -skip 4 -First 6
                
                    # This data is formated differently the the others for TCP and UDP as it as sent and recieve metrics in columns
                    $StatisticsData = $Statistics -replace " {2,}","," -replace "^,|,$",""

                    # Extracts the fields that become the file headers
                    $FileHeader = ""
                    foreach ($line in $StatisticsData) {$FileHeader += "$($($line -split ',')[0]) (Rx/Tx),"}
            
                    # Extracts the fields that contain data
                    $FileData = ""
                    foreach ($line in $StatisticsData) {$FileData += "$($($line -split ',')[1])/$($($line -split ',')[2]),"}
                    $ConvertedToCsv = ""
                    $ConvertedToCsv += "PSComputerName,"  + $FileHeader -replace ",$","`r`n"
                    $ConvertedToCsv += "$TargetComputer," + $FileData   -replace ",$",""
                    $ConvertedToCsv | Out-File -FilePath "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"                         
                }
            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Network Statistics IPv4 UDP
#============================================================================================================================================================

function NetworkStatisticsIPv4UDPCommand {
    $CollectionName             = "Network Statistics IPv4 UDP"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                            
                Invoke-Command -Credential $Credential -ComputerName $TargetComputer -ScriptBlock {
                    cmd /c netstat -e -p udp
                } -ArgumentList @($null) | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"

                if ((Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt") -eq $null) {
                    Remove-Item "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"
                }
                else {
                    # Processes collection to format it from txt to csv
                    $Statistics = Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt" | Select-Object -skip 4 -First 6
                
                    # This data is formated differently the the others for TCP and UDP as it as sent and recieve metrics in columns
                    $StatisticsData = $Statistics -replace " {2,}","," -replace "^,|,$",""

                    # Extracts the fields that become the file headers
                    $FileHeader = ""
                    foreach ($line in $StatisticsData) {$FileHeader += "$($($line -split ',')[0]) (Rx/Tx),"}
            
                    # Extracts the fields that contain data
                    $FileData = ""
                    foreach ($line in $StatisticsData) {$FileData += "$($($line -split ',')[1])/$($($line -split ',')[2]),"}
                    $ConvertedToCsv = ""
                    $ConvertedToCsv += "PSComputerName,"  + $FileHeader -replace ",$","`r`n"
                    $ConvertedToCsv += "$TargetComputer," + $FileData   -replace ",$",""
                    $ConvertedToCsv | Out-File -FilePath "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"             
                }
            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                            
                Invoke-Command -ComputerName $TargetComputer -ScriptBlock {
                    cmd /c netstat -e -p udp
                } -ArgumentList @($null) | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"

                if ((Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt") -eq $null) {
                    Remove-Item "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"
                }
                else {
                    # Processes collection to format it from txt to csv
                    $Statistics = Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt" | Select-Object -skip 4 -First 6
                
                    # This data is formated differently the the others for TCP and UDP as it as sent and recieve metrics in columns
                    $StatisticsData = $Statistics -replace " {2,}","," -replace "^,|,$",""

                    # Extracts the fields that become the file headers
                    $FileHeader = ""
                    foreach ($line in $StatisticsData) {$FileHeader += "$($($line -split ',')[0]) (Rx/Tx),"}
            
                    # Extracts the fields that contain data
                    $FileData = ""
                    foreach ($line in $StatisticsData) {$FileData += "$($($line -split ',')[1])/$($($line -split ',')[2]),"}
                    $ConvertedToCsv = ""
                    $ConvertedToCsv += "PSComputerName,"  + $FileHeader -replace ",$","`r`n"
                    $ConvertedToCsv += "$TargetComputer," + $FileData   -replace ",$",""
                    $ConvertedToCsv | Out-File -FilePath "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"             
                }
            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Network Statistics IPv4 ICMP
#============================================================================================================================================================

function NetworkStatisticsIPv4ICMPCommand {
    $CollectionName             = "Network Statistics IPv4 ICMP"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                            
                Invoke-Command -Credential $Credential -ComputerName $TargetComputer -ScriptBlock {
                    cmd /c netstat -e -p icmp
                } -ArgumentList @($null) | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"

                if ((Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt") -eq $null) {
                    Remove-Item "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"
                }
                else {            
                    # Processes collection to format it from txt to csv
                    $Statistics = Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt" | Select-Object -skip 4 -First 6
                    
                    # This data is formated differently the the others for TCP and UDP as it as sent and recieve metrics in columns
                    $StatisticsData = $Statistics -replace " {2,}","," -replace "^,|,$",""

                    # Extracts the fields that become the file headers
                    $FileHeader = ""
                    foreach ($line in $StatisticsData) {$FileHeader += "$($($line -split ',')[0]) (Rx/Tx),"}
                
                    # Extracts the fields that contain data
                    $FileData = ""
                    foreach ($line in $StatisticsData) {$FileData += "$($($line -split ',')[1])/$($($line -split ',')[2]),"}
                    $ConvertedToCsv = ""
                    $ConvertedToCsv += "PSComputerName,"  + $FileHeader -replace ",$","`r`n"
                    $ConvertedToCsv += "$TargetComputer," + $FileData   -replace ",$",""
                    $ConvertedToCsv | Out-File -FilePath "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"  
                }
            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                            
                Invoke-Command -ComputerName $TargetComputer -ScriptBlock {
                    cmd /c netstat -e -p icmp
                } -ArgumentList @($null) | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"

                if ((Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt") -eq $null) {
                    Remove-Item "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"
                }
                else {            
                    # Processes collection to format it from txt to csv
                    $Statistics = Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt" | Select-Object -skip 4 -First 6
                    
                    # This data is formated differently the the others for TCP and UDP as it as sent and recieve metrics in columns
                    $StatisticsData = $Statistics -replace " {2,}","," -replace "^,|,$",""

                    # Extracts the fields that become the file headers
                    $FileHeader = ""
                    foreach ($line in $StatisticsData) {$FileHeader += "$($($line -split ',')[0]) (Rx/Tx),"}
                
                    # Extracts the fields that contain data
                    $FileData = ""
                    foreach ($line in $StatisticsData) {$FileData += "$($($line -split ',')[1])/$($($line -split ',')[2]),"}
                    $ConvertedToCsv = ""
                    $ConvertedToCsv += "PSComputerName,"  + $FileHeader -replace ",$","`r`n"
                    $ConvertedToCsv += "$TargetComputer," + $FileData   -replace ",$",""
                    $ConvertedToCsv | Out-File -FilePath "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"  
                }
            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Network Statistics IPv6
#============================================================================================================================================================

function NetworkStatisticsIPv6Command {
    $CollectionName             = "Network Statistics IPv6 All"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                            
                Invoke-Command -Credential $Credential -ComputerName $TargetComputer -ScriptBlock {
                    cmd /c netstat -e -p ipv6
                } -ArgumentList @($null) | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"

                if ((Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt") -eq $null) {
                    Remove-Item "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"
                }
                else {
                    # Processes collection to format it from txt to csv
                    $Statistics = Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt" | Select-Object -skip 4 -First 6
                
                    # This data is formated differently the the others for TCP and UDP as it as sent and recieve metrics in columns
                    $StatisticsData = $Statistics -replace " {2,}","," -replace "^,|,$",""

                    # Extracts the fields that become the file headers
                    $FileHeader = ""
                    foreach ($line in $StatisticsData) {$FileHeader += "$($($line -split ',')[0]) (Rx/Tx),"}
            
                    # Extracts the fields that contain data
                    $FileData = ""
                    foreach ($line in $StatisticsData) {$FileData += "$($($line -split ',')[1])/$($($line -split ',')[2]),"}
                    $ConvertedToCsv = ""
                    $ConvertedToCsv += "PSComputerName,"  + $FileHeader -replace ",$","`r`n"
                    $ConvertedToCsv += "$TargetComputer," + $FileData   -replace ",$",""
                    $ConvertedToCsv | Out-File -FilePath "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"   
                }
            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                            
                Invoke-Command -ComputerName $TargetComputer -ScriptBlock {
                    cmd /c netstat -e -p ipv6
                } -ArgumentList @($null) | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"

                if ((Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt") -eq $null) {
                    Remove-Item "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"
                }
                else {
                    # Processes collection to format it from txt to csv
                    $Statistics = Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt" | Select-Object -skip 4 -First 6
                
                    # This data is formated differently the the others for TCP and UDP as it as sent and recieve metrics in columns
                    $StatisticsData = $Statistics -replace " {2,}","," -replace "^,|,$",""

                    # Extracts the fields that become the file headers
                    $FileHeader = ""
                    foreach ($line in $StatisticsData) {$FileHeader += "$($($line -split ',')[0]) (Rx/Tx),"}
            
                    # Extracts the fields that contain data
                    $FileData = ""
                    foreach ($line in $StatisticsData) {$FileData += "$($($line -split ',')[1])/$($($line -split ',')[2]),"}
                    $ConvertedToCsv = ""
                    $ConvertedToCsv += "PSComputerName,"  + $FileHeader -replace ",$","`r`n"
                    $ConvertedToCsv += "$TargetComputer," + $FileData   -replace ",$",""
                    $ConvertedToCsv | Out-File -FilePath "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"  
                }
            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }  
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Network Statistics IPv6 TCP
#============================================================================================================================================================

function NetworkStatisticsIPv6TCPCommand {
    $CollectionName             = "Network Statistics IPv6 TCP"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                            
                Invoke-Command -Credential $Credential -ComputerName $TargetComputer -ScriptBlock {
                    cmd /c netstat -e -p tcpv6
                } -ArgumentList @($null) | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"

                if ((Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt") -eq $null) {
                    Remove-Item "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"
                }
                else {
                    # Processes collection to format it from txt to csv
                    $Statistics = Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt" | Select-Object -skip 4 -First 6
                
                    # This data is formated differently the the others for TCP and UDP as it as sent and recieve metrics in columns
                    $StatisticsData = $Statistics -replace " {2,}","," -replace "^,|,$",""

                    # Extracts the fields that become the file headers
                    $FileHeader = ""
                    foreach ($line in $StatisticsData) {$FileHeader += "$($($line -split ',')[0]) (Rx/Tx),"}
            
                    # Extracts the fields that contain data
                    $FileData = ""
                    foreach ($line in $StatisticsData) {$FileData += "$($($line -split ',')[1])/$($($line -split ',')[2]),"}
                    $ConvertedToCsv = ""
                    $ConvertedToCsv += "PSComputerName,"  + $FileHeader -replace ",$","`r`n"
                    $ConvertedToCsv += "$TargetComputer," + $FileData   -replace ",$",""
                    $ConvertedToCsv | Out-File -FilePath "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"   
                }
            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                            
                Invoke-Command -ComputerName $TargetComputer -ScriptBlock {
                    cmd /c netstat -e -p tcpv6
                } -ArgumentList @($null) | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"

                if ((Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt") -eq $null) {
                    Remove-Item "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"
                }
                else {
                    # Processes collection to format it from txt to csv
                    $Statistics = Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt" | Select-Object -skip 4 -First 6
                
                    # This data is formated differently the the others for TCP and UDP as it as sent and recieve metrics in columns
                    $StatisticsData = $Statistics -replace " {2,}","," -replace "^,|,$",""

                    # Extracts the fields that become the file headers
                    $FileHeader = ""
                    foreach ($line in $StatisticsData) {$FileHeader += "$($($line -split ',')[0]) (Rx/Tx),"}
            
                    # Extracts the fields that contain data
                    $FileData = ""
                    foreach ($line in $StatisticsData) {$FileData += "$($($line -split ',')[1])/$($($line -split ',')[2]),"}
                    $ConvertedToCsv = ""
                    $ConvertedToCsv += "PSComputerName,"  + $FileHeader -replace ",$","`r`n"
                    $ConvertedToCsv += "$TargetComputer," + $FileData   -replace ",$",""
                    $ConvertedToCsv | Out-File -FilePath "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"   
                }
            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Network Statistics IPv6 UDP
#============================================================================================================================================================

function NetworkStatisticsIPv6UDPCommand {
    $CollectionName             = "Network Statistics IPv6 UDP"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                            
                Invoke-Command -Credential $Credential -ComputerName $TargetComputer -ScriptBlock {
                    cmd /c netstat -e -p udpv6
                } -ArgumentList @($null) | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"

                if ((Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt") -eq $null) {
                    Remove-Item "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"
                }
                else {
                    # Processes collection to format it from txt to csv
                    $Statistics = Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt" | Select-Object -skip 4 -First 6
                
                    # This data is formated differently the the others for TCP and UDP as it as sent and recieve metrics in columns
                    $StatisticsData = $Statistics -replace " {2,}","," -replace "^,|,$",""

                    # Extracts the fields that become the file headers
                    $FileHeader = ""
                    foreach ($line in $StatisticsData) {$FileHeader += "$($($line -split ',')[0]) (Rx/Tx),"}
            
                    # Extracts the fields that contain data
                    $FileData = ""
                    foreach ($line in $StatisticsData) {$FileData += "$($($line -split ',')[1])/$($($line -split ',')[2]),"}
                    $ConvertedToCsv = ""
                    $ConvertedToCsv += "PSComputerName,"  + $FileHeader -replace ",$","`r`n"
                    $ConvertedToCsv += "$TargetComputer," + $FileData   -replace ",$",""
                    $ConvertedToCsv | Out-File -FilePath "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"  
                }
            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                            
                Invoke-Command -ComputerName $TargetComputer -ScriptBlock {
                    cmd /c netstat -e -p udpv6
                } -ArgumentList @($null) | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"

                if ((Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt") -eq $null) {
                    Remove-Item "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"
                }
                else {        
                    # Processes collection to format it from txt to csv
                    $Statistics = Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt" | Select-Object -skip 4 -First 6
                
                    # This data is formated differently the the others for TCP and UDP as it as sent and recieve metrics in columns
                    $StatisticsData = $Statistics -replace " {2,}","," -replace "^,|,$",""

                    # Extracts the fields that become the file headers
                    $FileHeader = ""
                    foreach ($line in $StatisticsData) {$FileHeader += "$($($line -split ',')[0]) (Rx/Tx),"}
            
                    # Extracts the fields that contain data
                    $FileData = ""
                    foreach ($line in $StatisticsData) {$FileData += "$($($line -split ',')[1])/$($($line -split ',')[2]),"}
                    $ConvertedToCsv = ""
                    $ConvertedToCsv += "PSComputerName,"  + $FileHeader -replace ",$","`r`n"
                    $ConvertedToCsv += "$TargetComputer," + $FileData   -replace ",$",""
                    $ConvertedToCsv | Out-File -FilePath "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"  
                }
            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Network Statistics IPv6 ICMP
#============================================================================================================================================================

function NetworkStatisticsIPv6ICMPCommand {
    $CollectionName             = "Network Statistics IPv6 ICMP"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                            
                Invoke-Command -Credential $Credential -ComputerName $TargetComputer -ScriptBlock {
                    cmd /c netstat -e -p icmpv6
                } -ArgumentList @($null) | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"

                if ((Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt") -eq $null) {
                    Remove-Item "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"
                }
                else {
                    # Processes collection to format it from txt to csv
                    $Statistics = Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt" | Select-Object -skip 4 -First 6
                
                    # This data is formated differently the the others for TCP and UDP as it as sent and recieve metrics in columns
                    $StatisticsData = $Statistics -replace " {2,}","," -replace "^,|,$",""

                    # Extracts the fields that become the file headers
                    $FileHeader = ""
                    foreach ($line in $StatisticsData) {$FileHeader += "$($($line -split ',')[0]) (Rx/Tx),"}
            
                    # Extracts the fields that contain data
                    $FileData = ""
                    foreach ($line in $StatisticsData) {$FileData += "$($($line -split ',')[1])/$($($line -split ',')[2]),"}
                    $ConvertedToCsv = ""
                    $ConvertedToCsv += "PSComputerName,"  + $FileHeader -replace ",$","`r`n"
                    $ConvertedToCsv += "$TargetComputer," + $FileData   -replace ",$",""
                    $ConvertedToCsv | Out-File -FilePath "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"   
                }
            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                            
                Invoke-Command -ComputerName $TargetComputer -ScriptBlock {
                    cmd /c netstat -e -p icmpv6
                } -ArgumentList @($null) | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"

                if ((Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt") -eq $null) {
                    Remove-Item "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"
                }
                else {
                    # Processes collection to format it from txt to csv
                    $Statistics = Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt" | Select-Object -skip 4 -First 6
                
                    # This data is formated differently the the others for TCP and UDP as it as sent and recieve metrics in columns
                    $StatisticsData = $Statistics -replace " {2,}","," -replace "^,|,$",""

                    # Extracts the fields that become the file headers
                    $FileHeader = ""
                    foreach ($line in $StatisticsData) {$FileHeader += "$($($line -split ',')[0]) (Rx/Tx),"}
            
                    # Extracts the fields that contain data
                    $FileData = ""
                    foreach ($line in $StatisticsData) {$FileData += "$($($line -split ',')[1])/$($($line -split ',')[2]),"}
                    $ConvertedToCsv = ""
                    $ConvertedToCsv += "PSComputerName,"  + $FileHeader -replace ",$","`r`n"
                    $ConvertedToCsv += "$TargetComputer," + $FileData   -replace ",$",""
                    $ConvertedToCsv | Out-File -FilePath "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"   
                }
            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }  
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Plug and Play Devices
#============================================================================================================================================================

function PlugAndPlayCommand {
    $CollectionName = "Plug and Play Devices"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                            
                Get-WmiObject -Credential $Credential -Class Win32_PnPEntity -ComputerName $TargetComputer `
                | Select-Object PSComputerName, InstallDate, Status, Description, Service, DeviceID, @{Name="HardwareID";Expression={$_.HardwareID -join "; "}}, Manufacturer `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                            
                Get-WmiObject -Class Win32_PnPEntity -ComputerName $TargetComputer `
                | Select-Object PSComputerName, InstallDate, Status, Description, Service, DeviceID, @{Name="HardwareID";Expression={$_.HardwareID -join "; "}}, Manufacturer `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Port Proxy Rules
#============================================================================================================================================================

function PortProxyRulesCommand {
    $CollectionName = "Port Proxy Rules"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                            
                Invoke-Command -Credential $Credential -ComputerName $TargetComputer -ScriptBlock {
                    cmd /c netsh interface portproxy show all
                } -ArgumentList @($null) | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"

                if ((Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt") -eq $null) {
                    Remove-Item "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"
                }
                else {
                    # Extracts the fields that become the file headers
                    $FileHeader = "Listen on IPv4 Address,Listen on IPv4 Port,Connect to IPv4 Address,Connect to IPv4 Port"

                    # Extracts the fields that contain data
                    $ProxyRules = Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"

                    $FileData = @()
                    foreach ($line in ($ProxyRules | Select-Object -Skip 5)) {$FileData += "`n$($line -replace ' {2,}',',')"}
                    $FileData = $FileData  -replace "^,|,$","" -replace "^ | $","" -replace ";;","`n" | Where-Object {$_.trim() -ne ""}
                    $FileData = foreach ($line in $($FileData | Where-Object {$_.trim() -ne ""}))  {"$TargetComputer," + $($line -replace "`n","")}

                    # Combines the csv header and data to create the file
                    $Combined = @()
                    $Combined += $FileHeader
                    $Combined += $FileData
                    $Combined | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"

                    # Add PSComputerName header and host/ip name
                    $AddTargetHost = (Import-Csv "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv")
                    $AddTargetHost | Add-Member -MemberType NoteProperty "PSComputerName" -Value "$TargetComputer"
                    $AddTargetHost | Select-Object -Property PSComputerName, * | Export-Csv "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation
                }
            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                            
                Invoke-Command -ComputerName $TargetComputer -ScriptBlock {
                    cmd /c netsh interface portproxy show all
                } -ArgumentList @($null) | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"

                if ((Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt") -eq $null) {
                    Remove-Item "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"
                }
                else {
                    # Extracts the fields that become the file headers
                    <# $FileHeader = ""
                    foreach ($line in ($PortProxyRules | Select-Object -Skip 3 -First 1)) {$FileHeader += $line -replace ' {2,}',','} #>
                    $FileHeader = "Listen on IPv4 Address,Listen on IPv4 Port,Connect to IPv4 Address,Connect to IPv4 Port"

                    # Extracts the fields that contain data
                    $ProxyRules = Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"

                    $FileData = @()
                    foreach ($line in ($ProxyRules | Select-Object -Skip 5)) {$FileData += "`n$($line -replace ' {2,}',',')"}
                    $FileData = $FileData  -replace "^,|,$","" -replace "^ | $","" -replace ";;","`n" | Where-Object {$_.trim() -ne ""}
                    $FileData = foreach ($line in $($FileData | Where-Object {$_.trim() -ne ""}))  {"$TargetComputer," + $($line -replace "`n","")}

                    # Combines the csv header and data to create the file
                    $Combined = @()
                    $Combined += $FileHeader
                    $Combined += $FileData
                    $Combined | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"

                    # Add PSComputerName header and host/ip name
                    $AddTargetHost = (Import-Csv "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv")
                    $AddTargetHost | Add-Member -MemberType NoteProperty "PSComputerName" -Value "$TargetComputer"
                    $AddTargetHost | Select-Object -Property PSComputerName, * | Export-Csv "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation
                }
            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Prefetch Files
#============================================================================================================================================================

function PrefetchFilesCommand {
    $CollectionName = "Prefetch Files"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                            
                Invoke-Command -Credential $Credential -ComputerName $TargetComputer -ScriptBlock {
                    Get-ChildItem C:\Windows\Prefetch -Force
                } -ArgumentList @($null) `
                | Select-Object -Property PSComputerName, Directory, Name, Length, CreationTime, LastWriteTime, LastAccessTime, Attributes, Mode `
                | Export-Csv "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation
            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                            
                Invoke-Command -ComputerName $TargetComputer -ScriptBlock {
                    Get-ChildItem C:\Windows\Prefetch -Force
                } -ArgumentList @($null) `
                | Select-Object -Property PSComputerName, Directory, Name, Length, CreationTime, LastWriteTime, LastAccessTime, Attributes, Mode `
                | Export-Csv "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Process Tree - Lineage
#============================================================================================================================================================

function ProcessTreeLineageCommand {
    $CollectionName = "Process Tree - Lineage"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                            
                Invoke-Command -Credential $Credential -ComputerName $TargetComputer -ScriptBlock {
                    Function Get-ProcessTree {
                        '=================================================='
                        '{0,-7}{1}' -f 'PID','Process Name'
                        '==================================================' 
                        Function Get-ProcessChildren ($P,$Depth=1) {
                            $procs | Where-Object {
                                $_.ParentProcessId -eq $p.ProcessID -and $_.ParentProcessId -ne 0
                            } | ForEach-Object {
                                '{0,-7}{1}|--- {2}' -f $_.ProcessID,(' '*5*$Depth),$_.Name,$_.ParentProcessId 
                                Get-ProcessChildren $_ (++$Depth) 
                                $Depth-- 
                            }
                        } 
                        $filter = { -not (Get-Process -Id $_.ParentProcessId -ErrorAction SilentlyContinue) -or $_.ParentProcessId -eq 0 } 
                            $procs = Get-WmiObject -Class Win32_Process
                            $top = $procs | Where-Object $filter | Sort-Object ProcessID 
                        foreach ($p in $top) {
                            '{0,-7}{1}' -f $p.ProcessID, $p.Name 
                            Get-ProcessChildren $p
                        }
                    } 
                    Get-ProcessTree
                } -ArgumentList @($null) | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"                    
            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
               
                Invoke-Command -ComputerName $TargetComputer -ScriptBlock {
                    Function Get-ProcessTree {
                        '=================================================='
                        '{0,-7}{1}' -f 'PID','Process Name'
                        '==================================================' 
                        Function Get-ProcessChildren ($P,$Depth=1) {
                            $procs | Where-Object {
                                $_.ParentProcessId -eq $p.ProcessID -and $_.ParentProcessId -ne 0
                            } | ForEach-Object {
                                '{0,-7}{1}|--- {2}' -f $_.ProcessID,(' '*5*$Depth),$_.Name,$_.ParentProcessId 
                                Get-ProcessChildren $_ (++$Depth) 
                                $Depth-- 
                            }
                        } 
                        $filter = { -not (Get-Process -Id $_.ParentProcessId -ErrorAction SilentlyContinue) -or $_.ParentProcessId -eq 0 } 
                            $procs = Get-WmiObject -Class Win32_Process
                            $top = $procs | Where-Object $filter | Sort-Object ProcessID 
                        foreach ($p in $top) {
                            '{0,-7}{1}' -f $p.ProcessID, $p.Name 
                            Get-ProcessChildren $p
                        }
                    } 
                    Get-ProcessTree
                } -ArgumentList @($null) | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.txt"
            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    ### No Compile-CsvFiles as this is just text
    "You have to go into each 'Individual Host Results' to view their Process Trees (Lineage)" | Out-File "$CollectedDataTimeStampDirectory\$CollectionName.txt"
}

#============================================================================================================================================================
# Processes - Enhanced with Hashes
#============================================================================================================================================================

function ProcessesEnhancedCommand {
    $CollectionName = "Processes - Enhanced with Hashes"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                            
                $ErrorActionPreference="SilentlyContinue"
                function Get-FileHash{
                    param ([string] $Path ) $HashAlgorithm = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
                    $Hash=[System.BitConverter]::ToString($hashAlgorithm.ComputeHash([System.IO.File]::ReadAllBytes($Path)))
                    $Properties=@{"Algorithm" = "MD5"
                    "Path" = $Path
                    "Hash" = $Hash.Replace("-", "")
                    }
                $Ret=New-Object –TypeName PSObject –Prop $Properties
                return $Ret
                }
                function Get-Processes {
                    Write-Verbose "Getting ProcessList"
                    $processes = Get-WmiObject -Class Win32_Process
                    $processList = @()
                    foreach ($process in $processes) {
                        try {
                            $Owner = $process.GetOwner().Domain.ToString() + "\"+ $process.GetOwner().User.ToString()
                            $OwnerSID = $process.GetOwnerSid().Sid
                        } 
                        catch {}
                    $thisProcess=New-Object PSObject -Property @{
                        PSComputerName=$process.PSComputerName
                        OSName=$process.OSName
                        Name=$process.Caption
                        ProcessId=[int]$process.ProcessId
                        ParentProcessName=($processes | where {$_.ProcessID -eq $process.ParentProcessId}).Caption
                        ParentProcessId=[int]$process.ParentProcessId
                        MemoryKiloBytes=[int]$process.WorkingSetSize/1000
                        SessionId=[int]$process.SessionId
                        Owner=$Owner
                        OwnerSID=$OwnerSID
                        PathName=$process.ExecutablePath
                        CommandLine=$process.CommandLine
                        CreationDate=$process.ConvertToDateTime($process.CreationDate)
                    }
                    if ($process.ExecutablePath) {
                        $Signature = Get-FileHash $process.ExecutablePath | Select-Object -Property Hash, Algorithm
                        $Signature.PSObject.Properties | Foreach-Object {$thisProcess | Add-Member -type NoteProperty -Name $_.Name -Value $_.Value -Force}
                    } 
                    $processList += $thisProcess
                } 
                return $processList}
                Get-Processes | Select-Object -Property PSComputerName, Name, ProcessID, ParentProcessName, ParentProcessId, MemoryKiloBytes, CommandLine, PathName, Hash, Algorithm, CreationDate, Owner, OwnerSID, SessionId `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation


            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                            
                $ErrorActionPreference="SilentlyContinue"
                function Get-FileHash{
                    param ([string] $Path ) $HashAlgorithm = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
                    $Hash=[System.BitConverter]::ToString($hashAlgorithm.ComputeHash([System.IO.File]::ReadAllBytes($Path)))
                    $Properties=@{"Algorithm" = "MD5"
                    "Path" = $Path
                    "Hash" = $Hash.Replace("-", "")
                    }
                $Ret=New-Object –TypeName PSObject –Prop $Properties
                return $Ret
                }
                function Get-Processes {
                    Write-Verbose "Getting ProcessList"
                    $processes = Get-WmiObject -Class Win32_Process -ComputerName $TargetComputer
                    $processList = @()
                    foreach ($process in $processes) {
                        try {
                            $Owner = $process.GetOwner().Domain.ToString() + "\"+ $process.GetOwner().User.ToString()
                            $OwnerSID = $process.GetOwnerSid().Sid
                        } 
                        catch {}
                    $thisProcess=New-Object PSObject -Property @{
                        PSComputerName=$process.PSComputerName
                        OSName=$process.OSName
                        Name=$process.Caption
                        ProcessId=[int]$process.ProcessId
                        ParentProcessName=($processes | where {$_.ProcessID -eq $process.ParentProcessId}).Caption
                        ParentProcessId=[int]$process.ParentProcessId
                        MemoryKiloBytes=[int]$process.WorkingSetSize/1000
                        SessionId=[int]$process.SessionId
                        Owner=$Owner
                        OwnerSID=$OwnerSID
                        PathName=$process.ExecutablePath
                        CommandLine=$process.CommandLine
                        CreationDate=$process.ConvertToDateTime($process.CreationDate)
                    }
                    if ($process.ExecutablePath) {
                        $Signature = Get-FileHash $process.ExecutablePath | Select-Object -Property Hash, Algorithm
                        $Signature.PSObject.Properties | Foreach-Object {$thisProcess | Add-Member -type NoteProperty -Name $_.Name -Value $_.Value -Force}
                    } 
                    $processList += $thisProcess
                } 
                return $processList}
                Get-Processes | Select-Object -Property PSComputerName, Name, ProcessID, ParentProcessName, ParentProcessId, MemoryKiloBytes, CommandLine, PathName, Hash, Algorithm, CreationDate, Owner, OwnerSID, SessionId `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Processes - Standard
#============================================================================================================================================================

function ProcessesStandardCommand {
    $CollectionName = "Processes - Standard"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority                
                            
                Get-WmiObject -Credential $Credential -Class Win32_Process -ComputerName $TargetComputer `
                | Select-Object -Property PSComputerName, Name, ProcessID, ParentProcessID, Path, WorkingSetSize, Handle, HandleCount, ThreadCount, CreationDate `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                                            
                Get-WmiObject -Class Win32_Process -ComputerName $TargetComputer `
                | Select-Object -Property PSComputerName, Name, ProcessID, ParentProcessID, Path, WorkingSetSize, Handle, HandleCount, ThreadCount, CreationDate `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }  
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Processor - CPU Info
#============================================================================================================================================================

function ProcessorCPUInfoCommand {
    $CollectionName = "Processor - CPU Info"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                            
                Get-WmiObject -Credential $Credential -Class Win32_Processor -ComputerName $TargetComputer `
                | Select-Object -Property PSComputerName, Name, Manufacturer, Caption, DeviceID, SocketDesignation, MaxClockSpeed  `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                            
                Get-WmiObject -Class Win32_Processor -ComputerName $TargetComputer `
                | Select-Object -Property PSComputerName, Name, Manufacturer, Caption, DeviceID, SocketDesignation, MaxClockSpeed  `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Remote Capability Check
#============================================================================================================================================================

function RemoteCapabilityCheckCommand {
    $CollectionName = "Remote Capability Check"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
            param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
            Invoke-Expression -Command $ThreadPriority
                            
            Function Invoke-Ping {
            <#
            .SYNOPSIS
                Ping or test connectivity to systems in parallel
                    WSMan      via Test-WSMan
                    RemoteReg  via Microsoft.Win32.RegistryKey
                    RPC        via WMI
                    RDP        via port 3389
                    SMB        via \\ComputerName\C$
            .LINK
                https://gallery.technet.microsoft.com/scriptcenter/Invoke-Ping-Test-in-b553242a
            #>
                [cmdletbinding(DefaultParameterSetName='Ping')]
                param(
                    [Parameter( ValueFromPipeline=$true,
                                ValueFromPipelineByPropertyName=$true, 
                                Position=0)]
                    [string[]]$ComputerName,        
                    [Parameter( ParameterSetName='Detail')]
                    [validateset("*","WSMan","RemoteReg","RPC","RDP","SMB")]
                    [string[]]$Detail,
                    [Parameter(ParameterSetName='Ping')]
                    [switch]$Quiet,        
                    [int]$Timeout = 20,
                    [int]$Throttle = 100,
                    [switch]$NoCloseOnTimeout
                )
                Begin {
                    #http://gallery.technet.microsoft.com/Run-Parallel-Parallel-377fd430
                    function Invoke-Parallel {
                        [cmdletbinding(DefaultParameterSetName='ScriptBlock')]
                        Param (   
                            [Parameter(Mandatory=$false,position=0,ParameterSetName='ScriptBlock')]
                                [System.Management.Automation.ScriptBlock]$ScriptBlock,
                            [Parameter(Mandatory=$false,ParameterSetName='ScriptFile')]
                            [ValidateScript({test-path $_ -pathtype leaf})]
                                $ScriptFile,
                            [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
                            [Alias('CN','__Server','IPAddress','Server','ComputerName')]    
                                [PSObject]$InputObject,
                                [PSObject]$Parameter,
                                [switch]$ImportVariables,
                                [switch]$ImportModules,
                                [int]$Throttle = 20,
                                [int]$SleepTimer = 200,
                                [int]$RunspaceTimeout = 0,
			                    [switch]$NoCloseOnTimeout = $false,
                                [int]$MaxQueue,
                            [validatescript({Test-Path (Split-Path $_ -parent)})]
                                [string]$LogFile = "C:\temp\log.log",
			                    [switch] $Quiet = $false
                        )    
                        Begin {             
                            #No max queue specified?  Estimate one.
                            #We use the script scope to resolve an odd PowerShell 2 issue where MaxQueue isn't seen later in the function
                            if ( -not $PSBoundParameters.ContainsKey('MaxQueue') ) {
                                if($RunspaceTimeout -ne 0){ $script:MaxQueue = $Throttle }
                                else{ $script:MaxQueue = $Throttle * 3 }
                            }
                            else {$script:MaxQueue = $MaxQueue}
                            Write-Verbose "Throttle: '$throttle' SleepTimer '$sleepTimer' runSpaceTimeout '$runspaceTimeout' maxQueue '$maxQueue' logFile '$logFile'"
                            #If they want to import variables or modules, create a clean runspace, get loaded items, use those to exclude items
                            if ($ImportVariables -or $ImportModules) {
                                $StandardUserEnv = [powershell]::Create().addscript({
                                    #Get modules and snapins in this clean runspace
                                    $Modules = Get-Module | Select -ExpandProperty Name
                                    $Snapins = Get-PSSnapin | Select -ExpandProperty Name
                                    
                                    #Get variables in this clean runspace
                                    #Called last to get vars like $? into session
                                    $Variables = Get-Variable | Select -ExpandProperty Name               
                                    
                                    #Return a hashtable where we can access each.
                                    @{
                                        Variables = $Variables
                                        Modules = $Modules
                                        Snapins = $Snapins
                                    }
                                }).invoke()[0]            
                                if ($ImportVariables) {
                                    #Exclude common parameters, bound parameters, and automatic variables
                                    Function _temp {[cmdletbinding()] param() }
                                    $VariablesToExclude = @( (Get-Command _temp | Select -ExpandProperty parameters).Keys + $PSBoundParameters.Keys + $StandardUserEnv.Variables )
                                    Write-Verbose "Excluding variables $( ($VariablesToExclude | sort ) -join ", ")"
                                    
                                    # we don't use 'Get-Variable -Exclude', because it uses regexps. 
                                    # One of the veriables that we pass is '$?'. 
                                    # There could be other variables with such problems.
                                    # Scope 2 required if we move to a real module
                                    $UserVariables = @( Get-Variable | Where { -not ($VariablesToExclude -contains $_.Name) } ) 
                                    Write-Verbose "Found variables to import: $( ($UserVariables | Select -expandproperty Name | Sort ) -join ", " | Out-String).`n"
                                }
                                if ($ImportModules)  {
                                    $UserModules = @( Get-Module | Where {$StandardUserEnv.Modules -notcontains $_.Name -and (Test-Path $_.Path -ErrorAction SilentlyContinue)} | Select -ExpandProperty Path )
                                    $UserSnapins = @( Get-PSSnapin | Select -ExpandProperty Name | Where {$StandardUserEnv.Snapins -notcontains $_ } ) 
                                }
                            }
                                Function Get-RunspaceData {
                                    [cmdletbinding()]
                                    param( [switch]$Wait )
                                    #loop through runspaces
                                    #if $wait is specified, keep looping until all complete
                                    Do {
                                        #set more to false for tracking completion
                                        $more = $false

                                        #Progress bar if we have inputobject count (bound parameter)
                                        if (-not $Quiet) {
						                    Write-Progress  -Activity "Running Query" -Status "Starting threads"`
							                    -CurrentOperation "$startedCount threads defined - $totalCount input objects - $script:completedCount input objects processed"`
							                    -PercentComplete $( Try { $script:completedCount / $totalCount * 100 } Catch {0} )
					                    }
                                        #run through each runspace.           
                                        Foreach($runspace in $runspaces) {                   
                                            #get the duration - inaccurate
                                            $currentdate = Get-Date
                                            $runtime = $currentdate - $runspace.startTime
                                            $runMin = [math]::Round( $runtime.totalminutes ,2 )

                                            #set up log object
                                            $log = "" | select Date, Action, Runtime, Status, Details
                                            $log.Action = "Removing:'$($runspace.object)'"
                                            $log.Date = $currentdate
                                            $log.Runtime = "$runMin minutes"

                                            #If runspace completed, end invoke, dispose, recycle, counter++
                                            If ($runspace.Runspace.isCompleted) {                            
                                                $script:completedCount++
                        
                                                #check if there were errors
                                                if($runspace.powershell.Streams.Error.Count -gt 0) {                                
                                                    #set the logging info and move the file to completed
                                                    $log.status = "CompletedWithErrors"
                                                    Write-Verbose ($log | ConvertTo-Csv -Delimiter ";" -NoTypeInformation)[1]
                                                    foreach($ErrorRecord in $runspace.powershell.Streams.Error) {
                                                        Write-Error -ErrorRecord $ErrorRecord
                                                    }
                                                }
                                                else {                                
                                                    #add logging details and cleanup
                                                    $log.status = "Completed"
                                                    Write-Verbose ($log | ConvertTo-Csv -Delimiter ";" -NoTypeInformation)[1]
                                                }
                                                #everything is logged, clean up the runspace
                                                $runspace.powershell.EndInvoke($runspace.Runspace)
                                                $runspace.powershell.dispose()
                                                $runspace.Runspace = $null
                                                $runspace.powershell = $null
                                            }
                                            #If runtime exceeds max, dispose the runspace
                                            ElseIf ( $runspaceTimeout -ne 0 -and $runtime.totalseconds -gt $runspaceTimeout) {                            
                                                $script:completedCount++
                                                $timedOutTasks = $true
                            
							                    #add logging details and cleanup
                                                $log.status = "TimedOut"
                                                Write-Verbose ($log | ConvertTo-Csv -Delimiter ";" -NoTypeInformation)[1]
                                                Write-Error "Runspace timed out at $($runtime.totalseconds) seconds for the object:`n$($runspace.object | out-string)"

                                                #Depending on how it hangs, we could still get stuck here as dispose calls a synchronous method on the powershell instance
                                                if (!$noCloseOnTimeout) { $runspace.powershell.dispose() }
                                                $runspace.Runspace = $null
                                                $runspace.powershell = $null
                                                $completedCount++
                                            }                   
                                            #If runspace isn't null set more to true  
                                            ElseIf ($runspace.Runspace -ne $null ) {
                                                $log = $null
                                                $more = $true
                                            }
                                            #log the results if a log file was indicated
                                            if($logFile -and $log){
                                                ($log | ConvertTo-Csv -Delimiter ";" -NoTypeInformation)[1] | out-file $LogFile -append
                                            }
                                        }
                                        #Clean out unused runspace jobs
                                        $temphash = $runspaces.clone()
                                        $temphash | Where { $_.runspace -eq $Null } | ForEach {
                                            $Runspaces.remove($_)
                                        }
                                        #sleep for a bit if we will loop again
                                        if($PSBoundParameters['Wait']){ Start-Sleep -milliseconds $SleepTimer }
                                    #Loop again only if -wait parameter and there are more runspaces to process
                                    } while ($more -and $PSBoundParameters['Wait'])                
                                }        
                            #region Init
                                if($PSCmdlet.ParameterSetName -eq 'ScriptFile'){$ScriptBlock = [scriptblock]::Create( $(Get-Content $ScriptFile | out-string) )}
                                elseif($PSCmdlet.ParameterSetName -eq 'ScriptBlock') {
                                    #Start building parameter names for the param block
                                    [string[]]$ParamsToAdd = '$_'
                                    if( $PSBoundParameters.ContainsKey('Parameter') ){$ParamsToAdd += '$Parameter'}
                                    $UsingVariableData = $Null                

                                    # This code enables $Using support through the AST.
                                    # This is entirely from  Boe Prox, and his https://github.com/proxb/PoshRSJob module; all credit to Boe!                
                                    if ($PSVersionTable.PSVersion.Major -gt 2) {
                                        #Extract using references
                                        $UsingVariables = $ScriptBlock.ast.FindAll({$args[0] -is [System.Management.Automation.Language.UsingExpressionAst]},$True)    
                                        If ($UsingVariables) {
                                            $List = New-Object 'System.Collections.Generic.List`1[System.Management.Automation.Language.VariableExpressionAst]'
                                            ForEach ($Ast in $UsingVariables) {[void]$list.Add($Ast.SubExpression)}
                                            $UsingVar = $UsingVariables | Group Parent | ForEach {$_.Group | Select -First 1}
        
                                            #Extract the name, value, and create replacements for each
                                            $UsingVariableData = ForEach ($Var in $UsingVar) {
                                                Try {
                                                    $Value = Get-Variable -Name $Var.SubExpression.VariablePath.UserPath -ErrorAction Stop
                                                    $NewName = ('$__using_{0}' -f $Var.SubExpression.VariablePath.UserPath)
                                                    [pscustomobject]@{
                                                        Name = $Var.SubExpression.Extent.Text
                                                        Value = $Value.Value
                                                        NewName = $NewName
                                                        NewVarName = ('__using_{0}' -f $Var.SubExpression.VariablePath.UserPath)
                                                    }
                                                    $ParamsToAdd += $NewName
                                                }
                                                Catch {Write-Error "$($Var.SubExpression.Extent.Text) is not a valid Using: variable!"}
                                            }    
                                            $NewParams = $UsingVariableData.NewName -join ', '
                                            $Tuple = [Tuple]::Create($list, $NewParams)
                                            $bindingFlags = [Reflection.BindingFlags]"Default,NonPublic,Instance"
                                            $GetWithInputHandlingForInvokeCommandImpl = ($ScriptBlock.ast.gettype().GetMethod('GetWithInputHandlingForInvokeCommandImpl',$bindingFlags))        
                                            $StringScriptBlock = $GetWithInputHandlingForInvokeCommandImpl.Invoke($ScriptBlock.ast,@($Tuple))
                                            $ScriptBlock = [scriptblock]::Create($StringScriptBlock)
                                            Write-Verbose $StringScriptBlock
                                        }
                                    }                
                                    $ScriptBlock = $ExecutionContext.InvokeCommand.NewScriptBlock("param($($ParamsToAdd -Join ", "))`r`n" + $Scriptblock.ToString())
                                }
                                else {Throw "Must provide ScriptBlock or ScriptFile"; Break}
                                Write-Debug "`$ScriptBlock: $($ScriptBlock | Out-String)"
                                Write-Verbose "Creating runspace pool and session states"

                                #If specified, add variables and modules/snapins to session state
                                $sessionstate = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
                                if ($ImportVariables) {
                                    if($UserVariables.count -gt 0) {
                                        foreach($Variable in $UserVariables){$sessionstate.Variables.Add( (New-Object -TypeName System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList $Variable.Name, $Variable.Value, $null) )}
                                    }
                                }
                                if ($ImportModules) {
                                    if($UserModules.count -gt 0) {
                                        foreach($ModulePath in $UserModules) {
                                            $sessionstate.ImportPSModule($ModulePath)
                                        }
                                    }
                                    if($UserSnapins.count -gt 0) {
                                        foreach($PSSnapin in $UserSnapins) {
                                            [void]$sessionstate.ImportPSSnapIn($PSSnapin, [ref]$null)
                                        }
                                    }
                                }
                                #Create runspace pool
                                $runspacepool = [runspacefactory]::CreateRunspacePool(1, $Throttle, $sessionstate, $Host)
                                $runspacepool.Open() 

                                Write-Verbose "Creating empty collection to hold runspace jobs"
                                $Script:runspaces = New-Object System.Collections.ArrayList        
        
                                #If inputObject is bound get a total count and set bound to true
                                $global:__bound = $false
                                $allObjects = @()
                                if( $PSBoundParameters.ContainsKey("inputObject") ){
                                    $global:__bound = $true
                                }
                                #Set up log file if specified
                                if( $LogFile ){
                                    New-Item -ItemType file -path $logFile -force | Out-Null
                                    ("" | Select Date, Action, Runtime, Status, Details | ConvertTo-Csv -NoTypeInformation -Delimiter ";")[0] | Out-File $LogFile
                                }
                                #write initial log entry
                                $log = "" | Select Date, Action, Runtime, Status, Details
                                    $log.Date = Get-Date
                                    $log.Action = "Batch processing started"
                                    $log.Runtime = $null
                                    $log.Status = "Started"
                                    $log.Details = $null
                                    if ($logFile) { ($log | convertto-csv -Delimiter ";" -NoTypeInformation)[1] | Out-File $LogFile -Append}
			                    $timedOutTasks = $false
                        }
                        Process {
                            #add piped objects to all objects or set all objects to bound input object parameter
                            if( -not $global:__bound ){$allObjects += $inputObject}
                            else{$allObjects = $InputObject}
                        }

                        End {        
                            #Use Try/Finally to catch Ctrl+C and clean up.
                            Try {
                                #counts for progress
                                $totalCount = $allObjects.count
                                $script:completedCount = 0
                                $startedCount = 0

                                foreach($object in $allObjects){
                                    #region add scripts to runspace pool
                                        #Create the powershell instance, set verbose if needed, supply the scriptblock and parameters
                                        $powershell = [powershell]::Create()
                    
                                        if ($VerbosePreference -eq 'Continue') { [void]$PowerShell.AddScript({$VerbosePreference = 'Continue'}) }
                                        [void]$PowerShell.AddScript($ScriptBlock).AddArgument($object)
                                        if ($parameter) { [void]$PowerShell.AddArgument($parameter) }
                                        # $Using support from Boe Prox
                                        if ($UsingVariableData) {
                                            Foreach($UsingVariable in $UsingVariableData) {
                                                Write-Verbose "Adding $($UsingVariable.Name) with value: $($UsingVariable.Value)"
                                                [void]$PowerShell.AddArgument($UsingVariable.Value)
                                            }
                                        }
                                        #Add the runspace into the powershell instance
                                        $powershell.RunspacePool = $runspacepool
    
                                        #Create a temporary collection for each runspace
                                        $temp = "" | Select-Object PowerShell, StartTime, object, Runspace
                                        $temp.PowerShell = $powershell
                                        $temp.StartTime = Get-Date
                                        $temp.object = $object
    
                                        #Save the handle output when calling BeginInvoke() that will be used later to end the runspace
                                        $temp.Runspace = $powershell.BeginInvoke()
                                        $startedCount++

                                        #Add the temp tracking info to $runspaces collection
                                        Write-Verbose ( "Adding {0} to collection at {1}" -f $temp.object, $temp.starttime.tostring() )
                                        $runspaces.Add($temp) | Out-Null
            
                                        #loop through existing runspaces one time
                                        Get-RunspaceData

                                        #If we have more running than max queue (used to control timeout accuracy)
                                        #Script scope resolves odd PowerShell 2 issue
                                        $firstRun = $true
                                        while ($runspaces.count -ge $Script:MaxQueue) {
                                            #give verbose output
                                            if($ firstRun) { Write-Verbose "$($runspaces.count) items running - exceeded $Script:MaxQueue limit." }
                                            $firstRun = $false
                    
                                            #run get-runspace data and sleep for a short while
                                            Get-RunspaceData
                                            Start-Sleep -Milliseconds $sleepTimer                    
                                        }
                                }
                     
                                Write-Verbose ( "Finish processing the remaining runspace jobs: {0}" -f ( @($runspaces | Where {$_.Runspace -ne $Null}).Count) )
                                Get-RunspaceData -wait
                                if (-not $quiet) {Write-Progress -Activity "Running Query" -Status "Starting threads" -Completed}
                            }
                            Finally {
                                #Close the runspace pool, unless we specified no close on timeout and something timed out
                                if ( ($timedOutTasks -eq $false) -or ( ($timedOutTasks -eq $true) -and ($noCloseOnTimeout -eq $false) ) ) {
	                                Write-Verbose "Closing the runspace pool"
			                        $runspacepool.close()
                                }
                                #collect garbage
                                [gc]::Collect()
                            }       
                        }
                    }
                    Write-Verbose "PSBoundParameters = $($PSBoundParameters | Out-String)"        
                    $bound = $PSBoundParameters.keys -contains "ComputerName"
                    if(-not $bound) {[System.Collections.ArrayList]$AllComputers = @()}
                }
                Process{
                    #Handle both pipeline and bound parameter.  We don't want to stream objects, defeats purpose of parallelizing work
                    if ($bound) {$AllComputers = $ComputerName}
                    Else {foreach ($Computer in $ComputerName) {$AllComputers.add($Computer) | Out-Null}}
                }
                End {
                    #Built up the parameters and run everything in parallel
                    $params = @($Detail, $Quiet)
                    $splat = @{
                        Throttle = $Throttle
                        RunspaceTimeout = $Timeout
                        InputObject = $AllComputers
                        parameter = $params
                    }
                    if($NoCloseOnTimeout) {$splat.add('NoCloseOnTimeout',$True)}

                    Invoke-Parallel @splat -ScriptBlock {        
                        $computer = $_.trim()
                        $detail = $parameter[0]
                        $quiet = $parameter[1]

                        #They want detail, define and run test-server
                        if($detail) {
                            Try {
                                #Modification of jrich's Test-Server function: https://gallery.technet.microsoft.com/scriptcenter/Powershell-Test-Server-e0cdea9a
                                Function Test-Server{
                                    [cmdletBinding()]
                                    param(
	                                    [parameter(
                                            Mandatory=$true,
                                            ValueFromPipeline=$true)]
	                                    [string[]]$ComputerName,
                                        [switch]$All,
                                        [parameter(Mandatory=$false)]
	                                    [switch]$CredSSP,
                                        [switch]$RemoteReg,
                                        [switch]$RDP,
                                        [switch]$RPC,
                                        [switch]$SMB,
                                        [switch]$WSMAN,
                                        [switch]$IPV6,
	                                    [Management.Automation.PSCredential]$Credential
                                    )
                                        begin {
	                                        $total = Get-Date
	                                        $results = @()
	                                        if($credssp -and -not $Credential){
                                                Throw "Must supply Credentials with CredSSP test"
                                            }
                                            [string[]]$props = write-output Name, IP, Domain, Ping, WSMAN, CredSSP, RemoteReg, RPC, RDP, SMB

                                            #Hash table to create PSObjects later, compatible with ps2...
                                            $Hash = @{}
                                            foreach ($prop in $props) {
                                                $Hash.Add($prop,$null)
                                            }
                                            function Test-Port{
                                                [cmdletbinding()]
                                                Param(
                                                    [string]$srv,
                                                    $port=135,
                                                    $timeout=3000
                                                )
                                                $ErrorActionPreference = "SilentlyContinue"
                                                $tcpclient = new-Object system.Net.Sockets.TcpClient
                                                $iar = $tcpclient.BeginConnect($srv,$port,$null,$null)
                                                $wait = $iar.AsyncWaitHandle.WaitOne($timeout,$false)
                                                if(-not $wait){
                                                    $tcpclient.Close()
                                                    Write-Verbose "Connection Timeout to $srv`:$port"
                                                    $false
                                                }
                                                else {
                                                    Try {
                                                        $tcpclient.EndConnect($iar) | out-Null
                                                        $true
                                                    }
                                                    Catch {
                                                        write-verbose "Error for $srv`:$port`: $_"
                                                        $false
                                                    }
                                                    $tcpclient.Close()
                                                }
                                            }
                                        }
                                        process {
                                            foreach ($name in $computername) {
	                                            $dt = $cdt= Get-Date
	                                            Write-verbose "Testing: $Name"
	                                            $failed = 0
	                                            try{
	                                                $DNSEntity = [Net.Dns]::GetHostEntry($name)
	                                                $domain = ($DNSEntity.hostname).replace("$name.","")
	                                                $ips = $DNSEntity.AddressList | %{
                                                        if(-not ( -not $IPV6 -and $_.AddressFamily -like "InterNetworkV6" )) {
                                                            $_.IPAddressToString
                                                        }
                                                    }
	                                            }
	                                            catch {
		                                            $rst = New-Object -TypeName PSObject -Property $Hash | Select -Property $props
		                                            $rst.name = $name
		                                            $results += $rst
		                                            $failed = 1
	                                            }
	                                            Write-verbose "DNS:  $((New-TimeSpan $dt ($dt = get-date)).totalseconds)"
	                                            if($failed -eq 0){
	                                                foreach ($ip in $ips) {	    
		                                                $rst = New-Object -TypeName PSObject -Property $Hash | Select -Property $props
	                                                    $rst.name = $name
		                                                $rst.ip = $ip
		                                                $rst.domain = $domain
		            
                                                        if ($RDP -or $All) {
                                                            ####RDP Check (firewall may block rest so do before ping
		                                                    try{
                                                                $socket = New-Object Net.Sockets.TcpClient($name, 3389) -ErrorAction stop
		                                                        if ($socket -eq $null) {
			                                                        $rst.RDP = $false
		                                                        }
		                                                        else {
			                                                        $rst.RDP = $true
			                                                        $socket.close()
		                                                        }
                                                            }
                                                            catch {
                                                                $rst.RDP = $false
                                                                Write-Verbose "Error testing RDP: $_"
                                                            }
                                                        }
		                                            Write-verbose "RDP:  $((New-TimeSpan $dt ($dt = get-date)).totalseconds)"
	                                                if(test-connection $ip -count 2 -Quiet) {
	                                                    Write-verbose "PING:  $((New-TimeSpan $dt ($dt = get-date)).totalseconds)"
			                                            $rst.ping = $true
			    
                                                        if($WSMAN -or $All){
                                                            try {
				                                                Test-WSMan $ip -ErrorAction stop | Out-Null
				                                                $rst.WSMAN = $true
				                                            }
			                                                catch {
                                                                $rst.WSMAN = $false
                                                                Write-Verbose "Error testing WSMAN: $_"
                                                            }
				                                            Write-verbose "WSMAN:  $((New-TimeSpan $dt ($dt = get-date)).totalseconds)"
			                                                if ($rst.WSMAN -and $credssp) {
				                                                try{
					                                                Test-WSMan $ip -Authentication Credssp -Credential $cred -ErrorAction stop
					                                                $rst.CredSSP = $true
					                                            }
				                                                catch {
                                                                    $rst.CredSSP = $false
                                                                    Write-Verbose "Error testing CredSSP: $_"
                                                                }
				                                                Write-verbose "CredSSP:  $((New-TimeSpan $dt ($dt = get-date)).totalseconds)"
			                                                }
                                                        }
                                                        if ($RemoteReg -or $All) {
			                                                try {
				                                                [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, $ip) | Out-Null
				                                                $rst.remotereg = $true
			                                                }
			                                                catch {
                                                                $rst.remotereg = $false
                                                                Write-Verbose "Error testing RemoteRegistry: $_"
                                                            }
			                                                Write-verbose "remote reg:  $((New-TimeSpan $dt ($dt = get-date)).totalseconds)"
                                                        }
                                                        if ($RPC -or $All) {
			                                                try {	
				                                                $w = [wmi] ''
				                                                $w.psbase.options.timeout = 15000000
				                                                $w.path = "\\$Name\root\cimv2:Win32_ComputerSystem.Name='$Name'"
				                                                $w | select none | Out-Null
				                                                $rst.RPC = $true
			                                                }
			                                                catch {
                                                                $rst.rpc = $false
                                                                Write-Verbose "Error testing WMI/RPC: $_"
                                                            }
			                                                Write-verbose "WMI/RPC:  $((New-TimeSpan $dt ($dt = get-date)).totalseconds)"
                                                        }
                                                        if ($SMB -or $All) {
                    	                                    try {	
                                                                $path = "\\$name\c$"
				                                                Push-Location -Path $path -ErrorAction stop
				                                                $rst.SMB = $true
                                                                Pop-Location
			                                                }
			                                                catch {
                                                                $rst.SMB = $false
                                                                Write-Verbose "Error testing SMB: $_"
                                                            }
			                                                Write-verbose "SMB:  $((New-TimeSpan $dt ($dt = get-date)).totalseconds)"
                                                        }
	                                                }
		                                            else {
			                                            $rst.ping = $false
			                                            $rst.wsman = $false
			                                            $rst.credssp = $false
			                                            $rst.remotereg = $false
			                                            $rst.rpc = $false
                                                        $rst.smb = $false
		                                            }
		                                            $results += $rst	
	                                            }
                                            }
	                                        Write-Verbose "Time for $($Name): $((New-TimeSpan $cdt ($dt)).totalseconds)"
	                                        Write-Verbose "----------------------------"
                                            }
                                        }
                                        end {
	                                        Write-Verbose "Time for all: $((New-TimeSpan $total ($dt)).totalseconds)"
	                                        Write-Verbose "----------------------------"
                                            return $results
                                        }
                                    }                    
                                #Build up parameters for Test-Server and run it
                                    $TestServerParams = @{
                                        ComputerName = $Computer
                                        ErrorAction = "Stop"
                                    }
                                    if($detail -eq "*"){
                                        $detail = "WSMan","RemoteReg","RPC","RDP","SMB" 
                                    }
                                    $detail | Select -Unique | Foreach-Object { $TestServerParams.add($_,$True) }
                                    Test-Server @TestServerParams | Select -Property $( "Name", "IP", "Domain", "Ping" + $detail )
                            }
                            Catch { Write-Warning "Error with Test-Server: $_" }
                        }
                        #We just want ping output
                        else {
                            Try {
                                #Pick out a few properties, add a status label.  If quiet output, just return the address
                                $result = $null
                                if( $result = @( Test-Connection -ComputerName $computer -Count 2 -erroraction Stop ) )
                                {
                                    $Output = $result | Select -first 1 -Property Address,
                                                                                    IPV4Address,
                                                                                    IPV6Address,
                                                                                    ResponseTime,
                                                                                    @{ label = "STATUS"; expression = {"Responding"} }
                                    if($quiet) {$Output.address}
                                    else{$Output}
                                }
                            }
                            Catch {
                                if (-not $quiet) {
                                    #Ping failed.  I'm likely making inappropriate assumptions here, let me know if this is the case : )
                                    if($_ -match "No such host is known") {$status = "Unknown host"}
                                    elseif ($_ -match "Error due to lack of resources") {$status = "No Response"}
                                    else {$status = "Error: $_"}
                                    "" | Select -Property @{ label = "Address"; expression = {$computer} },
                                                            IPV4Address,
                                                            IPV6Address,
                                                            ResponseTime,
                                                            @{ label = "STATUS"; expression = {$status} }
                                }
                            }
                        }
                    }
                }
            }
            Invoke-Ping -ComputerName $TargetComputer -Detail * `
            | Select-Object -Property @{Name="PSComputerName";Expression={$_.Name}}, IP, Domain, Ping, WSMAN, RemoteReg, RPC, RDP, SMB `
            | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation
        } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv" 
}


#============================================================================================================================================================
# Scheduled Tasks - schtasks
#============================================================================================================================================================

function ScheduledTasksCommand {
    $CollectionName = "Scheduled Tasks - schtasks"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                
                Invoke-Command -Credential $Credential -ComputerName $TargetComputer -ScriptBlock {
                    cmd /c schtasks /query /V /FO CSV
                } -ArgumentList @($null) | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"

                if ((Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv") -eq $null) {
                    Remove-Item "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"
                }
            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                            
                Invoke-Command -ComputerName $TargetComputer -ScriptBlock {
                    cmd /c schtasks /query /V /FO CSV
                } -ArgumentList @($null) | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"

                if ((Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv") -eq $null) {
                    Remove-Item "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"
                }
            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv" 
    Remove-DuplicateCsvHeaders
}

#============================================================================================================================================================
# Screen Saver Info
#============================================================================================================================================================

function ScreenSaverInfoCommand {
    $CollectionName = "Screen Saver Info"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                            
                Get-WmiObject -Credential $Credential -Class Win32_Desktop -ComputerName $TargetComputer `
                | Select-Object -Property PSComputerName, Name, ScreenSaverActive, ScreenSaverTimeout, ScreenSaverExecutable, Wallpaper `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                            
                Get-WmiObject -Class Win32_Desktop -ComputerName $TargetComputer `
                | Select-Object -Property PSComputerName, Name, ScreenSaverActive, ScreenSaverTimeout, ScreenSaverExecutable, Wallpaper `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Security Patches
#============================================================================================================================================================

function SecurityPatchesCommand {
    $CollectionName = "Security Patches"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                            
                Get-WmiObject -Credential $Credential -Class Win32_QuickFixEngineering -ComputerName $TargetComputer `
                | Select-Object PSComputerName, @{Name="Name";Expression={$_.HotFixID}}, HotFixID, Description, InstalledBy, InstalledOn `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                            
                Get-WmiObject -Class Win32_QuickFixEngineering -ComputerName $TargetComputer `
                | Select-Object PSComputerName, @{Name="Name";Expression={$_.HotFixID}}, HotFixID, Description, InstalledBy, InstalledOn `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        } 
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Services
#============================================================================================================================================================

function ServicesCommand {
    $CollectionName = "Services"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                                            
                Get-WmiObject -Credential $Credential -Class Win32_Service -ComputerName $TargetComputer `
                | Select-Object PSComputerName, State, Name, ProcessID, Description, PathName, Started, StartMode, StartName | Sort-Object PSComputerName, State, Name `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                                            
                Get-WmiObject -Class Win32_Service -ComputerName $TargetComputer `
                | Select-Object PSComputerName, State, Name, ProcessID, Description, PathName, Started, StartMode, StartName | Sort-Object PSComputerName, State, Name `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Shares
#============================================================================================================================================================

function SharesCommand {
    $CollectionName = "Shares"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                            
                Get-WmiObject -Credential $Credential -Class Win32_Share -ComputerName $TargetComputer `
                | Select-Object PSComputerName, Status, Name, Path, Description `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                            
                Get-WmiObject -Class Win32_Share -ComputerName $TargetComputer `
                | Select-Object PSComputerName, Status, Name, Path, Description `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Software Installed
#============================================================================================================================================================

function SoftwareInstalledCommand {
    $CollectionName = "Software Installed"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                            
                Get-WmiObject -Credential $Credential -Class Win32_Product -ComputerName $TargetComputer `
                | Select-Object -Property PSComputerName, Name, Vendor, Version, InstallDate, InstallDate2, InstallLocation, InstallSource, PackageName, PackageCache, RegOwner, HelpLink, HelpTelephone, URLInfoAbout, URLUpdateInfo, Language, Description, IdentifyingNumber `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation     

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer)
                Invoke-Expression -Command $ThreadPriority
                
                ### working on faster script...
                <#Function Get-Software  {
                    [OutputType('System.Software.Inventory')]
                    [Cmdletbinding()] 
                    Param( 
                        [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)] 
                        [String[]]$Computername=$env:COMPUTERNAME
                    )         
                    Begin {}
                    Process  {
                        $Paths  = @("SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall","SOFTWARE\\Wow6432node\\Microsoft\\Windows\\CurrentVersion\\Uninstall")         
                        ForEach($Path in $Paths) { 
                        Write-Verbose  "Checking Path: $Path"
                        #  Create an instance of the Registry Object and open the HKLM base key 
                        Try  {$reg=[microsoft.win32.registrykey]::OpenRemoteBaseKey('LocalMachine',$Computername,'Registry64')} 
                        Catch  {Write-Error $_ ; Continue} 
                        #  Drill down into the Uninstall key using the OpenSubKey Method 
                        Try  {
                            $regkey=$reg.OpenSubKey($Path)  
                            # Retrieve an array of string that contain all the subkey names 
                            $subkeys=$regkey.GetSubKeyNames()      
                            # Open each Subkey and use GetValue Method to return the required  values for each 
                            ForEach ($key in $subkeys){   
                                Write-Verbose "Key: $Key"
                                $thisKey=$Path+"\\"+$key 
                                Try {  
                                    $thisSubKey=$reg.OpenSubKey($thisKey)   
                                    # Prevent Objects with empty DisplayName 
                                    $DisplayName =  $thisSubKey.getValue("DisplayName")
                                    If ($DisplayName  -AND $DisplayName  -notmatch '^Update  for|rollup|^Security Update|^Service Pack|^HotFix') {
                                        $Date = $thisSubKey.GetValue('InstallDate')
                                        If ($Date) {
                                            Try {
                                                $Date = [datetime]::ParseExact($Date, 'yyyyMMdd', $Null)
                                            }
                                            Catch{
                                                Write-Warning "$($Computername): $_ <$($Date)>"
                                                $Date = $Null
                                            }
                                        } 
                                        # Create New Object with empty Properties 
                                        $Publisher =  Try {$thisSubKey.GetValue('Publisher').Trim()} 
                                            Catch {$thisSubKey.GetValue('Publisher')}
                                        $Version = Try {
                                            #Some weirdness with trailing [char]0 on some strings
                                            $thisSubKey.GetValue('DisplayVersion').TrimEnd(([char[]](32,0)))
                                        } 
                                            Catch {$thisSubKey.GetValue('DisplayVersion')}
                                        $UninstallString =  Try {$thisSubKey.GetValue('UninstallString').Trim()} 
                                            Catch {$thisSubKey.GetValue('UninstallString')}
                                        $InstallLocation =  Try {$thisSubKey.GetValue('InstallLocation').Trim()} 
                                            Catch {$thisSubKey.GetValue('InstallLocation')}
                                        $InstallSource =  Try {$thisSubKey.GetValue('InstallSource').Trim()} 
                                            Catch {$thisSubKey.GetValue('InstallSource')}
                                        $HelpLink = Try {$thisSubKey.GetValue('HelpLink').Trim()} 
                                            Catch {$thisSubKey.GetValue('HelpLink')}
                                        $Object = [pscustomobject]@{
                                            Computername = $Computername
                                            DisplayName = $DisplayName
                                            Version  = $Version
                                            InstallDate = $Date
                                            Publisher = $Publisher
                                            UninstallString = $UninstallString
                                            InstallLocation = $InstallLocation
                                            InstallSource  = $InstallSource
                                            HelpLink = $thisSubKey.GetValue('HelpLink')
                                            EstimatedSizeMB = [decimal]([math]::Round(($thisSubKey.GetValue('EstimatedSize')*1024)/1MB,2))
                                        }
                                        $Object.pstypenames.insert(0,'System.Software.Inventory')
                                            Write-Output $Object
                                        }
                                    } 
                                    Catch {Write-Warning "$Key : $_"}   
                                }
                            } 
                            Catch  {}   
                            $reg.Close() 
                        }                  
                    } 
                } 
                Get-Software -Computername $TargetComputer `
                | Select-Object -Property @{Name = 'PSComputerName'; Expression = {$_.ComputerName}}, DisplayName, Version, InstallDate, Publisher, EstimatedSizeMB, UninstallString, InstallLocation, InstallSource, HelpLink `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation
                #>

                # If the above doesn't provide any results, it will try to get the installed software using WMI... though obtaining results from Win32_Product class is painfully slow process
                #if ((Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -ErrorAction SilentlyContinue).length -lt 1) {
                    Get-WmiObject -Class Win32_Product -ComputerName $TargetComputer `
                    | Select-Object -Property PSComputerName, Name, Vendor, Version, InstallDate, InstallDate2, InstallLocation, InstallSource, PackageName, PackageCache, RegOwner, HelpLink, HelpTelephone, URLInfoAbout, URLUpdateInfo, Language, Description, IdentifyingNumber `
                    | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation
                #}
            } -ArgumentList @($IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer)
        }  
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Startup Commands
#============================================================================================================================================================

function StartupCommandsCommand {
    $CollectionName = "Startup Commands"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                
                Get-WmiObject -Credential $Credential -Class Win32_StartupCommand -ComputerName $TargetComputer `
                | Select-Object PSComputerName, Name, Location, Command, User `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                            
                Get-WmiObject -Class Win32_StartupCommand -ComputerName $TargetComputer `
                | Select-Object PSComputerName, Name, Location, Command, User `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# System Info
#============================================================================================================================================================

function SystemInfoCommand {
    $CollectionName = "System Info"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                            
                Invoke-WmiMethod -Credential $Credential -Class Win32_Process -Name Create -ComputerName $TargetComputer -ArgumentList "cmd /c systeminfo /fo csv > `"C:\Windows\Temp\SystemInfo-$TargetComputer.csv`"" | Out-Null
    
                # This deleay is introduced to allow the collection command to complete gathering data before it pulls back the data
                Start-Sleep -Seconds $SleepTime

                # This copies the data from the target then removes the copy
                Copy-Item   "\\$TargetComputer\c$\Windows\Temp\SystemInfo-$TargetComputer.csv" "$IndividualHostResults\$CollectionDirectory"
                Remove-Item "\\$TargetComputer\c$\Windows\Temp\SystemInfo-$TargetComputer.csv"
    
                # Adds the addtional column header, PSComputerName, and target computer to each connection
                $SystemInfo = Get-Content "$IndividualHostResults\$CollectionDirectory\SystemInfo-$TargetComputer.csv"
                $SystemInfo | ForEach-Object {
                    if ($_ -match '"Host Name","OS Name"') {"PSComputerName," + "$_"}
                    else {"$TargetComputer," + "$_"}
                } | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"
    
                Remove-Item "$IndividualHostResults\$CollectionDirectory\SystemInfo-$TargetComputer.csv"

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                            
                Invoke-WmiMethod -Class Win32_Process -Name Create -ComputerName $TargetComputer -ArgumentList "cmd /c systeminfo /fo csv > `"C:\Windows\Temp\SystemInfo-$TargetComputer.csv`"" | Out-Null
    
                # This deleay is introduced to allow the collection command to complete gathering data before it pulls back the data
                Start-Sleep -Seconds $SleepTime

                # This copies the data from the target then removes the copy
                Copy-Item   "\\$TargetComputer\c$\Windows\Temp\SystemInfo-$TargetComputer.csv" "$IndividualHostResults\$CollectionDirectory"
                Remove-Item "\\$TargetComputer\c$\Windows\Temp\SystemInfo-$TargetComputer.csv"
    
                # Adds the addtional column header, PSComputerName, and target computer to each connection
                $SystemInfo = Get-Content "$IndividualHostResults\$CollectionDirectory\SystemInfo-$TargetComputer.csv"
                $SystemInfo | ForEach-Object {
                    if ($_ -match '"Host Name","OS Name"') {"PSComputerName," + "$_"}
                    else {"$TargetComputer," + "$_"}
                } | Out-File "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"
    
                Remove-Item "$IndividualHostResults\$CollectionDirectory\SystemInfo-$TargetComputer.csv"

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# USB Controller Device Connections
#============================================================================================================================================================

function USBControllerDevicesCommand {
    $CollectionName = "USB Controller Devices"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                            
                Get-WmiObject -Class Win32_USBControllerDevice -ComputerName $TargetComputer `
                | Foreach {[wmi]($_.Dependent)} `
                | Select-Object -Property PSComputerName, Name, Manufacturer, Status, Service, DeviceID, @{Name="HardwareID";Expression={$_.HardwareID}} `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                            
                #Get-WmiObject -Class Win32_USBControllerDevice -ComputerName $TargetComputer `
                #| Select-Object PSComputerName, Antecedent, Dependent `
                #| Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation
                
                Get-WmiObject -Class Win32_USBControllerDevice -ComputerName $TargetComputer `
                | Foreach {[wmi]($_.Dependent)} `
                | Select-Object -Property PSComputerName, Name, Manufacturer, Status, Service, DeviceID, @{Name="HardwareID";Expression={$_.HardwareID}} `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }  
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

##############################################################################################################################################################
##
## Section 1 Event Logs Tab
##
##############################################################################################################################################################

# Varables for positioning checkboxes
$EventLogsRightPosition     = 5
$EventLogsDownPositionStart = 10
$EventLogsDownPosition      = 10
$EventLogsDownPositionShift = 22
$EventLogsBoxWidth          = 410
$EventLogsBoxHeight         = 22

$LimitNumberOfEventLogsCollectToChoice = 100

#----------------
# Event Logs Tab
#----------------
$Section1EventLogsTab          = New-Object System.Windows.Forms.TabPage
$Section1EventLogsTab.Location = $System_Drawing_Point
$Section1EventLogsTab.Text     = "Event Logs"
$Section1EventLogsTab.Location = New-Object System.Drawing.Size($Column1RightPosition,$Column1DownPosition) 
$Section1EventLogsTab.Size     = New-Object System.Drawing.Size($Column1BoxWidth,$Column1BoxHeight) 
$Section1EventLogsTab.UseVisualStyleBackColor = $True
$Section1CollectionsTabControl.Controls.Add($Section1EventLogsTab)


#-------------------------
# Event Logs - Main Label
#-------------------------
$EventLogsMainLabel           = New-Object System.Windows.Forms.Label
$EventLogsMainLabel.Text      = "Event Logs can be obtained from hosts and servers."
$EventLogsMainLabel.Location  = New-Object System.Drawing.Point(5,5) 
$EventLogsMainLabel.Size      = New-Object System.Drawing.Size($EventLogsBoxWidth,$EventLogsBoxHeight) 
$EventLogsMainLabel.Font      = New-Object System.Drawing.Font("$Font",11,1,3,1)
$EventLogsMainLabel.ForeColor = "Blue"
$Section1EventLogsTab.Controls.Add($EventLogsMainLabel)

#============================================================================================================================================================
# Event Logs - Event IDs Manual Entry
#============================================================================================================================================================

#-----------------------------------------------
# Event Logs - Event IDs Manual Entry CheckBox
#-----------------------------------------------
$EventLogsEventIDsManualEntryCheckbox          = New-Object System.Windows.Forms.CheckBox
$EventLogsEventIDsManualEntryCheckbox.Name     = "Event IDs Manual Entry  *"
$EventLogsEventIDsManualEntryCheckbox.Text     = "$($EventLogsEventIDsManualEntryCheckbox.Name)"
$EventLogsEventIDsManualEntryCheckbox.Location = New-Object System.Drawing.Size(5,($EventLogsMainLabel.Location.Y + $EventLogsMainLabel.Size.Height + 2)) 
$EventLogsEventIDsManualEntryCheckbox.Size     = New-Object System.Drawing.Size(200,$EventLogsBoxHeight) 
$Section1EventLogsTab.Controls.Add($EventLogsEventIDsManualEntryCheckbox)

#-------------------------------------------------------
# Event Logs - Event IDs Manual Entry Selection Button
#-------------------------------------------------------
if (Test-Path "$ResourcesDirectory\Event IDs.csv") {
    $EventLogsEventIDsManualEntrySelectionButton          = New-Object System.Windows.Forms.Button
    $EventLogsEventIDsManualEntrySelectionButton.Text     = "Select Event IDs"
    $EventLogsEventIDsManualEntrySelectionButton.Location = New-Object System.Drawing.Size(226,($EventLogsMainLabel.Location.Y + $EventLogsMainLabel.Size.Height + 2)) 
    $EventLogsEventIDsManualEntrySelectionButton.Size     = New-Object System.Drawing.Size(125,20) 
    $EventLogsEventIDsManualEntrySelectionButton.add_click({
        Import-Csv "$ResourcesDirectory\Event IDs.csv" | Out-GridView -OutputMode Multiple | Set-Variable -Name EventCodeManualEntrySelectionContents
        $EventIDColumn = $EventCodeManualEntrySelectionContents | Select-Object -ExpandProperty "Event ID"
        Foreach ($EventID in $EventIDColumn) {
            $EventLogsEventIDsManualEntryTextbox.Text += "$EventID`r`n"
        }
    })
    $Section1EventLogsTab.Controls.Add($EventLogsEventIDsManualEntrySelectionButton) 
}

#---------------------------------------------------
# Event Logs - Event IDs Manual Entry Clear Button
#---------------------------------------------------
$EventLogsEventIDsManualEntryClearButton          = New-Object System.Windows.Forms.Button
$EventLogsEventIDsManualEntryClearButton.Text     = "Clear"
$EventLogsEventIDsManualEntryClearButton.Location = New-Object System.Drawing.Size(356,($EventLogsMainLabel.Location.Y + $EventLogsMainLabel.Size.Height + 2)) 
$EventLogsEventIDsManualEntryClearButton.Size     = New-Object System.Drawing.Size(75,20) 
$EventLogsEventIDsManualEntryClearButton.add_click({
    $EventLogsEventIDsManualEntryTextbox.Text = ""
})
$Section1EventLogsTab.Controls.Add($EventLogsEventIDsManualEntryClearButton) 

#--------------------------------------------
# Event Logs - Event IDs Manual Entry Label
#--------------------------------------------
$EventLogsEventIDsManualEntryLabel           = New-Object System.Windows.Forms.Label
$EventLogsEventIDsManualEntryLabel.Location  = New-Object System.Drawing.Point(5,($EventLogsEventIDsManualEntryCheckbox.Location.Y + $EventLogsEventIDsManualEntryCheckbox.Size.Height)) 
$EventLogsEventIDsManualEntryLabel.Size      = New-Object System.Drawing.Size($EventLogsBoxWidth,$EventLogsBoxHeight) 
$EventLogsEventIDsManualEntryLabel.Text      = "Enter Event IDs - One Per Line"
$EventLogsEventIDsManualEntryLabel.Font      = New-Object System.Drawing.Font("$Font",9,0,3,0)
$EventLogsEventIDsManualEntryLabel.ForeColor = "Black"
$Section1EventLogsTab.Controls.Add($EventLogsEventIDsManualEntryLabel)

#----------------------------------------------
# Event Logs - Event IDs Manual Entry Textbox
#----------------------------------------------
$EventLogsEventIDsManualEntryTextbox               = New-Object System.Windows.Forms.TextBox
$EventLogsEventIDsManualEntryTextbox.Location      = New-Object System.Drawing.Size(5,($EventLogsEventIDsManualEntryLabel.Location.Y + $EventLogsEventIDsManualEntryLabel.Size.Height)) 
$EventLogsEventIDsManualEntryTextbox.Size          = New-Object System.Drawing.Size(425,100)
$EventLogsEventIDsManualEntryTextbox.MultiLine     = $True
$EventLogsEventIDsManualEntryTextbox.ScrollBars    = "Vertical"
$EventLogsEventIDsManualEntryTextbox.WordWrap      = True
$EventLogsEventIDsManualEntryTextbox.AcceptsTab    = false # Allows you to enter in tabs into the textbox
$EventLogsEventIDsManualEntryTextbox.AcceptsReturn = false # Allows you to enter in tabs into the textbox
$EventLogsEventIDsManualEntryTextbox.Font          = New-Object System.Drawing.Font("$Font",9,0,3,1)
#$EventLogsEventIDsManualEntryTextbox.Add_KeyDown({          })
$Section1EventLogsTab.Controls.Add($EventLogsEventIDsManualEntryTextbox)

#============================================================================================================================================================
# Event Logs - Event IDs Individual Selection
#============================================================================================================================================================

#-------------------------------------------------------
# Event Logs - Event IDs Individual Selection CheckBox
#-------------------------------------------------------
$EventLogsEventIDsIndividualSelectionCheckbox          = New-Object System.Windows.Forms.CheckBox
$EventLogsEventIDsIndividualSelectionCheckbox.Name     = "Event IDs Individual Selection  *"
$EventLogsEventIDsIndividualSelectionCheckbox.Text     = "$($EventLogsEventIDsIndividualSelectionCheckbox.Name)"
$EventLogsEventIDsIndividualSelectionCheckbox.Location = New-Object System.Drawing.Size(5,($EventLogsEventIDsManualEntryTextbox.Location.Y + $EventLogsEventIDsManualEntryTextbox.Size.Height + 8)) 
$EventLogsEventIDsIndividualSelectionCheckbox.Size     = New-Object System.Drawing.Size(350,$EventLogsBoxHeight) 
$Section1EventLogsTab.Controls.Add($EventLogsEventIDsIndividualSelectionCheckbox)

#-----------------------------------------------------------
# Event Logs - Event IDs Individual Selection Clear Button
#-----------------------------------------------------------
$EventLogsEventIDsIndividualSelectionClearButton          = New-Object System.Windows.Forms.Button
$EventLogsEventIDsIndividualSelectionClearButton.Text     = "Clear"
$EventLogsEventIDsIndividualSelectionClearButton.Location = New-Object System.Drawing.Size(356,($EventLogsEventIDsManualEntryTextbox.Location.Y + $EventLogsEventIDsManualEntryTextbox.Size.Height + 8)) 
$EventLogsEventIDsIndividualSelectionClearButton.Size     = New-Object System.Drawing.Size(75,20)
$EventLogsEventIDsIndividualSelectionClearButton.add_click({
    # Clears the commands selected
    For ($i=0;$i -lt $EventLogsEventIDsIndividualSelectionChecklistbox.Items.count;$i++) {
        $EventLogsEventIDsIndividualSelectionChecklistbox.SetSelected($i,$False)
        $EventLogsEventIDsIndividualSelectionChecklistbox.SetItemChecked($i,$False)
        $EventLogsEventIDsIndividualSelectionChecklistbox.SetItemCheckState($i,$False)
    }
})
$Section1EventLogsTab.Controls.Add($EventLogsEventIDsIndividualSelectionClearButton) 

#----------------------------------------------------
# Event Logs - Event IDs Individual Selection Label
#----------------------------------------------------
$EventLogsEventIDsIndividualSelectionLabel           = New-Object System.Windows.Forms.Label
$EventLogsEventIDsIndividualSelectionLabel.Location  = New-Object System.Drawing.Point(5,($EventLogsEventIDsIndividualSelectionCheckbox.Location.Y + $EventLogsEventIDsIndividualSelectionCheckbox.Size.Height))
$EventLogsEventIDsIndividualSelectionLabel.Size      = New-Object System.Drawing.Size($EventLogsBoxWidth,$EventLogsBoxHeight) 
$EventLogsEventIDsIndividualSelectionLabel.Text      = "Events to Monitor for Signs of Compromise and their Severity"
$EventLogsEventIDsIndividualSelectionLabel.Font      = New-Object System.Drawing.Font("$Font",9,0,3,0)
$EventLogsEventIDsIndividualSelectionLabel.ForeColor = "Black"
$Section1EventLogsTab.Controls.Add($EventLogsEventIDsIndividualSelectionLabel)

#-----------------------------------------------------------
# Event Logs - Event IDs Individual Selection Checklistbox
#-----------------------------------------------------------
$EventLogsEventIDsIndividualSelectionChecklistbox          = New-Object -TypeName System.Windows.Forms.CheckedListBox
$EventLogsEventIDsIndividualSelectionChecklistbox.Name     = "Event IDs [Potential Criticality] Event Summary"
$EventLogsEventIDsIndividualSelectionChecklistbox.Text     = "$($EventLogsEventIDsIndividualSelectionChecklistbox.Name)"
$EventLogsEventIDsIndividualSelectionChecklistbox.Location = New-Object System.Drawing.Size(5,($EventLogsEventIDsIndividualSelectionLabel.Location.Y + $EventLogsEventIDsIndividualSelectionLabel.Size.Height)) 
$EventLogsEventIDsIndividualSelectionChecklistbox.Size     = New-Object System.Drawing.Size(425,125)
#$EventLogsEventIDsIndividualSelectionChecklistbox.checked = $true
#$EventLogsEventIDsIndividualSelectionChecklistbox.CheckOnClick = $true #so we only have to click once to check a box
#$EventLogsEventIDsIndividualSelectionChecklistbox.SelectionMode = One #This will only allow one options at a time
$EventLogsEventIDsIndividualSelectionChecklistbox.ScrollAlwaysVisible = $true

$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4618 [High] A monitored security event pattern has occurred.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4649 [High] A replay attack was detected. May be a harmless false positive due to misconfiguration error.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4719 [High] System audit policy was changed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4765 [High] SID History was added to an account.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4766 [High] An attempt to add SID History to an account failed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4794 [High] An attempt was made to set the Directory Services Restore Mode.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4897 [High] Role separation enabled:')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4964 [High] Special groups have been assigned to a new logon.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5124 [High] A security setting was updated on the OCSP Responder Service')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('1102 [High] The audit log was cleared')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4621 [Medium] Administrator recovered system from CrashOnAuditFail. Users who are not administrators will now be allowed to log on. Some auditable activity might not have been recorded.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4675 [Medium] SIDs were filtered.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4692 [Medium] Backup of data protection master key was attempted.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4693 [Medium] Recovery of data protection master key was attempted.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4706 [Medium] A new trust was created to a domain.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4713 [Medium] Kerberos policy was changed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4714 [Medium] Encrypted data recovery policy was changed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4715 [Medium] The audit policy (SACL) on an object was changed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4716 [Medium] Trusted domain information was modified.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4724 [Medium] An attempt was made to reset an accounts password.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4727 [Medium] A security-enabled global group was created.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4735 [Medium] A security-enabled local group was changed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4737 [Medium] A security-enabled global group was changed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4739 [Medium] Domain Policy was changed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4754 [Medium] A security-enabled universal group was created.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4755 [Medium] A security-enabled universal group was changed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4764 [Medium] A security-disabled group was deleted')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4764 [Medium] A groups type was changed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4780 [Medium] The ACL was set on accounts which are members of administrators groups.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4816 [Medium] RPC detected an integrity violation while decrypting an incoming message.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4865 [Medium] A trusted forest information entry was added.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4866 [Medium] A trusted forest information entry was removed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4867 [Medium] A trusted forest information entry was modified.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4868 [Medium] The certificate manager denied a pending certificate request.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4870 [Medium] Certificate Services revoked a certificate.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4882 [Medium] The security permissions for Certificate Services changed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4885 [Medium] The audit filter for Certificate Services changed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4890 [Medium] The certificate manager settings for Certificate Services changed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4892 [Medium] A property of Certificate Services changed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4896 [Medium] One or more rows have been deleted from the certificate database.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4906 [Medium] The CrashOnAuditFail value has changed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4907 [Medium] Auditing settings on object were changed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4908 [Medium] Special Groups Logon table modified.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4912 [Medium] Per User Audit Policy was changed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4960 [Medium] IPsec dropped an inbound packet that failed an integrity check. If this problem persists, it could indicate a network issue or that packets are being modified in transit to this computer. Verify that the packets sent from the remote computer are the same as those received by this computer. This error might also indicate interoperability problems with other IPsec implementations.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4961 [Medium] IPsec dropped an inbound packet that failed a replay check. If this problem persists, it could indicate a replay attack against this computer.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4962 [Medium] IPsec dropped an inbound packet that failed a replay check. The inbound packet had too low a sequence number to ensure it was not a replay.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4963 [Medium] IPsec dropped an inbound clear text packet that should have been secured. This is usually due to the remote computer changing its IPsec policy without informing this computer. This could also be a spoofing attack attempt.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4965 [Medium] IPsec received a packet from a remote computer with an incorrect Security Parameter Index (SPI). This is usually caused by malfunctioning hardware that is corrupting packets. If these errors persist, verify that the packets sent from the remote computer are the same as those received by this computer. This error may also indicate interoperability problems with other IPsec implementations. In that case, if connectivity is not impeded, then these events can be ignored.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4976 [Medium] During Main Mode negotiation, IPsec received an invalid negotiation packet. If this problem persists, it could indicate a network issue or an attempt to modify or replay this negotiation.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4977 [Medium] During Quick Mode negotiation, IPsec received an invalid negotiation packet. If this problem persists, it could indicate a network issue or an attempt to modify or replay this negotiation.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4978 [Medium] During Extended Mode negotiation, IPsec received an invalid negotiation packet. If this problem persists, it could indicate a network issue or an attempt to modify or replay this negotiation.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4983 [Medium] An IPsec Extended Mode negotiation failed. The corresponding Main Mode security association has been deleted.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4984 [Medium] An IPsec Extended Mode negotiation failed. The corresponding Main Mode security association has been deleted.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5027 [Medium] The Windows Firewall Service was unable to retrieve the security policy from the local storage. The service will continue enforcing the current policy.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5028 [Medium] The Windows Firewall Service was unable to parse the new security policy. The service will continue with currently enforced policy.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5029 [Medium] The Windows Firewall Service failed to initialize the driver. The service will continue to enforce the current policy.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5030 [Medium] The Windows Firewall Service failed to start.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5035 [Medium] The Windows Firewall Driver failed to start.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5037 [Medium] The Windows Firewall Driver detected critical runtime error. Terminating.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5038 [Medium] Code integrity determined that the image hash of a file is not valid. The file could be corrupt due to unauthorized modification or the invalid hash could indicate a potential disk device error.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5120 [Medium] OCSP Responder Service Started')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5121 [Medium] OCSP Responder Service Stopped')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5122 [Medium] A configuration entry changed in OCSP Responder Service')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5123 [Medium] A configuration entry changed in OCSP Responder Service')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5376 [Medium] Credential Manager credentials were backed up.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5377 [Medium] Credential Manager credentials were restored from a backup.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5453 [Medium] An IPsec negotiation with a remote computer failed because the IKE and AuthIP IPsec Keying Modules (IKEEXT) service is not started.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5480 [Medium] IPsec Services failed to get the complete list of network interfaces on the computer. This poses a potential security risk because some of the network interfaces may not get the protection provided by the applied IPsec filters. Use the IP Security Monitor snap-in to diagnose the problem.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5483 [Medium] IPsec Services failed to initialize RPC server. IPsec Services could not be started.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5484 [Medium] IPsec Services has experienced a critical failure and has been shut down. The shutdown of IPsec Services can put the computer at greater risk of network attack or expose the computer to potential security risks.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5485 [Medium] IPsec Services failed to process some IPsec filters on a plug-and-play event for network interfaces. This poses a potential security risk because some of the network interfaces may not get the protection provided by the applied IPsec filters. Use the IP Security Monitor snap-in to diagnose the problem.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('6145 [Medium] One or more errors occurred while processing security policy in the Group Policy objects.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('6273 [Medium] Network Policy Server denied access to a user.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('6274 [Medium] Network Policy Server discarded the request for a user.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('6275 [Medium] Network Policy Server discarded the accounting request for a user.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('6276 [Medium] Network Policy Server quarantined a user.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('6277 [Medium] Network Policy Server granted access to a user but put it on probation because the host did not meet the defined health policy.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('6278 [Medium] Network Policy Server granted full access to a user because the host met the defined health policy.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('6279 [Medium] Network Policy Server locked the user account due to repeated failed authentication attempts.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('6280 [Medium] Network Policy Server unlocked the user account.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('24586 [Medium] An error was encountered converting volume')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('24592 [Medium] An attempt to automatically restart conversion on volume %2 failed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('24593 [Medium] Metadata write: Volume %2 returning errors while trying to modify metadata. If failures continue, decrypt volume')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('24594 [Medium] Metadata rebuild: An attempt to write a copy of metadata on volume %2 failed and may appear as disk corruption. If failures continue, decrypt volume.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4608 [Low] Windows is starting up.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4609 [Low] Windows is shutting down.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4610 [Low] An authentication package has been loaded by the Local Security Authority.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4611 [Low] A trusted logon process has been registered with the Local Security Authority.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4612 [Low] Internal resources allocated for the queuing of audit messages have been exhausted, leading to the loss of some audits.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4614 [Low] A notification package has been loaded by the Security Account Manager.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4615 [Low] Invalid use of LPC port.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4616 [Low] The system time was changed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4622 [Low] A security package has been loaded by the Local Security Authority.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4624 [Low] An account was successfully logged on.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4625 [Low] An account failed to log on.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4634 [Low] An account was logged off.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4646 [Low] IKE DoS-prevention mode started.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4647 [Low] User initiated logoff.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4648 [Low] A logon was attempted using explicit credentials.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4650 [Low] An IPsec Main Mode security association was established. Extended Mode was not enabled. Certificate authentication was not used.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4651 [Low] An IPsec Main Mode security association was established. Extended Mode was not enabled. A certificate was used for authentication.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4652 [Low] An IPsec Main Mode negotiation failed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4653 [Low] An IPsec Main Mode negotiation failed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4654 [Low] An IPsec Quick Mode negotiation failed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4655 [Low] An IPsec Main Mode security association ended.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4656 [Low] A handle to an object was requested.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4657 [Low] A registry value was modified.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4658 [Low] The handle to an object was closed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4659 [Low] A handle to an object was requested with intent to delete.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4660 [Low] An object was deleted.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4661 [Low] A handle to an object was requested.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4662 [Low] An operation was performed on an object.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4663 [Low] An attempt was made to access an object.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4664 [Low] An attempt was made to create a hard link.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4665 [Low] An attempt was made to create an application client context.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4666 [Low] An application attempted an operation:')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4667 [Low] An application client context was deleted.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4668 [Low] An application was initialized.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4670 [Low] Permissions on an object were changed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4671 [Low] An application attempted to access a blocked ordinal through the TBS.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4672 [Low] Special privileges assigned to new logon.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4673 [Low] A privileged service was called.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4674 [Low] An operation was attempted on a privileged object.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4688 [Low] A new process has been created.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4689 [Low] A process has exited.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4690 [Low] An attempt was made to duplicate a handle to an object.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4691 [Low] Indirect access to an object was requested.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4694 [Low] Protection of auditable protected data was attempted.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4695 [Low] Unprotection of auditable protected data was attempted.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4696 [Low] A primary token was assigned to process.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4697 [Low] Attempt to install a service')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4698 [Low] A scheduled task was created.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4699 [Low] A scheduled task was deleted.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4700 [Low] A scheduled task was enabled.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4701 [Low] A scheduled task was disabled.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4702 [Low] A scheduled task was updated.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4704 [Low] A user right was assigned.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4705 [Low] A user right was removed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4707 [Low] A trust to a domain was removed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4709 [Low] IPsec Services was started.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4710 [Low] IPsec Services was disabled.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4711 [Low] May contain any one of the fol[Low]ing: PAStore Engine applied locally cached copy of Active Directory storage IPsec policy on the computer.PAStore Engine applied Active Directory storage IPsec policy on the computer.PAStore Engine applied local registry storage IPsec policy on the computer.PAStore Engine failed to apply locally cached copy of Active Directory storage IPsec policy on the computer.PAStore Engine failed to apply Active Directory storage IPsec policy on the computer.PAStore Engine failed to apply local registry storage IPsec policy on the computer.PAStore Engine failed to apply some rules of the active IPsec policy on the computer.PAStore Engine failed to load directory storage IPsec policy on the computer.PAStore Engine loaded directory storage IPsec policy on the computer.PAStore Engine failed to load local storage IPsec policy on the computer.PAStore Engine loaded local storage IPsec policy on the computer.PAStore Engine polled for changes to the active IPsec policy and detected no changes.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4712 [Low] IPsec Services encountered a potentially serious failure.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4717 [Low] System security access was granted to an account.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4718 [Low] System security access was removed from an account.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4720 [Low] A user account was created.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4722 [Low] A user account was enabled.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4723 [Low] An attempt was made to change an accounts password.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4725 [Low] A user account was disabled.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4726 [Low] A user account was deleted.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4728 [Low] A member was added to a security-enabled global group.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4729 [Low] A member was removed from a security-enabled global group.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4730 [Low] A security-enabled global group was deleted.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4731 [Low] A security-enabled local group was created.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4732 [Low] A member was added to a security-enabled local group.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4733 [Low] A member was removed from a security-enabled local group.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4734 [Low] A security-enabled local group was deleted.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4738 [Low] A user account was changed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4740 [Low] A user account was locked out.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4741 [Low] A computer account was changed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4742 [Low] A computer account was changed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4743 [Low] A computer account was deleted.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4744 [Low] A security-disabled local group was created.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4745 [Low] A security-disabled local group was changed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4746 [Low] A member was added to a security-disabled local group.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4747 [Low] A member was removed from a security-disabled local group.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4748 [Low] A security-disabled local group was deleted.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4749 [Low] A security-disabled global group was created.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4750 [Low] A security-disabled global group was changed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4751 [Low] A member was added to a security-disabled global group.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4752 [Low] A member was removed from a security-disabled global group.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4753 [Low] A security-disabled global group was deleted.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4756 [Low] A member was added to a security-enabled universal group.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4757 [Low] A member was removed from a security-enabled universal group.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4758 [Low] A security-enabled universal group was deleted.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4759 [Low] A security-disabled universal group was created.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4760 [Low] A security-disabled universal group was changed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4761 [Low] A member was added to a security-disabled universal group.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4762 [Low] A member was removed from a security-disabled universal group.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4767 [Low] A user account was unlocked.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4768 [Low] A Kerberos authentication ticket (TGT) was requested.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4769 [Low] A Kerberos service ticket was requested.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4770 [Low] A Kerberos service ticket was renewed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4771 [Low] Kerberos pre-authentication failed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4772 [Low] A Kerberos authentication ticket request failed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4774 [Low] An account was mapped for logon.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4775 [Low] An account could not be mapped for logon.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4776 [Low] The domain controller attempted to validate the credentials for an account.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4777 [Low] The domain controller failed to validate the credentials for an account.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4778 [Low] A session was reconnected to a Window Station.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4779 [Low] A session was disconnected from a Window Station.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4781 [Low] The name of an account was changed:')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4782 [Low] The password hash an account was accessed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4783 [Low] A basic application group was created.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4784 [Low] A basic application group was changed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4785 [Low] A member was added to a basic application group.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4786 [Low] A member was removed from a basic application group.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4787 [Low] A nonmember was added to a basic application group.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4788 [Low] A nonmember was removed from a basic application group.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4789 [Low] A basic application group was deleted.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4790 [Low] An LDAP query group was created.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4793 [Low] The Password Policy Checking API was called.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4800 [Low] The workstation was locked.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4801 [Low] The workstation was unlocked.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4802 [Low] The screen saver was invoked.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4803 [Low] The screen saver was dismissed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4864 [Low] A namespace collision was detected.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4869 [Low] Certificate Services received a resubmitted certificate request.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4871 [Low] Certificate Services received a request to publish the certificate revocation list (CRL).')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4872 [Low] Certificate Services published the certificate revocation list (CRL).')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4873 [Low] A certificate request extension changed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4874 [Low] One or more certificate request attributes changed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4875 [Low] Certificate Services received a request to shut down.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4876 [Low] Certificate Services backup started.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4877 [Low] Certificate Services backup completed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4878 [Low] Certificate Services restore started.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4879 [Low] Certificate Services restore completed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4880 [Low] Certificate Services started.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4881 [Low] Certificate Services stopped.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4883 [Low] Certificate Services retrieved an archived key.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4884 [Low] Certificate Services imported a certificate into its database.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4886 [Low] Certificate Services received a certificate request.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4887 [Low] Certificate Services approved a certificate request and issued a certificate.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4888 [Low] Certificate Services denied a certificate request.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4889 [Low] Certificate Services set the status of a certificate request to pending.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4891 [Low] A configuration entry changed in Certificate Services.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4893 [Low] Certificate Services archived a key.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4894 [Low] Certificate Services imported and archived a key.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4895 [Low] Certificate Services published the CA certificate to Active Directory Domain Services.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4898 [Low] Certificate Services loaded a template.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4902 [Low] The Per-user audit policy table was created.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4904 [Low] An attempt was made to register a security event source.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4905 [Low] An attempt was made to unregister a security event source.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4909 [Low] The local policy settings for the TBS were changed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4910 [Low] The Group Policy settings for the TBS were changed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4928 [Low] An Active Directory replica source naming context was established.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4929 [Low] An Active Directory replica source naming context was removed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4930 [Low] An Active Directory replica source naming context was modified.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4931 [Low] An Active Directory replica destination naming context was modified.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4932 [Low] Synchronization of a replica of an Active Directory naming context has begun.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4933 [Low] Synchronization of a replica of an Active Directory naming context has ended.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4934 [Low] Attributes of an Active Directory object were replicated.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4935 [Low] Replication failure begins.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4936 [Low] Replication failure ends.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4937 [Low] A lingering object was removed from a replica.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4944 [Low] The fol[Low]ing policy was active when the Windows Firewall started.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4945 [Low] A rule was listed when the Windows Firewall started.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4946 [Low] A change has been made to Windows Firewall exception list. A rule was added.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4947 [Low] A change has been made to Windows Firewall exception list. A rule was modified.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4948 [Low] A change has been made to Windows Firewall exception list. A rule was deleted.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4949 [Low] Windows Firewall settings were restored to the default values.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4950 [Low] A Windows Firewall setting has changed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4951 [Low] A rule has been ignored because its major version number was not recognized by Windows Firewall.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4952 [Low] Parts of a rule have been ignored because its minor version number was not recognized by Windows Firewall. The other parts of the rule will be enforced.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4953 [Low] A rule has been ignored by Windows Firewall because it could not parse the rule.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4954 [Low] Windows Firewall Group Policy settings have changed. The new settings have been applied.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4956 [Low] Windows Firewall has changed the active profile.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4957 [Low] Windows Firewall did not apply the following rule:')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4958 [Low] Windows Firewall did not apply the following rule because the rule referred to items not configured on this computer:')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4979 [Low] IPsec Main Mode and Extended Mode security associations were established.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4980 [Low] IPsec Main Mode and Extended Mode security associations were established.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4981 [Low] IPsec Main Mode and Extended Mode security associations were established.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4982 [Low] IPsec Main Mode and Extended Mode security associations were established.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('4985 [Low] The state of a transaction has changed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5024 [Low] The Windows Firewall Service has started successfully.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5025 [Low] The Windows Firewall Service has been stopped.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5031 [Low] The Windows Firewall Service blocked an application from accepting incoming connections on the network.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5032 [Low] Windows Firewall was unable to notify the user that it blocked an application from accepting incoming connections on the network.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5033 [Low] The Windows Firewall Driver has started successfully.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5034 [Low] The Windows Firewall Driver has been stopped.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5039 [Low] A registry key was virtualized.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5040 [Low] A change has been made to IPsec settings. An Authentication Set was added.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5041 [Low] A change has been made to IPsec settings. An Authentication Set was modified.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5042 [Low] A change has been made to IPsec settings. An Authentication Set was deleted.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5043 [Low] A change has been made to IPsec settings. A Connection Security Rule was added.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5044 [Low] A change has been made to IPsec settings. A Connection Security Rule was modified.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5045 [Low] A change has been made to IPsec settings. A Connection Security Rule was deleted.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5046 [Low] A change has been made to IPsec settings. A Crypto Set was added.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5047 [Low] A change has been made to IPsec settings. A Crypto Set was modified.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5048 [Low] A change has been made to IPsec settings. A Crypto Set was deleted.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5050 [Low] An attempt to programmatically disable the Windows Firewall using a call to InetFwProfile.FirewallEnabled(False)')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5051 [Low] A file was virtualized.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5056 [Low] A cryptographic self test was performed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5057 [Low] A cryptographic primitive operation failed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5058 [Low] Key file operation.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5059 [Low] Key migration operation.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5060 [Low] Verification operation failed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5061 [Low] Cryptographic operation.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5062 [Low] A kernel-mode cryptographic self test was performed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5063 [Low] A cryptographic provider operation was attempted.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5064 [Low] A cryptographic context operation was attempted.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5065 [Low] A cryptographic context modification was attempted.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5066 [Low] A cryptographic function operation was attempted.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5067 [Low] A cryptographic function modification was attempted.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5068 [Low] A cryptographic function provider operation was attempted.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5069 [Low] A cryptographic function property operation was attempted.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5070 [Low] A cryptographic function property modification was attempted.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5125 [Low] A request was submitted to the OCSP Responder Service')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5126 [Low] Signing Certificate was automatically updated by the OCSP Responder Service')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5127 [Low] The OCSP Revocation Provider successfully updated the revocation information')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5136 [Low] A directory service object was modified.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5137 [Low] A directory service object was created.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5138 [Low] A directory service object was undeleted.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5139 [Low] A directory service object was moved.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5140 [Low] A network share object was accessed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5141 [Low] A directory service object was deleted.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5152 [Low] The Windows Filtering Platform blocked a packet.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5153 [Low] A more restrictive Windows Filtering Platform filter has blocked a packet.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5154 [Low] The Windows Filtering Platform has permitted an application or service to listen on a port for incoming connections.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5155 [Low] The Windows Filtering Platform has blocked an application or service from listening on a port for incoming connections.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5156 [Low] The Windows Filtering Platform has al[Low]ed a connection.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5157 [Low] The Windows Filtering Platform has blocked a connection.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5158 [Low] The Windows Filtering Platform has permitted a bind to a local port.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5159 [Low] The Windows Filtering Platform has blocked a bind to a local port.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5378 [Low] The requested credentials delegation was disal[Low]ed by policy.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5440 [Low] The following callout was present when the Windows Filtering Platform Base Filtering Engine started.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5441 [Low] The following filter was present when the Windows Filtering Platform Base Filtering Engine started.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5442 [Low] The following provider was present when the Windows Filtering Platform Base Filtering Engine started.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5443 [Low] The following provider context was present when the Windows Filtering Platform Base Filtering Engine started.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5444 [Low] The following sublayer was present when the Windows Filtering Platform Base Filtering Engine started.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5446 [Low] A Windows Filtering Platform callout has been changed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5447 [Low] A Windows Filtering Platform filter has been changed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5448 [Low] A Windows Filtering Platform provider has been changed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5449 [Low] A Windows Filtering Platform provider context has been changed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5450 [Low] A Windows Filtering Platform sublayer has been changed.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5451 [Low] An IPsec Quick Mode security association was established.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5452 [Low] An IPsec Quick Mode security association ended.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5456 [Low] PAStore Engine applied Active Directory storage IPsec policy on the computer.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5457 [Low] PAStore Engine failed to apply Active Directory storage IPsec policy on the computer.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5458 [Low] PAStore Engine applied locally cached copy of Active Directory storage IPsec policy on the computer.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5459 [Low] PAStore Engine failed to apply locally cached copy of Active Directory storage IPsec policy on the computer.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5460 [Low] PAStore Engine applied local registry storage IPsec policy on the computer.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5461 [Low] PAStore Engine failed to apply local registry storage IPsec policy on the computer.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5462 [Low] PAStore Engine failed to apply some rules of the active IPsec policy on the computer. Use the IP Security Monitor snap-in to diagnose the problem.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5463 [Low] PAStore Engine polled for changes to the active IPsec policy and detected no changes.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5464 [Low] PAStore Engine polled for changes to the active IPsec policy, detected changes, and applied them to IPsec Services.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5465 [Low] PAStore Engine received a control for forced reloading of IPsec policy and processed the control successfully.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5466 [Low] PAStore Engine polled for changes to the Active Directory IPsec policy, determined that Active Directory cannot be reached, and will use the cached copy of the Active Directory IPsec policy instead. Any changes made to the Active Directory IPsec policy since the last poll could not be applied.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5467 [Low] PAStore Engine polled for changes to the Active Directory IPsec policy, determined that Active Directory can be reached, and found no changes to the policy. The cached copy of the Active Directory IPsec policy is no longer being used.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5468 [Low] PAStore Engine polled for changes to the Active Directory IPsec policy, determined that Active Directory can be reached, found changes to the policy, and applied those changes. The cached copy of the Active Directory IPsec policy is no longer being used.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5471 [Low] PAStore Engine loaded local storage IPsec policy on the computer.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5472 [Low] PAStore Engine failed to load local storage IPsec policy on the computer.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5473 [Low] PAStore Engine loaded directory storage IPsec policy on the computer.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5474 [Low] PAStore Engine failed to load directory storage IPsec policy on the computer.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5477 [Low] PAStore Engine failed to add quick mode filter.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5049 [Low] An IPsec Security Association was deleted.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5478 [Low] IPsec Services has started successfully.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5479 [Low] IPsec Services has been shut down successfully. The shutdown of IPsec Services can put the computer at greater risk of network attack or expose the computer to potential security risks.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5632 [Low] A request was made to authenticate to a wireless network.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5633 [Low] A request was made to authenticate to a wired network.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5712 [Low] A Remote Procedure Call (RPC) was attempted.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5888 [Low] An object in the COM+ Catalog was modified.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5889 [Low] An object was deleted from the COM+ Catalog.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('5890 [Low] An object was added to the COM+ Catalog.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('6008 [Low] The previous system shutdown was unexpected')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('6144 [Low] Security policy in the Group Policy objects has been applied successfully.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('6272 [Low] Network Policy Server granted access to a user.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('24577 [Low] Encryption of volume started')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('24578 [Low] Encryption of volume stopped')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('24579 [Low] Encryption of volume completed')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('24580 [Low] Decryption of volume started')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('24581 [Low] Decryption of volume stopped')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('24582 [Low] Decryption of volume completed')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('24583 [Low] Conversion worker thread for volume started')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('24584 [Low] Conversion worker thread for volume temporarily stopped')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('24588 [Low] The conversion operation on volume %2 encountered a bad sector error. Please validate the data on this volume')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('24595 [Low] Volume %2 contains bad clusters. These clusters will be skipped during conversion.')
$EventLogsEventIDsIndividualSelectionChecklistbox.Items.Add('24621 [Low] Initial state check: Rolling volume conversion transaction on %2.')

#$EventLogsEventIDsIndividualSelectionChecklistboxFilter = ""
$EventLogsEventIDsIndividualSelectionChecklistbox.Add_Click({
    $MainListBox.Items.Clear()
    $MainListBox.Items.Add($EventLogsEventIDsIndividualSelectionChecklistbox.SelectedItem)
})
$Section1EventLogsTab.Controls.Add($EventLogsEventIDsIndividualSelectionChecklistbox)

#============================================================================================================================================================
# Event Logs - Event IDs Quick Pick Selection 
#============================================================================================================================================================

#---------------------------------------------
# Event Logs - Event IDs Quick Pick CheckBox
#---------------------------------------------
$EventLogsQuickPickSelectionCheckbox          = New-Object System.Windows.Forms.CheckBox
$EventLogsQuickPickSelectionCheckbox.Name     = "Event IDs Quick Selection  *"
$EventLogsQuickPickSelectionCheckbox.Text     = "$($EventLogsQuickPickSelectionCheckbox.Name)"
$EventLogsQuickPickSelectionCheckbox.Location = New-Object System.Drawing.Size(5,($EventLogsEventIDsIndividualSelectionChecklistbox.Location.Y + $EventLogsEventIDsIndividualSelectionChecklistbox.Size.Height + 7)) 
$EventLogsQuickPickSelectionCheckbox.Size     = New-Object System.Drawing.Size(350,$EventLogsBoxHeight) 
$Section1EventLogsTab.Controls.Add($EventLogsQuickPickSelectionCheckbox)

#-----------------------------------------------------------
# Event Logs - Event IDs Quick Pick Selection Clear Button
#-----------------------------------------------------------
$EventLogsQuickPickSelectionClearButton          = New-Object System.Windows.Forms.Button
$EventLogsQuickPickSelectionClearButton.Text     = "Clear"
$EventLogsQuickPickSelectionClearButton.Location = New-Object System.Drawing.Size(356,($EventLogsEventIDsIndividualSelectionChecklistbox.Location.Y + $EventLogsEventIDsIndividualSelectionChecklistbox.Size.Height + 7))
$EventLogsQuickPickSelectionClearButton.Size     = New-Object System.Drawing.Size(75,20)
$EventLogsQuickPickSelectionClearButton.add_click({
    # Clears the commands selected
    For ($i=0;$i -lt $EventLogsQuickPickSelectionCheckedlistbox.Items.count;$i++) {
        $EventLogsQuickPickSelectionCheckedlistbox.SetSelected($i,$False)
        $EventLogsQuickPickSelectionCheckedlistbox.SetItemChecked($i,$False)
        $EventLogsQuickPickSelectionCheckedlistbox.SetItemCheckState($i,$False)
    }
})
$Section1EventLogsTab.Controls.Add($EventLogsQuickPickSelectionClearButton) 

#------------------------------------------
# Event Logs - Event IDs Quick Pick Label
#------------------------------------------
$EventLogsQuickPickSelectionLabel           = New-Object System.Windows.Forms.Label
$EventLogsQuickPickSelectionLabel.Location  = New-Object System.Drawing.Point(5,($EventLogsQuickPickSelectionCheckbox.Location.Y + $EventLogsQuickPickSelectionCheckbox.Size.Height))
$EventLogsQuickPickSelectionLabel.Size      = New-Object System.Drawing.Size($EventLogsBoxWidth,$EventLogsBoxHeight) 
$EventLogsQuickPickSelectionLabel.Text      = "The following have bundled Event IDs by Topic - Can Select Multiple"
$EventLogsQuickPickSelectionLabel.Font      = New-Object System.Drawing.Font("$Font",9,0,3,0)
$EventLogsQuickPickSelectionLabel.ForeColor = "Black"
$Section1EventLogsTab.Controls.Add($EventLogsQuickPickSelectionLabel)

#-------------------------------------------------
# Event Logs - Event IDs Quick Pick Checklistbox
#-------------------------------------------------
$EventLogsQuickPickSelectionCheckedlistbox          = New-Object -TypeName System.Windows.Forms.CheckedListBox
$EventLogsQuickPickSelectionCheckedlistbox.Name     = "Event Logs Selection"
$EventLogsQuickPickSelectionCheckedlistbox.Text     = "$($EventLogsQuickPickSelectionCheckedlistbox.Name)"
$EventLogsQuickPickSelectionCheckedlistbox.Location = New-Object System.Drawing.Size(5,($EventLogsQuickPickSelectionLabel.Location.Y + $EventLogsQuickPickSelectionLabel.Size.Height)) 
$EventLogsQuickPickSelectionCheckedlistbox.Size     = New-Object System.Drawing.Size(425,125)
#$EventLogsQuickPickSelectionCheckedlistbox.checked  = $true
#$EventLogsQuickPickSelectionCheckedlistbox.CheckOnClick = $true #so we only have to click once to check a box
#$EventLogsQuickPickSelectionCheckedlistbox.SelectionMode = One #This will only allow one options at a time
$EventLogsQuickPickSelectionCheckedlistbox.ScrollAlwaysVisible = $true

$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - Application Event Logs')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - Security Event Logs')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - System Event Logs')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - Application Event Logs Errors')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - System Event Logs Errors')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - Account Lockout')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - Account Management')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - Account Management Events - Other')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - Application Generated')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - Application Group Management')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - Authentication Policy Change')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - Authorization Policy Change')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - Audit Policy Change')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - Central Access Policy Staging')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - Certification Services')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - Computer Account Management')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - Detailed Directory Service Replication')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - Detailed File Share')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - Directory Service Access')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - Directory Service Changes')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - Directory Service Replication')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - Distribution Group Management')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - DPAPI Activity')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - File Share')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - File System')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - Filtering Platform Connection')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - Filtering Platform Packet Drop')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - Filtering Platform Policy Change')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - Group Membership')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - Handle Manipulation')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - IPSec Driver')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - IPSec Extended Mode')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - IPSec Main Mode')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - IPSec Quick Mode')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - Kerberos Authentication Service')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - Kerberos Service Ticket Operations')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - Kernel Object')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - Logon and Logoff Events')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - Logon and Logoff Events - Other')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - MPSSVC Rule Level Policy Change')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - Network Policy Server')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - Other Events')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - Other Object Access Events')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - Other Policy Change Events')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - Other System Events')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - PNP Activity')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - Process Creation and Termination')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - Registry')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - Removeable Storage')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - RPC Events')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - SAM')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - Security Group Management')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - Security State Change')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - Security System Extension')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - Sensitive and NonSensitive Privilege Use')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - Special Logon')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - System Integrity')
$EventLogsQuickPickSelectionCheckedlistbox.Items.Add('Event Logs - User and Device Claims')

$EventLogsQuickPickSelectionCheckedlistbox.Add_Click({
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - Application Event Logs') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\Application Event Logs.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - Security Event Logs') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\Security Event Logs.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - System Event Logs') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\System Event Logs.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - Application Event Logs Errors') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\Application Event Logs Errors.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - System Event Logs Errors') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\System Event Logs Errors.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - Account Lockout') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\Account Lockout.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - Account Management') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\Account Management.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - Account Management Events - Other') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\Account Management Events - Other.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - Application Generated') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\Application Generated.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - Application Group Management') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\Application Group Management.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - Audit Policy Change') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\Audit Policy Change.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - Authentication Policy Change') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\Authentication Policy Change.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - Authorization Policy Change') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\Authorization Policy Change.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - Logon and Logoff Events') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\Logon and Logoff Events.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - Logon and Logoff Events - Other') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\Logon and Logoff Events - Other.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - Special Logon') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\Special Logon.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - Central Access Policy Staging') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\Central Access Policy Staging.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - Certification Services') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\Certification Services.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - Computer Account Management') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\Computer Account Management.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - Detailed Directory Service Replication') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\Detailed Directory Service Replication.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - Detailed File Share') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\Detailed File Share.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - Directory Service Access') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\Directory Service Access.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - Directory Service Changes') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\Directory Service Changes.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - Directory Service Replication') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\Directory Service Replication.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - Distribution Group Management') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\Distribution Group Management.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - DPAPI Activity') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\DPAPI Activity.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - File Share') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\File Share.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - File System') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\File System.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - Filtering Platform Connection') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\Filtering Platform Connection.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - Filtering Platform Packet Drop') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\Filtering Platform Packet Drop.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - Filtering Platform Policy Change') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\Filtering Platform Policy Change.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - Group Membership') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\Group Membership.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - Handle Manipulation') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\Handle Manipulation.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - IPSec Driver') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\IPSec Driver.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - IPSec Extended Mode') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\IPSec Extended Mode.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - IPSec Main Mode') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\IPSec Main Mode.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - IPSec Quick Mode') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\IPSec Quick Mode.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - Kerberos Authentication Service') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\Kerberos Authentication Service.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - Kerberos Service Ticket Operations') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\Kerberos Service Ticket Operations.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - Kernel Object') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\Kernel Object.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - MPSSVC Rule Level Policy Change') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\MPSSVC Rule Level Policy Change.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - Network Policy Server') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\Network Policy Server.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - Other Events') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\Other Events.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - Other Object Access Events') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\Other Object Access Events.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - Other Policy Change Events') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\Other Policy Change Events.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - Other System Events') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\Other System Events.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - Process Creation and Termination') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\Process Creation and Termination.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - PNP Activity') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\PNP Activity.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - Registry') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\Registry.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - Removeable Storage') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\Removeable Storage.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - RPC Events') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\RPC Events.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - SAM') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\SAM.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - Security Group Management') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\Security Group Management.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - Security State Change') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\Security State Change.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - Security System Extension') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\Security System Extension.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - Sensitive and NonSensitive Privilege Use') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\Sensitive and NonSensitive Privilege Use.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - System Integrity') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\System Integrity.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($EventLogsQuickPickSelectionCheckedlistbox.SelectedItem -match 'Event Logs - User and Device Claims') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsEventLogsDirectory\User and Device Claims.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
})
$Section1EventLogsTab.Controls.Add($EventLogsQuickPickSelectionCheckedlistbox)

#============================================================================================================================================================
# Event Logs - Main Function - EventLogQuery
#============================================================================================================================================================
function EventLogQuery {
    param($CollectionName,$Filter)
    $CollectionName = $CollectionName
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$LimitNumberOfEventLogsCollectToChoice,$Filter,$Credential)
                Invoke-Expression -Command $ThreadPriority
                
                Get-WmiObject -Credential $Credential -Class Win32_NTLogEvent -ComputerName $TargetComputer -Filter $Filter `
                | Select-Object PSComputerName, EventCode, LogFile, TimeGenerated, Message, InsertionStrings, Type `
                | Select-Object -first $LimitNumberOfEventLogsCollectToChoice `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$LimitNumberOfEventLogsCollectToChoice,$Filter,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$LimitNumberOfEventLogsCollectToChoice,$Filter)
                Invoke-Expression -Command $ThreadPriority
                          
                Get-WmiObject -Class Win32_NTLogEvent -ComputerName $TargetComputer -Filter $Filter `
                | Select-Object PSComputerName, EventCode, LogFile, TimeGenerated, Message, InsertionStrings, Type `
                | Select-Object -first $LimitNumberOfEventLogsCollectToChoice `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$LimitNumberOfEventLogsCollectToChoice,$Filter)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Event Logs - Funtions / Commands
#============================================================================================================================================================
function EventLogsEventCodeManualEntryCommand {
    $CollectionName = "Event Logs - Event IDs Manual Entry"

    $ManualEntry = $EventLogsEventIDsManualEntryTextbox.Text -split "`r`n"
    $ManualEntry = $ManualEntry -replace " ","" -replace "a|b|c|d|e|f|g|h|i|j|k|l|m|n|o|p|q|r|s|t|u|v|w|x|y|z",""
    $ManualEntry = $ManualEntry | ? {$_.trim() -ne ""}

    # Variables begins with an open "(
    $EventLogsEventIDsManualEntryTextboxFilter = '('

    foreach ($EventCode in $ManualEntry) {
        $EventLogsEventIDsManualEntryTextboxFilter += "(EventCode='$EventCode') OR "
    }
    # Replaces the ' OR ' at the end of the varable with a closing )"
    $Filter = $EventLogsEventIDsManualEntryTextboxFilter -replace " OR $",")"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function EventLogsEventCodeIndividualSelectionCommand {
    $CollectionName = "Event Logs - Event IDs Indiviual Selection"

    # Variables begins with an open "(
    $EventLogsEventIDsIndividualSelectionChecklistboxFilter = '('
    foreach ($Checked in $EventLogsEventIDsIndividualSelectionChecklistbox.CheckedItems) {
        $Checked = $Checked[0..4] -join ''
        $Checked = $Checked -replace ' ',''
        $EventLogsEventIDsIndividualSelectionChecklistboxFilter += "(EventCode='$Checked') OR "
    }
    # Replaces the ' OR ' at the end of the varable with a closing )"
    $Filter = $EventLogsEventIDsIndividualSelectionChecklistboxFilter -replace " OR $",")"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function ApplicationEventLogsCommand {
    $CollectionName = "Event Logs - Application Event Logs"
    $Filter = "(logfile='Application')"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function SecurityEventLogsCommand {
    $CollectionName = "Event Logs - Security Event Logs"
    $Filter = "(logfile='Security')"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function SystemEventLogsCommand {
    $CollectionName = "Event Logs - System Event Logs"
    $Filter = "(logfile='System')"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function ApplicationEventLogsErrorsCommand {
    $CollectionName = "Event Logs - Application Event Logs Errors"
    $Filter = "(logfile='Application') AND (type='error')"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function SystemEventLogsErrorsCommand {
    $CollectionName = "Event Logs - System Event Logs Errors"
    $Filter = "(logfile='System') AND (type='error')"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function AccountLockoutCommand {
    $CollectionName = "Event Logs - Account Lockout"
    $Filter = "(logfile='Security') AND (EventCode='4625')"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function AccountManagementCommand {
    $CollectionName = "Event Logs - Account Management"
    $Filter = "(logfile='Security') AND ((EventCode='4720') OR (EventCode='4722') OR (EventCode='4723') OR (EventCode='4724') OR (EventCode='4725') OR (EventCode='4726') OR (EventCode='4738') OR (EventCode='4740') OR (EventCode='4765') OR (EventCode='4766') OR (EventCode='4767') OR (EventCode='4780') OR (EventCode='4781') OR (EventCode='4781') OR (EventCode='4794') OR (EventCode='4798') OR (EventCode='5376') OR (EventCode='5377'))"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function AccountManagementEventsOtherCommand {
    $CollectionName = "Event Logs - Account Management Events - Other"
    $Filter = "(logfile='Security') AND ((EventCode='4782') OR (EventCode='4793'))"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function ApplicationGeneratedCommand {
    $CollectionName = "Event Logs - Application Event Logs Generated"
    $Filter = "(logfile='Security') AND ((EventCode='4665') OR (EventCode='4666') OR (EventCode='4667') OR (EventCode='4668'))"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function ApplicationGroupManagementCommand {
    $CollectionName = "Event Logs - Application Event Logs Group Management"
    $Filter = "(logfile='Security') AND ((EventCode='4783') OR (EventCode='4784') OR (EventCode='4785') OR (EventCode='4786') OR (EventCode='4787') OR (EventCode='4788') OR (EventCode='4789') OR (EventCode='4790') OR (EventCode='4791') OR (EventCode='4792'))"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function AuthenticationPolicyChangeCommand {
    $CollectionName = "Event Logs - Authentication Policy Change"
    $Filter = "(logfile='Security') AND ((EventCode='4670') OR (EventCode='4706') OR (EventCode='4707') OR (EventCode='4716') OR (EventCode='4713') OR (EventCode='4717') OR (EventCode='4718') OR (EventCode='4739') OR (EventCode='4864') OR (EventCode='4865') OR (EventCode='4866') OR (EventCode='4867'))"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function AuthorizationPolicyChangeCommand {
    $CollectionName = "Event Logs - Authorization Policy Change"
    $Filter = "(logfile='Security') AND ((EventCode='4703') OR (EventCode='4704') OR (EventCode='4705') OR (EventCode='4670') OR (EventCode='4911') OR (EventCode='4913'))"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function AuditPolicyChangeCommand {
    $CollectionName = "Event Logs - Audit Policy Change"
    $Filter = "(logfile='Security') AND ((EventCode='4902') OR (EventCode='4907') OR (EventCode='4904') OR (EventCode='4905') OR (EventCode='4715') OR (EventCode='4719') OR (EventCode='4817') OR (EventCode='4902') OR (EventCode='4906') OR (EventCode='4907') OR (EventCode='4908') OR (EventCode='4912') OR (EventCode='4904') OR (EventCode='4905'))"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function CentralAccessPolicyStagingCommand {
    $CollectionName = "Event Logs - Central Access Policy Staging"
    $Filter = "(logfile='Security') AND (EventCode='4818')"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function CertificationServicesCommand {
    $CollectionName = "Event Logs - Certification Services"
    $Filter = "(logfile='Security') AND ((EventCode='4868') OR (EventCode='4869') OR (EventCode='4870') OR (EventCode='4871') OR (EventCode='4872') OR (EventCode='4873') OR (EventCode='4874') OR (EventCode='4875') OR (EventCode='4876') OR (EventCode='4877') OR (EventCode='4878') OR (EventCode='4879') OR (EventCode='4880') OR (EventCode='4881') OR (EventCode='4882') OR (EventCode='4883') OR (EventCode='4884') OR (EventCode='4885') OR (EventCode='4886') OR (EventCode='4887') OR (EventCode='4888') OR (EventCode='4889') OR (EventCode='4890') OR (EventCode='4891') OR (EventCode='4892') OR (EventCode='4893') OR (EventCode='4894') OR (EventCode='4895') OR (EventCode='4896') OR (EventCode='4897') OR (EventCode='4898'))"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function ComputerAccountManagementCommand {
    $CollectionName = "Event Logs - Computer Account Management"
    $Filter = "(logfile='Security') AND ((EventCode='4741') OR (EventCode='4742') OR (EventCode='4743'))"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function DetailedDirectoryServiceReplicationCommand {
    $CollectionName = "Event Logs - Detailed Directory Service Replication"
    $Filter = "(logfile='Security') AND ((EventCode='4928') OR (EventCode='4929') OR (EventCode='4930') OR (EventCode='4931') OR (EventCode='4934') OR (EventCode='4935') OR (EventCode='4936') OR (EventCode='4937'))"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function DetailedFileShareCommand {
    $CollectionName = "Event Logs - Detailed File Share"
    $Filter = "(logfile='Security') AND (EventCode='5145')"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function DirectoryServiceAccessCommand {
    $CollectionName = "Event Logs - Directory Service Access"
    $Filter = "(logfile='Security') AND ((EventCode='4662') OR (EventCode='4661'))"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function DirectoryServiceChangesCommand {
    $CollectionName = "Event Logs - Directory Service Changes"
    $Filter = "(logfile='Security') AND ((EventCode='5136') OR (EventCode='5137') OR (EventCode='5138') OR (EventCode='5139') OR (EventCode='5141'))"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function DirectoryServiceReplicationCommand {
    $CollectionName = "Event Logs - Directory Service Replication"
    $Filter = "(logfile='Security') AND ((EventCode='4932') OR (EventCode='4933'))"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function DistributionGroupManagementCommand {
    $CollectionName = "Event Logs - Distribution Group Management"
    $Filter = "(logfile='Security') AND ((EventCode='4749') OR (EventCode='4750') OR (EventCode='4751') OR (EventCode='4752') OR (EventCode='4753') OR (EventCode='4759') OR (EventCode='4760') OR (EventCode='4761') OR (EventCode='4762') OR (EventCode='4763') OR (EventCode='4744') OR (EventCode='4745') OR (EventCode='4746') OR (EventCode='4747') OR (EventCode='4748'))"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function DPAPIActivityCommand {
    $CollectionName = "Event Logs - DPAPI Activity"
    $Filter = "(logfile='Security') AND ((EventCode='4692') OR (EventCode='4693') OR (EventCode='4694') OR (EventCode='4695'))"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function FileShareCommand {
    $CollectionName = "Event Logs - File Share"
    $Filter = "(logfile='Security') AND ((EventCode='5140') OR (EventCode='5142') OR (EventCode='5143') OR (EventCode='5144') OR (EventCode='5168'))"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function FileSystemCommand {
    $CollectionName = "Event Logs - File System"
    $Filter = "(logfile='Security') AND ((EventCode='4656') OR (EventCode='4658') OR (EventCode='4660') OR (EventCode='4663') OR (EventCode='4664') OR (EventCode='4985') OR (EventCode='5051') OR (EventCode='4670'))"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function FilteringPlatformConnectionCommand {
    $CollectionName = "Event Logs - Filtering Platform Connection"
    $Filter = "(logfile='Security') AND ((EventCode='5031') OR (EventCode='5150') OR (EventCode='5151') OR (EventCode='5154') OR (EventCode='5155') OR (EventCode='5156') OR (EventCode='5157') OR (EventCode='5158') OR (EventCode='5159'))"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function FilteringPlatformPacketDropCommand {
    $CollectionName = "Event Logs - Filtering Platform Packet Drop"
    $Filter = "(logfile='Security') AND ((EventCode='5152') OR (EventCode='5153'))"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function FilteringPlatformPolicyChangeCommand {
    $CollectionName = "Event Logs - Filtering Platform Policy Change"
    $Filter = "(logfile='Security') AND ((EventCode='4709') OR (EventCode='4710') OR (EventCode='4711') OR (EventCode='4712') OR (EventCode='5040') OR (EventCode='5041') OR (EventCode='5042') OR (EventCode='5043') OR (EventCode='5044') OR (EventCode='5045') OR (EventCode='5046') OR (EventCode='5047') OR (EventCode='5048') OR (EventCode='5440') OR (EventCode='5441') OR (EventCode='5442') OR (EventCode='5443') OR (EventCode='5444') OR (EventCode='5446') OR (EventCode='5448') OR (EventCode='5449') OR (EventCode='5450') OR (EventCode='5456') OR (EventCode='5457') OR (EventCode='5458') OR (EventCode='5459') OR (EventCode='5460') OR (EventCode='5461') OR (EventCode='5462') OR (EventCode='5463') OR (EventCode='5464') OR (EventCode='5465') OR (EventCode='5466') OR (EventCode='5467') OR (EventCode='5468') OR (EventCode='5471') OR (EventCode='5472') OR (EventCode='5473') OR (EventCode='5474') OR (EventCode='5477'))"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function GroupMembershipCommand {
    $CollectionName = "Event Logs - Group Membership"
    $Filter = "(logfile='Security') AND (EventCode='4627')"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function HandleManipulationCommand {
    $CollectionName = "Event Logs - Handle Manipulation"
    $Filter = "(logfile='Security') AND ((EventCode='4658') OR (EventCode='4690'))"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function IPSecDriverCommand {
    $CollectionName = "Event Logs - IPSec Driver"
    $Filter = "(logfile='Security') AND ((EventCode='4960') OR (EventCode='4961') OR (EventCode='4962') OR (EventCode='4963') OR (EventCode='4965') OR (EventCode='5478') OR (EventCode='5479') OR (EventCode='5480') OR (EventCode='5483') OR (EventCode='5484') OR (EventCode='5485'))"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function IPSecExtendedModeCommand {
    $CollectionName = "Event Logs - IPSec Extended Mode"
    $Filter = "(logfile='Security') AND ((EventCode='4978') OR (EventCode='4979') OR (EventCode='4980') OR (EventCode='4981') OR (EventCode='4982') OR (EventCode='4983') OR (EventCode='4984'))"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function IPSecMainModeCommand {
    $CollectionName = "Event Logs - IPSec Main Mode"
    $Filter = "(logfile='Security') AND ((EventCode='4646') OR (EventCode='4650') OR (EventCode='4651') OR (EventCode='4652') OR (EventCode='4653') OR (EventCode='4655') OR (EventCode='4976') OR (EventCode='5049') OR (EventCode='5453'))"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function IPSecQuickModeCommand {
    $CollectionName = "Event Logs - IPSec Quick Mode"
    $Filter = "(logfile='Security') AND ((EventCode='4977') OR (EventCode='5451') OR (EventCode='5452'))"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function KerberosAuthenticationServiceCommand {
    $CollectionName = "Event Logs - Kerberos Authentication Service"
    $Filter = "(logfile='Security') AND ((EventCode='4768') OR (EventCode='4771') OR (EventCode='4772'))"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function KerberosServiceTicketOperationsCommand {
    $CollectionName = "Event Logs - Kerberos Service Ticket Operations"
    $Filter = "(logfile='Security') AND ((EventCode='4769') OR (EventCode='4770') OR (EventCode='4773'))"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function KernelObjectCommand {
    $CollectionName = "Event Logs - Kernel Object"
    $Filter = "(logfile='Security') AND ((EventCode='4656') OR (EventCode='4658') OR (EventCode='4660') OR (EventCode='4663'))"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function LogonLogoffEventsCommand{
    $CollectionName = "Event Logs - Logon and Logoff Events"
    $Filter = "(logfile='Security') AND ((EventCode='4624') OR (EventCode='4625') OR (EventCode='4648') OR (EventCode='4675') OR (EventCode='4634') OR (EventCode='4647'))"    
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function LogonLogoffEventsOtherCommand {
    $CollectionName = "Event Logs - Logon and Logoff Events - Other"
    $Filter = "(logfile='Security') AND ((EventCode='4649') OR (EventCode='4778') OR (EventCode='4779') OR (EventCode='4800') OR (EventCode='4801') OR (EventCode='4802') OR (EventCode='4803') OR (EventCode='5378') OR (EventCode='5632') OR (EventCode='5633'))"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function MPSSVCRuleLevelPolicyChangeCommand {
    $CollectionName = "Event Logs - MPSSVC Rule-Level Policy Change"
    $Filter = "(logfile='Security') AND ((EventCode='4944') OR (EventCode='4945') OR (EventCode='4946') OR (EventCode='4947') OR (EventCode='4948') OR (EventCode='4949') OR (EventCode='4950') OR (EventCode='4951') OR (EventCode='4952') OR (EventCode='4953') OR (EventCode='4954') OR (EventCode='4956') OR (EventCode='4957') OR (EventCode='4958'))"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function NetworkPolicyServerCommand {
    $CollectionName = "Event Logs - Network Policy Server"
    $Filter = "(logfile='Security') AND ((EventCode='6272') OR (EventCode='6273') OR (EventCode='6274') OR (EventCode='6275') OR (EventCode='6276') OR (EventCode='6277') OR (EventCode='6278') OR (EventCode='6279') OR (EventCode='6280'))"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function OtherEventsCommand {
    $CollectionName = "Event Logs - Other Events"
    $Filter = "(logfile='Security') AND ((EventCode='1100') OR (EventCode='1102') OR (EventCode='1104') OR (EventCode='1105') OR (EventCode='1108'))"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function OtherObjectAccessEventsCommand {
    $CollectionName = "Event Logs - Other Object Access Events"
    $Filter = "(logfile='Security') AND ((EventCode='4671') OR (EventCode='4691') OR (EventCode='5148') OR (EventCode='5149') OR (EventCode='4698') OR (EventCode='4699') OR (EventCode='4700') OR (EventCode='4701') OR (EventCode='4702') OR (EventCode='5888') OR (EventCode='5889') OR (EventCode='5890'))"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function OtherPolicyChangeEventsCommand {
    $CollectionName = "Event Logs - Other Policy Change Events"
    $Filter = "(logfile='Security') AND ((EventCode='4714') OR (EventCode='4819') OR (EventCode='4826') OR (EventCode='4909') OR (EventCode='4910') OR (EventCode='5063') OR (EventCode='5064') OR (EventCode='5065') OR (EventCode='5066') OR (EventCode='5067') OR (EventCode='5068') OR (EventCode='5069') OR (EventCode='5070') OR (EventCode='5447') OR (EventCode='6144') OR (EventCode='6145'))"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function OtherSystemEventsCommand {
    $CollectionName = "Event Logs - Other System Events"
    $Filter = "(logfile='Security') AND ((EventCode='5024') OR (EventCode='5025') OR (EventCode='5027') OR (EventCode='5028') OR (EventCode='5029') OR (EventCode='5030') OR (EventCode='5032') OR (EventCode='5033') OR (EventCode='5034') OR (EventCode='5035') OR (EventCode='5037') OR (EventCode='5058') OR (EventCode='5059') OR (EventCode='6400') OR (EventCode='6401') OR (EventCode='6402') OR (EventCode='6403') OR (EventCode='6404') OR (EventCode='6405') OR (EventCode='6406') OR (EventCode='6407') OR (EventCode='6408') OR (EventCode='6409'))"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function PNPActivityCommand {
    $CollectionName = "Event Logs - PNP Activity"
    $Filter = "(logfile='Security') AND ((EventCode='6416') OR (EventCode='6419') OR (EventCode='6420') OR (EventCode='6421') OR (EventCode='6422') OR (EventCode='6423') OR (EventCode='6424'))"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function ProcessCreationTerminationCommand {
    $CollectionName = "Event Logs - Process Creation and Termination"
    $Filter = "(logfile='Security') AND ((EventCode='4688') OR (EventCode='4696') OR (EventCode='4689'))"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function RegistryCommand {
    $CollectionName = "Event Logs - Registry"
    $Filter = "(logfile='Security') AND ((EventCode='4663') OR (EventCode='4656') OR (EventCode='4658') OR (EventCode='4660') OR (EventCode='4657') OR (EventCode='5039') OR (EventCode='4670'))"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function RemoveableStorageCommand {
    $CollectionName = "Event Logs - Removeable Storage"
    $Filter = "(logfile='Security') AND ((EventCode='4656') OR (EventCode='4658') OR (EventCode='4663'))"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function RPCEventsCommand {
    $CollectionName = "Event Logs - RPC Events"
    $Filter = "(logfile='Security') AND (EventCode='5712')"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function SAMCommand {
    $CollectionName = "Event Logs - SAM"
    $Filter = "(logfile='Security') AND (EventCode='4661')"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function SecurityGroupManagementCommand {
    $CollectionName = "Event Logs - Security Event Logs Group Management"
    $Filter = "(logfile='Security') AND ((EventCode='4731') OR (EventCode='4732') OR (EventCode='4733') OR (EventCode='4734') OR (EventCode='4735') OR (EventCode='4764') OR (EventCode='4799') OR (EventCode='4727') OR (EventCode='4737') OR (EventCode='4728') OR (EventCode='4729') OR (EventCode='4730') OR (EventCode='4754') OR (EventCode='4755') OR (EventCode='4756') OR (EventCode='4757') OR (EventCode='4758'))"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function SecurityStateChangeCommand {
    $CollectionName = "Event Logs - Security State Change"
    $Filter = "(logfile='Security') AND ((EventCode='4608') OR (EventCode='4609') OR (EventCode='4616') OR (EventCode='4621'))"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function SecuritySystemExtensionCommand {
    $CollectionName = "Event Logs - Security System Extension"
    $Filter = "(logfile='Security') AND ((EventCode='4610') OR (EventCode='4611') OR (EventCode='4614') OR (EventCode='4622') OR (EventCode='4697'))"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function SensitiveandNonSensitivePrivilegeUseCommand {
    $CollectionName = "Event Logs - Sensitive and Non-Sensitive Privilege Use"
    $Filter = "(logfile='Security') AND ((EventCode='4673') OR (EventCode='4674') OR (EventCode='4985'))"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function SpecialLogonCommand {
    $CollectionName = "Event Logs - Special Logon"
    $Filter = "(logfile='Security') AND ((EventCode='4964') OR (EventCode='4672'))"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function SystemIntegrityCommand {
    $CollectionName = "Event Logs - System Integrity"
    $Filter = "(logfile='Security') AND ((EventCode='4612') OR (EventCode='4615') OR (EventCode='4616') OR (EventCode='5038') OR (EventCode='5056') OR (EventCode='5062') OR (EventCode='5057') OR (EventCode='5060') OR (EventCode='5061') OR (EventCode='6281') OR (EventCode='6410'))"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}
function UserDeviceClaimsCommand {
    $CollectionName = "Event Logs - User and Device Claims"
    $Filter = "(logfile='Security') AND (EventCode='4626')"
    EventLogQuery -CollectionName $CollectionName -Filter $Filter
}

##############################################################################################################################################################
##############################################################################################################################################################
##
## Section 1 Active Directory Tab
##
##############################################################################################################################################################
##############################################################################################################################################################

# Varables
$ActiveDirectoryRightPosition     = 5
$ActiveDirectoryDownPositionStart = 10
$ActiveDirectoryDownPosition      = 10
$ActiveDirectoryDownPositionShift = 22
$ActiveDirectoryBoxWidth          = 410
$ActiveDirectoryBoxHeight         = 22


$Section1ActiveDirectoryTab          = New-Object System.Windows.Forms.TabPage
$Section1ActiveDirectoryTab.Location = $System_Drawing_Point
$Section1ActiveDirectoryTab.Text     = "Active Directory"
$Section1ActiveDirectoryTab.Location = New-Object System.Drawing.Size($ActiveDirectoryRightPosition,$ActiveDirectoryDownPosition) 
$Section1ActiveDirectoryTab.Size     = New-Object System.Drawing.Size($ActiveDirectoryBoxWidth,$ActiveDirectoryBoxHeight) 
$Section1ActiveDirectoryTab.UseVisualStyleBackColor = $True
$Section1CollectionsTabControl.Controls.Add($Section1ActiveDirectoryTab)

# Shift the fields
$ActiveDirectoryDownPosition += $ActiveDirectoryDownPositionShift

#------------------------
# Active Directory Label
#------------------------
$ActiveDirectoryTabLabel1           = New-Object System.Windows.Forms.Label
$ActiveDirectoryTabLabel1.Location  = New-Object System.Drawing.Point(($ActiveDirectoryRightPosition),$ActiveDirectoryDownPositionStart) 
$ActiveDirectoryTabLabel1.Size      = New-Object System.Drawing.Size($ActiveDirectoryBoxWidth,$ActiveDirectoryBoxHeight) 
$ActiveDirectoryTabLabel1.Text      = "These queries are to be ran against on a Domain Controller."
$ActiveDirectoryTabLabel1.Font      = New-Object System.Drawing.Font("$Font",13,1,2,1)
$ActiveDirectoryTabLabel1.ForeColor = "Blue"
$Section1ActiveDirectoryTab.Controls.Add($ActiveDirectoryTabLabel1)

# Shift the fields
$ActiveDirectoryDownPosition += $ActiveDirectoryDownPositionShift - 25

#============================================================================================================================================================
#============================================================================================================================================================
# Active Directory Selection Checkedlistbox 
#============================================================================================================================================================
#============================================================================================================================================================
$ActiveDirectorySelectionCheckedlistbox          = New-Object -TypeName System.Windows.Forms.CheckedListBox
$ActiveDirectorySelectionCheckedlistbox.Name     = "Active Directory Selection Checklistbox"
$ActiveDirectorySelectionCheckedlistbox.Location  = New-Object System.Drawing.Point($ActiveDirectoryRightPosition,($ActiveDirectoryDownPositionStart + 25)) 
$ActiveDirectorySelectionCheckedlistbox.Size     = New-Object System.Drawing.Size(425,450)
$ActiveDirectorySelectionCheckedlistbox.ScrollAlwaysVisible = $true

$ActiveDirectorySelectionCheckedlistbox.Items.Add('Active Directory - Accounts *')
$ActiveDirectorySelectionCheckedlistbox.Items.Add('Active Directory - Account Details and User Information')
$ActiveDirectorySelectionCheckedlistbox.Items.Add('Active Directory - Account Logon and Passowrd Policy')
$ActiveDirectorySelectionCheckedlistbox.Items.Add('Active Directory - Account Contact Information')
$ActiveDirectorySelectionCheckedlistbox.Items.Add('Active Directory - Account Email Addresses')
$ActiveDirectorySelectionCheckedlistbox.Items.Add('Active Directory - Account Phone Numbers')
$ActiveDirectorySelectionCheckedlistbox.Items.Add('Active Directory - Computers')
$ActiveDirectorySelectionCheckedlistbox.Items.Add('Active Directory - Default Domain Password Policy')
$ActiveDirectorySelectionCheckedlistbox.Items.Add('Active Directory - Groups *')
$ActiveDirectorySelectionCheckedlistbox.Items.Add('Active Directory - Group Membership By Groups')
$ActiveDirectorySelectionCheckedlistbox.Items.Add('Active Directory - Group Membership by Users')
$ActiveDirectorySelectionCheckedlistbox.Items.Add('Active Directory - Groups Without Account Members')
$ActiveDirectorySelectionCheckedlistbox.Items.Add('DNS All Records (Server 2008)  *')
$ActiveDirectorySelectionCheckedlistbox.Items.Add('DNS Root Hints (Server 2008)  *')
$ActiveDirectorySelectionCheckedlistbox.Items.Add('DNS Zones (Server 2008)  *')
$ActiveDirectorySelectionCheckedlistbox.Items.Add('DNS Statistics (Server 2008)  *')
$ActiveDirectorySelectionCheckedlistbox.Add_Click({
    If ($ActiveDirectorySelectionCheckedlistbox.SelectedItem -match 'Active Directory - Accounts') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsActiveDirectory\Active Directory - Account Details and User Information.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($ActiveDirectorySelectionCheckedlistbox.SelectedItem -match 'Active Directory - Account Details and User Information') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsActiveDirectory\Active Directory - Account Details and User Information.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($ActiveDirectorySelectionCheckedlistbox.SelectedItem -match 'Active Directory - Account Logon and Passowrd Policy') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsActiveDirectory\Active Directory - Account Logon and Passowrd Policy.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($ActiveDirectorySelectionCheckedlistbox.SelectedItem -match 'Active Directory - Account Contact Information') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsActiveDirectory\Active Directory - Account Contact Information.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($ActiveDirectorySelectionCheckedlistbox.SelectedItem -match 'Active Directory - Account Email Addresses') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsActiveDirectory\Active Directory - Account Email Addresses.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($ActiveDirectorySelectionCheckedlistbox.SelectedItem -match 'Active Directory - Account Phone Numbers') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsActiveDirectory\Active Directory - Account Phone Numbers.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($ActiveDirectorySelectionCheckedlistbox.SelectedItem -match 'Active Directory - Computers') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsActiveDirectory\Active Directory - Computers.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($ActiveDirectorySelectionCheckedlistbox.SelectedItem -match 'Active Directory - Default Domain Password Policy') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsActiveDirectory\Active Directory - Default Domain Password Policy.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($ActiveDirectorySelectionCheckedlistbox.SelectedItem -match 'Active Directory - Groups') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsActiveDirectory\Active Directory - Groups.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($ActiveDirectorySelectionCheckedlistbox.SelectedItem -match 'Active Directory - Group Membership By Groups') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsActiveDirectory\Active Directory - Group Membership By Groups.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($ActiveDirectorySelectionCheckedlistbox.SelectedItem -match 'Active Directory - Group Membership by Users') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsActiveDirectory\Active Directory - Group Membership by Users.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($ActiveDirectorySelectionCheckedlistbox.SelectedItem -match 'Active Directory - Groups Without Account Members') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsActiveDirectory\Active Directory - Groups Without Account Members.txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($ActiveDirectorySelectionCheckedlistbox.SelectedItem -match 'DNS All Records (Server 2008)') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsActiveDirectory\DNS All Records (Server 2008).txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($ActiveDirectorySelectionCheckedlistbox.SelectedItem -match 'DNS Root Hints (Server 2008)') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsActiveDirectory\DNS Root Hints (Server 2008).txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($ActiveDirectorySelectionCheckedlistbox.SelectedItem -match 'DNS Zones (Server 2008)') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsActiveDirectory\DNS Zones (Server 2008).txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
    If ($ActiveDirectorySelectionCheckedlistbox.SelectedItem -match 'DNS Statistics (Server 2008)') {
        $MainListBox.Items.Clear()
        $CommandFile = Get-Content -Path "$CommandsActiveDirectory\DNS Statistics (Server 2008).txt" -Force -ErrorAction SilentlyContinue | foreach {$_ + "`r`n"}
        foreach ($line in $CommandFile) {$MainListBox.Items.Add("$line")}
    }
})
$Section1ActiveDirectoryTab.Controls.Add($ActiveDirectorySelectionCheckedlistbox)

#============================================================================================================================================================
# Active Directory - Accounts
#============================================================================================================================================================
function ActiveDirectoryAccountsCommand {
    $CollectionName = "Active Directory - Accounts"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                                            
                Get-WmiObject -Credential $Credential -Class Win32_UserAccount -Filter "LocalAccount='False'" -ComputerName $TargetComputer `
                | Select-Object -Property PSComputerName, Name, Disabled, AccountType, Lockout, PasswordChangeable, PasswordRequired, SID, SIDType, LocalAccount, Domain, Caption, Description `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation -Force

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                                            
                Get-WmiObject -Class Win32_UserAccount -Filter "LocalAccount='False'" -ComputerName $TargetComputer `
                | Select-Object -Property PSComputerName, Name, Disabled, AccountType, Lockout, PasswordChangeable, PasswordRequired, SID, SIDType, LocalAccount, Domain, Caption, Description `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation -Force

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Active Directory - Account Details and User Information
#============================================================================================================================================================
function ActiveDirectoryAccountDetailsAndUserInfoCommand {
    $CollectionName = "Active Directory - Account Details and User Information"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                                            
                Invoke-Command -Credential $Credential -ComputerName $TargetComputer -ScriptBlock {
                    Get-ADUser -Filter * -Properties * `
                    | Select-Object Name, CanonicalName, SID, Enabled, LockedOut, AccountLockoutTime, Created, LogonWorkStations, LastLogonDate, LastBadPasswordAttempt, PasswordLastSet, PasswordExpired, PasswordNeverExpires, PasswordNotRequired, CannotChangePassword, MemberOf, SmartCardLogonRequired, ScriptPath, HomeDrive, Title, Organization, Office, POBox, StreetAddress, City, State, PostalCode, Fax, OfficePhone, HomePhone, MobilePhone, EmailAddress
                } | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation -Force

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                                            
                Invoke-Command -ComputerName $TargetComputer -ScriptBlock {
                    Get-ADUser -Filter * -Properties * `
                    | Select-Object Name, CanonicalName, SID, Enabled, LockedOut, AccountLockoutTime, Created, LogonWorkStations, LastLogonDate, LastBadPasswordAttempt, PasswordLastSet, PasswordExpired, PasswordNeverExpires, PasswordNotRequired, CannotChangePassword, MemberOf, SmartCardLogonRequired, ScriptPath, HomeDrive, Title, Organization, Office, POBox, StreetAddress, City, State, PostalCode, Fax, OfficePhone, HomePhone, MobilePhone, EmailAddress
                } | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation -Force

                if ((Get-Content "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv") -eq $null) {
                    Remove-Item "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"
                
                    Invoke-Command -ComputerName $TargetComputer -ScriptBlock {
                        net users /domain
                    } | Export-CSV "$CollectedDataTimeStampDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation -Force
                }

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Active Directory - Account Logon and Passowrd Policy
#============================================================================================================================================================
function ActiveDirectoryAccountLogonAndPassowrdPolicyCommand {
    $CollectionName = "Active Directory - Account Logon and Passowrd Policy"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                                            
                Invoke-Command -Credential $Credential -ComputerName $TargetComputer -ScriptBlock {
                    Get-ADUser -Filter * -Properties * `
                    | Select-Object Name, Enabled, LockedOut, AccountLockoutTime, LogonWorkStations, LastLogonDate, LastBadPasswordAttempt, PasswordLastSet, PasswordExpired, PasswordNeverExpires, PasswordNotRequired, CannotChangePassword
                } | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation -Force

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                                            
                Invoke-Command -ComputerName $TargetComputer -ScriptBlock {
                    Get-ADUser -Filter * -Properties * `
                    | Select-Object Name, Enabled, LockedOut, AccountLockoutTime, LogonWorkStations, LastLogonDate, LastBadPasswordAttempt, PasswordLastSet, PasswordExpired, PasswordNeverExpires, PasswordNotRequired, CannotChangePassword
                } | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation -Force

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Active Directory - Account Contact Information
#============================================================================================================================================================
function ActiveDirectoryAccountContactInfoCommand {
    $CollectionName = "Active Directory - Account Contact Information"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                                            
                Invoke-Command -Credential $Credential -ComputerName $TargetComputer -ScriptBlock {
                    Get-ADUser -Filter * -Properties * `
                    | Select-Object Name, Title, Organization, Office, POBox, StreetAddress, City, State, PostalCode, Fax, OfficePhone, HomePhone, MobilePhone, EmailAddress
                } | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation -Force

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                                            
                Invoke-Command -ComputerName $TargetComputer -ScriptBlock {
                    Get-ADUser -Filter * -Properties * `
                    | Select-Object Name, Title, Organization, Office, POBox, StreetAddress, City, State, PostalCode, Fax, OfficePhone, HomePhone, MobilePhone, EmailAddress
                } | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation -Force
                    
            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Active Directory - Account Email Addresses
#============================================================================================================================================================
function ActiveDirectoryAccountEmailAddressesCommand {
    $CollectionName = "Active Directory - Account Email Addresses"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                                            
                Invoke-Command -Credential $Credential -ComputerName $TargetComputer -ScriptBlock {
                    Get-ADUser -Filter * -Properties * `
                    | Where-Object {$_.EmailAddress -ne $null} `
                    | Select-Object Name, EmailAddress
                } | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation -Force

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                                            
                Invoke-Command -ComputerName $TargetComputer -ScriptBlock {
                    Get-ADUser -Filter * -Properties * `
                    | Where-Object {$_.EmailAddress -ne $null} `
                    | Select-Object Name, EmailAddress
                } | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation -Force

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Active Directory - Account Phone Numbers
#============================================================================================================================================================
function ActiveDirectoryAccountPhoneNumbersCommand {
    $CollectionName = "Active Directory - Account Phone Numbers"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                                            
                Invoke-Command -Credential $Credential -ComputerName $TargetComputer -ScriptBlock {
                    Get-ADUser -Filter * -Properties * `
                    | Where-Object {($_.OfficePhone -ne $null) -or ($_.HomePhone -ne $null) -or ($_.MobilePhone -ne $null)} `
                    | Select-Object Name, OfficePhone, HomePhone, MobilePhone
                } | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation -Force

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                                            
                Invoke-Command -ComputerName $TargetComputer -ScriptBlock {
                    Get-ADUser -Filter * -Properties * `
                    | Where-Object {($_.OfficePhone -ne $null) -or ($_.HomePhone -ne $null) -or ($_.MobilePhone -ne $null)} `
                    | Select-Object Name, OfficePhone, HomePhone, MobilePhone
                } | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation -Force

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Active Directory - Computers Details and OS Info
#============================================================================================================================================================
function ActiveDirectoryComputersCommand {
    $CollectionName = "Active Directory - Computers"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                                            
                Invoke-Command -Credential $Credential -ComputerName $TargetComputer -ScriptBlock {
                    Get-ADComputer -Filter * -Properties *  `
                    | Select-Object -Property Enabled, Name, OperatingSystem, OperatingSystemServicePack, OperatingSystemHotfix, OperatingSystemVersion, IPv4Address, IPv6Address, LastLogonDate, Created, ObjectClass, SID, SIDHistory, DistinguishedName, DNSHostName, SamAccountName, CannotChangePassword
                } | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation -Force

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                                            
                Invoke-Command -ComputerName $TargetComputer -ScriptBlock {
                    Get-ADComputer -Filter * -Properties *  `
                    | Select-Object -Property Enabled, Name, OperatingSystem, OperatingSystemServicePack, OperatingSystemHotfix, OperatingSystemVersion, IPv4Address, IPv6Address, LastLogonDate, Created, ObjectClass, SID, SIDHistory, DistinguishedName, DNSHostName, SamAccountName, CannotChangePassword
                } | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation -Force

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Active Directory - Default Domain Password Policy
#============================================================================================================================================================
function ActiveDirectoryDefaultDomainPasswordPolicyCommand {
    $CollectionName = "Active Directory - Default Domain Password Policy"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                                            
                Invoke-Command -Credential $Credential -ComputerName $TargetComputer -ScriptBlock {
                    Get-ADDefaultDomainPasswordPolicy
                } | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation -Force

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                                            
                Invoke-Command -ComputerName $TargetComputer -ScriptBlock {
                    Get-ADDefaultDomainPasswordPolicy
                } | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation -Force

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Active Directory - Groups 
#============================================================================================================================================================
function ActiveDirectoryGroupsCommand {
    $CollectionName = "Active Directory - Groups"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                            
                Get-WmiObject -Credential $Credential -Class Win32_Group -Filter "LocalAccount='False'" -ComputerName $TargetComputer `
                | Select-Object PSComputerName, Name, LocalAccount, Domain, SID, SIDType, Caption, Description `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                
                Get-WmiObject -Class Win32_Group -filter "LocalAccount='False'" -ComputerName $TargetComputer `
                | Select-Object PSComputerName, Name, LocalAccount, Domain, SID, SIDType, Caption, Description `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

<#
#============================================================================================================================================================
# Active Directory - Groups [PS]
#============================================================================================================================================================
function ActiveDirectoryGroupsCommand {
    $CollectionName = "Active Directory - Groups [PS]"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                                            
                Invoke-Command -Credential $Credential -ComputerName $TargetComputer -ScriptBlock {
                    Get-ADGroup -Filter * `
                    | Select-Object -Property Name, SID, GroupCategory, GroupScope, DistinguishedName
                } | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation -Force

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                                      
                Invoke-Command -ComputerName $TargetComputer -ScriptBlock {
                    Get-ADGroup -Filter * `
                    | Select-Object -Property Name, SID, GroupCategory, GroupScope, DistinguishedName
                } | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation -Force

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}
#>

#============================================================================================================================================================
# Active Directory - Group Membership by Groups
#============================================================================================================================================================
function ActiveDirectoryGroupMembershipByGroupsCommand {
    $CollectionName = "Active Directory - Group Membership by Groups"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                                            
                Invoke-Command -Credential $Credential -ComputerName $TargetComputer -ScriptBlock {
                    #Gets a list of all the groups
                    $ADGroupList = Get-ADGroup -Filter * | Select-Object -ExpandProperty Name
                    foreach ($Group in $ADGroupList) {
                        $GroupMemberships = Get-ADGroupMember $Group
                        $GroupMemberships | Add-Member -MemberType NoteProperty -Name GroupName -Value $Group -Force
                        $GroupMemberships | select * -First 1
                        $GroupMemberships | Select-Object -Property PSComputerName, GroupName, SamAccountName, SID, GroupCategory, GroupScope, DistinguishedName 
                    } 
                } | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation -Force

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                                            
                Invoke-Command -ComputerName $TargetComputer -ScriptBlock {
                    #Gets a list of all the groups
                    $ADGroupList = Get-ADGroup -Filter * | Select-Object -ExpandProperty Name
                    foreach ($Group in $ADGroupList) {
                        $GroupMemberships = Get-ADGroupMember $Group
                        $GroupMemberships | Add-Member -MemberType NoteProperty -Name GroupName -Value $Group -Force
                        $GroupMemberships | select * -First 1
                        $GroupMemberships | Select-Object -Property PSComputerName, GroupName, SamAccountName, SID, GroupCategory, GroupScope, DistinguishedName 
                    } 
                } | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation -Force

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Active Directory - Group Membership by Users
#============================================================================================================================================================
function ActiveDirectoryGroupMembershipByUsersCommand {
    $CollectionName = "Active Directory - Group Membership by Users"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                                            
                Invoke-Command -Credential $Credential -ComputerName $TargetComputer -ScriptBlock {
                    ###get-aduser dan -property Memberof | Select -ExpandProperty memberOf
                    $ADUserList = Get-ADUser -filter * | Select-Object -ExpandProperty SamAccountName
                    foreach ($SamAccountName in $ADUserList) {                        
                        $GroupMemberships = Get-ADPrincipalGroupMembership -Identity $SamAccountName
                        $GroupMemberships | Add-Member -MemberType NoteProperty -Name SamAccountName -Value $SamAccountName -Force
                        $GroupMemberships | Select-Object -Property SamAccountName, @{Name="Group Name";Expression={$_.Name}}, SID, GroupCategory, GroupScope, DistinguishedName
                    } 
                } | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation -Force

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                                            
                Invoke-Command -ComputerName $TargetComputer -ScriptBlock {                    
                    ###get-aduser dan -property Memberof | Select -ExpandProperty memberOf
                    $ADUserList = Get-ADUser -filter * | Select-Object -ExpandProperty SamAccountName
                    foreach ($SamAccountName in $ADUserList) {                        
                        $GroupMemberships = Get-ADPrincipalGroupMembership -Identity $SamAccountName
                        $GroupMemberships | Add-Member -MemberType NoteProperty -Name SamAccountName -Value $SamAccountName -Force
                        $GroupMemberships | Select-Object -Property SamAccountName, @{Name="Group Name";Expression={$_.Name}}, SID, GroupCategory, GroupScope, DistinguishedName
                    } 
                } | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation -Force

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Active Directory - Groups Without Account Members
#============================================================================================================================================================
function ActiveDirectoryGroupsWithoutAccountMembersCommand {
    $CollectionName = "Active Directory - Groups Without Account Members"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                                            
                Invoke-Command -Credential $Credential -ComputerName $TargetComputer -ScriptBlock {
                    Get-ADGroup -filter * `
                    | Where-Object {-Not ($_ | Get-ADGroupMember)} 
                } | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation -Force

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                                            
                Invoke-Command -ComputerName $TargetComputer -ScriptBlock {
                    Get-ADGroup -filter * `
                    | Where-Object {-Not ($_ | Get-ADGroupMember)} 
                } | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation -Force

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Domain - DNS All Records (Server 2008)
#============================================================================================================================================================
function DomainDNSAllRecordsServer2008Command {
    $CollectionName = "DNS All Records (Server 2008)"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                                            
                Get-WmiObject -Credential $Credential -ComputerName $TargetComputer -Namespace root\MicrosoftDNS -class microsoftdns_resourcerecord `
                | Select-Object PSComputerName, __Class, ContainerName, DomainName, RecordData, OwnerName `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                                            
                Get-WmiObject -ComputerName $TargetComputer -Namespace root\MicrosoftDNS -class microsoftdns_resourcerecord `
                | Select-Object PSComputerName, __Class, ContainerName, DomainName, RecordData, OwnerName `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Domain - DNS Root Hints (Server 2008)
#============================================================================================================================================================
function DomainDNSRootHintsServer2008Command {
    $CollectionName = "DNS Root Hints (Server 2008)"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                                            
                Get-WmiObject -Credential $Credential -Namespace root\MicrosoftDNS -class microsoftdns_resourcerecord `
                | Where-Object {$_.domainname -eq "..roothints"} `
                | Select-Object PSComputerName, * `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                                            
                Get-WmiObject -Namespace root\MicrosoftDNS -class microsoftdns_resourcerecord `
                | Where-Object {$_.domainname -eq "..roothints"} `
                | Select-Object PSComputerName, * `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation


            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Domain - DNS Zones (Server 2008)
#============================================================================================================================================================
function DomainDNSZonesServer2008Command {
    $CollectionName = "DNS Zones (Server 2008)"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                                            
                Get-WmiObject -Credential $Credential -Namespace "root\MicrosoftDNS" -Class MicrosoftDNS_Zone `
                | Select-Object PSComputerName, Name `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                                            
                Get-WmiObject -Namespace "root\MicrosoftDNS" -Class MicrosoftDNS_Zone `
                | Select-Object PSComputerName, Name `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

#============================================================================================================================================================
# Domain - DNS Statistics (Server 2008)
#============================================================================================================================================================
function DomainDNSStatisticsServer2008Command {
    $CollectionName = "DNS Statistics (Server 2008)"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
                Invoke-Expression -Command $ThreadPriority
                                            
                Get-WmiObject -Credential $Credential -Namespace root\MicrosoftDNS -Class MicrosoftDNS_Statistic `
                | Select-Object PSComputerName, Name, Value `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
                Invoke-Expression -Command $ThreadPriority
                                            
                Get-WmiObject -Namespace root\MicrosoftDNS -Class MicrosoftDNS_Statistic `
                | Select-Object PSComputerName, Name, Value `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}

##############################################################################################################################################################
##
## File Search
##
##############################################################################################################################################################

# Varables
$FileSearchRightPosition     = 3
$FileSearchDownPosition      = -10
$FileSearchDownPositionShift = 25
$FileSearchLabelWidth        = 450
$FileSearchLabelHeight       = 22
$FileSearchButtonWidth       = 110
$FileSearchButtonHeight      = 22


$Section1FileSearchTab          = New-Object System.Windows.Forms.TabPage
$Section1FileSearchTab.Location = $System_Drawing_Point
$Section1FileSearchTab.Text     = "File Search"
$Section1FileSearchTab.Location = New-Object System.Drawing.Size($FileSearchRightPosition,$FileSearchDownPosition) 
$Section1FileSearchTab.Size     = New-Object System.Drawing.Size($FileSearchLabelWidth,$FileSearchLabelHeight) 
$Section1FileSearchTab.UseVisualStyleBackColor = $True
$Section1CollectionsTabControl.Controls.Add($Section1FileSearchTab)

# Shift the fields
$FileSearchDownPosition += $FileSearchDownPositionShift

#============================================================================================================================================================
# File Search - Directory Listing
#============================================================================================================================================================

#---------------------------------------------------------
# File Search - Directory Listing CheckBox Command
#---------------------------------------------------------

$FileSearchDirectoryListingCheckbox = New-Object System.Windows.Forms.CheckBox
$FileSearchDirectoryListingCheckbox.Name = "Directory Listing"

function FileSearchDirectoryListingCommand {
    $CollectionName = "Directory Listing"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        $ListDirectory = $FileSearchDirectoryListingTextbox.Text

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                #param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$DirectoriesToSearch,$FilesToSearch,$Credential)
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$ListDirectory,$Credential)
                Invoke-Expression -Command $ThreadPriority
                                   
                $DirectoryListing = Invoke-Command -ComputerName $TargetComputer -Credential $Credential -ScriptBlock {
                    param($ListDirectory)
                    Get-ChildItem -Force $ListDirectory -ErrorAction SilentlyContinue                    
                } -ArgumentList @($ListDirectory)                       

                # Add the PSComputerName Property and Host name; then save the file
                $DirectoryListing | Add-Member -MemberType NoteProperty -Name PSComputerName -Value $TargetComputer
                $DirectoryListing | Select-Object -Property PSComputerName, FullName, Name, Extension, Attributes, CreationTime, LastWriteTime, LastAccessTime `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            #} -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$DirectoriesToSearch,$FilesToSearch,$Credential)
            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$ListDirectory,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$ListDirectory)
                Invoke-Expression -Command $ThreadPriority
                   
                $DirectoryListing = Invoke-Command -ComputerName $TargetComputer -ScriptBlock {
                    param($ListDirectory)
                    Get-ChildItem -Force $ListDirectory -ErrorAction SilentlyContinue                    
                } -ArgumentList @($ListDirectory)                       

                # Add the PSComputerName Property and Host name; then save the file
                $DirectoryListing | Add-Member -MemberType NoteProperty -Name PSComputerName -Value $TargetComputer
                $DirectoryListing | Select-Object -Property PSComputerName, FullName, Name, Extension, Attributes, CreationTime, LastWriteTime, LastAccessTime `
                | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation      

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$ListDirectory)
        }   
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
    Remove-DuplicateCsvHeaders
}

$FileSearchDirectoryListingCheckbox.Text     = "$($FileSearchDirectoryListingCheckbox.Name)"
$FileSearchDirectoryListingCheckbox.Location = New-Object System.Drawing.Size(($FileSearchRightPosition),($FileSearchDownPosition)) 
$FileSearchDirectoryListingCheckbox.Size     = New-Object System.Drawing.Size($FileSearchLabelWidth,$FileSearchLabelHeight) 
$Section1FileSearchTab.Controls.Add($FileSearchDirectoryListingCheckbox)


# Shift the fields
$FileSearchDownPosition += $FileSearchDownPositionShift


#----------------------------------------------
# File Search - Directory Listing Label
#----------------------------------------------
$FileSearchDirectoryListingLabel           = New-Object System.Windows.Forms.Label
$FileSearchDirectoryListingLabel.Location  = New-Object System.Drawing.Point($FileSearchRightPosition,$FileSearchDownPosition) 
$FileSearchDirectoryListingLabel.Size      = New-Object System.Drawing.Size($FileSearchLabelWidth,$FileSearchLabelHeight) 
$FileSearchDirectoryListingLabel.Text      = "Collection time is dependant on the directory's contents."
#$FileSearchDirectoryListingLabel.Font      = New-Object System.Drawing.Font("$Font",12,1,3,1)
$FileSearchDirectoryListingLabel.ForeColor = "Blue"
$Section1FileSearchTab.Controls.Add($FileSearchDirectoryListingLabel)


# Shift the fields
$FileSearchDownPosition += $FileSearchDownPositionShift


#----------------------------------------------------
# File Search - Directory Listing Directory Textbox
#----------------------------------------------------
$FileSearchDirectoryListingTextbox               = New-Object System.Windows.Forms.TextBox
$FileSearchDirectoryListingTextbox.Location      = New-Object System.Drawing.Size($FileSearchRightPosition,($FileSearchDownPosition)) 
$FileSearchDirectoryListingTextbox.Size          = New-Object System.Drawing.Size(430,22)
$FileSearchDirectoryListingTextbox.MultiLine     = $False
#$FileSearchDirectoryListingTextbox.ScrollBars    = "Vertical"
$FileSearchDirectoryListingTextbox.WordWrap      = True
$FileSearchDirectoryListingTextbox.AcceptsTab    = false # Allows you to enter in tabs into the textbox
$FileSearchDirectoryListingTextbox.AcceptsReturn = false # Allows you to enter in tabs into the textbox
$FileSearchDirectoryListingTextbox.Text          = "C:\Windows\System32"
#$FileSearchDirectoryListingTextbox.Add_KeyDown({          })
$Section1FileSearchTab.Controls.Add($FileSearchDirectoryListingTextbox)

# Shift the fields
$FileSearchDownPosition += $FileSearchDownPositionShift + $FileSearchDirectoryListingTextbox.Size.Height

#============================================================================================================================================================
# File Search - File Search
#============================================================================================================================================================

#---------------------------------------------------
# File Search - File Search Command CheckBox
#---------------------------------------------------

$FileSearchFileSearchCheckbox = New-Object System.Windows.Forms.CheckBox
$FileSearchFileSearchCheckbox.Name = "File Search"

function FileSearchFileSearchCommand {
    $CollectionName = "File Search"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        $DirectoriesToSearch = $FileSearchFileSearchDirectoryTextbox.Text -split "`r`n"
        $FilesToSearch       = $FileSearchFileSearchFileTextbox.Text -split "`r`n"
        $MaximumDepth        = $FileSearchFileSearchMaxDepthTextbox.text

        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$DirectoriesToSearch,$FilesToSearch,$MaximumDepth,$Credential)
                Invoke-Expression -Command $ThreadPriority
                
                ([System.Diagnostics.Process]::GetCurrentProcess()).PriorityClass = 'AboveNormal'
                $FilesFoundList = @()
                                                            
                foreach ($DirectoryPath in $DirectoriesToSearch) {
                    foreach ($Filename in $FilesToSearch) {
                        $FilesFound = Invoke-Command -Credential $Credential -ComputerName $TargetComputer -ScriptBlock {
                            param($DirectoryPath,$Filename,$MaximumDepth)
   
                            function Get-FileHash{
                                param ([string] $Path ) 
                                $HashAlgorithm = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
                                $Hash=[System.BitConverter]::ToString($hashAlgorithm.ComputeHash([System.IO.File]::ReadAllBytes($Path)))
                                $Properties=@{
                                "Algorithm" = "MD5"
                                "Path" = $Path
                                "Hash" = $Hash.Replace("-", "")
                                }
                                $Ret=New-Object –TypeName PSObject –Prop $Properties
                                return $Ret
                            }

                            Function Get-ChildItemRecurse {
                                Param(
                                [String]$Path = $PWD,
                                [String]$Filter = "*",
                                [Byte]$Depth = $MaxDepth
                                )

                                $CurrentDepth++
                                $RecursiveListing = New-Object PSObject
                                Get-ChildItem $Path -Filter $Filter -Force | Foreach { 
                                    $RecursiveListing | Add-Member -MemberType NoteProperty -Name PSComputerName -Value $TargetComputer -Force
                                    #$RecursiveListing | Add-Member -MemberType NoteProperty -Name DirectoryName -Value $_.DirectoryName -Force
                                    $RecursiveListing | Add-Member -MemberType NoteProperty -Name Directory -Value $_.Directory -Force
                                    $RecursiveListing | Add-Member -MemberType NoteProperty -Name Name -Value $_.Name -Force
                                    $RecursiveListing | Add-Member -MemberType NoteProperty -Name BaseName -Value $_.BaseName -Force
                                    $RecursiveListing | Add-Member -MemberType NoteProperty -Name Extension -Value $_.Extension -Force
                                    $RecursiveListing | Add-Member -MemberType NoteProperty -Name Hash -Value $_.Hash -Force
                                    $RecursiveListing | Add-Member -MemberType NoteProperty -Name Algorithm -Value $_.Algorithm -Force
                                    $RecursiveListing | Add-Member -MemberType NoteProperty -Name Attributes -Value $_.Attributes -Force
                                    $RecursiveListing | Add-Member -MemberType NoteProperty -Name CreationTime -Value $_.CreationTime -Force
                                    $RecursiveListing | Add-Member -MemberType NoteProperty -Name LastWriteTime -Value $_.LastWriteTime -Force
                                    $RecursiveListing | Add-Member -MemberType NoteProperty -Name LastAccessTime -Value $_.LastAccessTime -Force
                                    $RecursiveListing | Add-Member -MemberType NoteProperty -Name FullName -Value $_.FullName -Force
                                    $RecursiveListing | Add-Member -MemberType NoteProperty -Name PSIsContainer -Value $_.PSIsContainer -Force
                                    #marco#$RecursiveListing
                                    If ($_.PsIsContainer) {
                                        If ($CurrentDepth -le $Depth) {                
                                            # Callback to this function
                                            Get-ChildItemRecurse -Path $_.FullName -Filter $Filter -Depth $MaxDepth -CurrentDepth $CurrentDepth
                                        }
                                    }
                                }
                            }
                        $MaxDepth = $MaximumDepth
                        $Path = $DirectoryPath
                        Get-ChildItemRecurse -Path $Path -Depth $MaxDepth `
                        | Where-Object { ($_.PSIsContainer -eq $false) -and ($_.Name -match "$Filename") }

                        } -ArgumentList @($DirectoryPath,$Filename,$MaximumDepth)
                        
                        # Hash the file found
                        $FileFoundHash = Get-FileHash ($FilesFound).FullName

                        # Add the PSComputerName Property and Host name; then save the file
                        $FilesFound | Add-Member -MemberType NoteProperty -Name PSComputerName -Value $TargetComputer
                        $FilesFound | Add-Member -MemberType NoteProperty -Name Hash -Value $FileFoundHash.Hash
                        $FilesFound | Add-Member -MemberType NoteProperty -Name Algorithm -Value $FileFoundHash.Algorithm                        
                        $FilesFoundList += $FilesFound | Select-Object -Property PSComputerName, Directory, Name, BaseName, Extension, Hash, Algorithm, Attributes, CreationTime, LastWriteTime, LastAccessTime, FullName
                    }
                }
                $FilesFoundList | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation
                $FilesFoundListAddHeader = Import-Csv "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -Header "PSComputerName","Directory","Name","BaseName","Extension","Hash","Algorithm","Attributes","CreationTime","LastWriteTime","LastAccessTime","FullName"
                Remove-Item -Path "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"
                $FilesFoundListAddHeader | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$DirectoriesToSearch,$FilesToSearch,$MaximumDepth,$Credential)
        }
        else {
            Start-Job -Name "ACME-$CollectionName-$TargetComputer" -ScriptBlock {
                param($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$DirectoriesToSearch,$FilesToSearch,$MaximumDepth)
                Invoke-Expression -Command $ThreadPriority
                
                $FilesFoundList = @()
                                                            
                foreach ($DirectoryPath in $DirectoriesToSearch) {
                    foreach ($Filename in $FilesToSearch) {
                        $FilesFound = Invoke-Command -ComputerName $TargetComputer -ScriptBlock {
                            param($DirectoryPath,$Filename,$MaximumDepth)

                            Function Get-ChildItemRecurse {
                                Param(
                                [String]$Path = $PWD,
                                [String]$Filter = "*",
                                [Byte]$Depth = $MaxDepth
                                )
                                $CurrentDepth++
                                $RecursiveListing = New-Object PSObject
                                Get-ChildItem $Path -Filter $Filter -Force | Foreach { 
                                    $RecursiveListing | Add-Member -MemberType NoteProperty -Name PSComputerName -Value $TargetComputer -Force
                                    #$RecursiveListing | Add-Member -MemberType NoteProperty -Name DirectoryName -Value $_.DirectoryName -Force
                                    $RecursiveListing | Add-Member -MemberType NoteProperty -Name Directory -Value $_.Directory -Force
                                    $RecursiveListing | Add-Member -MemberType NoteProperty -Name Name -Value $_.Name -Force
                                    $RecursiveListing | Add-Member -MemberType NoteProperty -Name BaseName -Value $_.BaseName -Force
                                    $RecursiveListing | Add-Member -MemberType NoteProperty -Name Extension -Value $_.Extension -Force
                                    $RecursiveListing | Add-Member -MemberType NoteProperty -Name Attributes -Value $_.Attributes -Force
                                    $RecursiveListing | Add-Member -MemberType NoteProperty -Name CreationTime -Value $_.CreationTime -Force
                                    $RecursiveListing | Add-Member -MemberType NoteProperty -Name LastWriteTime -Value $_.LastWriteTime -Force
                                    $RecursiveListing | Add-Member -MemberType NoteProperty -Name LastAccessTime -Value $_.LastAccessTime -Force
                                    $RecursiveListing | Add-Member -MemberType NoteProperty -Name FullName -Value $_.FullName -Force
                                    $RecursiveListing | Add-Member -MemberType NoteProperty -Name PSIsContainer -Value $_.PSIsContainer -Force
                                    $RecursiveListing
                                    If ($_.PsIsContainer) {
                                        If ($CurrentDepth -le $Depth) {                
                                            # Callback to this function
                                            Get-ChildItemRecurse -Path $_.FullName -Filter $Filter -Depth $MaxDepth -CurrentDepth $CurrentDepth
                                        }
                                    }
                                }
                            }
                        $MaxDepth = $MaximumDepth
                        $Path = $DirectoryPath
                        
                        Get-ChildItemRecurse -Path $Path -Depth $MaxDepth `
                        | Where-Object { ($_.PSIsContainer -eq $false) -and ($_.Name -match "$Filename") }

                        } -ArgumentList @($DirectoryPath,$Filename,$MaximumDepth)
                        
                        $FilesFoundList += $FilesFound | Select-Object -Property PSComputerName, Directory, Name, BaseName, Extension, Attributes, CreationTime, LastWriteTime, LastAccessTime, FullName
                    }
                }
                $FilesFoundList | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation
                $FilesFoundListAddHeader = Import-Csv "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -Header "PSComputerName","Directory","Name","BaseName","Extension","Attributes","CreationTime","LastWriteTime","LastAccessTime","FullName"
                Remove-Item -Path "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv"
                $FilesFoundListAddHeader | Export-CSV "$IndividualHostResults\$CollectionDirectory\$CollectionName-$TargetComputer.csv" -NoTypeInformation

            } -ArgumentList @($CollectedDataTimeStampDirectory,$IndividualHostResults,$CollectionName,$CollectionDirectory,$TargetComputer,$SleepTime,$DirectoriesToSearch,$FilesToSearch,$MaximumDepth)
        } 
    }
    Monitor-Jobs $CollectionName
    Conduct-PostCommandExecution $CollectionName
    Compile-CsvFiles "$IndividualHostResults\$CollectionDirectory" "$CollectedDataTimeStampDirectory\$CollectionName.csv"
    Remove-DuplicateCsvHeaders
}

$FileSearchFileSearchCheckbox.Text     = "$($FileSearchFileSearchCheckbox.Name)"
$FileSearchFileSearchCheckbox.Location = New-Object System.Drawing.Size(($FileSearchRightPosition),($FileSearchDownPosition)) 
$FileSearchFileSearchCheckbox.Size     = New-Object System.Drawing.Size((230),$FileSearchLabelHeight) 
$Section1FileSearchTab.Controls.Add($FileSearchFileSearchCheckbox)


#--------------------------------------------------
# File Search - File Search Max Depth Label
#--------------------------------------------------
$FileSearchFileSearchMaxDepthLabel            = New-Object System.Windows.Forms.Label
$FileSearchFileSearchMaxDepthLabel.Location   = New-Object System.Drawing.Point(($FileSearchFileSearchCheckbox.Size.Width + 52),($FileSearchDownPosition + 3)) 
$FileSearchFileSearchMaxDepthLabel.Size       = New-Object System.Drawing.Size(100,$FileSearchLabelHeight) 
$FileSearchFileSearchMaxDepthLabel.Text       = "Recursive Depth"
#$FileSearchFileSearchMaxDepthLabel.Font      = New-Object System.Drawing.Font("$Font",12,1,3,1)
#$FileSearchFileSearchMaxDepthLabel.ForeColor  = "Blue"
$Section1FileSearchTab.Controls.Add($FileSearchFileSearchMaxDepthLabel)


#----------------------------------------------------
# File Search - File Search Max Depth Textbox
#----------------------------------------------------
$FileSearchFileSearchMaxDepthTextbox                = New-Object System.Windows.Forms.TextBox
$FileSearchFileSearchMaxDepthTextbox.Location       = New-Object System.Drawing.Size(($FileSearchFileSearchMaxDepthLabel.Location.X + $FileSearchFileSearchMaxDepthLabel.Size.Width),($FileSearchDownPosition)) 
$FileSearchFileSearchMaxDepthTextbox.Size           = New-Object System.Drawing.Size(50,20)
$FileSearchFileSearchMaxDepthTextbox.MultiLine      = $false
#$FileSearchFileSearchMaxDepthTextbox.ScrollBars    = "Vertical"
$FileSearchFileSearchMaxDepthTextbox.WordWrap       = false
#$FileSearchFileSearchMaxDepthTextbox.AcceptsTab    = false
#$FileSearchFileSearchMaxDepthTextbox.AcceptsReturn = false
$FileSearchFileSearchMaxDepthTextbox.Font           = New-Object System.Drawing.Font("$Font",9,0,3,1)
$FileSearchFileSearchMaxDepthTextbox.Text           = 0
#$FileSearchFileSearchMaxDepthTextbox.Add_KeyDown({          })
$Section1FileSearchTab.Controls.Add($FileSearchFileSearchMaxDepthTextbox)

# Shift the fields
$FileSearchDownPosition += $FileSearchDownPositionShift

#----------------------------------------
# File Search - File Search Label
#----------------------------------------
$FileSearchFileSearchLabel           = New-Object System.Windows.Forms.Label
$FileSearchFileSearchLabel.Location  = New-Object System.Drawing.Point($FileSearchRightPosition,$FileSearchDownPosition) 
$FileSearchFileSearchLabel.Size      = New-Object System.Drawing.Size($FileSearchLabelWidth,$FileSearchLabelHeight) 
$FileSearchFileSearchLabel.Text      = "Collection time depends on the number of files and directories, plus recursive depth."
#$FileSearchFileSearchLabel.Font      = New-Object System.Drawing.Font("$Font",12,1,3,1)
$FileSearchFileSearchLabel.ForeColor = "Blue"
$Section1FileSearchTab.Controls.Add($FileSearchFileSearchLabel)


# Shift the fields
$FileSearchDownPosition += $FileSearchDownPositionShift - 3


#------------------------------------------------
# File Search - File Search Files Textbox
#------------------------------------------------
$FileSearchFileSearchFileTextbox               = New-Object System.Windows.Forms.TextBox
$FileSearchFileSearchFileTextbox.Location      = New-Object System.Drawing.Size($FileSearchRightPosition,($FileSearchDownPosition)) 
$FileSearchFileSearchFileTextbox.Size          = New-Object System.Drawing.Size(430,(80))
$FileSearchFileSearchFileTextbox.MultiLine     = $True
$FileSearchFileSearchFileTextbox.ScrollBars    = "Vertical"
$FileSearchFileSearchFileTextbox.WordWrap      = True
$FileSearchFileSearchFileTextbox.AcceptsTab    = false    # Allows you to enter in tabs into the textbox
$FileSearchFileSearchFileTextbox.AcceptsReturn = false # Allows you to enter in tabs into the textbox
$FileSearchFileSearchFileTextbox.Font          = New-Object System.Drawing.Font("$Font",9,0,3,1)
$FileSearchFileSearchFileTextbox.Text          = "Enter FileNames - One Per Line"
#$FileSearchFileSearchFileTextbox.Add_KeyDown({          })
$Section1FileSearchTab.Controls.Add($FileSearchFileSearchFileTextbox)


# Shift the fields
$FileSearchDownPosition += $FileSearchFileSearchFileTextbox.Size.Height + 5


#----------------------------------------------------
# File Search - File Search Directory Textbox
#----------------------------------------------------
$FileSearchFileSearchDirectoryTextbox               = New-Object System.Windows.Forms.TextBox
$FileSearchFileSearchDirectoryTextbox.Location      = New-Object System.Drawing.Size($FileSearchRightPosition,($FileSearchDownPosition)) 
$FileSearchFileSearchDirectoryTextbox.Size          = New-Object System.Drawing.Size(430,(80))
$FileSearchFileSearchDirectoryTextbox.MultiLine     = $True
$FileSearchFileSearchDirectoryTextbox.ScrollBars    = "Vertical"
$FileSearchFileSearchDirectoryTextbox.WordWrap      = True
$FileSearchFileSearchDirectoryTextbox.AcceptsTab    = false    # Allows you to enter in tabs into the textbox
$FileSearchFileSearchDirectoryTextbox.AcceptsReturn = false # Allows you to enter in tabs into the textbox
$FileSearchFileSearchDirectoryTextbox.Text          = "Enter Directories; One Per Line"
#$FileSearchFileSearchDirectoryTextbox.Add_KeyDown({          })
$Section1FileSearchTab.Controls.Add($FileSearchFileSearchDirectoryTextbox)

##############################################################################################################################################################
##
## Section 1 Sysinternals Tab
##
##############################################################################################################################################################

# Varables
$SysinternalsRightPosition     = 3
$SysinternalsDownPosition      = -10
$SysinternalsDownPositionShift = 22
$SysinternalsLabelWidth        = 450
$SysinternalsLabelHeight       = 25
$SysinternalsButtonWidth       = 110
$SysinternalsButtonHeight      = 22


$Section1SysinternalsTab          = New-Object System.Windows.Forms.TabPage
$Section1SysinternalsTab.Location = $System_Drawing_Point
$Section1SysinternalsTab.Text     = "Sysinternals"
$Section1SysinternalsTab.Location = New-Object System.Drawing.Size($SysinternalsRightPosition,$SysinternalsDownPosition) 
$Section1SysinternalsTab.Size     = New-Object System.Drawing.Size($SysinternalsLabelWidth,$SysinternalsLabelHeight) 
$Section1SysinternalsTab.UseVisualStyleBackColor = $True

# Test if the External Programs directory is present; if it's there load the tab
if (Test-Path $ExternalPrograms) {
    $Section1CollectionsTabControl.Controls.Add($Section1SysinternalsTab)
}

# Shift the fields
$SysinternalsDownPosition += $SysinternalsDownPositionShift

# Sysinternals Tab Label
$SysinternalsTabLabel           = New-Object System.Windows.Forms.Label
$SysinternalsTabLabel.Location  = New-Object System.Drawing.Point($SysinternalsRightPosition,$SysinternalsDownPosition) 
$SysinternalsTabLabel.Size      = New-Object System.Drawing.Size($SysinternalsLabelWidth,$SysinternalsLabelHeight) 
$SysinternalsTabLabel.Text      = "Options here drop/remove files to the target host's temp dir."
$SysinternalsTabLabel.Font      = New-Object System.Drawing.Font("$Font",10,1,3,1)
$SysinternalsTabLabel.ForeColor = "Red"
$Section1SysinternalsTab.Controls.Add($SysinternalsTabLabel)

# Shift the fields
$SysinternalsDownPosition += $SysinternalsDownPositionShift
# Shift the fields
$SysinternalsDownPosition += $SysinternalsDownPositionShift

#============================================================================================================================================================
# Sysinternals Autoruns
#============================================================================================================================================================

#-----------------------------
# Sysinternals Autoruns Label
#-----------------------------
$SysinternalsAutorunsLabel           = New-Object System.Windows.Forms.Label
$SysinternalsAutorunsLabel.Location  = New-Object System.Drawing.Point($SysinternalsRightPosition,$SysinternalsDownPosition) 
$SysinternalsAutorunsLabel.Size      = New-Object System.Drawing.Size(($SysinternalsLabelWidth),$SysinternalsLabelHeight) 
$SysinternalsAutorunsLabel.Text      = "Autoruns - Obtains More Startup Information than Native WMI and other Windows Commands, like various built-in Windows Applications."
#$SysinternalsAutorunsLabel.Font      = New-Object System.Drawing.Font("$Font",12,1,3,1)
$SysinternalsAutorunsLabel.ForeColor = "Blue"
$Section1SysinternalsTab.Controls.Add($SysinternalsAutorunsLabel)


# Shift the fields
$SysinternalsDownPosition += $SysinternalsDownPositionShift


#--------------------------------
# Sysinternals - Autoruns Button
#--------------------------------
$SysinternalsAutorunsButton          = New-Object System.Windows.Forms.Button
$SysinternalsAutorunsButton.Text     = "Open Autoruns"
$SysinternalsAutorunsButton.Location = New-Object System.Drawing.Size($SysinternalsRightPosition,($SysinternalsDownPosition + 5)) 
$SysinternalsAutorunsButton.Size     = New-Object System.Drawing.Size($SysinternalsButtonWidth,$SysinternalsButtonHeight) 
$SysinternalsAutorunsButton.add_click({
    [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
    $SysinternalsAutorunsOpenFileDialog.Title = "Open Autoruns File"
    $SysinternalsAutorunsOpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $SysinternalsAutorunsOpenFileDialog.filter = "Autoruns File (*.arn)| *.arn|All files (*.*)|*.*"
    $SysinternalsAutorunsOpenFileDialog.ShowHelp = $true
    if (Test-Path -Path $CollectedDataTimeStampDirectory) {
        $SysinternalsAutorunsOpenFileDialog.InitialDirectory = "$IndividualHostResults\$($SysinternalsAutorunsCheckbox.Name)"
        $SysinternalsAutorunsOpenFileDialog.ShowDialog() | Out-Null
        $ProcMonFileLocation = "$CollectedDataTimeStampDirectory"
    }
    else {
        $SysinternalsAutorunsOpenFileDialog.InitialDirectory = "$CollectedDataDirectory"   
        $SysinternalsAutorunsOpenFileDialog.ShowDialog() | Out-Null
        $ProcMonFileLocation = "$CollectedDataDirectory"
    }
    if ($($SysinternalsAutorunsOpenFileDialog.filename)) {
        Start-Process "$ExternalPrograms\Autoruns.exe" -ArgumentList "`"$($SysinternalsAutorunsOpenFileDialog.filename)`""
    }
})
$Section1SysinternalsTab.Controls.Add($SysinternalsAutorunsButton) 


#--------------------------------
# Sysinternals Autoruns CheckBox
#--------------------------------
$SysinternalsAutorunsCheckbox = New-Object System.Windows.Forms.CheckBox
$SysinternalsAutorunsCheckbox.Name = "Autoruns"

# Command Execution
function SysinternalsAutorunsCommand {
    $CollectionName = "Autoruns"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName

    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile

        Function SysinternalsAutorunsData {
            $SysinternalsExecutable     = 'Autoruns.exe'
            $ToolName                   = 'Autoruns'
            $AdminShare                 = 'c$'
            $LocalDrive                 = 'c:'
            $PSExecPath                 = "$ExternalPrograms\PSExec.exe"
            $SysinternalsExecutablePath = "$ExternalPrograms\Autoruns.exe"
            $TargetFolder               = "Windows\Temp"
            
            $MainListBox.Items.Insert(2,"Copying $ToolName to $TargetComputer temporarily for use by PSExec.")
            try { Copy-Item $SysinternalsExecutablePath "\\$TargetComputer\$AdminShare\$TargetFolder" -Force -Verbose -ErrorAction Stop } catch { $MainListBox.Items.Insert(2,$_.Exception); break }

            # Process monitor must be launched as a separate process otherwise the sleep and terminate commands below would never execute and fill the disk
            $MainListBox.Items.Insert(2,"Starting process monitor on $TargetComputer")
            Start-Process -WindowStyle Hidden -FilePath $PSExecPath -ArgumentList "/accepteula -s \\$TargetComputer $LocalDrive\$TargetFolder\$SysinternalsExecutable /AcceptEula -a $LocalDrive\$TargetFolder\Autoruns-$TargetComputer.arn" -PassThru | Out-Null   

            #$MainListBox.Items.Insert(2,"Terminating $ToolName process on $TargetComputer")
            #Start-Process -WindowStyle Hidden -FilePath $PSExecPath -ArgumentList "/accepteula -s \\$TargetComputer $LocalDrive\$TargetFolder\$procmon /accepteula /terminate /quiet" -PassThru | Out-Null
            Start-Sleep -Seconds 30

            # Checks to see if the process is still running
            while ($true) {
                if ($(Get-WmiObject -Class Win32_Process -ComputerName "$TargetComputer" | Where-Object {$_.ProcessName -match "Autoruns"})) {  
                    #$RemoteFileSize = "$(Get-ChildItem -Path `"C:\$TempPath`" | Where-Object {$_.Name -match `"$MemoryCaptureFile`"} | Select-Object -Property Length)" #-replace "@{Length=","" -replace "}",""
                    
                    $Message = "$((Get-Date).ToString('yyyy/MM/dd HH:mm:ss')) Checking Autoruns Status on $TargetComputer"
                    #$MainListBox.Items.RemoveAt(0) ; $MainListBox.Items.RemoveAt(0)
                    $MainListBox.Items.Insert(0,$Message)
                    Start-Sleep -Seconds 30
                }
                else {
                    Start-Sleep -Seconds 5

                    $MainListBox.Items.Insert(2,"Copy $ToolName data to local machine for analysis")
                    try { Copy-Item "\\$TargetComputer\$AdminShare\$TargetFolder\Autoruns-$TargetComputer.arn" "$IndividualHostResults\$CollectionDirectory" -Force -Verbose -ErrorAction Stop }
                    catch { $_ ; }

                    $MainListBox.Items.Insert(2,"Remove temporary $ToolName executable and data file from target system")
                 
                    Remove-Item "\\$TargetComputer\$AdminShare\$TargetFolder\Autoruns-$TargetComputer.arn" -Verbose -Force
                    Remove-Item "\\$TargetComputer\$AdminShare\$TargetFolder\$SysinternalsExecutable" -Verbose -Force

                    $MainListBox.Items.Insert(2,"Launching $ToolName and loading collected log data")
                    if(Test-Path("$IndividualHostResults\$CollectionDirectory\$TargetComputer.arn")) { & $procmonPath /openlog $PoShHome\Sysinternals\$TargetComputer.arn }

                    $FileSize = [math]::round(((Get-Item "$PoShHome\$TargetComputer.arn").Length/1mb),2)    
                    $MainListBox.Items.Insert(2,"$CollectedDataTimeStampDirectory\$TargetComputer.arn is $FileSize MB. Remember to delete it when finished.")

                    break
                }
            }
        }

        SysinternalsAutorunsData -TargetComputer $TargetComputer
    }
    Conduct-PostCommandExecution $CollectionName
}

$SysinternalsAutorunsCheckbox.Text     = "$($SysinternalsAutorunsCheckbox.Name)"
$SysinternalsAutorunsCheckbox.Location = New-Object System.Drawing.Size(($SysinternalsRightPosition + $SysinternalsButtonWidth + 5),($SysinternalsDownPosition + 5)) 
$SysinternalsAutorunsCheckbox.Size     = New-Object System.Drawing.Size(($SysinternalsLabelWidth - 130),$SysinternalsLabelHeight) 
$Section1SysinternalsTab.Controls.Add($SysinternalsAutorunsCheckbox)


# Shift the fields
$SysinternalsDownPosition += $SysinternalsDownPositionShift
# Shift the fields
$SysinternalsDownPosition += $SysinternalsDownPositionShift

#============================================================================================================================================================
# Sysinternals Process Monitor
#============================================================================================================================================================

#------------------------------
# Sysinternals - ProcMon Label
#------------------------------
$SysinternalsProcessMonitorLabel           = New-Object System.Windows.Forms.Label
$SysinternalsProcessMonitorLabel.Location  = New-Object System.Drawing.Point($SysinternalsRightPosition,$SysinternalsDownPosition) 
$SysinternalsProcessMonitorLabel.Size      = New-Object System.Drawing.Size($SysinternalsLabelWidth,$SysinternalsLabelHeight) 
$SysinternalsProcessMonitorLabel.Text      = "Procmon data will be megabytes of data per target host; Command will not run if there is less than 500MB on the local and target hosts."
#$SysinternalsProcessMonitorLabel.Font      = New-Object System.Drawing.Font("$Font",12,1,3,1)
$SysinternalsProcessMonitorLabel.ForeColor = "Blue"
$Section1SysinternalsTab.Controls.Add($SysinternalsProcessMonitorLabel)


# Shift the fields
$SysinternalsDownPosition += $SysinternalsDownPositionShift


#-------------------------------
# Sysinternals - ProcMon Button
#-------------------------------
$SysinternalsProcmonButton          = New-Object System.Windows.Forms.Button
$SysinternalsProcmonButton.Text     = "Open ProcMon"
$SysinternalsProcmonButton.Location = New-Object System.Drawing.Size($SysinternalsRightPosition,($SysinternalsDownPosition + 5)) 
$SysinternalsProcmonButton.Size     = New-Object System.Drawing.Size($SysinternalsButtonWidth,$SysinternalsButtonHeight) 
$SysinternalsProcmonButton.add_click({
    [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
    $SysinternalsProcmonOpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $SysinternalsProcmonOpenFileDialog.Title = "Open ProcMon File"
    $SysinternalsProcmonOpenFileDialog.filter = "ProcMon Log File (*.pml)| *.pml|All files (*.*)|*.*"
    $SysinternalsProcmonOpenFileDialog.ShowHelp = $true
    if (Test-Path -Path $CollectedDataTimeStampDirectory) {
        $SysinternalsProcmonOpenFileDialog.InitialDirectory = "$IndividualHostResults\$($SysinternalsProcessMonitorCheckbox.Name)"
        $SysinternalsProcmonOpenFileDialog.ShowDialog() | Out-Null
    }
    else {
        $SysinternalsProcmonOpenFileDialog.InitialDirectory = "$CollectedDataDirectory"   
        $SysinternalsProcmonOpenFileDialog.ShowDialog() | Out-Null
    }
    if ($($SysinternalsProcmonOpenFileDialog.filename)) {
        Start-Process "$ExternalPrograms\Procmon.exe" -ArgumentList "`"$($SysinternalsProcmonOpenFileDialog.filename)`""
    }
})
$Section1SysinternalsTab.Controls.Add($SysinternalsProcmonButton) 


#------------------------------
# Sysinternals Procmon Command
#------------------------------
$SysinternalsProcessMonitorCheckbox = New-Object System.Windows.Forms.CheckBox
$SysinternalsProcessMonitorCheckbox.Name = "Process Monitor"

# Default Procmon Time
$Script:SysinternalsProcessMonitorTime = 10

function SysinternalsProcessMonitorCommand {
    $CollectionName = "Process Monitor"
    Conduct-PreCommandExecution $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionName
    foreach ($TargetComputer in $ComputerList) {
        Conduct-PreCommandCheck $CollectedDataTimeStampDirectory $IndividualHostResults $CollectionDirectory $CollectionName $TargetComputer
        Create-LogEntry $LogFile
                
        # Collect Remote host Disk Space       
        Function Get-DiskSpace([string] $TargetComputer) {
                try { $HD = Get-WmiObject Win32_LogicalDisk -ComputerName $TargetComputer -Filter "DeviceID='C:'" -ErrorAction Stop } 
                catch { $MainListBox.Items.Insert(2,"Unable to connect to $TargetComputer. $_"); continue}
                if(!$HD) { throw }
                $FreeSpace = [math]::round(($HD.FreeSpace/1gb),2)
                return $FreeSpace
        }

        # Uses PSExec and Procmon to get Process Monitoring informaiton on remote hosts
        # Diskspace is calculated on local and target hosts to determine if there's a risk
        # Procmon is copied over to the target host, and data is gathered there and then exported back
        # The Procmon program and capture file are deleted
        Function SysinternalsProcessMonitorData {
            # Checks to see if the duration is within 10 and 100 seconds
            Param(
                [Parameter(Mandatory=$true)][string]$TargetComputer, 
                [Parameter(Mandatory=$true,
                    HelpMessage="Enter a duration from 10 to 300 seconds (limited due to disk space requriements")]
                    [ValidateRange(10,300)][int]$Duration
            )
            $SysinternalsExecutable      = 'procmon.exe'
            $ToolName                    = 'ProcMon'
            $AdminShare                  = 'c$'
            $LocalDrive                  = 'c:'
            $PSExecPath                  = "$ExternalPrograms\PSExec.exe"
            $SysinternalsExecutablePath  = "$ExternalPrograms\Procmon.exe"
            $TargetFolder                = "Windows\Temp"            
           
            $MainListBox.Items.Insert(2,"Verifing connection to $TargetComputer, checking for PSExec and Procmon.")
    
            # Process monitor generates enormous amounts of data.  
            # To try and offer some protections, the script won't run if the source or target have less than 500MB free
            $MainListBox.Items.Insert(2,"Verifying free diskspace on source and target.")
            if((Get-DiskSpace $TargetComputer) -lt 0.5) 
                { $MainListBox.Items.Insert(2,"$TargetComputer has less than 500MB free - aborting to avoid filling the disk."); break }

            if((Get-DiskSpace $Env:ComputerName) -lt 0.5) 
                { $MainListBox.Items.Insert(2,"Local computer has less than 500MB free - aborting to avoid filling the disk."); break }

            $MainListBox.Items.Insert(2,"Copying Procmon to the target system temporarily for use by PSExec.")
            try { Copy-Item $SysinternalsExecutablePath "\\$TargetComputer\$AdminShare\$TargetFolder" -Force -Verbose -ErrorAction Stop } catch { $MainListBox.Items.Insert(2,$_.Exception); break }

            # Process monitor must be launched as a separate process otherwise the sleep and terminate commands below would never execute and fill the disk
            $MainListBox.Items.Insert(2,"Starting process monitor on $TargetComputer")
            #$Command = Start-Process -WindowStyle Hidden -FilePath $PSExecPath -ArgumentList "/accepteula $Credentials -s \\$TargetComputer $LocalDrive\$TargetFolder\$SysinternalsExecutable /AcceptEula /BackingFile $LocalDrive\$TargetFolder\$TargetComputer /RunTime 10 /Quiet" -PassThru | Out-Null
            $Command = Start-Process -WindowStyle Hidden -FilePath $PSExecPath -ArgumentList "/accepteula -s \\$TargetComputer $LocalDrive\$TargetFolder\$SysinternalsExecutable /AcceptEula /BackingFile `"$LocalDrive\$TargetFolder\ProcMon-$TargetComputer`" /RunTime $Duration /Quiet" -PassThru | Out-Null
            $Command
            $Message = "$((Get-Date).ToString('yyyy/MM/dd HH:mm:ss')) - $TargetComputer $($SysinternalsProcessMonitorCheckbox.Name)"
            $Message | Add-Content -Path $LogFile
            $Message = "$((Get-Date).ToString('yyyy/MM/dd HH:mm:ss')) - $TargetComputer $Command"
            $Message | Add-Content -Path $LogFile

            Start-Sleep -Seconds ($Duration + 5)

            while ($true) {
                if ($(Get-WmiObject -Class Win32_Process -ComputerName "$TargetComputer" | Where-Object {$_.ProcessName -match "Procmon"})) {                      
                    $Message = "$((Get-Date).ToString('yyyy/MM/dd HH:mm:ss')) Checking ProcMon Status on $TargetComputer"
                    $MainListBox.Items.Insert(0,$Message)
                    Start-Sleep -Seconds 30
                }
                else {
                    Start-Sleep -Seconds 5

                    $MainListBox.Items.Insert(2,"Copy $ToolName data to local machine for analysis")
                    try { Copy-Item "\\$TargetComputer\$AdminShare\$TargetFolder\ProcMon-$TargetComputer.pml" "$IndividualHostResults\$CollectionDirectory" -Force -Verbose -ErrorAction Stop }
                    catch { $_ ; }

                    $MainListBox.Items.Insert(2,"Remove temporary $ToolName executable and data file from target system")
                 
                    Remove-Item "\\$TargetComputer\$AdminShare\$TargetFolder\ProcMon-$TargetComputer.pml" -Verbose -Force
                    Remove-Item "\\$TargetComputer\$AdminShare\$TargetFolder\$SysinternalsExecutable" -Verbose -Force

                    $MainListBox.Items.Insert(2,"Launching $ToolName and loading collected log data")
                    if(Test-Path("$IndividualHostResults\$CollectionDirectory\$TargetComputer.pml")) { & $SysinternalsExecutablePath /openlog $PoShHome\Sysinternals\$TargetComputer.pml }

                    $FileSize = [math]::round(((Get-Item "$IndividualHostResults\$CollectionDirectory\$TargetComputer.pml").Length/1mb),2)    
                    $MainListBox.Items.Insert(2,"$IndividualHostResults\$CollectionDirectory\$TargetComputer.pml is $FileSize MB. Remember to delete it when finished.")

                    break
                }
            }

        }

        SysinternalsProcessMonitorData -TargetComputer $TargetComputer -Duration $Script:SysinternalsProcessMonitorTime
    }
    Conduct-PostCommandExecution $CollectionName
}

$SysinternalsProcessMonitorCheckbox.Text     = "$($SysinternalsProcessMonitorCheckbox.Name)"
$SysinternalsProcessMonitorCheckbox.Location = New-Object System.Drawing.Size(($SysinternalsRightPosition + $SysinternalsButtonWidth + 5),($SysinternalsDownPosition + 5)) 
$SysinternalsProcessMonitorCheckbox.Size     = New-Object System.Drawing.Size(($SysinternalsLabelWidth - 330),$SysinternalsLabelHeight) 
$Section1SysinternalsTab.Controls.Add($SysinternalsProcessMonitorCheckbox)


#------------------------
# Procmon - Time TextBox
#------------------------
$SysinternalsProcessMonitorTimeTextBox          = New-Object System.Windows.Forms.TextBox
$SysinternalsProcessMonitorTimeTextBox.Location = New-Object System.Drawing.Size(($SysinternalsRightPosition + $SysinternalsButtonWidth + 150),($SysinternalsDownPosition + 6)) 
$SysinternalsProcessMonitorTimeTextBox.Size     = New-Object System.Drawing.Size((160),$SysinternalsLabelHeight) 
$SysinternalsProcessMonitorTimeTextBox.Text     = "Default = 10 Seconds"
# Press Enter to Input Data
$SysinternalsProcessMonitorTimeTextBox.Add_KeyDown({
    if ($_.KeyCode -eq "Enter") {
        # Enter a capture time between 10 and 300 seconds
        if (($SysinternalsProcessMonitorTimeTextBox.Text -ge 10) -and ($SysinternalsProcessMonitorTimeTextBox.Text -le 300)) {
            $Script:SysinternalsProcessMonitorTime = $SysinternalsProcessMonitorTimeTextBox.Text
            $Success=[System.Windows.Forms.MessageBox]::Show(`
                "Success! The capture time has been set for $SysinternalsProcessMonitorTime seconds.",`
                "PoSh-ACME",`
                [System.Windows.Forms.MessageBoxButtons]::OK)
                switch ($Success){
                "OK" {
                    #write-host "You pressed OK"
                }
            }
        }
        else {
            $OhDarn=[System.Windows.Forms.MessageBox]::Show(`
                "Enter a capture time between 10 and 300 seconds.",`
                "PoSh-ACME",`
                [System.Windows.Forms.MessageBoxButtons]::OK)
                switch ($OhDarn){
                "OK" {
                    #write-host "You pressed OK"
                }
            }        
        }
    }
})
$Section1SysinternalsTab.Controls.Add($SysinternalsProcessMonitorTimeTextBox)

##############################################################################################################################################################
##
## Enumeration
##
##############################################################################################################################################################

# Varables
$EnumerationRightPosition     = 3
$EnumerationDownPosition      = 0
$EnumerationDownPositionShift = 25
$EnumerationLabelWidth        = 450
$EnumerationLabelHeight       = 25
$EnumerationButtonWidth       = 110
$EnumerationButtonHeight      = 22
$EnumerationGroupGap          = 15

$Section1EnumerationTab          = New-Object System.Windows.Forms.TabPage
$Section1EnumerationTab.Location = $System_Drawing_Point
$Section1EnumerationTab.Name     = "Enumeration"
$Section1EnumerationTab.Text     = "Enumeration"
$Section1EnumerationTab.Location = New-Object System.Drawing.Size($EnumerationRightPosition,$EnumerationDownPosition) 
$Section1EnumerationTab.Size     = New-Object System.Drawing.Size($EnumerationLabelWidth,$EnumerationLabelHeight) 
$Section1EnumerationTab.UseVisualStyleBackColor = $True
$Section1TabControl.Controls.Add($Section1EnumerationTab)

$EnumerationDownPosition += 13

#============================================================================================================================================================
# Enumeration - Domain Generated
#============================================================================================================================================================

#-------------------------------------------------------
# Enumeration - Domain Generated - function Input Check
#-------------------------------------------------------
function EnumerationDomainGeneratedInputCheck {
    if (($EnumerationDomainGeneratedTextBox.Text -ne '<Domain Name>') -or ($EnumerationDomainGeneratedAutoCheckBox.Checked)) {
        if (($EnumerationDomainGeneratedTextBox.Text -ne '') -or ($EnumerationDomainGeneratedAutoCheckBox.Checked)) {
            # Checks if the domain input field is either blank or contains the default info
            If ($EnumerationDomainGeneratedAutoCheckBox.Checked  -eq $true){. ListComputers "Auto"}
            else {. ListComputers "Manual" "$($EnumerationDomainGeneratedTextBox.Text)"}

            $EnumerationComputerListBox.Items.Clear()
            foreach ($Computer in $ComputerList) {
                [void] $EnumerationComputerListBox.Items.Add("$Computer")
            }
        }
    }
}

#------------------------------------
# Enumeration - Port Scan - GroupBox
#------------------------------------
$EnumerationDomainGenerateGroupBox           = New-Object System.Windows.Forms.GroupBox
$EnumerationDomainGenerateGroupBox.Location  = New-Object System.Drawing.Size(0,$EnumerationDownPosition)
$EnumerationDomainGenerateGroupBox.size      = New-Object System.Drawing.Size(294,100)
$EnumerationDomainGenerateGroupBox.text      = "Import List From Domain"
$EnumerationDomainGenerateGroupBox.Font      = New-Object System.Drawing.Font("$Font",12,1,2,1)
$EnumerationDomainGenerateGroupBox.ForeColor = "Blue"

$EnumerationDomainGenerateDownPosition      = 18
$EnumerationDomainGenerateDownPositionShift = 25

    $EnumerationDomainGeneratedLabelNote           = New-Object System.Windows.Forms.Label
    $EnumerationDomainGeneratedLabelNote.Location  = New-Object System.Drawing.Size($EnumerationRightPosition,($EnumerationDomainGenerateDownPosition + 3)) 
    $EnumerationDomainGeneratedLabelNote.Size      = New-Object System.Drawing.Size(220,22)
    $EnumerationDomainGeneratedLabelNote.Text      = "This host must be domained for this feature."    
    $EnumerationDomainGeneratedLabelNote.Font      = New-Object System.Drawing.Font("$Font",10,0,2,1)
    $EnumerationDomainGeneratedLabelNote.ForeColor = "Black"
    $EnumerationDomainGenerateGroupBox.Controls.Add($EnumerationDomainGeneratedLabelNote)  

    #-----------------------------------------------------
    # Enumeration - Domain Generated - Auto Pull Checkbox
    #-----------------------------------------------------
    $EnumerationDomainGeneratedAutoCheckBox           = New-Object System.Windows.Forms.Checkbox
    $EnumerationDomainGeneratedAutoCheckBox.Name      = "Auto Pull"
    $EnumerationDomainGeneratedAutoCheckBox.Text      = "$($EnumerationDomainGeneratedAutoCheckBox.Name)"
    $EnumerationDomainGeneratedAutoCheckBox.Location  = New-Object System.Drawing.Size(($EnumerationDomainGeneratedLabelNote.Size.Width + 3),($EnumerationDomainGenerateDownPosition - 1))
    $EnumerationDomainGeneratedAutoCheckBox.Size      = New-Object System.Drawing.Size(100,$EnumerationLabelHeight)
    $EnumerationDomainGeneratedAutoCheckBox.Font      = New-Object System.Drawing.Font("$Font",10,0,2,1)
    $EnumerationDomainGeneratedAutoCheckBox.ForeColor = "Black"
    $EnumerationDomainGeneratedAutoCheckBox.Add_Click({
        if ($EnumerationDomainGeneratedAutoCheckBox.Checked -eq $true){
            $EnumerationDomainGeneratedTextBox.Enabled   = $false
            $EnumerationDomainGeneratedTextBox.BackColor = "lightgray"
        }
        elseif ($EnumerationDomainGeneratedAutoCheckBox.Checked -eq $false) {
            $EnumerationDomainGeneratedTextBox.Text = "<Domain Name>"
            $EnumerationDomainGeneratedTextBox.Enabled   = $true    
            $EnumerationDomainGeneratedTextBox.BackColor = "white"
        }
    })
    $EnumerationDomainGenerateGroupBox.Controls.Add($EnumerationDomainGeneratedAutoCheckBox)

    $EnumerationDomainGenerateDownPosition += $EnumerationDomainGenerateDownPositionShift

    #------------------------------------------------
    # Enumeration - Domain Generated - Input Textbox
    #------------------------------------------------
    $EnumerationDomainGeneratedTextBox           = New-Object System.Windows.Forms.TextBox
    $EnumerationDomainGeneratedTextBox.Text      = "<Domain Name>"
    $EnumerationDomainGeneratedTextBox.Location  = New-Object System.Drawing.Size($EnumerationRightPosition,$EnumerationDomainGenerateDownPosition)
    $EnumerationDomainGeneratedTextBox.Size      = New-Object System.Drawing.Size(286,$EnumerationLabelHeight)
    $EnumerationDomainGeneratedTextBox.Font      = New-Object System.Drawing.Font("$Font",10,0,2,1)
    $EnumerationDomainGeneratedTextBox.ForeColor = "Black"
    $EnumerationDomainGeneratedTextBox.Add_KeyDown({
        if ($_.KeyCode -eq "Enter") { EnumerationDomainGeneratedInputCheck }
    })
    $EnumerationDomainGenerateGroupBox.Controls.Add($EnumerationDomainGeneratedTextBox)

    $EnumerationDomainGenerateDownPosition += $EnumerationDomainGenerateDownPositionShift

    #----------------------------------------------------------
    # Enumeration - Domain Generated - Import Hosts/IPs Button
    #----------------------------------------------------------
    $EnumerationDomainGeneratedListButton           = New-Object System.Windows.Forms.Button
    $EnumerationDomainGeneratedListButton.Text      = "Import Hosts"
    $EnumerationDomainGeneratedListButton.Location  = New-Object System.Drawing.Size(190,($EnumerationDomainGenerateDownPosition - 1))
    $EnumerationDomainGeneratedListButton.Size      = New-Object System.Drawing.Size(100,22)
    $EnumerationDomainGeneratedListButton.Font      = New-Object System.Drawing.Font("$Font",11,0,2,1)
    $EnumerationDomainGeneratedListButton.ForeColor = "Red"
    $EnumerationDomainGeneratedListButton.add_click({ EnumerationDomainGeneratedInputCheck })
    $EnumerationDomainGenerateGroupBox.Controls.Add($EnumerationDomainGeneratedListButton) 

$Section1EnumerationTab.Controls.Add($EnumerationDomainGenerateGroupBox) 

#============================================================================================================================================================
# Enumeration - Port Scanning
#============================================================================================================================================================
function Conduct-PortScan {
    param (
        $Timeout_ms,
        $TestWithICMPFirst,
        $SpecificIPsToScan,
        $Network,
        $FirstIP,
        $LastIP,
        $SpecificPortsToScan,
        $FirstPort,
        $LastPort
    )
    $IPsToScan = @()
    $IPsToScan += $SpecificIPsToScan -split "," -replace " ",""
    if ( $FirstIP -ne "" -and $LastIP -ne "" ) {
        if ( ($FirstIP -lt [int]0 -or $FirstIP -gt [int]255) -or ($LastIP -lt [int]0 -or $LastIP -gt [int]255) ) {             
            $MainListBox.Items.Clear()
            $MainListBox.Items.Add("Error! The First and Last IP Fields must be an interger between 0 and 255")
            return
        }
        $IPRange = $FirstIP..$LastIP
        foreach ( $IP in $IPRange ) { $IPsToScan += "$Network.$IP" }
    }
    elseif (( $FirstIP -ne "" -and $LastIP -eq "" ) -or ( $FirstIP -eq "" -and $LastIP -ne "" )) {        
        $MainListBox.Items.Clear()
        $MainListBox.Items.Add("Error! You can't have one empty IP range field.")
        return
    }
    
    # Since sorting IPs in PowerShell easily and accurately can be a pain...
    # The [System.Version] object is used to represent file and application versions, and we can leverage it to sort IP addresses simply. We sort on a custom calculation, converting the IP addresses to version objects. The conversion is just for sorting purposes.
    $IPsToScan  = $IPsToScan | Sort-Object { [System.Version]$_ } -Unique | ? {$_ -ne ""}

    $PortsToScan = @()
    # Adds the user entered specific ports that were comma separated
    $PortsToScan += $SpecificPortsToScan -split "," -replace " ",""
    # Adds the user entered ports ranged entered in the port range section
    $PortsToScan += $FirstPort..$LastPort

    function GeneratePortsStatusMessage {
        $MainListBox.Items.Clear()
        $MainListBox.Items.Add("Please wait as the port range is being generated...")
        Start-Sleep -Seconds 1
    }
    # If the respective drop down is selected, the ports will be added to the port scan
    if ($EnumerationPortScanPortQuickPickComboBox.SelectedItem -eq "Nmap Top 100 Ports") {
        GeneratePortsStatusMessage
        $PortsToScan += "7,9,13,21,22,23,25,26,37,53,79,80,81,88,106,110,111,113,119,135,139,143,144,179,199,389,427,443,444,445,465,513,514,515,543,544,548,554,587,631,646,873,990,993,995,1025,1026,1027,1028,1029,1110,1433,1720,1723,1755,1900,2000,2001,2049,2121,2717,3000,3128,3306,3389,3986,4899,5000,5009,5051,5060,5101,5190,5357,5432,5631,5666,5800,5900,6000,6001,6646,7070,8000,8008-8009,8080,8081,8443,8888,9100,9999,10000,32768,49152,49153,49154,49155,49156,49157" -split "," -replace " ",""
    }
    elseif ($EnumerationPortScanPortQuickPickComboBox.SelectedItem -eq "Nmap Top 1000 Ports") {
        GeneratePortsStatusMessage
        $PortsToScan += "1,3,4,6,7,9,13,17,19,20,21,22,23,24,25,26,30,32,33,37,42,43,49,53,70,79,80,81,82,83,84,85,88,89,90,99,100,106,109,110,111,113,119,125,135,139,143,144,146,161,163,179,199,211,212,222,254,255,256,259,264,280,301,306,311,340,366,389,406,407,416,417,425,427,443,444,445,458,464,465,481,497,500,512,513,514,515,524,541,543,544,545,548,554,555,563,587,593,616,617,625,631,636,646,648,666,667,668,683,687,691,700,705,711,714,720,722,726,749,765,777,783,787,800,801,808,843,873,880,888,898,900,901,902,903,911,912,981,987,990,992,993,995,999,1000,1001,1002,1007,1009,1010,1011,1021,1022,1023,1024,1025,1026,1027,1028,1029,1030,1031,1032,1033,1034,1035,1036,1037,1038,1039,1040,1041,1042,1043,1044,1045,1046,1047,1048,1049,1050,1051,1052,1053,1054,1055,1056,1057,1058,1059,1060,1061,1062,1063,1064,1065,1066,1067,1068,1069,1070,1071,1072,1073,1074,1075,1076,1077,1078,1079,1080,1081,1082,1083,1084,1085,1086,1087,1088,1089,1090,1091,1092,1093,1094,1095,1096,1097,1098,1099,1100,1102,1104,1105,1106,1107,1108,1110,1111,1112,1113,1114,1117,1119,1121,1122,1123,1124,1126,1130,1131,1132,1137,1138,1141,1145,1147,1148,1149,1151,1152,1154,1163,1164,1165,1166,1169,1174,1175,1183,1185,1186,1187,1192,1198,1199,1201,1213,1216,1217,1218,1233,1234,1236,1244,1247,1248,1259,1271,1272,1277,1287,1296,1300,1301,1309,1310,1311,1322,1328,1334,1352,1417,1433,1434,1443,1455,1461,1494,1500,1501,1503,1521,1524,1533,1556,1580,1583,1594,1600,1641,1658,1666,1687,1688,1700,1717,1718,1719,1720,1721,1723,1755,1761,1782,1783,1801,1805,1812,1839,1840,1862,1863,1864,1875,1900,1914,1935,1947,1971,1972,1974,1984,1998,1999,2000,2001,2002,2003,2004,2005,2006,2007,2008,2009,2010,2013,2020,2021,2022,2030,2033,2034,2035,2038,2040,2041,2042,2043,2045,2046,2047,2048,2049,2065,2068,2099,2100,2103,2105,2106,2107,2111,2119,2121,2126,2135,2144,2160,2161,2170,2179,2190,2191,2196,2200,2222,2251,2260,2288,2301,2323,2366,2381,2382,2383,2393,2394,2399,2401,2492,2500,2522,2525,2557,2601,2602,2604,2605,2607,2608,2638,2701,2702,2710,2717,2718,2725,2800,2809,2811,2869,2875,2909,2910,2920,2967,2968,2998,3000,3001,3003,3005,3006,3007,3011,3013,3017,3030,3031,3052,3071,3077,3128,3168,3211,3221,3260,3261,3268,3269,3283,3300,3301,3306,3322,3323,3324,3325,3333,3351,3367,3369,3370,3371,3372,3389,3390,3404,3476,3493,3517,3527,3546,3551,3580,3659,3689,3690,3703,3737,3766,3784,3800,3801,3809,3814,3826,3827,3828,3851,3869,3871,3878,3880,3889,3905,3914,3918,3920,3945,3971,3986,3995,3998,4000,4001,4002,4003,4004,4005,4006,4045,4111,4125,4126,4129,4224,4242,4279,4321,4343,4443,4444,4445,4446,4449,4550,4567,4662,4848,4899,4900,4998,5000,5001,5002,5003,5004,5009,5030,5033,5050,5051,5054,5060,5061,5080,5087,5100,5101,5102,5120,5190,5200,5214,5221,5222,5225,5226,5269,5280,5298,5357,5405,5414,5431,5432,5440,5500,5510,5544,5550,5555,5560,5566,5631,5633,5666,5678,5679,5718,5730,5800,5801,5802,5810,5811,5815,5822,5825,5850,5859,5862,5877,5900,5901,5902,5903,5904,5906,5907,5910,5911,5915,5922,5925,5950,5952,5959,5960,5961,5962,5963,5987,5988,5989,5998,5999,6000,6001,6002,6003,6004,6005,6006,6007,6009,6025,6059,6100,6101,6106,6112,6123,6129,6156,6346,6389,6502,6510,6543,6547,6565,6566,6567,6580,6646,6666,6667,6668,6669,6689,6692,6699,6779,6788,6789,6792,6839,6881,6901,6969,7000,7001,7002,7004,7007,7019,7025,7070,7100,7103,7106,7200,7201,7402,7435,7443,7496,7512,7625,7627,7676,7741,7777,7778,7800,7911,7920,7921,7937,7938,7999,8000,8001,8002,8007,8008,8009,8010,8011,8021,8022,8031,8042,8045,8080,8081,8082,8083,8084,8085,8086,8087,8088,8089,8090,8093,8099,8100,8180,8181,8192,8193,8194,8200,8222,8254,8290,8291,8292,8300,8333,8383,8400,8402,8443,8500,8600,8649,8651,8652,8654,8701,8800,8873,8888,8899,8994,9000,9001,9002,9003,9009,9010,9011,9040,9050,9071,9080,9081,9090,9091,9099,9100,9101,9102,9103,9110,9111,9200,9207,9220,9290,9415,9418,9485,9500,9502,9503,9535,9575,9593,9594,9595,9618,9666,9876,9877,9878,9898,9900,9917,9929,9943,9944,9968,9998,9999,10000,10001,10002,10003,10004,10009,10010,10012,10024,10025,10082,10180,10215,10243,10566,10616,10617,10621,10626,10628,10629,10778,11110,11111,11967,12000,12174,12265,12345,13456,13722,13782,13783,14000,14238,14441,14442,15000,15002,15003,15004,15660,15742,16000,16001,16012,16016,16018,16080,16113,16992,16993,17877,17988,18040,18101,18988,19101,19283,19315,19350,19780,19801,19842,20000,20005,20031,20221,20222,20828,21571,22939,23502,24444,24800,25734,25735,26214,27000,27352,27353,27355,27356,27715,28201,30000,30718,30951,31038,31337,32768,32769,32770,32771,32772,32773,32774,32775,32776,32777,32778,32779,32780,32781,32782,32783,32784,32785,33354,33899,34571,34572,34573,35500,38292,40193,40911,41511,42510,44176,44442,44443,44501,45100,48080,49152,49153,49154,49155,49156,49157,49158,49159,49160,49161,49163,49165,49167,49175,49176,49400,49999,50000,50001,50002,50003,50006,50300,50389,50500,50636,50800,51103,51493,52673,52822,52848,52869,54045,54328,55055,55056,55555,55600,56737,56738,57294,57797,58080,60020,60443,61532,61900,62078,63331,64623,64680,65000,65129,65389" -split "," -replace " ",""
    }
    elseif ($EnumerationPortScanPortQuickPickComboBox.SelectedItem -eq "Well-Known Ports (0-1023)") {
        GeneratePortsStatusMessage
        $PortsToScan += 0..1023
    }
    elseif ($EnumerationPortScanPortQuickPickComboBox.SelectedItem -eq "Registered Ports (1024-49151)") {
        GeneratePortsStatusMessage
        $PortsToScan += 1024..49151
    }
    elseif ($EnumerationPortScanPortQuickPickComboBox.SelectedItem -eq "Dynamic Ports (49152-65535)") {
        GeneratePortsStatusMessage
        $PortsToScan += 49152..65535
    }
    elseif ($EnumerationPortScanPortQuickPickComboBox.SelectedItem -eq "All Ports (0-65535)") {
        GeneratePortsStatusMessage
        $PortsToScan += 0..65535
    }
    elseif ($EnumerationPortScanPortQuickPickComboBox.SelectedItem -eq "Last Ports Scanned") {
        $PortsToScan += $null
    }
    elseif ($EnumerationPortScanPortQuickPickComboBox.SelectedItem -eq "Custom Saved Ports") {
        $PortsToScan += $null
    }
    elseif ($EnumerationPortScanPortQuickPickComboBox.SelectedItem -eq "") {
        $PortsToScan += $null
    }

    # Places the Ports to Scan in Numerical Order, removes duplicate entries, and remove possible empty fields
##Consumes too much time##
##    $SortedPorts=@()
##    foreach ( $Port in $PortsToScan ) { $SortedPorts += [int]$Port }
##    $PortsToScan = $SortedPorts | ? {$_ -ne ""}
    $PortsToScan = $PortsToScan | Sort-Object -Unique | ? {$_ -ne ""}

    $NetworkPortScanIPResponded = ""
    $LogMessage = "$((Get-Date).ToString('yyyy/MM/dd HH:mm:ss'))  ==================== Port Scan Initiliaztion ===================="
    $LogMessage = "$((Get-Date).ToString('yyyy/MM/dd HH:mm:ss'))  Ports To Be Scanned:  $PortsToScan"
    $LogMessage | Add-Content -Path $LogFile
    $EnumerationComputerListBox.Items.Clear()
    $MainListBox.Items.Clear()
    $StatusListBox.Items.Clear()
    $StatusListBox.Items.Add("Conducting Port Scan"); Start-Sleep -Seconds 1

    function PortScan {
        foreach ($Port in $PortsToScan) {
            $ErrorActionPreference = 'SilentlyContinue'
            $socket = New-Object System.Net.Sockets.TcpClient
            $connect = $socket.BeginConnect($IPAddress, $port, $null, $null)
            $tryconnect = Measure-Command { $success = $connect.AsyncWaitHandle.WaitOne($Timeout_ms, $true) } | % totalmilliseconds
            $tryconnect | Out-Null 
            if ($socket.Connected) {
                $MainListBox.Items.Add("$(Get-Date)  - $IPAddress is listening on port $Port (Response Time: $tryconnect ms)")
                $LogMessage = "$((Get-Date).ToString('yyyy/MM/dd HH:mm:ss'))  - $IPAddress is listening on port $Port (Response Time: $tryconnect ms)"
                $LogMessage | Add-Content -Path $LogFile
                $NetworkPortScanIPResponded = $IPAddress
                $socket.Close()
                $socket.Dispose()
                $socket = $null
            }
            $ErrorActionPreference = 'Continue'
            $StatusListBox.Items.Clear()
            $StatusListBox.Items.Add("Scanning: $IPAddress`:$Port")
        }
        if ($NetworkPortScanIPResponded -ne "") {
            $EnumerationComputerListBox.Items.Add("$NetworkPortScanIPResponded")
        }
        $NetworkPortScanResultsIPList = @() # To Clear out the Variable        
    }
    foreach ($IPAddress in $IPsToScan) {
        if ($TestWithICMPFirst -eq $true) {
            $StatusListBox.Items.Clear()
            $StatusListBox.Items.Add("Testing Connection (ping): $IPAddress")
            if (Test-Connection -BufferSize 32 -Count 1 -Quiet -ComputerName $IPAddress) {
                $MainListBox.Items.Add("$(Get-Date)  Port Scan IP:  $IPAddress")
                $LogMessage = "$((Get-Date).ToString('yyyy/MM/dd HH:mm:ss'))  ICMP Connection Test - $IPAddress is UP - Conducting Port Scan:)"
                $LogMessage | Add-Content -Path $LogFile
                PortScan
            }
            else {
                $LogMessage = "$((Get-Date).ToString('yyyy/MM/dd HH:mm:ss'))  ICMP Connection Test - $IPAddress is DOWN - No ports scanned)"
                $LogMessage | Add-Content -Path $LogFile
            }
        }
        elseif ($TestWithICMPFirst -eq $false) {
            $MainListBox.Items.Add("$(Get-Date)  Port Scan IP - $IPAddress")
            $LogMessage = "$((Get-Date).ToString('yyyy/MM/dd HH:mm:ss'))  Port Scan IP:  $IPAddress"
            $LogMessage | Add-Content -Path $LogFile
            PortScan
        } 
    }
    $StatusListBox.Items.Clear()
    $StatusListBox.Items.Add("Port Scan Completed - Results Are Saved In The Log File")
    $MainListBox.Items.Add("$(Get-Date)  ==================== Port Scan Complete ====================")
}

#------------------------------------
# Enumeration - Port Scan - GroupBox
#------------------------------------
$EnumerationPortScanGroupBox           = New-Object System.Windows.Forms.GroupBox
$EnumerationPortScanGroupBox.Location  = New-Object System.Drawing.Size(0,($EnumerationDomainGenerateGroupBox.Location.Y + $EnumerationDomainGenerateGroupBox.Size.Height + $EnumerationGroupGap))
$EnumerationPortScanGroupBox.size      = New-Object System.Drawing.Size(294,270)
$EnumerationPortScanGroupBox.text      = "Create List From TCP Port Scan"
$EnumerationPortScanGroupBox.Font      = New-Object System.Drawing.Font("$Font",12,1,2,1)
$EnumerationPortScanGroupBox.ForeColor = "Blue"

$EnumerationPortScanGroupDownPosition      = 18
$EnumerationPortScanGroupDownPositionShift = 25

    #----------------------------------------
    # Enumeration - Port Scan - Specific IPs
    #----------------------------------------
    $EnumerationPortScanIPNote1Label            = New-Object System.Windows.Forms.Label
    $EnumerationPortScanIPNote1Label.Location   = New-Object System.Drawing.Point($EnumerationRightPosition,($EnumerationPortScanGroupDownPosition + 3)) 
    $EnumerationPortScanIPNote1Label.Size       = New-Object System.Drawing.Size(170,22) 
    $EnumerationPortScanIPNote1Label.Text       = "Enter Comma Separated IPs"
    $EnumerationPortScanIPNote1Label.Font       = New-Object System.Drawing.Font("$Font",10,1,2,1)
    $EnumerationPortScanIPNote1Label.ForeColor  = "Black"
    $EnumerationPortScanGroupBox.Controls.Add($EnumerationPortScanIPNote1Label)

    $EnumerationPortScanIPNote2Label            = New-Object System.Windows.Forms.Label
    $EnumerationPortScanIPNote2Label.Location   = New-Object System.Drawing.Point(($EnumerationPortScanIPNote1Label.Size.Width + 3),($EnumerationPortScanGroupDownPosition + 4)) 
    $EnumerationPortScanIPNote2Label.Size       = New-Object System.Drawing.Size(110,20) 
    $EnumerationPortScanIPNote2Label.Text       = "(ex: 10.0.0.1,10.0.0.2)"
    $EnumerationPortScanIPNote2Label.Font       = New-Object System.Drawing.Font("$Font",9,0,2,1)
    $EnumerationPortScanIPNote2Label.ForeColor  = "Black"
    $EnumerationPortScanGroupBox.Controls.Add($EnumerationPortScanIPNote2Label)

    $EnumerationPortScanGroupDownPosition += $EnumerationPortScanGroupDownPositionShift

    #--------------------------------------------------------------
    # Enumeration - Port Scan - Enter Specific Comma Separated IPs
    #--------------------------------------------------------------
    $EnumerationPortScanSpecificIPTextbox               = New-Object System.Windows.Forms.TextBox
    $EnumerationPortScanSpecificIPTextbox.Location      = New-Object System.Drawing.Size($EnumerationRightPosition,$EnumerationPortScanGroupDownPosition) 
    $EnumerationPortScanSpecificIPTextbox.Size          = New-Object System.Drawing.Size(287,22)
    $EnumerationPortScanSpecificIPTextbox.MultiLine     = $False
    $EnumerationPortScanSpecificIPTextbox.WordWrap      = True
    $EnumerationPortScanSpecificIPTextbox.AcceptsTab    = false # Allows you to enter in tabs into the textbox
    $EnumerationPortScanSpecificIPTextbox.AcceptsReturn = false # Allows you to enter in returnss into the textbox
    $EnumerationPortScanSpecificIPTextbox.Text          = ""
    $EnumerationPortScanSpecificIPTextbox.Font          = New-Object System.Drawing.Font("$Font",10,0,2,1)
    $EnumerationPortScanSpecificIPTextbox.ForeColor     = "Black"
    #$EnumerationPortScanSpecificIPTextbox.Add_KeyDown({ 
    #    if ($_.KeyCode -eq "Enter") { Conduct-PortScan }
    #})
    $EnumerationPortScanGroupBox.Controls.Add($EnumerationPortScanSpecificIPTextbox)

    $EnumerationPortScanGroupDownPosition += $EnumerationPortScanGroupDownPositionShift

    #------------------------------------
    # Enumeration - Port Scan - IP Range
    #------------------------------------
    $EnumerationPortScanIPRangeNote1Label            = New-Object System.Windows.Forms.Label
    $EnumerationPortScanIPRangeNote1Label.Location   = New-Object System.Drawing.Point($EnumerationRightPosition,($EnumerationPortScanGroupDownPosition + 3)) 
    $EnumerationPortScanIPRangeNote1Label.Size       = New-Object System.Drawing.Size(143,22) 
    $EnumerationPortScanIPRangeNote1Label.Text       = "Network Range:"
    $EnumerationPortScanIPRangeNote1Label.Font       = New-Object System.Drawing.Font("$Font",10,1,2,1)
    $EnumerationPortScanIPRangeNote1Label.ForeColor  = "Black"
    $EnumerationPortScanGroupBox.Controls.Add($EnumerationPortScanIPRangeNote1Label)

    $EnumerationPortScanIPRangeNote2Label            = New-Object System.Windows.Forms.Label
    $EnumerationPortScanIPRangeNote2Label.Location   = New-Object System.Drawing.Point(($EnumerationPortScanIPRangeNote1Label.Size.Width + 3),($EnumerationPortScanGroupDownPosition + 4)) 
    $EnumerationPortScanIPRangeNote2Label.Size       = New-Object System.Drawing.Size(150,20) 
    $EnumerationPortScanIPRangeNote2Label.Text       = "(ex: [ 192.168.1 ]   [ 1 ]   [ 100 ])"
    $EnumerationPortScanIPRangeNote2Label.Font       = New-Object System.Drawing.Font("$Font",9,0,2,1)
    $EnumerationPortScanIPRangeNote2Label.ForeColor  = "Black"
    $EnumerationPortScanGroupBox.Controls.Add($EnumerationPortScanIPRangeNote2Label)


    $EnumerationPortScanGroupDownPosition += $EnumerationPortScanGroupDownPositionShift
    $RightShift = $EnumerationRightPosition

    $EnumerationPortScanIPRangeNetworkLabel           = New-Object System.Windows.Forms.Label
    $EnumerationPortScanIPRangeNetworkLabel.Location  = New-Object System.Drawing.Point($RightShift,($EnumerationPortScanGroupDownPosition + 3)) 
    $EnumerationPortScanIPRangeNetworkLabel.Size      = New-Object System.Drawing.Size(45,22) 
    $EnumerationPortScanIPRangeNetworkLabel.Text      = "Network"
    $EnumerationPortScanIPRangeNetworkLabel.Font      = New-Object System.Drawing.Font("$Font",10,0,2,1)
    $EnumerationPortScanIPRangeNetworkLabel.ForeColor = "Black"
    $EnumerationPortScanGroupBox.Controls.Add($EnumerationPortScanIPRangeNetworkLabel)

    $RightShift += $EnumerationPortScanIPRangeNetworkLabel.Size.Width

    $EnumerationPortScanIPRangeNetworkTextbox               = New-Object System.Windows.Forms.TextBox
    $EnumerationPortScanIPRangeNetworkTextbox.Location      = New-Object System.Drawing.Size($RightShift,$EnumerationPortScanGroupDownPosition) 
    $EnumerationPortScanIPRangeNetworkTextbox.Size          = New-Object System.Drawing.Size(82,22)
    $EnumerationPortScanIPRangeNetworkTextbox.MultiLine     = $False
    $EnumerationPortScanIPRangeNetworkTextbox.WordWrap      = True
    $EnumerationPortScanIPRangeNetworkTextbox.AcceptsTab    = false # Allows you to enter in tabs into the textbox
    $EnumerationPortScanIPRangeNetworkTextbox.AcceptsReturn = false # Allows you to enter in returnss into the textbox
    $EnumerationPortScanIPRangeNetworkTextbox.Text          = ""
    $EnumerationPortScanIPRangeNetworkTextbox.Font          = New-Object System.Drawing.Font("$Font",10,0,2,1)
    $EnumerationPortScanIPRangeNetworkTextbox.ForeColor     = "Black"
    $EnumerationPortScanGroupBox.Controls.Add($EnumerationPortScanIPRangeNetworkTextbox)

    $RightShift += $EnumerationPortScanIPRangeNetworkTextbox.Size.Width

    $EnumerationPortScanIPRangeFirstLabel           = New-Object System.Windows.Forms.Label
    $EnumerationPortScanIPRangeFirstLabel.Location  = New-Object System.Drawing.Point($RightShift,($EnumerationPortScanGroupDownPosition + 3)) 
    $EnumerationPortScanIPRangeFirstLabel.Size      = New-Object System.Drawing.Size(40,22) 
    $EnumerationPortScanIPRangeFirstLabel.Text      = "First IP"
    $EnumerationPortScanIPRangeFirstLabel.Font      = New-Object System.Drawing.Font("$Font",10,0,2,1)
    $EnumerationPortScanIPRangeFirstLabel.ForeColor = "Black"
    $EnumerationPortScanGroupBox.Controls.Add($EnumerationPortScanIPRangeFirstLabel)

    $RightShift += $EnumerationPortScanIPRangeFirstLabel.Size.Width

    $EnumerationPortScanIPRangeFirstTextbox               = New-Object System.Windows.Forms.TextBox
    $EnumerationPortScanIPRangeFirstTextbox.Location      = New-Object System.Drawing.Size($RightShift,$EnumerationPortScanGroupDownPosition) 
    $EnumerationPortScanIPRangeFirstTextbox.Size          = New-Object System.Drawing.Size(40,22)
    $EnumerationPortScanIPRangeFirstTextbox.MultiLine     = $False
    $EnumerationPortScanIPRangeFirstTextbox.WordWrap      = True
    $EnumerationPortScanIPRangeFirstTextbox.AcceptsTab    = false # Allows you to enter in tabs into the textbox
    $EnumerationPortScanIPRangeFirstTextbox.AcceptsReturn = false # Allows you to enter in returnss into the textbox
    $EnumerationPortScanIPRangeFirstTextbox.Text          = ""
    $EnumerationPortScanIPRangeFirstTextbox.Font          = New-Object System.Drawing.Font("$Font",10,0,2,1)
    $EnumerationPortScanIPRangeFirstTextbox.ForeColor     = "Black"
    $EnumerationPortScanGroupBox.Controls.Add($EnumerationPortScanIPRangeFirstTextbox)

    $RightShift += $EnumerationPortScanIPRangeFirstTextbox.Size.Width

    $EnumerationPortScanIPRangeLastLabel           = New-Object System.Windows.Forms.Label
    $EnumerationPortScanIPRangeLastLabel.Location  = New-Object System.Drawing.Point($RightShift,($EnumerationPortScanGroupDownPosition + 3)) 
    $EnumerationPortScanIPRangeLastLabel.Size      = New-Object System.Drawing.Size(40,22) 
    $EnumerationPortScanIPRangeLastLabel.Text      = "Last IP"
    $EnumerationPortScanIPRangeLastLabel.Font      = New-Object System.Drawing.Font("$Font",10,0,2,1)
    $EnumerationPortScanIPRangeLastLabel.ForeColor = "Black"
    $EnumerationPortScanGroupBox.Controls.Add($EnumerationPortScanIPRangeLastLabel)

    $RightShift += $EnumerationPortScanIPRangeLastLabel.Size.Width

    $EnumerationPortScanIPRangeLastTextbox               = New-Object System.Windows.Forms.TextBox
    $EnumerationPortScanIPRangeLastTextbox.Location      = New-Object System.Drawing.Size($RightShift,$EnumerationPortScanGroupDownPosition) 
    $EnumerationPortScanIPRangeLastTextbox.Size          = New-Object System.Drawing.Size(40,22)
    $EnumerationPortScanIPRangeLastTextbox.MultiLine     = $False
    $EnumerationPortScanIPRangeLastTextbox.WordWrap      = True
    $EnumerationPortScanIPRangeLastTextbox.AcceptsTab    = false # Allows you to enter in tabs into the textbox
    $EnumerationPortScanIPRangeLastTextbox.AcceptsReturn = false # Allows you to enter in returnss into the textbox
    $EnumerationPortScanIPRangeLastTextbox.Text          = ""
    $EnumerationPortScanIPRangeLastTextbox.Font          = New-Object System.Drawing.Font("$Font",10,0,2,1)
    $EnumerationPortScanIPRangeLastTextbox.ForeColor     = "Black"
    $EnumerationPortScanGroupBox.Controls.Add($EnumerationPortScanIPRangeLastTextbox)

    $EnumerationPortScanGroupDownPosition += $EnumerationPortScanGroupDownPositionShift

    #------------------------------------------
    # Enumeration - Port Scan - Specific Ports
    #------------------------------------------
    $EnumerationPortScanPortNote1Label            = New-Object System.Windows.Forms.Label
    $EnumerationPortScanPortNote1Label.Location   = New-Object System.Drawing.Point($EnumerationRightPosition,($EnumerationPortScanGroupDownPosition + 3)) 
    $EnumerationPortScanPortNote1Label.Size       = New-Object System.Drawing.Size(170,22) 
    $EnumerationPortScanPortNote1Label.Text       = "Enter Comma Separated Ports"
    $EnumerationPortScanPortNote1Label.Font       = New-Object System.Drawing.Font("$Font",10,1,2,1)
    $EnumerationPortScanPortNote1Label.ForeColor  = "Black"
    $EnumerationPortScanGroupBox.Controls.Add($EnumerationPortScanPortNote1Label)

    $EnumerationPortScanPortNote2Label            = New-Object System.Windows.Forms.Label
    $EnumerationPortScanPortNote2Label.Location   = New-Object System.Drawing.Point(($EnumerationPortScanPortNote1Label.Size.Width + 3),($EnumerationPortScanGroupDownPosition + 4)) 
    $EnumerationPortScanPortNote2Label.Size       = New-Object System.Drawing.Size(110,20)
    $EnumerationPortScanPortNote2Label.Text       = "(ex: 22,139,80,443,445)"
    $EnumerationPortScanPortNote2Label.Font       = New-Object System.Drawing.Font("$Font",9,0,2,1)
    $EnumerationPortScanPortNote2Label.ForeColor  = "Black"
    $EnumerationPortScanGroupBox.Controls.Add($EnumerationPortScanPortNote2Label)

    $EnumerationPortScanGroupDownPosition += $EnumerationPortScanGroupDownPositionShift

    $EnumerationPortScanSpecificPortsTextbox               = New-Object System.Windows.Forms.TextBox
    $EnumerationPortScanSpecificPortsTextbox.Location      = New-Object System.Drawing.Size($EnumerationRightPosition,$EnumerationPortScanGroupDownPosition) 
    $EnumerationPortScanSpecificPortsTextbox.Size          = New-Object System.Drawing.Size(288,22)
    $EnumerationPortScanSpecificPortsTextbox.MultiLine     = $False
    $EnumerationPortScanSpecificPortsTextbox.WordWrap      = True
    $EnumerationPortScanSpecificPortsTextbox.AcceptsTab    = false # Allows you to enter in tabs into the textbox
    $EnumerationPortScanSpecificPortsTextbox.AcceptsReturn = false # Allows you to enter in returnss into the textbox
    $EnumerationPortScanSpecificPortsTextbox.Text          = ""
    $EnumerationPortScanSpecificPortsTextbox.Font          = New-Object System.Drawing.Font("$Font",10,0,2,1)
    $EnumerationPortScanSpecificPortsTextbox.ForeColor     = "Black"
    #$EnumerationPortScanSpecificPortsTextbox.Add_KeyDown({ 
    #    if ($_.KeyCode -eq "Enter") { Conduct-PortScan }
    #})
    $EnumerationPortScanGroupBox.Controls.Add($EnumerationPortScanSpecificPortsTextbox)

    $EnumerationPortScanGroupDownPosition += $EnumerationPortScanGroupDownPositionShift

    #-----------------------------------------------------
    # Enumeration - Port Scan - Ports Quick Pick ComboBox
    #-----------------------------------------------------

    $EnumerationPortScanPortQuickPickComboBox               = New-Object System.Windows.Forms.ComboBox
    $EnumerationPortScanPortQuickPickComboBox.Location      = New-Object System.Drawing.Size($EnumerationRightPosition,$EnumerationPortScanGroupDownPosition) 
    $EnumerationPortScanPortQuickPickComboBox.Size          = New-Object System.Drawing.Size(183,20)
    $EnumerationPortScanPortQuickPickComboBox.Text          = "Quick-Pick Port Selection"
    $EnumerationPortScanPortQuickPickComboBox.Font          = New-Object System.Drawing.Font("$Font",10,0,2,1)
    $EnumerationPortScanPortQuickPickComboBox.ForeColor     = "Black"
    $EnumerationPortScanPortQuickPickComboBox.Items.Add("Nmap Top 100 Ports")
    $EnumerationPortScanPortQuickPickComboBox.Items.Add("Nmap Top 1000 Ports")
    $EnumerationPortScanPortQuickPickComboBox.Items.Add("Well-Known Ports (0-1023)")
    $EnumerationPortScanPortQuickPickComboBox.Items.Add("Registered Ports (1024-49151)")
    $EnumerationPortScanPortQuickPickComboBox.Items.Add("Dynamic Ports (49152-65535)")
    $EnumerationPortScanPortQuickPickComboBox.Items.Add("All Ports (0-65535)")
    $EnumerationPortScanPortQuickPickComboBox.Items.Add("Last Ports Scanned")
    $EnumerationPortScanPortQuickPickComboBox.Items.Add("Custom Saved Ports")
    #$EnumerationPortScanPortQuickPickComboBox.Add_KeyDown({ 
    #    if ($_.KeyCode -eq "Enter") { Conduct-PortScan }
    #})
    $EnumerationPortScanGroupBox.Controls.Add($EnumerationPortScanPortQuickPickComboBox)

    #-------------------------------------------------
    # Enumeration - Port Scan - Port Selection Button
    #-------------------------------------------------
    if (Test-Path "$ResourcesDirectory\Ports, Protocols, and Services.csv") {
        $EnumerationPortScanPortsSelectionButton           = New-Object System.Windows.Forms.Button
        $EnumerationPortScanPortsSelectionButton.Text      = "Select Ports"
        $EnumerationPortScanPortsSelectionButton.Location  = New-Object System.Drawing.Size(($EnumerationPortScanPortQuickPickComboBox.Size.Width + 8),$EnumerationPortScanGroupDownPosition) 
        $EnumerationPortScanPortsSelectionButton.Size      = New-Object System.Drawing.Size(100,20) 
        $EnumerationPortScanPortsSelectionButton.Font      = New-Object System.Drawing.Font("$Font",12,0,2,1)
        $EnumerationPortScanPortsSelectionButton.ForeColor = "Black"
        $EnumerationPortScanPortsSelectionButton.add_click({
            Import-Csv "$ResourcesDirectory\Ports, Protocols, and Services.csv" | Out-GridView -OutputMode Multiple | Set-Variable -Name PortManualEntrySelectionContents
            $PortsColumn = $PortManualEntrySelectionContents | Select-Object -ExpandProperty "Port"
            $PortsToBeScan = ""
            Foreach ($Port in $PortsColumn) {
                $PortsToBeScan += "$Port,"
            }       
            $EnumerationPortScanSpecificPortsTextbox.Text += $("," + $PortsToBeScan)
            $EnumerationPortScanSpecificPortsTextbox.Text = $EnumerationPortScanSpecificPortsTextbox.Text.Trim(",")
        })
        $EnumerationPortScanGroupBox.Controls.Add($EnumerationPortScanPortsSelectionButton) 
    }

    $EnumerationPortScanGroupDownPosition += $EnumerationPortScanGroupDownPositionShift

    #--------------------------------------
    # Enumeration - Port Scan - Port Range
    #--------------------------------------

    $EnumerationPortScanRightShift = $EnumerationRightPosition

    $EnumerationPortScanPortRangeNetworkLabel           = New-Object System.Windows.Forms.Label
    $EnumerationPortScanPortRangeNetworkLabel.Location  = New-Object System.Drawing.Point($EnumerationPortScanRightShift,($EnumerationPortScanGroupDownPosition + 3)) 
    $EnumerationPortScanPortRangeNetworkLabel.Size      = New-Object System.Drawing.Size(83,22) 
    $EnumerationPortScanPortRangeNetworkLabel.Text      = "Port Range"
    $EnumerationPortScanPortRangeNetworkLabel.Font      = New-Object System.Drawing.Font("$Font",10,1,2,1)
    $EnumerationPortScanPortRangeNetworkLabel.ForeColor = "Black"
    $EnumerationPortScanGroupBox.Controls.Add($EnumerationPortScanPortRangeNetworkLabel)

    $EnumerationPortScanRightShift += $EnumerationPortScanPortRangeNetworkLabel.Size.Width

    $EnumerationPortScanPortRangeFirstLabel           = New-Object System.Windows.Forms.Label
    $EnumerationPortScanPortRangeFirstLabel.Location  = New-Object System.Drawing.Point($EnumerationPortScanRightShift,($EnumerationPortScanGroupDownPosition + 3)) 
    $EnumerationPortScanPortRangeFirstLabel.Size      = New-Object System.Drawing.Size(50,22) 
    $EnumerationPortScanPortRangeFirstLabel.Text      = "First Port"
    $EnumerationPortScanPortRangeFirstLabel.Font      = New-Object System.Drawing.Font("$Font",10,0,2,1)
    $EnumerationPortScanPortRangeFirstLabel.ForeColor = "Black"
    $EnumerationPortScanGroupBox.Controls.Add($EnumerationPortScanPortRangeFirstLabel)

    $EnumerationPortScanRightShift += $EnumerationPortScanPortRangeFirstLabel.Size.Width

    $EnumerationPortScanPortRangeFirstTextbox               = New-Object System.Windows.Forms.TextBox
    $EnumerationPortScanPortRangeFirstTextbox.Location      = New-Object System.Drawing.Size($EnumerationPortScanRightShift,$EnumerationPortScanGroupDownPosition) 
    $EnumerationPortScanPortRangeFirstTextbox.Size          = New-Object System.Drawing.Size(50,22)
    $EnumerationPortScanPortRangeFirstTextbox.MultiLine     = $False
    $EnumerationPortScanPortRangeFirstTextbox.WordWrap      = True
    $EnumerationPortScanPortRangeFirstTextbox.AcceptsTab    = false # Allows you to enter in tabs into the textbox
    $EnumerationPortScanPortRangeFirstTextbox.AcceptsReturn = false # Allows you to enter in returnss into the textbox
    $EnumerationPortScanPortRangeFirstTextbox.Text          = ""
    $EnumerationPortScanPortRangeFirstTextbox.Font          = New-Object System.Drawing.Font("$Font",10,0,2,1)
    $EnumerationPortScanPortRangeFirstTextbox.ForeColor     = "Black"
    $EnumerationPortScanGroupBox.Controls.Add($EnumerationPortScanPortRangeFirstTextbox)

    $EnumerationPortScanRightShift += $EnumerationPortScanPortRangeFirstTextbox.Size.Width + 4

    $EnumerationPortScanPortRangeLastLabel           = New-Object System.Windows.Forms.Label
    $EnumerationPortScanPortRangeLastLabel.Location  = New-Object System.Drawing.Point($EnumerationPortScanRightShift,($EnumerationPortScanGroupDownPosition + 3)) 
    $EnumerationPortScanPortRangeLastLabel.Size      = New-Object System.Drawing.Size(50,22) 
    $EnumerationPortScanPortRangeLastLabel.Text      = "Last Port"
    $EnumerationPortScanPortRangeLastLabel.Font      = New-Object System.Drawing.Font("$Font",10,0,2,1)
    $EnumerationPortScanPortRangeLastLabel.ForeColor = "Black"
    $EnumerationPortScanGroupBox.Controls.Add($EnumerationPortScanPortRangeLastLabel)

    $EnumerationPortScanRightShift += $EnumerationPortScanPortRangeLastLabel.Size.Width

    $EnumerationPortScanPortRangeLastTextbox               = New-Object System.Windows.Forms.TextBox
    $EnumerationPortScanPortRangeLastTextbox.Location      = New-Object System.Drawing.Size($EnumerationPortScanRightShift,$EnumerationPortScanGroupDownPosition) 
    $EnumerationPortScanPortRangeLastTextbox.Size          = New-Object System.Drawing.Size(50,22)
    $EnumerationPortScanPortRangeLastTextbox.MultiLine     = $False
    $EnumerationPortScanPortRangeLastTextbox.WordWrap      = True
    $EnumerationPortScanPortRangeLastTextbox.AcceptsTab    = false # Allows you to enter in tabs into the textbox
    $EnumerationPortScanPortRangeLastTextbox.AcceptsReturn = false # Allows you to enter in returnss into the textbox
    $EnumerationPortScanPortRangeLastTextbox.Text          = ""
    $EnumerationPortScanPortRangeLastTextbox.Font          = New-Object System.Drawing.Font("$Font",10,0,2,1)
    $EnumerationPortScanPortRangeLastTextbox.ForeColor     = "Black"
    $EnumerationPortScanGroupBox.Controls.Add($EnumerationPortScanPortRangeLastTextbox)

    $EnumerationPortScanGroupDownPosition += $EnumerationPortScanGroupDownPositionShift

    #--------------------------------------
    # Enumeration - Port Scan - Port Range
    #--------------------------------------

    $EnumerationPortScanRightShift = $EnumerationRightPosition

    $EnumerationPortScanTestICMPFirstCheckBox           = New-Object System.Windows.Forms.CheckBox
    $EnumerationPortScanTestICMPFirstCheckBox.Location  = New-Object System.Drawing.Point($EnumerationPortScanRightShift,($EnumerationPortScanGroupDownPosition)) 
    $EnumerationPortScanTestICMPFirstCheckBox.Size      = New-Object System.Drawing.Size(130,22) 
    $EnumerationPortScanTestICMPFirstCheckBox.Text      = "Test ICMP First (ping)"
    $EnumerationPortScanTestICMPFirstCheckBox.Font      = New-Object System.Drawing.Font("$Font",10,1,2,1)
    $EnumerationPortScanTestICMPFirstCheckBox.ForeColor = "Black"
    $EnumerationPortScanTestICMPFirstCheckBox.Checked   = $False
    $EnumerationPortScanGroupBox.Controls.Add($EnumerationPortScanTestICMPFirstCheckBox)

    $EnumerationPortScanRightShift += $EnumerationPortScanTestICMPFirstCheckBox.Size.Width + 32

    $EnumerationPortScanTimeoutLabel           = New-Object System.Windows.Forms.Label
    $EnumerationPortScanTimeoutLabel.Location  = New-Object System.Drawing.Point($EnumerationPortScanRightShift,($EnumerationPortScanGroupDownPosition + 3)) 
    $EnumerationPortScanTimeoutLabel.Size      = New-Object System.Drawing.Size(75,22) 
    $EnumerationPortScanTimeoutLabel.Text      = "Timeout (ms)"
    $EnumerationPortScanTimeoutLabel.Font      = New-Object System.Drawing.Font("$Font",10,1,2,1)
    $EnumerationPortScanTimeoutLabel.ForeColor = "Black"
    $EnumerationPortScanGroupBox.Controls.Add($EnumerationPortScanTimeoutLabel)

    $EnumerationPortScanRightShift += $EnumerationPortScanTimeoutLabel.Size.Width

    $EnumerationPortScanTimeoutTextbox               = New-Object System.Windows.Forms.TextBox
    $EnumerationPortScanTimeoutTextbox.Location      = New-Object System.Drawing.Size($EnumerationPortScanRightShift,$EnumerationPortScanGroupDownPosition) 
    $EnumerationPortScanTimeoutTextbox.Size          = New-Object System.Drawing.Size(50,22)
    $EnumerationPortScanTimeoutTextbox.MultiLine     = $False
    $EnumerationPortScanTimeoutTextbox.WordWrap      = True
    $EnumerationPortScanTimeoutTextbox.AcceptsTab    = false # Allows you to enter in tabs into the textbox
    $EnumerationPortScanTimeoutTextbox.AcceptsReturn = false # Allows you to enter in returnss into the textbox
    $EnumerationPortScanTimeoutTextbox.Text          = 50
    $EnumerationPortScanTimeoutTextbox.Font          = New-Object System.Drawing.Font("$Font",10,0,2,1)
    $EnumerationPortScanTimeoutTextbox.ForeColor     = "Black"
    $EnumerationPortScanGroupBox.Controls.Add($EnumerationPortScanTimeoutTextbox)

    $EnumerationPortScanRightShift        += $EnumerationPortScanTimeoutTextbox.Size.Width
    $EnumerationPortScanGroupDownPosition += $EnumerationPortScanGroupDownPositionShift

    #------------------------------------------
    # Enumeration - Port Scan - Execute Button
    #------------------------------------------
    $EnumerationPortScanExecutionButton           = New-Object System.Windows.Forms.Button
    $EnumerationPortScanExecutionButton.Text      = "Execute Scan"
    $EnumerationPortScanExecutionButton.Location  = New-Object System.Drawing.Size(190,$EnumerationPortScanGroupDownPosition)
    $EnumerationPortScanExecutionButton.Size      = New-Object System.Drawing.Size(100,22)
    $EnumerationPortScanExecutionButton.Font      = New-Object System.Drawing.Font("$Font",12,0,2,1)
    $EnumerationPortScanExecutionButton.ForeColor = "Red"
    $EnumerationPortScanExecutionButton.add_click({ 
        Conduct-PortScan -Timeout_ms $EnumerationPortScanTimeoutTextbox.Text -TestWithICMPFirst $EnumerationPortScanTestICMPFirstCheckBox.Checked -SpecificIPsToScan $EnumerationPortScanSpecificIPTextbox.Text -SpecificPortsToScan $EnumerationPortScanSpecificPortsTextbox.Text -Network $EnumerationPortScanIPRangeNetworkTextbox.Text -FirstIP $EnumerationPortScanIPRangeFirstTextbox.Text -LastIP $EnumerationPortScanIPRangeLastTextbox.Text -FirstPort $EnumerationPortScanPortRangeFirstTextbox.Text -LastPort $EnumerationPortScanPortRangeLastTextbox.Text
    })
    $EnumerationPortScanGroupBox.Controls.Add($EnumerationPortScanExecutionButton) 
                
$Section1EnumerationTab.Controls.Add($EnumerationPortScanGroupBox) 

#============================================================================================================================================================
# Enumeration - Ping Sweep
#============================================================================================================================================================

Function Conduct-PingSweep {
    Function Create-PingList {
        param($IPAddress)
        $Comp = $IPAddress
        if ($Comp -eq $Null) { . Create-PingList } 
        elseif ($Comp -match "\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/\d{1,2}") {
            $Temp = $Comp.Split("/")
            $IP = $Temp[0]
            $Mask = $Temp[1]
            . Get-Subnet-Range $IP $Mask
            $global:PingList = $Script:IPList
        }
        Else { $global:PingList = $Comp }
    }
    . Create-PingList $EnumerationPingSweepIPNetworkCIDRTextbox.Text
    $EnumerationComputerListBox.Items.Clear()

    foreach ($Computer in $PingList) {
        #$EnumerationComputerListBox.Items.Add($Computer)
        $ping = Test-Connection $Computer -Count 1
        $StatusListBox.Items.Clear()
        $StatusListBox.Items.Add("Pinging: $Computer")
        $LogMessage = "$((Get-Date).ToString('yyyy/MM/dd HH:mm:ss')) - $ping"
        $LogMessage | Add-Content -Path $LogFile
        if($ping){$EnumerationComputerListBox.Items.Insert(0,"$Computer")}
    }
    $StatusListBox.Items.Clear()
    $StatusListBox.Items.Add("Finished with Ping Sweep!")
    #Start-Sleep -Seconds 2
    #$StatusListBox.Items.Clear()
}

#-------------------------------------
# Enumeration - Ping Sweep - GroupBox
#-------------------------------------
# Create a group that will contain your radio buttons
$EnumerationPingSweepGroupBox           = New-Object System.Windows.Forms.GroupBox
$EnumerationPingSweepGroupBox.Location  = New-Object System.Drawing.Size(0,($EnumerationPortScanGroupBox.Location.Y + $EnumerationPortScanGroupBox.Size.Height + $EnumerationGroupGap))
$EnumerationPingSweepGroupBox.size      = New-Object System.Drawing.Size(294,70)
$EnumerationPingSweepGroupBox.text      = "Create List From Ping Sweep"
$EnumerationPingSweepGroupBox.Font      = New-Object System.Drawing.Font("$Font",12,1,2,1)
$EnumerationPingSweepGroupBox.ForeColor = "Blue"

$EnumerationPingSweepGroupDownPosition      = 18
$EnumerationPingSweepGroupDownPositionShift = 25

    #-------------------------------------------------
    # Enumeration - Ping Sweep - Network & CIDR Label
    #-------------------------------------------------
    $EnumerationPingSweepNote1Label            = New-Object System.Windows.Forms.Label
    $EnumerationPingSweepNote1Label.Location   = New-Object System.Drawing.Point($EnumerationRightPosition,($EnumerationPingSweepGroupDownPosition + 3)) 
    $EnumerationPingSweepNote1Label.Size       = New-Object System.Drawing.Size(105,22) 
    $EnumerationPingSweepNote1Label.Text       = "Enter Network/CIDR:"
    $EnumerationPingSweepNote1Label.Font       = New-Object System.Drawing.Font("$Font",10,1,2,1)
    $EnumerationPingSweepNote1Label.ForeColor  = "Black"
    $EnumerationPingSweepGroupBox.Controls.Add($EnumerationPingSweepNote1Label)

    $EnumerationPingSweepNote2Label            = New-Object System.Windows.Forms.Label
    $EnumerationPingSweepNote2Label.Location   = New-Object System.Drawing.Point(($EnumerationPingSweepNote1Label.Size.Width + 5),($EnumerationPingSweepGroupDownPosition + 4)) 
    $EnumerationPingSweepNote2Label.Size       = New-Object System.Drawing.Size(80,22)
    $EnumerationPingSweepNote2Label.Text       = "(ex: 10.0.0.0/24)"
    $EnumerationPingSweepNote2Label.Font       = New-Object System.Drawing.Font("$Font",9,0,2,1)
    $EnumerationPingSweepNote2Label.ForeColor  = "Black"
    $EnumerationPingSweepGroupBox.Controls.Add($EnumerationPingSweepNote2Label)

    #---------------------------------------------------
    # Enumeration - Ping Sweep - Network & CIDR Textbox
    #---------------------------------------------------
    $EnumerationPingSweepIPNetworkCIDRTextbox               = New-Object System.Windows.Forms.TextBox
    $EnumerationPingSweepIPNetworkCIDRTextbox.Location      = New-Object System.Drawing.Size(190,($EnumerationPingSweepGroupDownPosition)) 
    $EnumerationPingSweepIPNetworkCIDRTextbox.Size          = New-Object System.Drawing.Size(100,$EnumerationLabelHeight)
    $EnumerationPingSweepIPNetworkCIDRTextbox.MultiLine     = $False
    $EnumerationPingSweepIPNetworkCIDRTextbox.WordWrap      = True
    $EnumerationPingSweepIPNetworkCIDRTextbox.AcceptsTab    = false # Allows you to enter in tabs into the textbox
    $EnumerationPingSweepIPNetworkCIDRTextbox.AcceptsReturn = false # Allows you to enter in returnss into the textbox
    $EnumerationPingSweepIPNetworkCIDRTextbox.Text          = ""
    $EnumerationPingSweepIPNetworkCIDRTextbox.Font          = New-Object System.Drawing.Font("$Font",10,0,2,1)
    $EnumerationPingSweepIPNetworkCIDRTextbox.ForeColor     = "Black"
    $EnumerationPingSweepIPNetworkCIDRTextbox.Add_KeyDown({
        if ($_.KeyCode -eq "Enter") { Conduct-PingSweep }
    })
    $EnumerationPingSweepGroupBox.Controls.Add($EnumerationPingSweepIPNetworkCIDRTextbox)

    # Shift the fields
    $EnumerationPingSweepGroupDownPosition += $EnumerationPingSweepGroupDownPositionShift

    #-------------------------------------------
    # Enumeration - Ping Sweep - Execute Button
    #-------------------------------------------
    $EnumerationPingSweepExecutionButton          = New-Object System.Windows.Forms.Button
    $EnumerationPingSweepExecutionButton.Text     = "Execute Sweep"
    $EnumerationPingSweepExecutionButton.Location = New-Object System.Drawing.Size(190,$EnumerationPingSweepGroupDownPosition)
    $EnumerationPingSweepExecutionButton.Size     = New-Object System.Drawing.Size(100,22)
    $EnumerationPingSweepExecutionButton.Font      = New-Object System.Drawing.Font("$Font",12,0,2,1)
    $EnumerationPingSweepExecutionButton.ForeColor = "Red"
    $EnumerationPingSweepExecutionButton.add_click({ 
        Conduct-PingSweep
    })
    $EnumerationPingSweepGroupBox.Controls.Add($EnumerationPingSweepExecutionButton) 

$Section1EnumerationTab.Controls.Add($EnumerationPingSweepGroupBox) 

#============================================================================================================================================================
# Enumeration - Computer List ListBox
#============================================================================================================================================================
$EnumerationComputerListBox               = New-Object System.Windows.Forms.ListBox
$EnumerationComputerListBox.Location      = New-Object System.Drawing.Size(297,10)
$EnumerationComputerListBox.Size          = New-Object System.Drawing.Size(150,480)
$EnumerationComputerListBox.SelectionMode = 'MultiExtended'
$EnumerationComputerListBox.Items.Add("127.0.0.1")
$EnumerationComputerListBox.Items.Add("localhost")
$Section1EnumerationTab.Controls.Add($EnumerationComputerListBox)

#----------------------------------
# Single Host - Add To List Button
#----------------------------------
$EnumerationComputerListBoxAddToListButton          = New-Object System.Windows.Forms.Button
$EnumerationComputerListBoxAddToListButton.Text     = "Add To Computer List"
$EnumerationComputerListBoxAddToListButton.Location = New-Object System.Drawing.Size(($EnumerationComputerListBox.Location.X - 1),($EnumerationComputerListBox.Location.Y + $EnumerationComputerListBox.Size.Height - 3))
$EnumerationComputerListBoxAddToListButton.Size     = New-Object System.Drawing.Size(($EnumerationComputerListBox.Size.Width + 2),22) 
$EnumerationComputerListBoxAddToListButton.add_click({
    $StatusListBox.Items.Clear()
    $StatusListBox.Items.Add("Enumeration:  Added $($EnumerationComputerListBox.SelectedItems.Count) IPs")
    $MainListBox.Items.Clear()
    foreach ($Selected in $EnumerationComputerListBox.SelectedItems) {      
        if ($script:ComputerListTreeViewData.Name -contains $Selected) {
            $StatusListBox.Items.Clear()
            $StatusListBox.Items.Add("Port Scan Import:  Warning")
            $MainListBox.Items.Add("$($Selected) already exists with the following data:")
            $MainListBox.Items.Add("- OU/CN: $($($script:ComputerListTreeViewData | Where-Object {$_.Name -eq $Selected}).CanonicalName)")
            $MainListBox.Items.Add("- OS:    $($($script:ComputerListTreeViewData | Where-Object {$_.Name -eq $Selected}).OperatingSystem)")
            $MainListBox.Items.Add("")
        }
        else {
            if ($ComputerListOSHostnameRadioButton.Checked) {
                Add-Node -RootNode $script:TreeNode -Category 'Unknown' -Entry $Selected #-ToolTip $Computer.IPv4Address
                $MainListBox.Items.Add("$($Selected) has been added to the Unknown category")
            }
            elseif ($ComputerListOUHostnameRadioButton.Checked) {
                $CanonicalName = $($($Computer.CanonicalName) -replace $Computer.Name,"" -replace $Computer.CanonicalName.split('/')[0],"").TrimEnd("/")
                Add-Node -RootNode $script:TreeNode -Category '/Unknown' -Entry $Selected #-ToolTip $Computer.IPv4Address
                $MainListBox.Items.Add("$($Selected) has been added to /Unknown category")
            }
            $ComputerListTreeViewAddHostnameIP = New-Object PSObject -Property @{ 
                Name            = $Selected
                OperatingSystem = 'Unknown'
                CanonicalName   = '/Unknown'
                IPv4Address     = $Selected
            }
            $script:ComputerListTreeViewData += $ComputerListTreeViewAddHostnameIP
        }
    }
    $ComputerListTreeView.ExpandAll()
    Populate-ComputerListTreeViewDefaultData
})
$Section1EnumerationTab.Controls.Add($EnumerationComputerListBoxAddToListButton) 

#---------------------------------
# Enumeration - Select All Button
#---------------------------------
$EnumerationComputerListBoxSelectAllButton          = New-Object System.Windows.Forms.Button
$EnumerationComputerListBoxSelectAllButton.Location = New-Object System.Drawing.Size($EnumerationComputerListBoxAddToListButton.Location.X,($EnumerationComputerListBoxAddToListButton.Location.Y + $EnumerationComputerListBoxAddToListButton.Size.Height + 4))
$EnumerationComputerListBoxSelectAllButton.Size     = New-Object System.Drawing.Size($EnumerationComputerListBoxAddToListButton.Size.Width,22)
$EnumerationComputerListBoxSelectAllButton.Text     = "Select All"
$EnumerationComputerListBoxSelectAllButton.add_click({
    # Select all fields
    for($i = 0; $i -lt $EnumerationComputerListBox.Items.Count; $i++) {
        $EnumerationComputerListBox.SetSelected($i, $true)
    }
})
$Section1EnumerationTab.Controls.Add($EnumerationComputerListBoxSelectAllButton) 

#-----------------------------------
# Computer List - Clear List Button
#-----------------------------------
$EnumerationComputerListBoxClearButton               = New-Object System.Windows.Forms.Button
$EnumerationComputerListBoxClearButton.Location      = New-Object System.Drawing.Size($EnumerationComputerListBoxSelectAllButton.Location.X,($EnumerationComputerListBoxSelectAllButton.Location.Y + $EnumerationComputerListBoxSelectAllButton.Size.Height + 4))
$EnumerationComputerListBoxClearButton.Size          = New-Object System.Drawing.Size($EnumerationComputerListBoxSelectAllButton.Size.Width,22)
$EnumerationComputerListBoxClearButton.Text          = 'Clear List'
$EnumerationComputerListBoxClearButton.add_click({
    $EnumerationComputerListBox.Items.Clear()
})
$Section1EnumerationTab.Controls.Add($EnumerationComputerListBoxClearButton) 

##############################################################################################################################################################
##
## Section 1 Checklist Tab
##
##############################################################################################################################################################

$Section1ChecklistTab          = New-Object System.Windows.Forms.TabPage
$Section1ChecklistTab.Text     = "Checklist"
$Section1ChecklistTab.Name     = "Checklist Tab"
$Section1ChecklistTab.UseVisualStyleBackColor = $True

#Checks if the Resources Directory is there and loads it if it is
if (Test-Path $PoShHome\Resources\Checklists) {
    $Section1TabControl.Controls.Add($Section1ChecklistTab)
}

# Variable Sizes
$TabRightPosition     = 3
$TabhDownPosition     = 3
$TabAreaWidth         = 446
$TabAreaHeight        = 557

$TextBoxRightPosition = -2 
$TextBoxDownPosition  = -2
$TextBoxWidth         = 442
$TextBoxHeight        = 536


#####################################################################################################################################
##
## Section 1 Checklilst TabControl
##
#####################################################################################################################################

# The TabControl controls the tabs within it
$Section1ChecklistTabControl               = New-Object System.Windows.Forms.TabControl
$Section1ChecklistTabControl.Name          = "Checklist TabControl"
$Section1ChecklistTabControl.Location      = New-Object System.Drawing.Size($TabRightPosition,$TabhDownPosition)
$Section1ChecklistTabControl.Size          = New-Object System.Drawing.Size($TabAreaWidth,$TabAreaHeight) 
$Section1ChecklistTabControl.ShowToolTips  = $True
$Section1ChecklistTabControl.SelectedIndex = 0
$Section1ChecklistTab.Controls.Add($Section1ChecklistTabControl)


############################################################################################################
# Section 1 Checklist SubTab
############################################################################################################

# Varables for positioning checkboxes
$ChecklistRightPosition     = 5
$ChecklistDownPositionStart = 10
$ChecklistDownPosition      = 10
$ChecklistDownPositionShift = 30
$ChecklistBoxWidth          = 410
$ChecklistBoxHeight         = 30

#-------------------------------------------------------
# Checklists Auto Create Tabs and Checkboxes from files
#-------------------------------------------------------
# Obtains a list of the files in the resources folder
$ResourceChecklistFiles = Get-ChildItem "$PoShHome\Resources\Checklists"

# Iterates through the files and dynamically creates tabs and imports data
foreach ($File in $ResourceChecklistFiles) {
    #-------------------------
    # Creates Tabs From Files
    #-------------------------
    $TabName                                   = $File.BaseName
    $Section1ChecklistSubTab                   = New-Object System.Windows.Forms.TabPage
    $Section1ChecklistSubTab.Text              = "$TabName"
    $Section1ChecklistSubTab.AutoScroll        = $True
    $Section1ChecklistSubTab.UseVisualStyleBackColor = $True
    $Section1ChecklistTabControl.Controls.Add($Section1ChecklistSubTab)

    #-------------------------------------
    # Imports Data and Creates Checkboxes
    #-------------------------------------
    $TabContents = Get-Content -Path $File.FullName -Force | foreach {$_ + "`r`n"}
    foreach ($line in $TabContents) {
        $Checklist          = New-Object System.Windows.Forms.CheckBox
        $Checklist.Text     = "$line"
        $Checklist.Location = New-Object System.Drawing.Size($ChecklistRightPosition,$ChecklistDownPosition) 
        $Checklist.Size     = New-Object System.Drawing.Size($ChecklistBoxWidth,$ChecklistBoxHeight)
        if ($Checklist.Check -eq $True) {
            $Checklist.ForeColor = "Blue"
        }
        $Section1ChecklistSubTab.Controls.Add($Checklist)          

        # Shift the Text and Button's Location
        $ChecklistDownPosition += $ChecklistDownPositionShift
    }

    # Resets the Down Position
    $ChecklistDownPosition = $ChecklistDownPositionStart
}

##############################################################################################################################################################
##
## Section 1 Processes Tab
##
##############################################################################################################################################################
$Section1ProcessesTab          = New-Object System.Windows.Forms.TabPage
$Section1ProcessesTab.Text     = "Processes"
$Section1ProcessesTab.Name     = "Processes Tab"
$Section1ProcessesTab.UseVisualStyleBackColor = $True

#Checks if the Resources Directory is there and loads it if it is
if (Test-Path "$PoShHome\Resources\Process Info") {
    $Section1TabControl.Controls.Add($Section1ProcessesTab)
}

# Variable Sizes
$TabRightPosition       = 3
$TabhDownPosition       = 3
$TabAreaWidth           = 446
$TabAreaHeight          = 557

$TextBoxRightPosition   = -2 
$TextBoxDownPosition    = -2
$TextBoxWidth           = 442
$TextBoxHeight          = 536


#####################################################################################################################################
##
## Section 1 Processes TabControl
##
#####################################################################################################################################

# The TabControl controls the tabs within it
$Section1ProcessesTabControl               = New-Object System.Windows.Forms.TabControl
$Section1ProcessesTabControl.Name          = "Processes TabControl"
$Section1ProcessesTabControl.Location      = New-Object System.Drawing.Size($TabRightPosition,$TabhDownPosition)
$Section1ProcessesTabControl.Size          = New-Object System.Drawing.Size($TabAreaWidth,$TabAreaHeight) 
$Section1ProcessesTabControl.ShowToolTips  = $True
$Section1ProcessesTabControl.SelectedIndex = 0
$Section1ProcessesTab.Controls.Add($Section1ProcessesTabControl)


############################################################################################################
# Section 1 Processes SubTab
############################################################################################################

#------------------------------------
# Auto Creates Tabs and Imports Data
#------------------------------------
# Obtains a list of the files in the resources folder
$ResourceProcessFiles = Get-ChildItem "$PoShHome\Resources\Process Info"

# Iterates through the files and dynamically creates tabs and imports data
foreach ($File in $ResourceProcessFiles) {
    #-----------------------------
    # Creates Tabs From Each File
    #-----------------------------
    $TabName                                   = $File.BaseName
    $Section1ProcessesSubTab                   = New-Object System.Windows.Forms.TabPage
    $Section1ProcessesSubTab.Text              = "$TabName"
    $Section1ProcessesSubTab.UseVisualStyleBackColor = $True
    $Section1ProcessesTabControl.Controls.Add($Section1ProcessesSubTab)

    #-----------------------------
    # Imports Data Into Textboxes
    #-----------------------------
    $TabContents                               = Get-Content -Path $File.FullName -Force | foreach {$_ + "`r`n"} 
    $Section1ProcessesSubTabTextBox            = New-Object System.Windows.Forms.TextBox
    $Section1ProcessesSubTabTextBox.Name       = "$file"
    $Section1ProcessesSubTabTextBox.Location   = New-Object System.Drawing.Size($TextBoxRightPosition,$TextBoxDownPosition) 
    $Section1ProcessesSubTabTextBox.Size       = New-Object System.Drawing.Size($TextBoxWidth,$TextBoxHeight)
    $Section1ProcessesSubTabTextBox.MultiLine  = $True
    $Section1ProcessesSubTabTextBox.ScrollBars = "Vertical"
    $Section1ProcessesSubTabTextBox.Font       = New-Object System.Drawing.Font("$Font",9,0,3,1)
    $Section1ProcessesSubTab.Controls.Add($Section1ProcessesSubTabTextBox)
    $Section1ProcessesSubTabTextBox.Text       = "$TabContents"
}

##############################################################################################################################################################
##
## Section 1 OpNotes Tab
##
##############################################################################################################################################################

# The OpNotes TabPage Window
$Section1OpNotesTab          = New-Object System.Windows.Forms.TabPage
$Section1OpNotesTab.Text     = "OpNotes"
$Section1OpNotesTab.Name     = "OpNotes Tab"
$Section1OpNotesTab.UseVisualStyleBackColor = $True
$Section1TabControl.Controls.Add($Section1OpNotesTab)


# Variable Sizes
$TabRightPosition          = 3
$TabhDownPosition          = 3
$TabAreaWidth              = 446
$TabAreaHeight             = 557

$OpNotesInputTextBoxWidth  = 450
$OpNotesInputTextBoxHeight = 22

$OpNotesButtonWidth        = 100
$OpNotesButtonHeight       = 22

$OpNotesMainTextBoxWidth   = 450
$OpNotesMainTextBoxHeight  = 470

$OpNotesRightPositionStart = 0
$OpNotesRightPosition      = 0
$OpNotesRightPositionShift = $OpNotesButtonWidth + 10
$OpNotesDownPosition       = 2
$OpNotesDownPositionShift  = 22


#-------------------------------
# OpNotes - OpNotes Save Script
#-------------------------------
# The purpose to allow saving of Opnotes automatcially

function OpNotesSaveScript {
    # Select all fields to be saved
    for($i = 0; $i -lt $OpNotesListBox.Items.Count; $i++) {
        $OpNotesListBox.SetSelected($i, $true)
    }

    # Saves all OpNotes to file
    Set-Content -Path $OpNotesFile -Value ($OpNotesListBox.SelectedItems) -Force
    
    # Unselects Fields
    for($i = 0; $i -lt $OpNotesListBox.Items.Count; $i++) {
        $OpNotesListBox.SetSelected($i, $false)
    }
}


#---------------------------------
# OpNotes - OpNotes Textbox Entry
#---------------------------------
# This function is called when pressing enter in the text box or click add
function OpNoteTextBoxEntry {
    # Adds Timestamp to Entered Text
    $OpNotesAdded = $OpNotesListBox.Items.Add("$((Get-Date).ToString('yyyy/MM/dd HH:mm:ss')) $($OpNotesInputTextBox.Text)")

    OpNotesSaveScript

    # Adds all entries to the OpNotesWriteOnlyFile -- This file gets all entries and are not editable from the GUI
    # Useful for looking into accidentally deleted entries
    Add-Content -Path $OpNotesWriteOnlyFile -Value ("$($(Get-Date).ToString('yyyy/MM/dd HH:mm:ss')) $($OpNotesInputTextBox.Text)") -Force 
#    $PrependData = Get-Content $OpNotesWriteOnlyFile
#    Set-Content -Path $OpNotesWriteOnlyFile -Value (("$($(Get-Date).ToString('yyyy/MM/dd HH:mm:ss')) $($OpNotesInputTextBox.Text)"),$PrependData) -Force 
    
    #Clears Textbox
    $OpNotesInputTextBox.Text = ""
}


############################################################################################################
# Section 1 OpNotes SubTab
############################################################################################################

#-------------------------------------
# OpNoptes - Enter your OpNotes Label
#-------------------------------------
$OpNotesLabel           = New-Object System.Windows.Forms.Label
$OpNotesLabel.Location  = New-Object System.Drawing.Point($OpNotesRightPosition,$OpNotesDownPosition) 
$OpNotesLabel.Size      = New-Object System.Drawing.Size($OpNotesInputTextBoxWidth,$OpNotesInputTextBoxHeight)
$OpNotesLabel.Text      = "Enter Your OpNotes (Auto-Timestamp):"
$OpNotesLabel.Font      = New-Object System.Drawing.Font("$Font",12,1,3,1)
$OpNotesLabel.ForeColor = "Blue"
$Section1OpNotesTab.Controls.Add($OpNotesLabel)

$OpNotesDownPosition += $OpNotesDownPositionShift

#--------------------------
# OpNotes - Input Text Box
#--------------------------
$OpNotesInputTextBox          = New-Object System.Windows.Forms.TextBox
$OpNotesInputTextBox.Location = New-Object System.Drawing.Size($OpNotesRightPosition,$OpNotesDownPosition)
$OpNotesInputTextBox.Size     = New-Object System.Drawing.Size($OpNotesInputTextBoxWidth,$OpNotesInputTextBoxHeight)
# Press Enter to Input Data
$OpNotesInputTextBox.Add_KeyDown({
    if ($_.KeyCode -eq "Enter") {
        # There must be text in the input to make an entry
        if ($OpNotesInputTextBox.Text -ne "") {
            OpNoteTextBoxEntry
        }
    }
})
$Section1OpNotesTab.Controls.Add($OpNotesInputTextBox)

$OpNotesDownPosition += $OpNotesDownPositionShift

#----------------------
# OpNotes - Add Button
#----------------------
$OpNotesAddButton          = New-Object System.Windows.Forms.Button
$OpNotesAddButton.Text     = "Add"
$OpNotesAddButton.Location = New-Object System.Drawing.Size($OpNotesRightPosition,$OpNotesDownPosition)
$OpNotesAddButton.Size     = New-Object System.Drawing.Size($OpNotesButtonWidth,$OpNotesButtonHeight)
$OpNotesAddButton.add_click({
    # There must be text in the input to make an entry
    if ($OpNotesInputTextBox.Text -ne "") {
        OpNoteTextBoxEntry
    }    
})
$Section1OpNotesTab.Controls.Add($OpNotesAddButton) 


# Shift Right
$OpNotesRightPosition += $OpNotesRightPositionShift


#-----------------------------
# OpNotes - Select All Button
#-----------------------------
$OpNotesAddButton          = New-Object System.Windows.Forms.Button
$OpNotesAddButton.Text     = "Select All"
$OpNotesAddButton.Location = New-Object System.Drawing.Size($OpNotesRightPosition,$OpNotesDownPosition)
$OpNotesAddButton.Size     = New-Object System.Drawing.Size($OpNotesButtonWidth,$OpNotesButtonHeight)
$OpNotesAddButton.add_click({
    for($i = 0; $i -lt $OpNotesListBox.Items.Count; $i++) {
        $OpNotesListBox.SetSelected($i, $true)
    }
})
$Section1OpNotesTab.Controls.Add($OpNotesAddButton) 


# Shift Right
$OpNotesRightPosition += $OpNotesRightPositionShift


#-------------------------------
# OpNotes - Open OpNotes Button
#-------------------------------
$OpNotesOpenListBox          = New-Object System.Windows.Forms.Button
$OpNotesOpenListBox.Text     = "Open OpNotes"
$OpNotesOpenListBox.Location = New-Object System.Drawing.Size($OpNotesRightPosition,$OpNotesDownPosition)
$OpNotesOpenListBox.Size     = New-Object System.Drawing.Size($OpNotesButtonWidth,$OpNotesButtonHeight) 
$OpNotesOpenListBox.add_click({
    Invoke-Item -Path "$PoShHome\OpNotes.txt"
})
$Section1OpNotesTab.Controls.Add($OpNotesOpenListBox)


# Shift Right
$OpNotesRightPosition += $OpNotesRightPositionShift


#--------------------------
# OpNotes - Move Up Button
#--------------------------
$OpNotesMoveUpButton               = New-Object System.Windows.Forms.Button
$OpNotesMoveUpButton.Location      = New-Object System.Drawing.Size($OpNotesRightPosition,$OpNotesDownPosition)
$OpNotesMoveUpButton.Size          = New-Object System.Drawing.Size($OpNotesButtonWidth,$OpNotesButtonHeight)
$OpNotesMoveUpButton.Text          = 'Move Up'
$OpNotesMoveUpButton.add_click({
    # only if the first item isn't the current one
    if($OpNotesListBox.SelectedIndex -gt 0)
    {
        $OpNotesListBox.BeginUpdate()
        #Get starting position
        $pos = $OpNotesListBox.selectedIndex
        # add a duplicate of original item up in the listbox
        $OpNotesListBox.items.insert($pos -1,$OpNotesListBox.Items.Item($pos))
        # make it the current item
        $OpNotesListBox.SelectedIndex = ($pos -1)
        # delete the old occurrence of this item
        $OpNotesListBox.Items.RemoveAt($pos +1)
        $OpNotesListBox.EndUpdate()
    }
    else {
       #Top of list, beep
       [console]::beep(500,100)
    }
    OpNotesSaveScript
})
$Section1OpNotesTab.Controls.Add($OpNotesMoveUpButton) 


# Shift Down
$OpNotesDownPosition += $OpNotesDownPositionShift

# Move Position back to left
$OpNotesRightPosition = $OpNotesRightPositionStart

#----------------------------------
# OpNotes - Remove Selected Button
#----------------------------------
$OpNotesRemoveButton               = New-Object System.Windows.Forms.Button
$OpNotesRemoveButton.Location      = New-Object System.Drawing.Size($OpNotesRightPosition,$OpNotesDownPosition)
$OpNotesRemoveButton.Size          = New-Object System.Drawing.Size($OpNotesButtonWidth,$OpNotesButtonHeight)
$OpNotesRemoveButton.Text          = 'Remove'
$OpNotesRemoveButton.add_click({
    $OpNotesListBox.Items.Remove($OpNotesListBox.SelectedItem)
    OpNotesSaveScript
})
$Section1OpNotesTab.Controls.Add($OpNotesRemoveButton) 


# Shift Right
$OpNotesRightPosition += $OpNotesRightPositionShift


#--------------------------------
# OpNotes - Create Report Button
#--------------------------------
$OpNotesCreateReportButton          = New-Object System.Windows.Forms.Button
$OpNotesCreateReportButton.Location = New-Object System.Drawing.Size($OpNotesRightPosition,$OpNotesDownPosition)
$OpNotesCreateReportButton.Size     = New-Object System.Drawing.Size($OpNotesButtonWidth,$OpNotesButtonHeight)
$OpNotesCreateReportButton.Text     = "Create Report"
$OpNotesCreateReportButton.add_click({
    New-Item -ItemType Directory "$PoShHome\Reports" -ErrorAction SilentlyContinue | Out-Null
    if ($OpNotesListBox.SelectedItems.Count -gt 0) { 
        # Popup that allows you select where to save the Report
        [System.Reflection.Assembly]::LoadWithPartialName("PresentationFramework") | Out-Null
        #$OpNotesSaveLocation                 = New-Object -Typename System.Windows.Forms.SaveFileDialog
        $OpNotesSaveLocation                  = New-Object Microsoft.Win32.SaveFileDialog
        $OpNotesSaveLocation.InitialDirectory = "$PoShHome\Reports"
        $OpNotesSaveLocation.MultiSelect      = $false
        $OpNotesSaveLocation.Filter           = "Text files (*.txt)| *.txt" 
        $OpNotesSaveLocation.ShowDialog()
        Write-Output $($OpNotesListBox.SelectedItems) | Out-File "$($OpNotesSaveLocation.Filename)"
    }
    else {
        $MainListBox.Items.Clear()
        $MainListBox.Items.Add('You must select at least one line to add to a report!')
    }
})
$Section1OpNotesTab.Controls.Add($OpNotesCreateReportButton) 


# Shift Right
$OpNotesRightPosition += $OpNotesRightPositionShift


#-------------------------------
# OpNotes - Open Reports Button
#-------------------------------
$OpNotesOpenListBox          = New-Object System.Windows.Forms.Button
$OpNotesOpenListBox.Text     = "Open Reports"
$OpNotesOpenListBox.Location = New-Object System.Drawing.Size($OpNotesRightPosition,$OpNotesDownPosition)
$OpNotesOpenListBox.Size     = New-Object System.Drawing.Size($OpNotesButtonWidth,$OpNotesButtonHeight) 
$OpNotesOpenListBox.add_click({
    Invoke-Item -Path "$PoShHome\Reports"
})
$Section1OpNotesTab.Controls.Add($OpNotesOpenListBox)

# Shift Right
$OpNotesRightPosition += $OpNotesRightPositionShift


#----------------------------
# OpNotes - Move Down Button
#----------------------------
$OpNotesMoveDownButton               = New-Object System.Windows.Forms.Button
$OpNotesMoveDownButton.Location      = New-Object System.Drawing.Size($OpNotesRightPosition,$OpNotesDownPosition)
$OpNotesMoveDownButton.Size          = New-Object System.Drawing.Size($OpNotesButtonWidth,$OpNotesButtonHeight)
$OpNotesMoveDownButton.Text          = 'Move Down'
$OpNotesMoveDownButton.add_click({
    #only if the last item isn't the current one
    if(($OpNotesListBox.SelectedIndex -ne -1) -and ($OpNotesListBox.SelectedIndex -lt $OpNotesListBox.Items.Count - 1) ) {
        $OpNotesListBox.BeginUpdate()
        #Get starting position 
        $pos = $OpNotesListBox.selectedIndex
        # add a duplicate of item below in the listbox
        $OpNotesListBox.items.insert($pos,$OpNotesListBox.Items.Item($pos +1))
        # delete the old occurrence of this item
        $OpNotesListBox.Items.RemoveAt($pos +2 )
        # move to current item
        $OpNotesListBox.SelectedIndex = ($pos +1)
        $OpNotesListBox.EndUpdate()
    }
    else {
       #Bottom of list, beep
       [console]::beep(500,100)
    }
    OpNotesSaveScript
})
$Section1OpNotesTab.Controls.Add($OpNotesMoveDownButton) 

$OpNotesDownPosition += $OpNotesDownPositionShift

#------------------------
# OpNotes - Main ListBox
#------------------------
$OpNotesListBox          = New-Object System.Windows.Forms.ListBox
$OpNotesListBox.Name     = "OpNotesListBox"
$OpNotesListBox.FormattingEnabled = $True
$OpNotesListBox.Location = New-Object System.Drawing.Size($OpNotesRightPositionStart,($OpNotesDownPosition + 5)) 
$OpNotesListBox.Size     = New-Object System.Drawing.Size($OpNotesMainTextBoxWidth,$OpNotesMainTextBoxHeight)
$OpNotesListBox.Font     = New-Object System.Drawing.Font("Courier New",8,[System.Drawing.FontStyle]::Regular)
$OpNotesListBox.SelectionMode = 'MultiExtended'
$OpNotesListBox.ScrollAlwaysVisible = $True
$OpNotesListBox.AutoSize = $false
$Section1OpNotesTab.Controls.Add($OpNotesListBox)

# Obtains the OpNotes to be viewed and manipulated later
$OpNotesFileContents = Get-Content "$OpNotesFile"

# Checks to see if OpNotes.txt exists and loads it
$OpNotesFileContents = Get-Content "$OpNotesFile"
if (Test-Path -Path $OpNotesFile) {
    $OpNotesListBox.Items.Clear()
    foreach ($OpNotesEntry in $OpNotesFileContents){
        $OpNotesListBox.Items.Add("$OpNotesEntry")
    }
}

##############################################################################################################################################################
##
## Section 1 About Tab
##
##############################################################################################################################################################
$Section1AboutTab          = New-Object System.Windows.Forms.TabPage
$Section1AboutTab.Text     = "About"
$Section1AboutTab.Name     = "About Tab"
$Section1AboutTab.UseVisualStyleBackColor = $True

#Checks if the Resources Directory is there and loads it if it is
if (Test-Path $PoShHome\Resources\About) {
    $Section1TabControl.Controls.Add($Section1AboutTab)
}

# Variable Sizes
$TabRightPosition       = 3
$TabhDownPosition       = 3
$TabAreaWidth           = 446
$TabAreaHeight          = 557

$TextBoxRightPosition   = -2 
$TextBoxDownPosition    = -2
$TextBoxWidth           = 442
$TextBoxHeight          = 536


#####################################################################################################################################
##
## Section 1 About TabControl
##
#####################################################################################################################################

# The TabControl controls the tabs within it
$Section1AboutTabControl               = New-Object System.Windows.Forms.TabControl
$Section1AboutTabControl.Name          = "About TabControl"
$Section1AboutTabControl.Location      = New-Object System.Drawing.Size($TabRightPosition,$TabhDownPosition)
$Section1AboutTabControl.Size          = New-Object System.Drawing.Size($TabAreaWidth,$TabAreaHeight) 
$Section1AboutTabControl.ShowToolTips  = $True
$Section1AboutTabControl.SelectedIndex = 0
$Section1AboutTab.Controls.Add($Section1AboutTabControl)

############################################################################################################
# Section 1 About SubTab
############################################################################################################

#------------------------------------
# Auto Creates Tabs and Imports Data
#------------------------------------
# Obtains a list of the files in the resources folder
$ResourceProcessFiles = Get-ChildItem "$PoShHome\Resources\About"

# Iterates through the files and dynamically creates tabs and imports data
foreach ($File in $ResourceProcessFiles) {
    #-----------------------------
    # Creates Tabs From Each File
    #-----------------------------
    $TabName                               = $File.BaseName
    $Section1AboutSubTab                   = New-Object System.Windows.Forms.TabPage
    $Section1AboutSubTab.Text              = "$TabName"
    $Section1AboutSubTab.UseVisualStyleBackColor = $True
    $Section1AboutTabControl.Controls.Add($Section1AboutSubTab)

    #-----------------------------
    # Imports Data Into Textboxes
    #-----------------------------
    $TabContents                           = Get-Content -Path $File.FullName -Force | foreach {$_ + "`r`n"} 
    $Section1AboutSubTabTextBox            = New-Object System.Windows.Forms.TextBox
    $Section1AboutSubTabTextBox.Name       = "$file"
    $Section1AboutSubTabTextBox.Location   = New-Object System.Drawing.Size($TextBoxRightPosition,$TextBoxDownPosition) 
    $Section1AboutSubTabTextBox.Size       = New-Object System.Drawing.Size($TextBoxWidth,$TextBoxHeight)
    $Section1AboutSubTabTextBox.MultiLine  = $True
    $Section1AboutSubTabTextBox.ScrollBars = "Vertical"
    $Section1AboutSubTabTextBox.Font       = New-Object System.Drawing.Font("Courier New",7.5,0,0,0)
    $Section1AboutSubTab.Controls.Add($Section1AboutSubTabTextBox)
    $Section1AboutSubTabTextBox.Text       = "$TabContents"
}



##############################################################################################################################################################
##############################################################################################################################################################
##
## Section 2 Tab Control
##
##############################################################################################################################################################
##############################################################################################################################################################
# Varables to Control Section 1 Tab Control
$Section2TabControlRightPosition  = 470
$Section2TabControlDownPosition   = 5
$Section2TabControlBoxWidth       = 370
$Section2TabControlBoxHeight      = 285

$Section2TabControl               = New-Object System.Windows.Forms.TabControl
$Section2TabControl.Name          = "Main Tab Window"
$Section2TabControl.SelectedIndex = 0
$Section2TabControl.ShowToolTips  = $True
$Section2TabControl.Location      = New-Object System.Drawing.Size($Section2TabControlRightPosition,$Section2TabControlDownPosition) 
$Section2TabControl.Size          = New-Object System.Drawing.Size($Section2TabControlBoxWidth,$Section2TabControlBoxHeight) 

$PoShACME.Controls.Add($Section2TabControl)

##############################################################################################################################################################
##
## Section 2 Main SubTab
##
##############################################################################################################################################################
$Section2MainTab          = New-Object System.Windows.Forms.TabPage
$Section2MainTab.Text     = "Main"
$Section2MainTab.Name     = "Main"
$Section2MainTab.UseVisualStyleBackColor = $True
$Section2TabControl.Controls.Add($Section2MainTab)



#============================================================================================================================================================
# Functions used for commands/queries
#============================================================================================================================================================
# Varables to Control Column 3
$Column3RightPosition     = 3
$Column3DownPosition      = 11
$Column3BoxWidth          = 300
$Column3BoxHeight         = 22
$Column3DownPositionShift = 26

#---------------------------------------------------
# Single Host - Enter A Single Hostname/IP Checkbox
#---------------------------------------------------
# This checkbox highlights when selecing computers from the ComputerList
$SingleHostIPCheckBox          = New-Object System.Windows.Forms.Checkbox
$SingleHostIPCheckBox.Name     = "Query A Single Hostname/IP:"
$SingleHostIPCheckBox.Text     = "$($SingleHostIPCheckBox.Name)"
$SingleHostIPCheckBox.Location = New-Object System.Drawing.Size(3,11) 
$SingleHostIPCheckBox.Size     = New-Object System.Drawing.Size(200,$Column3BoxHeight)
$SingleHostIPCheckBox.Enabled  = $true
$SingleHostIPCheckBox.Font     = [System.Drawing.Font]::new("$Font", 8, [System.Drawing.FontStyle]::Bold)
$SingleHostIPCheckBox.Add_Click({
    if ($SingleHostIPCheckBox.Checked -eq $true){
        $ComputerListTreeView.Enabled   = $false
        $ComputerListTreeView.BackColor = "lightgray"
    }
    elseif ($SingleHostIPCheckBox.Checked -eq $false) {
        $SingleHostIPTextBox.Text       = "<Type In A Hostname / IP>"
        $ComputerListTreeView.Enabled   = $true
        $ComputerListTreeView.BackColor = "white"
    }
})
$Section2MainTab.Controls.Add($SingleHostIPCheckBox)

#----------------------------------
# Single Host - Add To List Button
#----------------------------------
$SingleHostIPAddButton          = New-Object System.Windows.Forms.Button
$SingleHostIPAddButton.Text     = "Add To List"
$SingleHostIPAddButton.Location = New-Object System.Drawing.Size(($Column3RightPosition + 240),$Column3DownPosition)
$SingleHostIPAddButton.Size     = New-Object System.Drawing.Size(115,$Column3BoxHeight) 
$SingleHostIPAddButton.add_click({
    # Conducts a simple input check for default or blank data
    if (($SingleHostIPTextBox.Text -ne '<Type In A Hostname / IP>') -and ($SingleHostIPTextBox.Text -ne '')) {
        # Adds the hostname/ip entered into the collection list box
        $value = "Manually Added"
        Add-Node -RootNode $TreeNode -Category $value -Entry $SingleHostIPTextBox.Text -ToolTip 'Manually Added'
        $ComputerListTreeView.ExpandAll()
        # Clears Textbox
        $SingleHostIPTextBox.Text = "<Type In A Hostname / IP>"
        # Auto checks/unchecks various checkboxes for visual status indicators
        $SingleHostIPCheckBox.Checked = $false
    }
})
$Section2MainTab.Controls.Add($SingleHostIPAddButton) 

$Column3DownPosition += $Column3DownPositionShift

#------------------------------------
# Single Host - Input Check Function
#------------------------------------
function SingleHostInputCheck {
    if (($SingleHostIPTextBox.Text -ne '<Type In A Hostname / IP>') -and ($SingleHostIPTextBox.Text -ne '') ) {
        # Auto checks/unchecks various checkboxes for visual status indicators
        $SingleHostIPCheckBox.Checked = $true

        . SingleEntry

        $MainListBox.Items.Clear()
        $MainListBox.Items.Add("Collect Data From:")
        foreach ($Computer in $ComputerList) {
            $MainListBox.Items.Add("$Computer")
        }
    }
    if ($SingleHostIPCheckBox.Checked -eq $true){
        $ComputerListBox.Enabled   = $false
        $ComputerListBox.BackColor = "lightgray"
    }
    elseif ($SingleHostIPCheckBox.Checked -eq $false) {
        $SingleHostIPTextBox.Text  = "<Type In A Hostname / IP>"
        $ComputerListBox.Enabled   = $true
        $ComputerListBox.BackColor = "white"
    }
}

#-----------------------------------------------
# Single Host - <Type In A Hostname / IP> Textbox
#-----------------------------------------------
$SingleHostIPTextBox          = New-Object System.Windows.Forms.TextBox
$SingleHostIPTextBox.Text     = "<Type In A Hostname / IP>"
$SingleHostIPTextBox.Location = New-Object System.Drawing.Size($Column3RightPosition,($Column3DownPosition + 1))
$SingleHostIPTextBox.Size     = New-Object System.Drawing.Size(235,$Column3BoxHeight)
$SingleHostIPTextBox.Add_KeyDown({
    if ($_.KeyCode -eq "Enter") {
        SingleHostInputCheck
    }
})
$Section2MainTab.Controls.Add($SingleHostIPTextBox)


#--------------------------------------
# Single Host - Collect Entered Button
#--------------------------------------
$SingleHostIPOKButton          = New-Object System.Windows.Forms.Button
$SingleHostIPOKButton.Text     = "Single Collection"
$SingleHostIPOKButton.Location = New-Object System.Drawing.Size(($Column3RightPosition + 240),$Column3DownPosition)
$SingleHostIPOKButton.Size     = New-Object System.Drawing.Size(115,$Column3BoxHeight) 
$SingleHostIPOKButton.add_click({
    $SingleHostIPCheckBox.Checked = $true
    SingleHostInputCheck
})
$Section2MainTab.Controls.Add($SingleHostIPOKButton) 


# Shift Row Location
$Column3DownPosition += $Column3DownPositionShift

# Shift Row Location
$Column3DownPosition += $Column3DownPositionShift

# Shift Row Location
$Column3DownPosition += $Column3DownPositionShift - 3

#-------------------------------------------
# Directory Location - Results Folder Label
#-------------------------------------------
$DirectoryListLabel           = New-Object System.Windows.Forms.Label
$DirectoryListLabel.Location  = New-Object System.Drawing.Size($Column3RightPosition,($Column3DownPosition + 2)) 
$DirectoryListLabel.Size      = New-Object System.Drawing.Size(120,$Column3BoxHeight) 
$DirectoryListLabel.Font      = [System.Drawing.Font]::new("Microsoft Sans Serif", 9, [System.Drawing.FontStyle]::Bold)
$DirectoryListLabel.Text      = "Results Folder:"
$DirectoryListLabel.ForeColor = "Black"
$Section2MainTab.Controls.Add($DirectoryListLabel)

#------------------------------------------
# Directory Location - Open Results Button
#------------------------------------------
$DirectoryOpenListBox          = New-Object System.Windows.Forms.Button
$DirectoryOpenListBox.Text     = "Open Results"
$DirectoryOpenListBox.Location = New-Object System.Drawing.Size(($Column3RightPosition + 120),$Column3DownPosition)
$DirectoryOpenListBox.Size     = New-Object System.Drawing.Size(115,$Column3BoxHeight) 
$Section2MainTab.Controls.Add($DirectoryOpenListBox)

$DirectoryOpenListBox.add_click({
    Invoke-Item -Path $CollectedDataDirectory
})

#-------------------------------------------
# Directory Location - New Timestamp Button
#-------------------------------------------
$DirectoryUpdateListBox              = New-Object System.Windows.Forms.Button
$DirectoryUpdateListBox.Text         = "New Timestamp"
$DirectoryUpdateListBox.Location     = New-Object System.Drawing.Size(($Column3RightPosition + 240),$Column3DownPosition)
$DirectoryUpdateListBox.Size         = New-Object System.Drawing.Size(115,$Column3BoxHeight) 
$Section2MainTab.Controls.Add($DirectoryUpdateListBox) 
#$DirectoryUpdateListBox.Add_KeyDown({ if ($_.KeyCode -eq "Enter") {} })

$DirectoryUpdateListBox.add_click({
    $CollectedDataTimeStampDirectory = "$CollectedDataDirectory\$((Get-Date).ToString('yyyy-MM-dd @ HHmm ss'))"
    $CollectionSavedDirectoryTextBox.Text  = $CollectedDataTimeStampDirectory
})

# Shift Row Location
$Column3DownPosition += $Column3DownPositionShift

#----------------------------------------
# Directory Location - Directory TextBox
#----------------------------------------
# This shows the name of the directy that data will be currently saved to
$CollectionSavedDirectoryTextBox               = New-Object System.Windows.Forms.TextBox
$CollectionSavedDirectoryTextBox.Name          = "Saved Directory List Box"
$CollectionSavedDirectoryTextBox.Text          = $CollectedDataTimeStampDirectory
$CollectionSavedDirectoryTextBox.WordWrap      = $true
#$CollectionSavedDirectoryTextBox.Multiline     = $true
#$CollectionSavedDirectoryTextBox.AutoSize      = $true
$CollectionSavedDirectoryTextBox.AutoCompleteSource = "FileSystem" # Options are: FileSystem, HistoryList, RecentlyUsedList, AllURL, AllSystemSources, FileSystemDirectories, CustomSource, ListItems, None
$CollectionSavedDirectoryTextBox.AutoCompleteMode   = "SuggestAppend" # Options are: "Suggest", "Append", "SuggestAppend"
$CollectionSavedDirectoryTextBox.Location      = New-Object System.Drawing.Size($Column3RightPosition,$Column3DownPosition) 
$CollectionSavedDirectoryTextBox.Size          = New-Object System.Drawing.Size(354,35)
$Section2MainTab.Controls.Add($CollectionSavedDirectoryTextBox)

#============================================================================================================================================================
# Results Section
#============================================================================================================================================================

#-------------------------------------------
# Directory Location - Results Folder Label
#-------------------------------------------
$ResultsSectionLabel           = New-Object System.Windows.Forms.Label
$ResultsSectionLabel.Location  = New-Object System.Drawing.Size(2,200) 
$ResultsSectionLabel.Size      = New-Object System.Drawing.Size(220,$Column3BoxHeight) 
$ResultsSectionLabel.Font      = [System.Drawing.Font]::new("Microsoft Sans Serif", 9, [System.Drawing.FontStyle]::Bold)
$ResultsSectionLabel.Text      = "Choose How To View Results:"
$ResultsSectionLabel.ForeColor = "Black"
$Section2MainTab.Controls.Add($ResultsSectionLabel)

#============================================================================================================================================================
# View CSV Results
#============================================================================================================================================================
$OpenResultsButton          = New-Object System.Windows.Forms.Button
$OpenResultsButton.Name     = "View CSV Results"
$OpenResultsButton.Text     = "$($OpenResultsButton.Name)"
$OpenResultsButton.UseVisualStyleBackColor = $True
$OpenResultsButton.Location = New-Object System.Drawing.Size(2,($ResultsSectionLabel.Location.Y + $ResultsSectionLabel.Size.Height + 5))
$OpenResultsButton.Size     = New-Object System.Drawing.Size(115,22)
$Section2MainTab.Controls.Add($OpenResultsButton)

$OpenResultsButton.add_click({
    [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
    $ViewCSVResultsOpenResultsOpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $ViewCSVResultsOpenResultsOpenFileDialog.Title = "View Collection CSV Results"
    $ViewCSVResultsOpenResultsOpenFileDialog.InitialDirectory = "$CollectedDataDirectory"
    $ViewCSVResultsOpenResultsOpenFileDialog.filter = "CSV (*.csv)| *.csv|Excel (*.xlsx)| *.xlsx|Excel (*.xls)| *.xls|All files (*.*)|*.*"
    $ViewCSVResultsOpenResultsOpenFileDialog.ShowDialog() | Out-Null
    $ViewCSVResultsOpenResultsOpenFileDialog.ShowHelp = $true
    Import-Csv $($ViewCSVResultsOpenResultsOpenFileDialog.filename) | Out-GridView -OutputMode Multiple | Set-Variable -Name ViewImportResults
    
    if ($ViewImportResults) {
        $OpNotesListBox.Items.Add("$((Get-Date).ToString('yyyy/MM/dd HH:mm:ss')) View CSV File:  $($ViewCSVResultsOpenResultsOpenFileDialog.filename)")
        Add-Content -Path $OpNotesWriteOnlyFile -Value ("$($(Get-Date).ToString('yyyy/MM/dd HH:mm:ss')) View CSV File:  $($ViewCSVResultsOpenResultsOpenFileDialog.filename)") -Force 
        foreach ($Selection in $ViewImportResults) {
            $OpNotesListBox.Items.Add("$((Get-Date).ToString('yyyy/MM/dd HH:mm:ss')) Selection:  $Selection")
            Add-Content -Path $OpNotesWriteOnlyFile -Value ("$($(Get-Date).ToString('yyyy/MM/dd HH:mm:ss')) Selection:  $Selection") -Force 
        }
    }
    OpNotesSaveScript
})

# Shift Row Location
$Column5DownPosition += $Column5DownPositionShift


#============================================================================================================================================================
# Compare CSV Files
#============================================================================================================================================================

#--------------------
# Compare CSV Button
#--------------------
$CompareButton          = New-Object System.Windows.Forms.Button
$CompareButton.Name     = "Compare CSVs"
$CompareButton.Text     = "$($CompareButton.Name)"
$CompareButton.UseVisualStyleBackColor = $True
$CompareButton.Location = New-Object System.Drawing.Size(($OpenResultsButton.Location.X + $OpenResultsButton.Size.Width + 5),$OpenResultsButton.Location.Y)
$CompareButton.Size     = New-Object System.Drawing.Size(115,22)
$Section2MainTab.Controls.Add($CompareButton)

$CompareButton.add_click({
    # Compare Reference Object
    [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
    $OpenCompareReferenceObjectFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenCompareReferenceObjectFileDialog.Title = "Compare Reference Csv"
    $OpenCompareReferenceObjectFileDialog.InitialDirectory = "$CollectedDataDirectory"
    $OpenCompareReferenceObjectFileDialog.filter = "CSV (*.csv)| *.csv|Excel (*.xlsx)| *.xlsx|Excel (*.xls)| *.xls|All files (*.*)|*.*"
    $OpenCompareReferenceObjectFileDialog.ShowDialog() | Out-Null
    $OpenCompareReferenceObjectFileDialog.ShowHelp = $true

    if ($OpenCompareReferenceObjectFileDialog.Filename) {

    # Compare Difference Object
    [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
    $OpenCompareDifferenceObjectFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenCompareDifferenceObjectFileDialog.Title = "Compare Difference Csv"
    $OpenCompareDifferenceObjectFileDialog.InitialDirectory = "$CollectedDataDirectory"
    $OpenCompareDifferenceObjectFileDialog.filter = "CSV (*.csv)| *.csv|Excel (*.xlsx)| *.xlsx|Excel (*.xls)| *.xls|All files (*.*)|*.*"
    $OpenCompareDifferenceObjectFileDialog.ShowDialog() | Out-Null
    $OpenCompareDifferenceObjectFileDialog.ShowHelp = $true

    if ($OpenCompareDifferenceObjectFileDialog.Filename) {

    # Imports Csv file headers
    [array]$DropDownArrayItems = Import-Csv $OpenCompareReferenceObjectFileDialog.FileName | Get-Member -MemberType NoteProperty | Select-Object -Property Name -ExpandProperty Name
    [array]$DropDownArray = $DropDownArrayItems | sort

    # This Function Returns the Selected Value and Closes the Form
    function CompareCsvFilesFormReturn-DropDown {
        if ($DropDownField.SelectedItem -eq $null){
            $DropDownField.SelectedItem = $DropDownField.Items[0]
            $script:Choice = $DropDownField.SelectedItem.ToString()
            $CompareCsvFilesForm.Close()
        }
        else{
            $script:Choice = $DropDownField.SelectedItem.ToString()
            $CompareCsvFilesForm.Close()
        }
    }

    function SelectProperty{
        [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
        [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")

        #------------------------
        # Compare Csv Files Form
        #------------------------
        $CompareCsvFilesForm = New-Object System.Windows.Forms.Form
        $CompareCsvFilesForm.width  = 330
        $CompareCsvFilesForm.height = 160
        $CompareCsvFilesForm.Text   = ”Compare Two CSV Files”
        $CompareCsvFilesForm.Icon   = [System.Drawing.Icon]::ExtractAssociatedIcon("$ResourcesDirectory\favicon.ico")
        $CompareCsvFilesForm.StartPosition = "CenterScreen"
        $CompareCsvFilesForm.ControlBox = $true
        #$CompareCsvFilesForm.Add_Shown({$CompareCsvFilesForm.Activate()})

        #-----------------
        # Drop Down Label
        #-----------------
        $DropDownLabel          = New-Object System.Windows.Forms.Label
        $DropDownLabel.Location = New-Object System.Drawing.Size(10,10) 
        $DropDownLabel.size     = New-Object System.Drawing.Size(290,45) 
        $DropDownLabel.Text     = "What Property Field Do You Want To Compare?`n  <=   Found in the Reference File`n  =>   Found in the Difference File`n`nReplace the 'Name' property as necessary..."
        $CompareCsvFilesForm.Controls.Add($DropDownLabel)

        #-----------------
        # Drop Down Field
        #-----------------
        $DropDownField          = New-Object System.Windows.Forms.ComboBox
        $DropDownField.Location = New-Object System.Drawing.Size(10,($DropDownLabel.Location.y + $DropDownLabel.Size.Height))
        $DropDownField.Size     = New-Object System.Drawing.Size(290,30)
        ForEach ($Item in $DropDownArray) {
         [void] $DropDownField.Items.Add($Item)
        }
        $CompareCsvFilesForm.Controls.Add($DropDownField)

        #------------------
        # Drop Down Button
        #------------------
        $DropDownButton          = New-Object System.Windows.Forms.Button
        $DropDownButton.Location = New-Object System.Drawing.Size(10,($DropDownField.Location.y + $DropDownField.Size.Height + 10))
        $DropDownButton.Size     = New-Object System.Drawing.Size(100,20)
        $DropDownButton.Text     = "Execute"
        $DropDownButton.Add_Click({CompareCsvFilesFormReturn-DropDown})
        $CompareCsvFilesForm.Controls.Add($DropDownButton)   

        [void] $CompareCsvFilesForm.ShowDialog()
        return $script:choice
    }
    $Property = $null
    $Property = SelectProperty

   
    #--------------------------------
    # Compares two Csv files Command
    #--------------------------------
    Compare-Object -ReferenceObject (Import-Csv $OpenCompareReferenceObjectFileDialog.FileName) -DifferenceObject (Import-Csv $OpenCompareDifferenceObjectFileDialog.FileName) -Property $Property `
        | Out-GridView -OutputMode Multiple | Set-Variable -Name CompareImportResults

    # Outputs messages to mainlistbox 
    $MainListBox.Items.Clear()
    $MainListBox.Items.Add("Compare Reference File:  $($OpenCompareReferenceObjectFileDialog.FileName)")
    $MainListBox.Items.Add("Compare Difference File: $($OpenCompareDifferenceObjectFileDialog.FileName)")
    $MainListBox.Items.Add("Compare Property Field:  $($Property)")

    # Writes selected fields to OpNotes
    if ($CompareImportResults) {
        $OpNotesListBox.Items.Add("$((Get-Date).ToString('yyyy/MM/dd HH:mm:ss')) Compare Reference File:  $($OpenCompareReferenceObjectFileDialog.FileName)")
        $OpNotesListBox.Items.Add("$((Get-Date).ToString('yyyy/MM/dd HH:mm:ss')) Compare Difference File: $($OpenCompareDifferenceObjectFileDialog.FileName)")
        $OpNotesListBox.Items.Add("$((Get-Date).ToString('yyyy/MM/dd HH:mm:ss')) Compare Property Field:  $($OpenCompareWhatToCompare)")
        foreach ($Selection in $CompareImportResults) {
            $OpNotesListBox.Items.Add("$((Get-Date).ToString('yyyy/MM/dd HH:mm:ss')) Compare Selection: $($Selection)")
            Add-Content -Path $OpNotesWriteOnlyFile -Value ($OpNotesListBox.SelectedItems) -Force
        }
    }
    OpNotesSaveScript

    } # End If Statement for Compare CSV Reference
    } # End If Statement for Compare CSV Difference
})

#============================================================================================================================================================
# Custom View Chart
#============================================================================================================================================================
#-------------------
# View Chart Button
#-------------------
$ViewChartButton          = New-Object System.Windows.Forms.Button
$ViewChartButton.Name     = "Build Chart"
$ViewChartButton.Text     = "$($ViewChartButton.Name)"
$ViewChartButton.UseVisualStyleBackColor = $True
$ViewChartButton.Location = New-Object System.Drawing.Size(($CompareButton.Location.X + $CompareButton.Size.Width + 5),$CompareButton.Location.Y)
$ViewChartButton.Size     = New-Object System.Drawing.Size(115,22)
$Section2MainTab.Controls.Add($ViewChartButton)

$ViewChartButton.add_click({
    # Open File
    [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
    $ViewChartOpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $ViewChartOpenFileDialog.Title = "Open File To View As A Chart"
    $ViewChartOpenFileDialog.InitialDirectory = "$CollectedDataDirectory"
    $ViewChartOpenFileDialog.filter = "CSV (*.csv)| *.csv|Excel (*.xlsx)| *.xlsx|Excel (*.xls)| *.xls|All files (*.*)|*.*"
    $ViewChartOpenFileDialog.ShowDialog() | Out-Null
    $ViewChartOpenFileDialog.ShowHelp = $true

    #====================================
    # Custom View Chart Command Function
    #====================================
    function ViewChartCommand {
        #https://bytecookie.wordpress.com/2012/04/13/tutorial-powershell-and-microsoft-chart-controls-or-how-to-spice-up-your-reports/
        # PowerShell v3+ OR PowerShell v2 with Microsoft Chart Controls for Microsoft .NET Framework 3.5 Installed

        Function Invoke-SaveDialog {
            $FileTypes = [enum]::GetNames('System.Windows.Forms.DataVisualization.Charting.ChartImageFormat')| ForEach {
                $_.Insert(0,'*.')
            }
            $SaveFileDlg = New-Object System.Windows.Forms.SaveFileDialog
            $SaveFileDlg.DefaultExt='PNG'
            $SaveFileDlg.Filter="Image Files ($($FileTypes)) | All Files (*.*)|*.*"
            $return = $SaveFileDlg.ShowDialog()
            If ($Return -eq 'OK') {
                [pscustomobject]@{
                    FileName = $SaveFileDlg.FileName
                    Extension = $SaveFileDlg.FileName -replace '.*\.(.*)','$1'
                }
            }
        }
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Windows.Forms.DataVisualization

        #-----------------------------------------
        # Custom View Chart - Obtains source data
        #-----------------------------------------
            $DataSource = $ViewChartFile | Select-Object -Property $Script:ViewChartChoice[0], $Script:ViewChartChoice[1]

        #--------------------------
        # Custom View Chart Object
        #--------------------------
            $Chart = New-object System.Windows.Forms.DataVisualization.Charting.Chart
            $Chart.Width           = 700
            $Chart.Height          = 400
            $Chart.Left            = 10
            $Chart.Top             = 10
            $Chart.BackColor       = [System.Drawing.Color]::White
            $Chart.BorderColor     = 'Black'
            $Chart.BorderDashStyle = 'Solid'
            $Chart.Font            = New-Object System.Drawing.Font @('Microsoft Sans Serif','18', [System.Drawing.FontStyle]::Bold)
        #-------------------------
        # Custom View Chart Title 
        #-------------------------
            $ChartTitle = New-Object System.Windows.Forms.DataVisualization.Charting.Title
            $ChartTitle.text      = ($ViewChartOpenFileDialog.FileName.split('\'))[-1] -replace '.csv',''
            $ChartTitle.Font      = New-Object System.Drawing.Font @('Microsoft Sans Serif','18', [System.Drawing.FontStyle]::Bold)
            $ChartTitle.ForeColor = "black"
            $ChartTitle.Alignment = "topcenter" #"topLeft"
            $Chart.Titles.Add($ChartTitle)
        #------------------------
        # Custom View Chart Area
        #------------------------
            $ChartArea                = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
            $ChartArea.Name           = "Chart Area"
            $ChartArea.AxisX.Title    = $Script:ViewChartChoice[0]
            if ($Script:ViewChartChoice[1] -eq "PSComputername") {$ChartArea.AxisY.Title = "Number of Computers"}
            else {$ChartArea.AxisY.Title    = $Script:ViewChartChoice[1]}
            $ChartArea.AxisX.Interval = 1
            #$ChartArea.AxisY.Interval = 1
            $ChartArea.AxisY.IntervalAutoMode = $true

            # Option to enable 3D Charts
            if ($Script:ViewChartChoice[7] -eq $true) {
                $ChartArea.Area3DStyle.Enable3D=$True
                $ChartArea.Area3DStyle.Inclination = 50
            }
            $Chart.ChartAreas.Add($ChartArea)
        #--------------------------
        # Custom View Chart Legend 
        #--------------------------
            $Legend = New-Object system.Windows.Forms.DataVisualization.Charting.Legend
            $Legend.Enabled = $Script:ViewChartChoice[6]
            $Legend.Name = "Legend"
            $Legend.Title = $Script:ViewChartChoice[1]
            $Legend.TitleAlignment = "topleft"
            $Legend.TitleFont = New-Object System.Drawing.Font @('Microsoft Sans Serif','11', [System.Drawing.FontStyle]::Bold)
            $Legend.IsEquallySpacedItems = $True
            $Legend.BorderColor = 'Black'
            $Chart.Legends.Add($Legend)
        #---------------------------------
        # Custom View Chart Data Series 1
        #---------------------------------
            $Series01Name = $Script:ViewChartChoice[1]
            $Chart.Series.Add("$Series01Name")
            $Chart.Series["$Series01Name"].ChartType = $Script:ViewChartChoice[2]
            $Chart.Series["$Series01Name"].BorderWidth  = 1
            $Chart.Series["$Series01Name"].IsVisibleInLegend = $true
            $Chart.Series["$Series01Name"].Chartarea = "Chart Area"
            $Chart.Series["$Series01Name"].Legend = "Legend"
            $Chart.Series["$Series01Name"].Color = "#62B5CC"
            $Chart.Series["$Series01Name"].Font = New-Object System.Drawing.Font @('Microsoft Sans Serif','9', [System.Drawing.FontStyle]::Normal)
            # Pie Charts - Moves text off pie
            $Chart.Series["$Series01Name"]['PieLabelStyle'] = 'Outside'
            $Chart.Series["$Series01Name"]['PieLineColor'] = 'Black'
            $Chart.Series["$Series01Name"]['PieDrawingStyle'] = 'Concave'
            

        #-----------------------------------------------------------
        # Custom View Chart - Code that counts computers that match
        #-----------------------------------------------------------
            # If the Second field/Y Axis equals PSComputername, it counts it
            if ($Script:ViewChartChoice[1] -eq "PSComputerName") {
                $Script:ViewChartChoice0 = "Name"
                $Script:ViewChartChoice1 = "PSComputerName"                
                #$DataSource = Import-Csv "C:\Users\Dan\Documents\GitHub\Dev Ops\Collected Data\2018-10-23 @ 2246 51\Processes - Standard.csv"
                $UniqueDataFields = $DataSource | Select-Object -Property $Script:ViewChartChoice0 | Sort-Object -Property $Script:ViewChartChoice0 -Unique                
                $ComputerWithDataResults = @()
                foreach ($DataField in $UniqueDataFields) {
                    $Count = 0
                    $Computers = @()
                    foreach ( $Line in $DataSource ) { 
                        if ( $Line.Name -eq $DataField.Name ) {
                            $Count += 1
                            if ( $Computers -notcontains $Line.PSComputerName ) { $Computers += $Line.PSComputerName }
                        }
                    }
                    $UniqueCount = $Computers.Count
                    $ComputersWithData =  New-Object PSObject -Property @{
                        DataField    = $DataField
                        TotalCount   = $Count
                        UniqueCount  = $UniqueCount
                        ComputerHits = $Computers 
                    }
                    $ComputerWithDataResults += $ComputersWithData
                    #"$DataField"
                    #"Count: $Count"
                    #"Computers: $Computers"
                    #"------------------------------"
                }
                #$DataSourceX = '$_.DataField.Name'
                #$DataSourceY = '$_.UniqueCount'
                if ($Script:ViewChartChoice[5]) {
                    $ComputerWithDataResults `
                        | Sort-Object -Property UniqueCount -Descending `
                        | Select-Object -First $Script:ViewChartChoice[3] `
                        | ForEach-Object {$Chart.Series["$Series01Name"].Points.AddXY($_.DataField.Name,$_.UniqueCount)}
                }
                else {
                    $ComputerWithDataResults `
                        | Sort-Object -Property UniqueCount `
                        | Select-Object -First $Script:ViewChartChoice[3] `
                        | ForEach-Object {$Chart.Series["$Series01Name"].Points.AddXY($_.DataField.Name,$_.UniqueCount)}
                }
            }
            # If the Second field/Y Axis DOES NOT equal PSComputername, Data is generated from the DataSource fields Selected
            else {
                ConvertCSVNumberStringsToIntergers $DataSource
                $DataSourceX = '$_.($Script:ViewChartXChoice)'
                $DataSourceY = '$_.($Script:ViewChartYChoice)'
                if ($Script:ViewChartChoice[5]) {
                    $DataSource `
                    | Sort-Object -Property $Script:ViewChartChoice[1] -Descending `
                    | Select-Object -First $Script:ViewChartChoice[3] `
                    | ForEach-Object {$Chart.Series["$Series01Name"].Points.AddXY( $(iex $DataSourceX), $(iex $DataSourceY) )}  
                }
                else {
                    $DataSource `
                    | Sort-Object -Property $Script:ViewChartChoice[1] `
                    | Select-Object -First $Script:ViewChartChoice[3] `
                    | ForEach-Object {$Chart.Series["$Series01Name"].Points.AddXY( $(iex $DataSourceX), $(iex $DataSourceY) )}  
                }
            }        
        #------------------------
        # Custom View Chart Form 
        #------------------------
            $AnchorAll = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right -bor
                [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left
            $ViewChartForm               = New-Object Windows.Forms.Form
            $ViewChartForm.Icon          = [System.Drawing.Icon]::ExtractAssociatedIcon("$ResourcesDirectory\favicon.ico")
            $ViewChartForm.Width         = 740
            $ViewChartForm.Height        = 490
            $ViewChartForm.StartPosition = "CenterScreen"
            $ViewChartForm.controls.add($Chart)
            $Chart.Anchor = $AnchorAll
        #-------------------------------
        # Custom View Chart Save Button
        #-------------------------------
            $SaveButton        = New-Object Windows.Forms.Button
            $SaveButton.Text   = "Save"
            $SaveButton.Top    = 420
            $SaveButton.Left   = 600
            $SaveButton.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
             [enum]::GetNames('System.Windows.Forms.DataVisualization.Charting.ChartImageFormat')
            $SaveButton.add_click({
                $Result = Invoke-SaveDialog
                If ($Result) { $Chart.SaveImage($Result.FileName, $Result.Extension) }
            }) 
        $ViewChartForm.controls.add($SaveButton)
        $ViewChartForm.Add_Shown({$ViewChartForm.Activate()})
        [void]$ViewChartForm.ShowDialog()
        #---------------------------------------
        # Custom View Chart - Autosave an Image
        #---------------------------------------
        #$Chart.SaveImage('C:\temp\chart.jpeg', 'jpeg')
    }

    #=================================================
    # Custom View Chart Select Property Form Function
    #=================================================
    # This following 'if statement' is used for when canceling out of a window
    if ($ViewChartOpenFileDialog.FileName) {
        # Imports the file chosen
        $ViewChartFile = Import-Csv $ViewChartOpenFileDialog.FileName
        [array]$ViewChartArrayItems = $ViewChartFile | Get-Member -MemberType NoteProperty | Select-Object -Property Name -ExpandProperty Name
        [array]$ViewChartArray = $ViewChartArrayItems | Sort-Object

        function ViewChartSelectProperty{
            [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
            [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")

            #------------------------------------
            # Custom View Chart Execute Function
            #------------------------------------
            # This Function Returns the Selected Value from the Drop Down and then Closes the Form
            function ViewChartExecute {
                if ($ViewChartXComboBox.SelectedItem -eq $null){
                    #$ViewChartXComboBox.SelectedItem = $ViewChartXComboBox.Items[0]
                    $ViewChartXComboBox.SelectedItem = "Name"
                    $Script:ViewChartXChoice = $ViewChartXComboBox.SelectedItem.ToString()
                    #$ViewChartSelectionForm.Close()
                }
                if ($ViewChartYComboBox.SelectedItem -eq $null){
                    #$ViewChartYComboBox.SelectedItem = $ViewChartYComboBox.Items[0]
                    $ViewChartYComboBox.SelectedItem = "PSComputerName"
                    $Script:ViewChartYChoice = $ViewChartYComboBox.SelectedItem.ToString()
                    #$ViewChartSelectionForm.Close()
                }
                if ($ViewChartChartTypesComboBox.SelectedItem -eq $null){
                    #$ViewChartChartTypesComboBox.SelectedItem = $ViewChartChartTypesComboBox.Items[0]
                    $ViewChartChartTypesComboBox.SelectedItem = "Column"
                    $Script:ViewChartChartTypesChoice = $ViewChartChartTypesComboBox.SelectedItem.ToString()
                    #$ViewChartSelectionForm.Close()
                }
                else{
                    $Script:ViewChartXChoice = $ViewChartXComboBox.SelectedItem.ToString()
                    $Script:ViewChartYChoice = $ViewChartYComboBox.SelectedItem.ToString()
                    $Script:ViewChartChartTypesChoice = $ViewChartChartTypesComboBox.SelectedItem.ToString()
                    ViewChartCommand
                    #$ViewChartSelectionForm.Close()
                }
                # This array outputs the multiple results and is later used in the charts
                $Script:ViewChartChoice = @($Script:ViewChartXChoice, $Script:ViewChartYChoice, $Script:ViewChartChartTypesChoice, $ViewChartLimitResultsTextBox.Text, $ViewChartAscendingRadioButton.Checked, $ViewChartDescendingRadioButton.Checked, $ViewChartLegendCheckBox.Checked, $ViewChart3DChartCheckBox.Checked)
                <# Notes:
                    $Script:ViewChartChoice[0] = $Script:ViewChartXChoice
                    $Script:ViewChartChoice[1] = $Script:ViewChartYChoice
                    $Script:ViewChartChoice[2] = $Script:ViewChartChartTypesChoice
                    $Script:ViewChartChoice[3] = $ViewChartLimitResultsTextBox.Text
                    $Script:ViewChartChoice[4] = $ViewChartAscendingRadioButton.Checked
                    $Script:ViewChartChoice[5] = $ViewChartDescendingRadioButton.Checked
                    $Script:ViewChartChoice[6] = $ViewChartLegendCheckBox.Checked
                    $Script:ViewChartChoice[7] = $ViewChart3DChartCheckBox.Checked
                #>
                return $Script:ViewChartChoice
            }

            #----------------------------------
            # Custom View Chart Selection Form
            #----------------------------------
            $ViewChartSelectionForm        = New-Object System.Windows.Forms.Form
            $ViewChartSelectionForm.width  = 327
            $ViewChartSelectionForm.height = 287 
            $ViewChartSelectionForm.StartPosition = "CenterScreen"
            $ViewChartSelectionForm.Text   = ”View Chart - Select Fields ”
            $ViewChartSelectionForm.Icon   = [System.Drawing.Icon]::ExtractAssociatedIcon("$ResourcesDirectory\favicon.ico")
            $ViewChartSelectionForm.ControlBox = $true
            #$ViewChartSelectionForm.Add_Shown({$ViewChartSelectionForm.Activate()})

            #------------------------------
            # Custom View Chart Main Label
            #------------------------------
            $ViewChartMainLabel          = New-Object System.Windows.Forms.Label
            $ViewChartMainLabel.Location = New-Object System.Drawing.Size(10,10) 
            $ViewChartMainLabel.size     = New-Object System.Drawing.Size(290,25) 
            $ViewChartMainLabel.Text     = "Fill out the bellow to view a chart of a csv file:`nNote: Currently some limitations with compiled results files."
            $ViewChartSelectionForm.Controls.Add($ViewChartMainLabel)

            #------------------------------
            # Custom View Chart X ComboBox
            #------------------------------
            $ViewChartXComboBox          = New-Object System.Windows.Forms.ComboBox
            $ViewChartXComboBox.Location = New-Object System.Drawing.Size(10,($ViewChartMainLabel.Location.y + $ViewChartMainLabel.Size.Height + 5))
            $ViewChartXComboBox.Size     = New-Object System.Drawing.Size(185,25)
            $ViewChartXComboBox.Text     = "Field 1 - X Axis"
            $ViewChartXComboBox.AutoCompleteSource = "ListItems"
            $ViewChartXComboBox.AutoCompleteMode   = "SuggestAppend" # Options are: "Suggest", "Append", "SuggestAppend"
            $ViewChartXComboBox.Add_KeyDown({ if ($_.KeyCode -eq "Enter") {ViewChartExecute} })
            ForEach ($Item in $ViewChartArray) { $ViewChartXComboBox.Items.Add($Item) }
            $ViewChartSelectionForm.Controls.Add($ViewChartXComboBox)

            #------------------------------
            # Custom View Chart Y ComboBox
            #------------------------------
            $ViewChartYComboBox          = New-Object System.Windows.Forms.ComboBox
            $ViewChartYComboBox.Location = New-Object System.Drawing.Size(10,($ViewChartXComboBox.Location.y + $ViewChartXComboBox.Size.Height + 5))
            $ViewChartYComboBox.Size     = New-Object System.Drawing.Size(185,25)
            $ViewChartYComboBox.Text     = "Field 2 - Y Axis"
            $ViewChartYComboBox.AutoCompleteSource = "ListItems"
            $ViewChartYComboBox.AutoCompleteMode   = "SuggestAppend" # Options are: "Suggest", "Append", "SuggestAppend"
            $ViewChartYComboBox.Add_KeyDown({ if ($_.KeyCode -eq "Enter") {ViewChartExecute} })
            ForEach ($Item in $ViewChartArray) { $ViewChartYComboBox.Items.Add($Item) }
            $ViewChartSelectionForm.Controls.Add($ViewChartYComboBox)

            #----------------------------------
            # Custom View Chart Types ComboBox
            #----------------------------------
            $ViewChartChartTypesComboBox          = New-Object System.Windows.Forms.ComboBox
            $ViewChartChartTypesComboBox.Location = New-Object System.Drawing.Size(10,($ViewChartYComboBox.Location.y + $ViewChartYComboBox.Size.Height + 5))
            $ViewChartChartTypesComboBox.Size     = New-Object System.Drawing.Size(185,25)
            $ViewChartChartTypesComboBox.Text     = "Chart Types"
            $ViewChartChartTypesComboBox.AutoCompleteSource = "ListItems"
            $ViewChartChartTypesComboBox.AutoCompleteMode   = "SuggestAppend" # Options are: "Suggest", "Append", "SuggestAppend"
            $ViewChartChartTypesComboBox.Add_KeyDown({ if ($_.KeyCode -eq "Enter") {ViewChartExecute} })
            $ChartTypesAvailable = @('Pie','Column','Line','Bar','Doughnut','Area','--- Less Commonly Used Below ---','BoxPlot','Bubble','CandleStick','ErrorBar','Fastline','FastPoint','Funnel','Kagi','Point','PointAndFigure','Polar','Pyramid','Radar','Range','Rangebar','RangeColumn','Renko','Spline','SplineArea','SplineRange','StackedArea','StackedBar','StackedColumn','StepLine','Stock','ThreeLineBreak')
            ForEach ($Item in $ChartTypesAvailable) {
             [void] $ViewChartChartTypesComboBox.Items.Add($Item)
            }
            $ViewChartSelectionForm.Controls.Add($ViewChartChartTypesComboBox) 

            #---------------------------------------
            # Custom View Chart Limit Results Label
            #---------------------------------------
            $ViewChartLimitResultsLabel          = New-Object System.Windows.Forms.Label
            $ViewChartLimitResultsLabel.Location = New-Object System.Drawing.Size(10,($ViewChartChartTypesComboBox.Location.y + $ViewChartChartTypesComboBox.Size.Height + 8)) 
            $ViewChartLimitResultsLabel.size     = New-Object System.Drawing.Size(120,25) 
            $ViewChartLimitResultsLabel.Text     = "Limit Results to:"
            $ViewChartSelectionForm.Controls.Add($ViewChartLimitResultsLabel)

            #-----------------------------------------
            # Custom View Chart Limit Results Textbox
            #-----------------------------------------
            $ViewChartLimitResultsTextBox          = New-Object System.Windows.Forms.TextBox
            $ViewChartLimitResultsTextBox.Text     = 10
            $ViewChartLimitResultsTextBox.Location = New-Object System.Drawing.Size(135,($ViewChartChartTypesComboBox.Location.y + $ViewChartChartTypesComboBox.Size.Height + 5))
            $ViewChartLimitResultsTextBox.Size     = New-Object System.Drawing.Size(60,25)
            $ViewChartLimitResultsTextBox.Add_KeyDown({ if ($_.KeyCode -eq "Enter") {ViewChartExecute} })
            $ViewChartSelectionForm.Controls.Add($ViewChartLimitResultsTextBox)

            #---------------------------------------
            # Custom View Chart Sort Order GroupBox
            #---------------------------------------
            # Create a group that will contain your radio buttons
            $ViewChartSortOrderGroupBox          = New-Object System.Windows.Forms.GroupBox
            $ViewChartSortOrderGroupBox.Location = New-Object System.Drawing.Size(10,($ViewChartLimitResultsTextBox.Location.y + $ViewChartLimitResultsTextBox.Size.Height + 7))
            $ViewChartSortOrderGroupBox.size     = '290,65'
            $ViewChartSortOrderGroupBox.text     = "Select how to Sort Data:"

                ### Ascending Radio Button
                $ViewChartAscendingRadioButton          = New-Object System.Windows.Forms.RadioButton
                $ViewChartAscendingRadioButton.Location = New-Object System.Drawing.Size(20,15)
                $ViewChartAscendingRadioButton.size     = '250,25'
                $ViewChartAscendingRadioButton.Checked  = $false
                $ViewChartAscendingRadioButton.Text     = "Ascending / Lowest to Highest"
                
                ### Descending Radio Button
                $ViewChartDescendingRadioButton          = New-Object System.Windows.Forms.RadioButton
                $ViewChartDescendingRadioButton.Location = New-Object System.Drawing.Size(20,38)
                $ViewChartDescendingRadioButton.size     = '250,25'
                $ViewChartDescendingRadioButton.Checked  = $true
                $ViewChartDescendingRadioButton.Text     = "Descending / Highest to Lowest"
                
                $ViewChartSortOrderGroupBox.Controls.AddRange(@($ViewChartAscendingRadioButton,$ViewChartDescendingRadioButton))
            $ViewChartSelectionForm.Controls.Add($ViewChartSortOrderGroupBox) 

            #------------------------------------
            # Custom View Chart Options GroupBox
            #------------------------------------
            # Create a group that will contain your radio buttons
            $ViewChartOptionsGroupBox          = New-Object System.Windows.Forms.GroupBox
            $ViewChartOptionsGroupBox.Location = New-Object System.Drawing.Size(($ViewChartXComboBox.Location.X + $ViewChartXComboBox.Size.Width + 5),$ViewChartXComboBox.Location.Y)
             $ViewChartOptionsGroupBox.size     = '100,105'
            $ViewChartOptionsGroupBox.text     = "Options:"

                ### View Chart Legend CheckBox
                $ViewChartLegendCheckBox          = New-Object System.Windows.Forms.Checkbox
                $ViewChartLegendCheckBox.Location = New-Object System.Drawing.Size(10,15)
                $ViewChartLegendCheckBox.Size     = '85,25'
                $ViewChartLegendCheckBox.Checked  = $false
                $ViewChartLegendCheckBox.Enabled  = $true
                $ViewChartLegendCheckBox.Text     = "Legend"
                $ViewChartLegendCheckBox.Font     = [System.Drawing.Font]::new("$Font", 8, [System.Drawing.FontStyle]::Bold)

                ### View Chart 3D Chart CheckBox
                $ViewChart3DChartCheckBox          = New-Object System.Windows.Forms.Checkbox
                $ViewChart3DChartCheckBox.Location = New-Object System.Drawing.Size(10,38)
                $ViewChart3DChartCheckBox.Size     = '85,25'
                $ViewChart3DChartCheckBox.Checked  = $false
                $ViewChart3DChartCheckBox.Enabled  = $true
                $ViewChart3DChartCheckBox.Text     = "3D Chart"
                $ViewChart3DChartCheckBox.Font     = [System.Drawing.Font]::new("$Font", 8, [System.Drawing.FontStyle]::Bold)
                
                $ViewChartOptionsGroupBox.Controls.AddRange(@($ViewChartLegendCheckBox,$ViewChart3DChartCheckBox))
            $ViewChartSelectionForm.Controls.Add($ViewChartOptionsGroupBox) 
            #----------------------------------
            # Custom View Chart Execute Button
            #----------------------------------
            $ViewChartExecuteButton          = New-Object System.Windows.Forms.Button
            $ViewChartExecuteButton.Location = New-Object System.Drawing.Size(200,($ViewChartSortOrderGroupBox.Location.y + $ViewChartSortOrderGroupBox.Size.Height + 8))
            $ViewChartExecuteButton.Size     = New-Object System.Drawing.Size(100,23)
            $ViewChartExecuteButton.Text     = "Execute"
            $ViewChartExecuteButton.Add_Click({ ViewChartExecute })            
            #---------------------------------------------
            # Custom View Chart Execute Button Note Label
            #---------------------------------------------
            $ViewChartExecuteButtonNoteLabel          = New-Object System.Windows.Forms.Label
            $ViewChartExecuteButtonNoteLabel.Location = New-Object System.Drawing.Size(10,($ViewChartSortOrderGroupBox.Location.y + $ViewChartSortOrderGroupBox.Size.Height + 8)) 
            $ViewChartExecuteButtonNoteLabel.size     = New-Object System.Drawing.Size(190,25) 
            $ViewChartExecuteButtonNoteLabel.Text     = "Note: Press execute again if the desired chart did not appear."
            $ViewChartSelectionForm.Controls.Add($ViewChartExecuteButtonNoteLabel)

            $ViewChartSelectionForm.Controls.Add($ViewChartExecuteButton)   
            [void] $ViewChartSelectionForm.ShowDialog()
        }
        $Property = $null
        $Property = ViewChartSelectProperty
    }
}) 
















#============================================================================================================================================================
#============================================================================================================================================================
# Auto Create Charts
#============================================================================================================================================================
#============================================================================================================================================================
# https://bytecookie.wordpress.com/2012/04/13/tutorial-powershell-and-microsoft-chart-controls-or-how-to-spice-up-your-reports/
# https://blogs.msdn.microsoft.com/alexgor/2009/03/27/aligning-multiple-series-with-categorical-values/

#======================================
# Auto Charts Select Property Function
#======================================
function AutoChartsSelectOptions {
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")

    #----------------------------------
    # Auto Create Charts Selection Form
    #----------------------------------
    $AutoChartsSelectionForm        = New-Object System.Windows.Forms.Form
    $AutoChartsSelectionForm.width  = 327
    $AutoChartsSelectionForm.height = 243 
    $AutoChartsSelectionForm.StartPosition = "CenterScreen"
    $AutoChartsSelectionForm.Text   = ”View Chart - Select Fields ”
    $AutoChartsSelectionForm.Icon   = [System.Drawing.Icon]::ExtractAssociatedIcon("$ResourcesDirectory\favicon.ico")
    $AutoChartsSelectionForm.ControlBox = $true

    #------------------------------
    # Auto Create Charts Main Label
    #------------------------------
    $AutoChartsMainLabel          = New-Object System.Windows.Forms.Label
    $AutoChartsMainLabel.Location = New-Object System.Drawing.Size(10,10) 
    $AutoChartsMainLabel.size     = New-Object System.Drawing.Size(290,25) 
    $AutoChartsMainLabel.Text     = "This Will Auto Create Varios Charts From Past Collections."
    $AutoChartsSelectionForm.Controls.Add($AutoChartsMainLabel)

    #------------------------------------
    # Auto Create Charts Series GroupBox
    #------------------------------------
    # Create a group that will contain your radio buttons
    $AutoChartsSeriesGroupBox          = New-Object System.Windows.Forms.GroupBox
    $AutoChartsSeriesGroupBox.Location = New-Object System.Drawing.Size(10,($AutoChartsMainLabel.Location.y + $AutoChartsMainLabel.Size.Height + 8))
    $AutoChartsSeriesGroupBox.size     = '185,90'
    $AutoChartsSeriesGroupBox.text     = "Select Collection Series to View:`n(if Available)"

        ### View Chart Legend CheckBox
        $AutoChartsBaselineCheckBox          = New-Object System.Windows.Forms.Checkbox
        $AutoChartsBaselineCheckBox.Location = New-Object System.Drawing.Size(10,15)
        $AutoChartsBaselineCheckBox.Size     = '165,25'
        $AutoChartsBaselineCheckBox.Checked  = $true
        $AutoChartsBaselineCheckBox.Enabled  = $true
        $AutoChartsBaselineCheckBox.Text     = "Baseline"
        $AutoChartsBaselineCheckBox.Font     = [System.Drawing.Font]::new("$Font", 8, [System.Drawing.FontStyle]::Bold)

        ### View Chart 3D Chart CheckBox
        $AutoChartsPreviousCheckBox          = New-Object System.Windows.Forms.Checkbox
        $AutoChartsPreviousCheckBox.Location = New-Object System.Drawing.Size(10,38)
        $AutoChartsPreviousCheckBox.Size     = '165,25'
        $AutoChartsPreviousCheckBox.Checked  = $true
        $AutoChartsPreviousCheckBox.Enabled  = $true
        $AutoChartsPreviousCheckBox.Text     = "Previous"
        $AutoChartsPreviousCheckBox.Font     = [System.Drawing.Font]::new("$Font", 8, [System.Drawing.FontStyle]::Bold)

        ### View Chart 3D Chart CheckBox
        $AutoChartsMostRecentCheckBox          = New-Object System.Windows.Forms.Checkbox
        $AutoChartsMostRecentCheckBox.Location = New-Object System.Drawing.Size(10,61)
        $AutoChartsMostRecentCheckBox.Size     = '165,25'
        $AutoChartsMostRecentCheckBox.Checked  = $true
        $AutoChartsMostRecentCheckBox.Enabled  = $true
        $AutoChartsMostRecentCheckBox.Text     = "Most Recent"
        $AutoChartsMostRecentCheckBox.Font     = [System.Drawing.Font]::new("$Font", 8, [System.Drawing.FontStyle]::Bold)                

        $AutoChartsSeriesGroupBox.Controls.AddRange(@($AutoChartsBaselineCheckBox,$AutoChartsPreviousCheckBox,$AutoChartsMostRecentCheckBox))
    $AutoChartsSelectionForm.Controls.Add($AutoChartsSeriesGroupBox) 

    #------------------------------------
    # Auto Create Charts Options GroupBox
    #------------------------------------
    # Create a group that will contain your radio buttons
    $AutoChartsOptionsGroupBox          = New-Object System.Windows.Forms.GroupBox
    $AutoChartsOptionsGroupBox.Location = New-Object System.Drawing.Size(($AutoChartsSeriesGroupBox.Location.X + $AutoChartsSeriesGroupBox.Size.Width + 5),($AutoChartsSeriesGroupBox.Location.Y))
    $AutoChartsOptionsGroupBox.size     = '100,90'
    $AutoChartsOptionsGroupBox.text     = "Options:"

        ### View Chart Legend CheckBox
        $AutoChartsLegendCheckBox          = New-Object System.Windows.Forms.Checkbox
        $AutoChartsLegendCheckBox.Location = New-Object System.Drawing.Size(10,15)
        $AutoChartsLegendCheckBox.Size     = '85,25'
        $AutoChartsLegendCheckBox.Checked  = $true
        $AutoChartsLegendCheckBox.Enabled  = $true
        $AutoChartsLegendCheckBox.Text     = "Legend"
        $AutoChartsLegendCheckBox.Font     = [System.Drawing.Font]::new("$Font", 8, [System.Drawing.FontStyle]::Bold)

        ### View Chart 3D Chart CheckBox
        $AutoCharts3DChartCheckBox          = New-Object System.Windows.Forms.Checkbox
        $AutoCharts3DChartCheckBox.Location = New-Object System.Drawing.Size(10,38)
        $AutoCharts3DChartCheckBox.Size     = '85,25'
        $AutoCharts3DChartCheckBox.Checked  = $false
        $AutoCharts3DChartCheckBox.Enabled  = $true
        $AutoCharts3DChartCheckBox.Text     = "3D Chart"
        $AutoCharts3DChartCheckBox.Font     = [System.Drawing.Font]::new("$Font", 8, [System.Drawing.FontStyle]::Bold)
                
        $AutoChartsOptionsGroupBox.Controls.AddRange(@($AutoChartsLegendCheckBox,$AutoCharts3DChartCheckBox))
    $AutoChartsSelectionForm.Controls.Add($AutoChartsOptionsGroupBox) 

    #----------------------------------
    # Auto Chart Select Color ComboBox
    #----------------------------------
    $AutoChartColorSchemeSelectionComboBox          = New-Object System.Windows.Forms.ComboBox
    $AutoChartColorSchemeSelectionComboBox.Location = New-Object System.Drawing.Size(10,($AutoChartsMainLabel.Location.y + $AutoChartsMainLabel.Size.Height + 108))
    $AutoChartColorSchemeSelectionComboBox.Size     = New-Object System.Drawing.Size(185,25)
    $AutoChartColorSchemeSelectionComboBox.Text     = "Select Alternate Color Scheme"
    $AutoChartColorSchemeSelectionComboBox.AutoCompleteSource = "ListItems"
    $AutoChartColorSchemeSelectionComboBox.AutoCompleteMode   = "SuggestAppend" # Options are: "Suggest", "Append", "SuggestAppend"
    $ColorShcemesAvailable = @(
        'Blue, Orange, Red',
        'Light Blue, Orange, Red',
        'Black, Red, Green',  
        'Dark Red, Red, Orange',
        'Dark Blue, Blue, Light Blue',
        'Dark Green, Green, Light Green',
        'Dark Gray, Gray, Light Gray')
    ForEach ($Item in $ColorShcemesAvailable) {
        [void] $AutoChartColorSchemeSelectionComboBox.Items.Add($Item)
    }
    $AutoChartsSelectionForm.Controls.Add($AutoChartColorSchemeSelectionComboBox) 

    #----------------------------------
    # Auto Chart Select Chart ComboBox
    #----------------------------------
    $AutoChartSelectChartComboBox          = New-Object System.Windows.Forms.ComboBox
    $AutoChartSelectChartComboBox.Location = New-Object System.Drawing.Size(10,($AutoChartColorSchemeSelectionComboBox.Location.y + $AutoChartColorSchemeSelectionComboBox.Size.Height + 10))
    $AutoChartSelectChartComboBox.Size     = New-Object System.Drawing.Size(185,25)
    $AutoChartSelectChartComboBox.Text     = "Select A Chart"
    $AutoChartSelectChartComboBox.AutoCompleteSource = "ListItems"
    $AutoChartSelectChartComboBox.AutoCompleteMode   = "SuggestAppend" # Options are: "Suggest", "Append", "SuggestAppend"
    $AutoChartSelectChartComboBox.Add_KeyDown({ if ($_.KeyCode -eq "Enter") { AutoChartsViewCharts }})
    $AutoChartsAvailable = @(
        #"All Charts",
        "Logon Info",
        "Mapped Drives",
        "Network Settings",        
        "Processes - Standard",
        "Security Patches",
        "Services",
        "Shares",
        "Software Installed",
        "Startup Commands")
    ForEach ($Item in $AutoChartsAvailable) { [void] $AutoChartSelectChartComboBox.Items.Add($Item) }
    $AutoChartsSelectionForm.Controls.Add($AutoChartSelectChartComboBox) 

    #-----------------------------------
    # Auto Create Charts Execute Button
    #-----------------------------------
    $AutoChartsExecuteButton          = New-Object System.Windows.Forms.Button
    $AutoChartsExecuteButton.Location = New-Object System.Drawing.Size(200,($AutoChartsMainLabel.Location.y + $AutoChartsMainLabel.Size.Height + 107))
    $AutoChartsExecuteButton.Size     = New-Object System.Drawing.Size(101,54)
    $AutoChartsExecuteButton.Text     = "View Chart"
    $AutoChartsExecuteButton.Add_Click({ AutoChartsViewCharts })

    function AutoChartsViewCharts {
        if (($AutoChartsBaselineCheckBox.Checked -eq $False) -and ($AutoChartsPreviousCheckBox.Checked -eq $False) -and ($AutoChartsMostRecentCheckBox.Checked -eq $False)) {
            $OhDarn=[System.Windows.Forms.MessageBox]::Show(`
                "You need to select at least one collection series:`nBaseline, Previous, or Most Recent",`
                "PoSh-ACME",`
                [System.Windows.Forms.MessageBoxButtons]::OK)
                switch ($OhDarn){
                "OK" {
                    #write-host "You pressed OK"
                }
            }        
        }
        elseif ($AutoChartSelectChartComboBox.SelectedItem -notin $AutoChartsAvailable) {
            $OhDarn=[System.Windows.Forms.MessageBox]::Show(`
                "You need to select a Chart!",`
                "PoSh-ACME",`
                [System.Windows.Forms.MessageBoxButtons]::OK)
                switch ($OhDarn){
                "OK" {
                    #write-host "You pressed OK"
                }
            }
        }
        else {
            #####################################################################################################################################
            #####################################################################################################################################
            ##
            ## Auto Create Charts Form 
            ##
            #####################################################################################################################################             
            #####################################################################################################################################

            $AnchorAll = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right -bor
                [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left
            $AutoChartsForm               = New-Object Windows.Forms.Form
            $AutoChartsForm.Icon          = [System.Drawing.Icon]::ExtractAssociatedIcon("$ResourcesDirectory\favicon.ico")
            $AutoChartsForm.Width         = $PoShACME.Size.Width  #1160
            $AutoChartsForm.Height        = $PoShACME.Size.Height #638
            $AutoChartsForm.StartPosition = "CenterScreen"

            #####################################################################################################################################
            ##
            ## Auto Create Charts TabControl
            ##
            #####################################################################################################################################

            # The TabControl controls the tabs within it
            $AutoChartsTabControl               = New-Object System.Windows.Forms.TabControl
            $AutoChartsTabControl.Name          = "Auto Charts"
            $AutoChartsTabControl.Text          = "Auto Charts"
            $AutoChartsTabControl.Location      = New-Object System.Drawing.Size(5,5)
            $AutoChartsTabControl.Size          = New-Object System.Drawing.Size(1135,590) 
            $AutoChartsTabControl.ShowToolTips  = $True
            $AutoChartsTabControl.SelectedIndex = 0
            $AutoChartsTabControl.Anchor        = $AnchorAll
            $AutoChartsForm.Controls.Add($AutoChartsTabControl)
            #polo

            # These functions contains the commands to generate specific auto charts        
            function AutoChartsCommandLogonInfo {
                AutoChartsCommand -QueryName "Logon Info" -QueryTabName "Logged On Accounts" -PropertyX Name -PropertyY PSComputerName -ChartType1 'Column' -ChartType2_3 'Point' -MarkerStyle1 'None' -MarkerStyle2 'Square' -MarkerStyle3 'Diamond'
                AutoChartsCommand -QueryName "Logon Info" -QueryTabName "Number of Accounts Logged In To Computers" -PropertyX PSComputerName -PropertyY Name -ChartType1 'Column' -ChartType2_3 'Point' -MarkerStyle1 'None' -MarkerStyle2 'Square' -MarkerStyle3 'Diamond'
            }
            function AutoChartsCommandMappedDrives {
                AutoChartsCommand -QueryName "Mapped Drives" -QueryTabName "Number of Mapped Drives per Server" -PropertyX PSComputerName -PropertyY ProviderName -ChartType1 'Column' -ChartType2_3 'Point' -MarkerStyle1 'None' -MarkerStyle2 'Square' -MarkerStyle3 'Diamond'
                AutoChartsCommand -QueryName "Mapped Drives" -QueryTabName "Number of Servers to Mapped Drives" -PropertyX ProviderName -PropertyY PSComputerName -ChartType1 'Column' -ChartType2_3 'Point' -MarkerStyle1 'None' -MarkerStyle2 'Square' -MarkerStyle3 'Diamond'
            }
            function AutoChartsCommandNetworkSettings {
                AutoChartsCommand -QueryName "Network Settings" -QueryTabName "Number of Interfaces with IPs" -PropertyX PSComputerName -PropertyY IPAddress -ChartType1 'Column' -ChartType2_3 'Point' -MarkerStyle1 'None' -MarkerStyle2 'Square' -MarkerStyle3 'Diamond'
                AutoChartsCommand -QueryName "Network Settings" -QueryTabName "Number of Hosts with IPs"      -PropertyX IPAddress -PropertyY PSComputerName -ChartType1 'Column' -ChartType2_3 'Point' -MarkerStyle1 'None' -MarkerStyle2 'Square' -MarkerStyle3 'Diamond'            
            }
            function AutoChartsCommandProcessesStandard {
                AutoChartsCommand -QueryName "Processes - Standard" -QueryTabName "Process Names" -PropertyX Name -PropertyY PSComputerName -ChartType1 'Column' -ChartType2_3 'Point' -MarkerStyle1 'None' -MarkerStyle2 'Square' -MarkerStyle3 'Diamond'
                AutoChartsCommand -QueryName "Processes - Standard" -QueryTabName "Process Paths" -PropertyX Path -PropertyY PSComputerName -ChartType1 'Bar'    -ChartType2_3 'Bar'   -MarkerStyle1 'None' -MarkerStyle2 'None'   -MarkerStyle3 'None'
            }
            function AutoChartsCommandSecurityPatches {
                AutoChartsCommand -QueryName "Security Patches" -QueryTabName "Number of Computers with Security Patches" -PropertyX Name -PropertyY PSComputerName     -ChartType1 'Column' -ChartType2_3 'Point' -MarkerStyle1 'None' -MarkerStyle2 'Square' -MarkerStyle3 'Diamond'
                AutoChartsCommand -QueryName "Security Patches" -QueryTabName "Number of Security Patches per Computer"   -PropertyX PSComputerName -PropertyY HotFixID -ChartType1 'Column' -ChartType2_3 'Point' -MarkerStyle1 'None' -MarkerStyle2 'Square' -MarkerStyle3 'Diamond'
            }
            function AutoChartsCommandServices {
                AutoChartsCommand -QueryName "Services" -QueryTabName "Service Names" -PropertyX Name     -PropertyY PSComputerName -ChartType1 'Column' -ChartType2_3 'Point' -MarkerStyle1 'None' -MarkerStyle2 'Square' -MarkerStyle3 'Diamond'
                AutoChartsCommand -QueryName "Services" -QueryTabName "Service Paths" -PropertyX PathName -PropertyY PSComputerName -ChartType1 'Bar'    -ChartType2_3 'Bar'   -MarkerStyle1 'None' -MarkerStyle2 'None'   -MarkerStyle3 'None'
            }
            function AutoChartsCommandShares {
                AutoChartsCommand -QueryName "Shares" -QueryTabName "Shares" -PropertyX Path -PropertyY PSComputerName -ChartType1 'Column' -ChartType2_3 'Point' -MarkerStyle1 'None' -MarkerStyle2 'Square' -MarkerStyle3 'Diamond'
                AutoChartsCommand -QueryName "Shares" -QueryTabName "Shares" -PropertyX PSComputerName -PropertyY Path -ChartType1 'Bar'    -ChartType2_3 'Bar'   -MarkerStyle1 'None' -MarkerStyle2 'None'   -MarkerStyle3 'None'
            }
            function AutoChartsCommandSoftwareInstalled {
                AutoChartsCommand -QueryName "Software Installed" -QueryTabName "Software Installed" -PropertyX Name -PropertyY PSComputerName -ChartType1 'Column' -ChartType2_3 'Point' -MarkerStyle1 'None' -MarkerStyle2 'Square' -MarkerStyle3 'Diamond'
                AutoChartsCommand -QueryName "Software Installed" -QueryTabName "Software Installed" -PropertyX PSComputerName -PropertyY Name -ChartType1 'Column' -ChartType2_3 'Point' -MarkerStyle1 'None' -MarkerStyle2 'Square' -MarkerStyle3 'Diamond'
            }
            function AutoChartsCommandStartUpCommands {
                AutoChartsCommand -QueryName "Startup Commands" -QueryTabName "Startup Names"    -PropertyX Name    -PropertyY PSComputerName -ChartType1 'Column' -ChartType2_3 'Point' -MarkerStyle1 'None' -MarkerStyle2 'Square' -MarkerStyle3 'Diamond'
                AutoChartsCommand -QueryName "Startup Commands" -QueryTabName "Startup Commands" -PropertyX Command -PropertyY PSComputerName -ChartType1 'Bar'    -ChartType2_3 'Bar'   -MarkerStyle1 'None' -MarkerStyle2 'None'   -MarkerStyle3 'None'
            }

            # Calls the functions for the respective commands to generate charts
            if ($AutoChartSelectChartComboBox.SelectedItem -match "All Charts") {
                AutoChartsCommandLogonInfo
                AutoChartsCommandMappedDrives
                AutoChartsCommandNetworkSettings
                AutoChartsCommandProcessesStandard
                AutoChartsCommandSecurityPatches
                AutoChartsCommandServices
                AutoChartsCommandShares
                AutoChartsCommandSoftwareInstalled
                AutoChartsCommandStartUpCommands
            }
            elseif ($AutoChartSelectChartComboBox.SelectedItem -match "Logon Info")           { AutoChartsCommandLogonInfo }
            elseif ($AutoChartSelectChartComboBox.SelectedItem -match "Mapped Drives")        { AutoChartsCommandMappedDrives }
            elseif ($AutoChartSelectChartComboBox.SelectedItem -match "Network Settings")     { AutoChartsCommandNetworkSettings }
            elseif ($AutoChartSelectChartComboBox.SelectedItem -match "Processes - Standard") { AutoChartsCommandProcessesStandard }
            elseif ($AutoChartSelectChartComboBox.SelectedItem -match "Security Patches")     { AutoChartsCommandSecurityPatches }
            elseif ($AutoChartSelectChartComboBox.SelectedItem -match "Services")             { AutoChartsCommandServices }
            elseif ($AutoChartSelectChartComboBox.SelectedItem -match "Shares")               { AutoChartsCommandShares }
            elseif ($AutoChartSelectChartComboBox.SelectedItem -match "Software Installed")   { AutoChartsCommandSoftwareInstalled }
            elseif ($AutoChartSelectChartComboBox.SelectedItem -match "Startup Commands")     { AutoChartsCommandStartUpCommands }
        
            # Launches the form
            $AutoChartsForm.Add_Shown({$AutoChartsForm.Activate()})
            [void]$AutoChartsForm.ShowDialog()

            #---------------------------------------
            # Auto Create Charts - Autosave an Image
            #---------------------------------------
            #$AutoChart.SaveImage('C:\temp\chart.jpeg', 'jpeg')
        }
    }
    
    $AutoChartsSelectionForm.Controls.Add($AutoChartsExecuteButton)   
    [void] $AutoChartsSelectionForm.ShowDialog()
}

#=====================================
# Auto Create Charts Command Function
#=====================================
function AutoChartsCommand {
    param (
        $QueryName,
        $QueryTabName,
        $PropertyX,
        $PropertyY,
        $ChartType1,
        $ChartType2_3,
        $MarkerStyle1,
        $MarkerStyle2,
        $MarkerStyle3
    )

    # Searches though the all Collection Data Directories to find files that match the $QueryName
    $ListOfCollectedDataDirectories = (Get-ChildItem -Path $CollectedDataDirectory).FullName
    $CSVFileMatch = @()
    foreach ($CollectionDir in $ListOfCollectedDataDirectories) {
        $CSVFiles = (Get-ChildItem -Path $CollectionDir).FullName
        foreach ($CSVFile in $CSVFiles) {
            if ($CSVFile -match $QueryName) {
                $CSVFileMatch += $CSVFile
            }
        }
    }
    # Checkes if the Appropriate Checkbox is selected, if so it selects the very first, previous, and most recent collections respectively
    if ($AutoChartsBaselineCheckBox.Checked -eq $true) {
        $script:CSVFileBaselineCollection   = $CSVFileMatch | Select-Object -First 1
    }
    if ($AutoChartsPreviousCheckBox.Checked -eq $true) { 
        $script:CSVFilePreviousCollection   = $CSVFileMatch | Select-Object -Last 2 | Select-Object -First 1 
    }
    if ($AutoChartsMostRecentCheckBox.Checked -eq $true) { 
        $script:CSVFileMostRecentCollection   = $CSVFileMatch | Select-Object -Last 1 
    }

    # Checks if the files selected are identicle, removing series as necessary that are to prevent erroneous double data
    if (($script:CSVFileMostRecentCollection -eq $script:CSVFilePreviousCollection) -and ($script:CSVFileMostRecentCollection -eq $script:CSVFileBaselineCollection)) {
        $script:CSVFilePreviousCollection = $null
        $script:CSVFileBaselineCollection = $null
    }
    else {
        if (($script:CSVFileMostRecentCollection -ne $script:CSVFilePreviousCollection) -and ($script:CSVFilePreviousCollection -eq $script:CSVFileBaselineCollection)) {
            $script:CSVFilePreviousCollection = $null        
        }    
    }

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Windows.Forms.DataVisualization

    #--------------------------
    # Auto Create Charts Object
    #--------------------------
    $AutoChart = New-object System.Windows.Forms.DataVisualization.Charting.Chart
    $AutoChart.Width           = 1115
    $AutoChart.Height          = 552
    $AutoChart.Left            = 5
    $AutoChart.Top             = 7
    $AutoChart.BackColor       = [System.Drawing.Color]::White
    $AutoChart.BorderColor     = 'Black'
    $AutoChart.BorderDashStyle = 'Solid'
    #$AutoChart.DataManipulator.Sort() = "Descending"
    $AutoChart.Font            = New-Object System.Drawing.Font @('Microsoft Sans Serif','18', [System.Drawing.FontStyle]::Bold)
    $AutoChart.Anchor          = $AnchorAll
    
    #--------------------------
    # Auto Create Charts Title 
    #--------------------------
    $AutoChartTitle = New-Object System.Windows.Forms.DataVisualization.Charting.Title
    $AutoChartTitle.ForeColor = "black"
    if ($AutoChartsMostRecentCheckBox.Checked -eq $true) {
        $AutoChartTitle.Text = ($script:CSVFileMostRecentCollection.split('\'))[-1] -replace '.csv',''
    }
    elseif ($AutoChartsPreviousCheckBox.Checked -eq $true) {
        $AutoChartTitle.Text = ($script:CSVFilePreviousCollection.split('\'))[-1] -replace '.csv',''
    }
    elseif ($AutoChartsBaselineCheckBox.Checked -eq $true) {
        $AutoChartTitle.Text = ($CSVFileMostBaselineCollection.split('\'))[-1] -replace '.csv',''
    }
    else {       
        $AutoChartTitle.Text = "`Missing Data!`n1). Run The Appropriate Query`n2). Ensure To Select At Least One Series"
        $AutoChartTitle.ForeColor = "Red"
    }
    if (-not $script:CSVFileBaselineCollection -and -not $script:CSVFilePreviousCollection -and -not $script:CSVFileMostRecentCollection) {
        $AutoChartTitle.Text = "`Missing Data!`n1). Run The Appropriate Query`n2). Ensure To Select At Least One Series"
        $AutoChartTitle.ForeColor = "Red"
    }
    $AutoChartTitle.Font      = New-Object System.Drawing.Font @('Microsoft Sans Serif','18', [System.Drawing.FontStyle]::Bold)
    $AutoChartTitle.Alignment = "topcenter" #"topLeft"
    $AutoChart.Titles.Add($AutoChartTitle)

    #-------------------------
    # Auto Create Charts Area
    #-------------------------
    $AutoChartArea                        = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
    $AutoChartArea.Name                   = "Chart Area"
    $AutoChartArea.AxisX.Title            = $PropertyX
    if ($PropertyY -eq "PSComputername") {$AutoChartArea.AxisY.Title = "Number of Computers"}
    else {
        if ($PropertyY -eq 'Name') {
            $AutoChartArea.AxisY.Title    = "Number of $QueryName"
        }
        else {$AutoChartArea.AxisY.Title  = "Number of $PropertyY"}
    }
    #else {$AutoChartArea.AxisY.Title      = $PropertyY}
    $AutoChartArea.AxisX.Interval         = 1
    #$AutoChartArea.AxisY.Interval        = 1
    $AutoChartArea.AxisY.IntervalAutoMode = $true

    # Option to enable 3D Charts
    if ($AutoCharts3DChartCheckBox.Checked) {
        $AutoChartArea.Area3DStyle.Enable3D=$True
        $AutoChartArea.Area3DStyle.Inclination = 75
    }
    $AutoChart.ChartAreas.Add($AutoChartArea)

    #--------------------------
    # Auto Create Charts Legend 
    #--------------------------
    $Legend                      = New-Object system.Windows.Forms.DataVisualization.Charting.Legend
    $Legend.Enabled              = $AutoChartsLegendCheckBox.Checked
    $Legend.Name                 = "Legend"
    $Legend.Title                = "Legend"
    $Legend.TitleAlignment       = "topleft"
    $Legend.TitleFont            = New-Object System.Drawing.Font @('Microsoft Sans Serif','11', [System.Drawing.FontStyle]::Bold)
    $Legend.IsEquallySpacedItems = $True
    $Legend.BorderColor          = 'Black'
    $AutoChart.Legends.Add($Legend)

    #-----------------------------------------
    # Auto Create Charts Data Series Baseline
    #-----------------------------------------
    $Series01Name = "Baseline"
    $AutoChart.Series.Add("$Series01Name")
    $AutoChart.Series["$Series01Name"].Enabled           = $True
    $AutoChart.Series["$Series01Name"].ChartType         = $ChartType1
    $AutoChart.Series["$Series01Name"].BorderWidth       = 1
    $AutoChart.Series["$Series01Name"].IsVisibleInLegend = $true
    $AutoChart.Series["$Series01Name"].Chartarea         = "Chart Area"
    $AutoChart.Series["$Series01Name"].Legend            = "Legend"
    $AutoChart.Series["$Series01Name"].Font              = New-Object System.Drawing.Font @('Microsoft Sans Serif','9', [System.Drawing.FontStyle]::Normal)
    # Pie Charts - Moves text off pie
    $AutoChart.Series["$Series01Name"]['PieLineColor']   = 'Black'
    $AutoChart.Series["$Series01Name"]['PieLabelStyle']  = 'Outside'

    #-----------------------------------------
    # Auto Create Charts Data Series Previous
    #-----------------------------------------
    $Series02Name = 'Previous'
    $AutoChart.Series.Add("$Series02Name")
    $AutoChart.Series["$Series02Name"].Enabled           = $True
    $AutoChart.Series["$Series02Name"].BorderWidth       = 1
    $AutoChart.Series["$Series02Name"].IsVisibleInLegend = $true
    $AutoChart.Series["$Series02Name"].Chartarea         = "Chart Area"
    $AutoChart.Series["$Series02Name"].Legend            = "Legend"
    $AutoChart.Series["$Series02Name"].Font              = New-Object System.Drawing.Font @('Microsoft Sans Serif','9', [System.Drawing.FontStyle]::Normal)
    # Pie Charts - Moves text off pie
    #if (-not ($script:CSVFileMostRecentCollection -eq $script:CSVFilePreviousCollection) -or -not ($script:CSVFileMostRecentCollection -eq $script:CSVFileBaselineCollection)) {
    #    $AutoChart.Series["$Series03Name"].ChartType         = $ChartType1
    #    $AutoChart.Series["$Series03Name"].MarkerColor       = 'Blue'
    #}
    $AutoChart.Series["$Series02Name"]['PieLineColor']   = 'Black'
    $AutoChart.Series["$Series02Name"]['PieLabelStyle']  = 'Outside'
           
    #---------------------------------------
    # Auto Create Charts Data Series Recent
    #---------------------------------------
    $Series03Name = 'Most Recent'
    $AutoChart.Series.Add("$Series03Name")  
    $AutoChart.Series["$Series03Name"].Enabled           = $True
    $AutoChart.Series["$Series03Name"].BorderWidth       = 1
    $AutoChart.Series["$Series03Name"].IsVisibleInLegend = $true
    $AutoChart.Series["$Series03Name"].Chartarea         = "Chart Area"
    $AutoChart.Series["$Series03Name"].Legend            = "Legend"
    $AutoChart.Series["$Series03Name"].Font              = New-Object System.Drawing.Font @('Microsoft Sans Serif','9', [System.Drawing.FontStyle]::Normal)
    # Pie Charts - Moves text off pie
    $AutoChart.Series["$Series03Name"]['PieLineColor']   = 'Black'
    $AutoChart.Series["$Series03Name"]['PieLabelStyle']  = 'Outside'

    #-------------------------------------------------------
    # Auto Create Charts - Chart Type and Series Management
    #-------------------------------------------------------

    # Empties out variable that contains csv data if the respective checkbox is not checked
    if ($AutoChartsBaselineCheckBox.Checked   -eq $False) { $script:CSVFileBaselineCollection   = $null }
    if ($AutoChartsPreviousCheckBox.Checked   -eq $False) { $script:CSVFilePreviousCollection   = $null }
    if ($AutoChartsMostRecentCheckBox.Checked -eq $False) { $script:CSVFileMostRecentCollection = $null }

    # Controls which series is showing and what type of charts will be displayed
    if ($script:CSVFileBaselineCollection -and $script:CSVFilePreviousCollection -and $script:CSVFileMostRecentCollection) {
        $AutoChart.Series["$Series01Name"].ChartType     = $ChartType1
        $AutoChart.Series["$Series01Name"].Color         = 'Blue'
        $AutoChart.Series["$Series02Name"].ChartType     = $ChartType2_3
        $AutoChart.Series["$Series02Name"].MarkerColor   = 'Orange'  
        $AutoChart.Series["$Series02Name"].MarkerStyle   = $MarkerStyle2
        $AutoChart.Series["$Series02Name"].MarkerSize    = '10'            
        $AutoChart.Series["$Series03Name"].ChartType     = $ChartType2_3
        $AutoChart.Series["$Series03Name"].MarkerColor   = 'Red'  
        $AutoChart.Series["$Series03Name"].MarkerStyle   = $MarkerStyle3
        $AutoChart.Series["$Series03Name"].MarkerSize    = '10'        
        $AutoChart.Series["$Series01Name"].Enabled       = $True
        $AutoChart.Series["$Series02Name"].Enabled       = $True
        $AutoChart.Series["$Series03Name"].Enabled       = $True
    }
    elseif ($script:CSVFileBaselineCollection -and -not $script:CSVFilePreviousCollection -and -not $script:CSVFileMostRecentCollection) {
        $AutoChart.Series["$Series01Name"].ChartType     = $ChartType1
        $AutoChart.Series["$Series01Name"].Color         = 'Blue'
        $AutoChart.Series["$Series01Name"].Enabled       = $True
        $AutoChart.Series["$Series02Name"].Enabled       = $False
        $AutoChart.Series["$Series03Name"].Enabled       = $False
    }
    elseif (($script:CSVFileBaselineCollection) -and ($script:CSVFilePreviousCollection) -and -not ($script:CSVFileMostRecentCollection)) {
        $AutoChart.Series["$Series01Name"].ChartType     = $ChartType1
        $AutoChart.Series["$Series01Name"].Color         = 'Blue'
        $AutoChart.Series["$Series01Name"].MarkerColor   = 'Blue'              
        $AutoChart.Series["$Series02Name"].ChartType     = $ChartType2_3
        $AutoChart.Series["$Series02Name"].MarkerColor   = 'Orange'  
        $AutoChart.Series["$Series02Name"].MarkerStyle   = $MarkerStyle2
        $AutoChart.Series["$Series02Name"].MarkerSize    = '10'  
        $AutoChart.Series["$Series03Name"].Enabled       = $False
    }
    elseif (($script:CSVFileBaselineCollection) -and -not ($script:CSVFilePreviousCollection) -and ($script:CSVFileMostRecentCollection)) {
        $AutoChart.Series["$Series01Name"].ChartType     = $ChartType1
        $AutoChart.Series["$Series01Name"].Color         = 'Blue'         
        $AutoChart.Series["$Series03Name"].ChartType     = $ChartType2_3
        $AutoChart.Series["$Series03Name"].MarkerColor   = 'Red'  
        $AutoChart.Series["$Series03Name"].MarkerStyle   = $MarkerStyle3
        $AutoChart.Series["$Series03Name"].MarkerSize    = '10'  
        $AutoChart.Series["$Series02Name"].Enabled       = $False
    }

    elseif (($script:CSVFilePreviousCollection) -and -not ($script:CSVFileBaselineCollection) -and -not ($script:CSVFileMostRecentCollection)) {
        $AutoChart.Series["$Series02Name"].ChartType     = $ChartType1
        $AutoChart.Series["$Series02Name"].Color         = 'Orange'
        $AutoChart.Series["$Series01Name"].Enabled       = $False
        $AutoChart.Series["$Series03Name"].Enabled       = $False
    }
    elseif (($script:CSVFilePreviousCollection) -and -not ($script:CSVFileBaselineCollection) -and ($script:CSVFileMostRecentCollection)) {
        $AutoChart.Series["$Series02Name"].ChartType     = $ChartType1
        $AutoChart.Series["$Series02Name"].Color         = 'Orange'
        $AutoChart.Series["$Series03Name"].ChartType     = $ChartType2_3
        $AutoChart.Series["$Series03Name"].MarkerColor   = 'Red'  
        $AutoChart.Series["$Series03Name"].MarkerStyle   = $MarkerStyle3
        $AutoChart.Series["$Series03Name"].MarkerSize    = '10'                     
        $AutoChart.Series["$Series01Name"].Enabled       = $False
    }
    elseif (($script:CSVFileMostRecentCollection) -and -not ($script:CSVFilePreviousCollection) -and -not ($script:CSVFileBaselineCollection)) {
        $AutoChart.Series["$Series03Name"].ChartType     = $ChartType1
        $AutoChart.Series["$Series03Name"].Color         = 'Red'
        $AutoChart.Series["$Series01Name"].Enabled       = $False
        $AutoChart.Series["$Series02Name"].Enabled       = $False
    }

    #---------------------------------------------
    # Auto Create Charts - Alternate Color Scheme
    #---------------------------------------------
    if ($AutoChartColorSchemeSelectionComboBox -ne 'Select Alternate Color Scheme') {
        $AutoChart.Series["$Series01Name"].Color       = ($AutoChartColorSchemeSelectionComboBox.SelectedItem -replace ' ','' -split ',')[0]
        $AutoChart.Series["$Series01Name"].MarkerColor = ($AutoChartColorSchemeSelectionComboBox.SelectedItem -replace ' ','' -split ',')[0]
        $AutoChart.Series["$Series02Name"].Color       = ($AutoChartColorSchemeSelectionComboBox.SelectedItem -replace ' ','' -split ',')[1]
        $AutoChart.Series["$Series02Name"].MarkerColor = ($AutoChartColorSchemeSelectionComboBox.SelectedItem -replace ' ','' -split ',')[1]
        $AutoChart.Series["$Series03Name"].Color       = ($AutoChartColorSchemeSelectionComboBox.SelectedItem -replace ' ','' -split ',')[2]
        $AutoChart.Series["$Series03Name"].MarkerColor = ($AutoChartColorSchemeSelectionComboBox.SelectedItem -replace ' ','' -split ',')[2]
    }

    #------------------------------------------------------------
    # Auto Create Charts - Code that counts computers that match
    #------------------------------------------------------------
    function Merge-CSVFiles { 
        [cmdletbinding()] 
        param( 
            [string[]]$CSVFiles, 
            [string]$OutputFile = "c:\merged.csv" 
        ) 
        $Script:MergedCSVFilesOutput = @(); 
        foreach($CSV in $CSVFiles) { 
            if(Test-Path $CSV) {          
                $FileName = [System.IO.Path]::GetFileName($CSV) 
                $temp = Import-CSV -Path $CSV | select *, @{Expression={$FileName};Label="FileName"} 
                $Script:MergedCSVFilesOutput += $temp 
            } else { 
                Write-Warning "$CSV : No such file found" 
            } 
 
        }        
        #$Script:Output | Export-Csv -Path $OutputFile -NoTypeInformation 
        #Write-Output "$OutputFile successfully created" 
        return $Script:MergedCSVFilesOutput
    }

    # Later used to iterate through
    $CSVFileCollection = @($script:CSVFileBaselineCollection,$script:CSVFilePreviousCollection,$script:CSVFileMostRecentCollection)
    $SeriesCount = 0

    # If the Second field/Y Axis equals PSComputername, it counts it
    if ($PropertyY -eq "PSComputerName") {
        #$Script:AutoChartsChoice0 = "Name"
        #$Script:AutoChartsChoice1 = "PSComputerName"

        # This file merger is later used to get a unique count of PropertyX and add to the DataSource (later the count is then subtracted by 1), 
        # this allow each collection to have a minimum of zero count of a process. This aligns all results, otherwise unique results will be shifted off from one another
        Merge-CSVFiles -CSVFiles $script:CSVFileBaselineCollection,$script:CSVFilePreviousCollection,$script:CSVFileMostRecentCollection 

        foreach ($CSVFile in $CSVFileCollection) {
            $SeriesCount += 1
            $DataSource = @()

            # Filtering Results for Services to show just running services
            if ($CSVFile -match "Services.csv") {
                $DataSource += Import-Csv $CSVFile | Where-Object {$_.State -eq "Running"}
                $DataSource += $Script:MergedCSVFilesOutput  | Where-Object {$_.State -eq "Running"} | Select-Object -Property $PropertyX -Unique
                $AutoChartTitle.Text = (($script:CSVFileMostRecentCollection.split('\'))[-1] -replace '.csv','') + " - Running"
            }
            else {
                #test# $DataSource = Import-Csv $CSVFile
                $DataSource += Import-Csv $CSVFile
                $DataSource += $Script:MergedCSVFilesOutput | Select-Object -Property $PropertyX -Unique
            }                    
            # Creates a Unique list
            $UniqueDataFields   = $DataSource | Select-Object -Property $PropertyX | Sort-Object -Property $PropertyX -Unique
            $UniqueComputerList = $DataSource | Select-Object -Property $PropertyY | Sort-Object -Property $PropertyY -Unique

            # Generates and Counts the data
            $OverallDataResults = @()
            foreach ($DataField in $UniqueDataFields) {
                $Count          = 0
                $Computers      = @()
                foreach ( $Line in $DataSource ) { 
                    if ( $Line.$PropertyX -eq $DataField.$PropertyX ) {
                        $Count += 1
                        if ( $Computers -notcontains $Line.$PropertyY ) { $Computers += $Line.$PropertyY }
                    }
                }
                $UniqueCount    = $Computers.Count - 1 ### 1 is subtracted to account for the one added when ensuring all data fields are present
                $DataResults    =  New-Object PSObject -Property @{
                    DataField   = $DataField
                    TotalCount  = $Count
                    UniqueCount = $UniqueCount
                    Computers   = $Computers 
                }
                $OverallDataResults += $DataResults
            }
            $Series = '$Series0' + $SeriesCount + 'Name'
            $OverallDataResults `
            | ForEach-Object {$AutoChart.Series["$(iex $Series)"].Points.AddXY($_.DataField.$PropertyX,$_.UniqueCount)}
        }
    }

    # If the Second field/Y Axis DOES NOT equals PSComputername, it uses the field provided
    elseif ($PropertyX -eq "PSComputerName") {   
        # Import Data
        $DataSource = ""
        foreach ($CSVFile in $CSVFileCollection) {
            $SeriesCount += 1
            $DataSource = Import-Csv $CSVFile
########## TEST DATA ##########
#            $DataSource = @()
#            $DataSource += Import-Csv "C:\Users\Dan\Documents\GitHub\PoSH-ACME\PoSh-ACME_v2.3_20181106_Beta_Nightly_Build\Collected Data\2018-11-19 @ 2101 42\Network Settings.csv"
#            $PropertyX = "PSComputerName"
#            $PropertyY = "IPAddress"
########## TEST DATA ##########

            $SelectedDataField  = $DataSource | Select-Object -Property $PropertyY | Sort-Object -Property $PropertyY -Unique
            $UniqueComputerList = $DataSource | Select-Object -Property $PropertyX | Sort-Object -Property $PropertyX -Unique
            $OverallResults     = @()
            $CurrentComputer    = ''
            $CheckIfFirstLine   = 'False'
            $ResultsCount       = 0
            $Computer           = ''
            $YResults           = @()
            $OverallDataResults = @()
            foreach ( $Line in $DataSource ) {
                if ( $CheckIfFirstLine -eq 'False' ) { 
                    $CurrentComputer  = $Line.$PropertyX
                    $CheckIfFirstLine = 'True' 
                }
                if ( $CheckIfFirstLine -eq 'True' ) { 
                    if ( $Line.$PropertyX -eq $CurrentComputer ) {
                        if ( $YResults -notcontains $Line.$PropertyY ) {
                            if ( $Line.$PropertyY -ne "" ) {
                                $YResults     += $Line.$PropertyY
                                $ResultsCount += 1
                            }
                            if ( $Computer -notcontains $Line.$PropertyX ) { $Computer = $Line.$PropertyX }
                        }       
                    }
                    elseif ( $Line.$PropertyX -ne $CurrentComputer ) { 
                        $CurrentComputer = $Line.$PropertyX
                        $DataResults     = New-Object PSObject -Property @{
                            ResultsCount = $ResultsCount
                            Computer     = $Computer
                        }
                        $OverallDataResults += $DataResults
                        $YResults        = @()
                        $ResultsCount    = 0
                        $Computer        = @()
                        if ( $YResults -notcontains $Line.$PropertyY ) {
                            if ( $Line.$PropertyY -ne "" ) {
                                $YResults     += $Line.$PropertyY
                                $ResultsCount += 1
                            }
                            if ( $Computer -notcontains $Line.$PropertyX ) { $Computer = $Line.$PropertyX }
                        }
                    }
                }
            }
            $DataResults     = New-Object PSObject -Property @{
                ResultsCount = $ResultsCount
                Computer     = $Computer
            }    
            $OverallDataResults += $DataResults
            #$OverallDataResults
        $Series = '$Series0' + $SeriesCount + 'Name'        
        $OverallDataResults `
        | ForEach-Object {$AutoChart.Series["$(iex $Series)"].Points.AddXY($_.Computer,$_.ResultsCount)}        
        }
    } 

    ############################################################################################################
    # Auto Create Charts Processes
    ############################################################################################################

    #------------------------------------
    # Auto Creates Tabs and Imports Data
    #------------------------------------
    # Obtains a list of the files in the resources folder
    $ResourceProcessFiles = Get-ChildItem "$PoShHome\Resources\Process Info"


    #-----------------------------
    # Creates Tabs From Each File
    #-----------------------------
    $TabName                          = $QueryTabName
    $AutoChartsIndividualTabs         = New-Object System.Windows.Forms.TabPage
    $AutoChartsIndividualTabs.Text    = "$TabName"
    $AutoChartsIndividualTabs.UseVisualStyleBackColor = $True
    $AutoChartsIndividualTabs.Anchor  = $AnchorAll
    $AutoChartsTabControl.Controls.Add($AutoChartsIndividualTabs)            
    $AutoChartsIndividualTabs.controls.add($AutoChart)

    #-----------------------------------------------------
    # Auto Create Charts Collection Series Computer Count
    #-----------------------------------------------------
    $AutoChartsSeriesComputerCount           = New-Object System.Windows.Forms.Label
    $AutoChartsSeriesComputerCount.Location  = New-Object System.Drawing.Size(955,216) 
    $AutoChartsSeriesComputerCount.Size      = New-Object System.Drawing.Size(150,25)
    $AutoChartsSeriesComputerCount.Font      = [System.Drawing.Font]::new("$Font", 10, [System.Drawing.FontStyle]::Bold)
    $AutoChartsSeriesComputerCount.ForeColor = 'Black'
    $AutoChartsSeriesComputerCount.Text      = "Future Notes Section"
    $AutoChart.Controls.Add($AutoChartsSeriesComputerCount)
    
    #--------------------------------
    # Auto Create Charts Save Button
    #--------------------------------
    Function Invoke-SaveDialog {
        $FileTypes = [enum]::GetNames('System.Windows.Forms.DataVisualization.Charting.ChartImageFormat')| ForEach {
            $_.Insert(0,'*.')
        }
        $SaveFileDlg = New-Object System.Windows.Forms.SaveFileDialog
        $SaveFileDlg.DefaultExt='PNG'
        $SaveFileDlg.Filter="Image Files ($($FileTypes)) | All Files (*.*)|*.*"
        $return = $SaveFileDlg.ShowDialog()
        If ($Return -eq 'OK') {
            [pscustomobject]@{
                FileName = $SaveFileDlg.FileName
                Extension = $SaveFileDlg.FileName -replace '.*\.(.*)','$1'
            }
        }
    }
    $AutoChartsSaveButton           = New-Object Windows.Forms.Button
    $AutoChartsSaveButton.Text      = "Save Image"
    $AutoChartsSaveButton.Location  = New-Object System.Drawing.Size(955,516)
    $AutoChartsSaveButton.Size      = New-Object System.Drawing.Size(150,25)
    $AutoChartsSaveButton.Anchor    = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
        [enum]::GetNames('System.Windows.Forms.DataVisualization.Charting.ChartImageFormat')
    $AutoChartsSaveButton.Font      = [System.Drawing.Font]::new("$Font", 10, [System.Drawing.FontStyle]::Bold)
    $AutoChartsSaveButton.ForeColor = "Black"
    $AutoChartsSaveButton.UseVisualStyleBackColor = $True
    $AutoChartsSaveButton.add_click({
        $Result = Invoke-SaveDialog
        If ($Result) { $AutoChart.SaveImage($Result.FileName, $Result.Extension) }
    }) 
    $AutoChart.controls.add($AutoChartsSaveButton)

    $ButtonSpacing = 35 

    if ($AutoChartSelectChartComboBox.SelectedItem -notmatch "All Charts") {
        #------------------------------------
        # Auto Create Charts Series3 Results
        #------------------------------------
        if ($AutoChartsMostRecentCheckBox.Checked -eq $True) {
            if ($script:CSVFileMostRecentCollection) { 
                $AutoChartsSeries3Results           = New-Object Windows.Forms.Button
                $AutoChartsSeries3Results.Text      = "$Series03Name Results"
                $AutoChartsSeries3Results.Location  = New-Object System.Drawing.Size(($AutoChartsSaveButton.Location.X),($AutoChartsSaveButton.Location.Y - $ButtonSpacing))
                $AutoChartsSeries3Results.Size      = New-Object System.Drawing.Size(150,25)
                $AutoChartsSeries3Results.Anchor    = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
                $AutoChartsSeries3Results.Font      = [System.Drawing.Font]::new("$Font", 10, [System.Drawing.FontStyle]::Bold)
                $AutoChartsSeries3Results.ForeColor = "Red"
                $AutoChartsSeries3Results.UseVisualStyleBackColor = $True
                $AutoChartsSeries3Results.add_click({ Import-CSV $script:CSVFileMostRecentCollection | Out-GridView }) 
                $AutoChart.controls.add($AutoChartsSeries3Results)
                $ButtonSpacing += 35
            }
        }

        #------------------------------------
        # Auto Create Charts Series2 Results
        #------------------------------------
        if ($AutoChartsPreviousCheckBox.Checked -eq $True) {
            if ($script:CSVFilePreviousCollection) {
                $AutoChartsSeries2Results           = New-Object Windows.Forms.Button
                $AutoChartsSeries2Results.Text      = "$Series02Name Results"
                $AutoChartsSeries2Results.Location  = New-Object System.Drawing.Size(($AutoChartsSaveButton.Location.X),($AutoChartsSaveButton.Location.Y - $ButtonSpacing))
                $AutoChartsSeries2Results.Size      = New-Object System.Drawing.Size(150,25)
                $AutoChartsSeries2Results.Anchor    = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
                $AutoChartsSeries2Results.Font      = [System.Drawing.Font]::new("$Font", 10, [System.Drawing.FontStyle]::Bold)
                $AutoChartsSeries2Results.ForeColor = "Orange"
                $AutoChartsSeries2Results.UseVisualStyleBackColor = $True
                $AutoChartsSeries2Results.add_click({ Import-CSV $script:CSVFilePreviousCollection | Out-GridView }) 
                $AutoChart.controls.add($AutoChartsSeries2Results)
                $ButtonSpacing += 35
            }
        }

        #------------------------------------
        # Auto Create Charts Series1 Results
        #------------------------------------
        if ($AutoChartsBaselineCheckBox.Checked -eq $True) {
            if ($script:CSVFileBaselineCollection) {
                $AutoChartsSeries1Results           = New-Object Windows.Forms.Button
                $AutoChartsSeries1Results.Text      = "$Series01Name Results"
                $AutoChartsSeries1Results.Location  = New-Object System.Drawing.Size(($AutoChartsSaveButton.Location.X),($AutoChartsSaveButton.Location.Y - $ButtonSpacing))
                $AutoChartsSeries1Results.Size      = New-Object System.Drawing.Size(150,25)
                $AutoChartsSeries1Results.Anchor    = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
                $AutoChartsSeries1Results.Font      = [System.Drawing.Font]::new("$Font", 10, [System.Drawing.FontStyle]::Bold)
                $AutoChartsSeries1Results.ForeColor = "Blue"
                $AutoChartsSeries1Results.UseVisualStyleBackColor = $True
                $AutoChartsSeries1Results.add_click({ Import-CSV $script:CSVFileBaselineCollection | Out-GridView }) 
                $AutoChart.controls.add($AutoChartsSeries1Results)
                $ButtonSpacing += 35
            }
        }
    }

    ####$AutoChart.Add_Shown({$ViewChartForm.Activate()})
    ####[void]$AutoChart.ShowDialog()
    
    #---------------------------------------
    # Custom View Chart - Autosave an Image
    #---------------------------------------
    #$AutoChart.SaveImage('C:\temp\chart.jpeg', 'jpeg')    
}

#-------------------------
# View Auto Charts Button
#-------------------------
$AutoChartsButton2          = New-Object System.Windows.Forms.Button
$AutoChartsButton2.Name     = "View Auto Chart"
$AutoChartsButton2.Text     = "$($AutoChartsButton2.Name)"
$AutoChartsButton2.UseVisualStyleBackColor = $True
$AutoChartsButton2.Location = New-Object System.Drawing.Size(($ViewChartButton.Location.X),($ViewChartButton.Location.Y - 30))
$AutoChartsButton2.Size     = New-Object System.Drawing.Size(115,22)
$AutoChartsButton2.add_click({ AutoChartsSelectOptions })
$Section2MainTab.Controls.Add($AutoChartsButton2)

##############################################################################################################################################################
##
## Section 1 Options SubTab
##
##############################################################################################################################################################
$Section2OptionsTab          = New-Object System.Windows.Forms.TabPage
$Section2OptionsTab.Text     = "Options"
$Section2OptionsTab.Name     = "Options"
$Section2OptionsTab.UseVisualStyleBackColor = $True
$Section2TabControl.Controls.Add($Section2OptionsTab)

#---------------------------------
# Computer List - View Log Button
#---------------------------------
$LogButton          = New-Object System.Windows.Forms.Button
$LogButton.Name     = "View Log"
$LogButton.Text     = "$($LogButton.Name)"
$LogButton.UseVisualStyleBackColor = $True
$LogButton.Location = New-Object System.Drawing.Size(3,11)
$LogButton.Size     = New-Object System.Drawing.Size(115,22)
$LogButton.add_Click({Start-Process notepad.exe $LogFile})
$Section2OptionsTab.Controls.Add($LogButton)


#-----------------------------
# Text To Speach/TTS Checkbox
#-----------------------------
$TextToSpeachCheckBox          = New-Object System.Windows.Forms.Checkbox
$TextToSpeachCheckBox.Text     = "Audible Completion Message"
$TextToSpeachCheckBox.Location = New-Object System.Drawing.Size(3,($LogButton.Location.Y + $LogButton.Size.Height + 5))
$TextToSpeachCheckBox.Size     = New-Object System.Drawing.Size(200,$Column3BoxHeight) 
$TextToSpeachCheckBox.Enabled  = $true
$TextToSpeachCheckBox.Checked  = $False
$TextToSpeachCheckBox.Font     = [System.Drawing.Font]::new("$Font", 8, [System.Drawing.FontStyle]::Bold)
#$TextToSpeachCheckBox.Add_Click({ })
$Section2OptionsTab.Controls.Add($TextToSpeachCheckBox)


#============================================================================================================================================================
# Column 4
#============================================================================================================================================================
# Varables to Control Column 4
$Column4RightPosition     = 845
$Column4DownPosition      = 11
$Column4BoxWidth          = 220
$Column4BoxHeight         = 22
$Column4DownPositionShift = 25

# Initial load of CSV data
$script:ComputerListTreeViewData = $null
$script:ComputerListTreeViewData = Import-Csv $ComputerListTreeViewFileSaved -ErrorAction SilentlyContinue | Select-Object -Property Name, OperatingSystem, CanonicalName, IPv4Address

# Initial load of Txt data
#if ($(Test-Path $IPListFile)) {
#    foreach ($line in $(Get-Content "$IPListFile")) {
#        $script:ComputerListTreeViewData += "@{Name=$line; OperatingSystem=Unknown; CanonicalName=Unknown; IPv4Address=No Data Available}"
#        $account += New-Object -TypeName psobject -Property @{User="Jimbo"; Password="1234"}
#    }
#}


#polo

function Add-Node { 
        param ( 
            $RootNode, 
            $Category,
            $Entry,
            $ToolTip
        )
        $newNode      = New-Object System.Windows.Forms.TreeNode  
        $newNode.Name = "$Entry"
        $newNode.Text = "$Entry"
        if ($ToolTip) { $newNode.ToolTipText  = "$ToolTip" }
        else { $newNode.ToolTipText  = "No Data Available" }
        If ($RootNode.Nodes.Tag -contains $Category) {
            $HostNode = $RootNode.Nodes | Where-Object {$_.Tag -eq $Category}
        }
        Else {
            $newHostNode             = New-Object System.Windows.Forms.TreeNode
            $newHostNode.Name        = $Category
            $newHostNode.Text        = $Category
            $newHostNode.Tag         = $Category
            $newHostNode.ToolTipText = "Checkbox this Category to query all its hosts"

            $Null     = $RootNode.Nodes.Add($newHostNode)
            $HostNode = $RootNode.Nodes | Where-Object {$_.Tag -eq $Category}
        }
        $Null = $HostNode.Nodes.Add($newNode)
}
$script:ComputerListTreeViewSelected = ""

#-----------------------
# ComputerList Treeview
#-----------------------
$ComputerListTreeView            = New-Object System.Windows.Forms.TreeView
$System_Drawing_Size             = New-Object System.Drawing.Size
$System_Drawing_Size.Width       = 230
$System_Drawing_Size.Height      = 333
$ComputerListTreeView.Size       = $System_Drawing_Size
$System_Drawing_Point            = New-Object System.Drawing.Point
$System_Drawing_Point.X          = $Column4RightPosition
$System_Drawing_Point.Y          = $Column4DownPosition + 14
$ComputerListTreeView.Location   = $System_Drawing_Point
$ComputerListTreeView.Font       = New-Object System.Drawing.Font("$Font",8,0,3,0)
$ComputerListTreeView.CheckBoxes = $True
#$ComputerListTreeView.LabelEdit  = $True
$ComputerListTreeView.ShowLines  = $True
$ComputerListTreeView.ShowNodeToolTips  = $True
$ComputerListTreeView.Sort()
$ComputerListTreeView.add_AfterSelect({
    # This will return data on hosts selected/highlight, but not necessarily checked
    [System.Windows.Forms.TreeNodeCollection]$AllHostsNode = $ComputerListTreeView.Nodes 
    foreach ($root in $AllHostsNode) { 
        if ($root.isselected) { 
            $script:ComputerListTreeViewSelected = ""
            $StatusListBox.Items.clear()
            $StatusListBox.Items.Add("Category:  $($root.Text)")
            $MainListBox.Items.Clear()
            $MainListBox.Items.Add("- Checkbox this Category to query all its hosts")
        }
        foreach ($Category in $root.Nodes) { 
            if ($Category.isselected) { 
                $script:ComputerListTreeViewSelected = ""
                $StatusListBox.Items.clear()
                $StatusListBox.Items.Add("Category:  $($Category.Text)")
                $MainListBox.Items.Clear()
                $MainListBox.Items.Add("- Checkbox this Category to query all its hosts")
            }
            foreach ($Entry in $Category.nodes) { 
                if ($Entry.isselected) { 
                    $script:ComputerListTreeViewSelected = $Entry.Text
                    $StatusListBox.Items.clear()
                    $StatusListBox.Items.Add("Hostname/IP:  $($Entry.Text)")
                    $MainListBox.Items.Clear()
                    $MainListBox.Items.Add("- Checkkbox one hostname/IP to RDP, PSSession, or PSExec")
                    $MainListBox.Items.Add("- Checkbox any number of Categories, hostnames, or IPs to run any number of queries or ping")
                }
            }       
        }         
    }
})
$PoShACME.Controls.Add($ComputerListTreeView)


function Initialize-ComputerTreeView {
    $script:TreeNode                       = New-Object -TypeName System.Windows.Forms.TreeNode -ArgumentList 'All Hosts'
    $script:TreeNode.Tag                   = 'Computers'
}

#============================================================================================================================================================
# Radio Buttons
#============================================================================================================================================================
function Populate-ComputerListTreeViewDefaultData {
    # This section populates the data with default data if it doesn't have any
    $script:ComputerListTreeViewDataTemp = @()

    Foreach($Computer in $script:ComputerListTreeViewData) {
        $CanonicalName = $($($Computer.CanonicalName) -replace $Computer.Name,"" -replace $Computer.CanonicalName.split('/')[0],"").TrimEnd("/")

        $ComputerListTreeViewInsertDefaultData = New-Object PSObject -Property @{ Name = $Computer.Name}        
        if ($Computer.OperatingSystem) { 
            $ComputerListTreeViewInsertDefaultData | Add-Member -MemberType NoteProperty -Name OperatingSystem -Value $Computer.OperatingSystem -Force }
        else { 
            $ComputerListTreeViewInsertDefaultData | Add-Member -MemberType NoteProperty -Name OperatingSystem -Value "Unknown" -Force }
        
        if ($Computer.CanonicalName) { 
            $ComputerListTreeViewInsertDefaultData | Add-Member -MemberType NoteProperty -Name CanonicalName -Value $CanonicalName -Force }
        else { 
            $ComputerListTreeViewInsertDefaultData | Add-Member -MemberType NoteProperty -Name CanonicalName -Value "/Unknown" -Force }

        if ($Computer.IPv4Address) { 
            $ComputerListTreeViewInsertDefaultData | Add-Member -MemberType NoteProperty -Name IPv4Address -Value $Computer.IPv4Address -Force }
        else { 
            $ComputerListTreeViewInsertDefaultData | Add-Member -MemberType NoteProperty -Name IPv4Address -Value "No Data Available" -Force }
        
        $script:ComputerListTreeViewDataTemp += $ComputerListTreeViewInsertDefaultData
        #write-host $($ComputerListTreeViewInsertDefaultData | Select Name, OperatingSystem, CanonicalName, IPv4Address)
    }
    $script:ComputerListTreeViewData       = $script:ComputerListTreeViewDataTemp
    $script:ComputerListTreeViewDataTemp   = $null
    $ComputerListTreeViewInsertDefaultData = $null
}

# This section will check the checkboxes selected under the other view
function Keep-CheckboxesChecked {
    $ComputerListTreeView.Nodes.Add($script:TreeNode)
    $ComputerListTreeView.ExpandAll()
    
    if ($ComputerListCheckedBoxesSelected.count -gt 0) {
        $MainListBox.Items.Clear()
        $MainListBox.Items.Add("Categories that were checked will not remained checked.")
        $MainListBox.Items.Add("")
        $MainListBox.Items.Add("The following hostname/IP selections are still selected in the new treeview:")
        foreach ($root in $AllHostsNode) { 
            foreach ($Category in $root.Nodes) { 
                foreach ($Entry in $Category.nodes) { 
                    if ($ComputerListCheckedBoxesSelected -contains $Entry.text) {
                        $Entry.Checked = $true
                        $MainListBox.Items.Add($Entry.Text)
                    }            
                }
            }
        }
    }
}

# Default View
Initialize-ComputerTreeView
Populate-ComputerListTreeViewDefaultData
# This will load data that is located in the saved file
Foreach($Computer in $script:ComputerListTreeViewData) {
    Add-Node -RootNode $script:TreeNode -Category $Computer.OperatingSystem -Entry $Computer.Name -ToolTip $Computer.IPv4Address
}
$ComputerListTreeView.Nodes.Add($script:TreeNode)
$ComputerListTreeView.ExpandAll()

#-----------------------------
# View hostname/IPs by: Label
#-----------------------------
$ComputerListViewByLabel          = New-Object System.Windows.Forms.Label
$ComputerListViewByLabel.Text     = "View by:"
$ComputerListViewByLabel.Location = New-Object System.Drawing.Size($Column4RightPosition,9)
$ComputerListViewByLabel.Size     = New-Object System.Drawing.Size(75,25)
$ComputerListViewByLabel.Font     = New-Object System.Drawing.Font("$Font",11,1,2,1)
$PoShACME.Controls.Add($ComputerListViewByLabel)

#----------------------------
# OS & Hostname Radio Button
#----------------------------
$ComputerListOSHostnameRadioButton          = New-Object System.Windows.Forms.RadioButton
$System_Drawing_Point                       = New-Object System.Drawing.Point
$System_Drawing_Point.X                     = $ComputerListViewByLabel.Location.X + $ComputerListViewByLabel.Size.Width
$System_Drawing_Point.Y                     = $ComputerListViewByLabel.Location.Y - 5
$ComputerListOSHostnameRadioButton.Location = $System_Drawing_Point
$System_Drawing_Size                        = New-Object System.Drawing.Size
$System_Drawing_Size.Height                 = 25
$System_Drawing_Size.Width                  = 50
$ComputerListOSHostnameRadioButton.size     = $System_Drawing_Size
$ComputerListOSHostnameRadioButton.Checked  = $True
$ComputerListOSHostnameRadioButton.Text     = "OS"
$ComputerListOSHostnameRadioButton.Add_Click({
    $ComputerListTreeViewCollapseAllButton.Text = "Collapse"
    $StatusListBox.Items.Clear()
    $StatusListBox.Items.Add("Treeview:  Operating Systems")

    # This variable stores data on checked checkboxes, so boxes checked remain among different views
    $ComputerListCheckedBoxesSelected = @()

    [System.Windows.Forms.TreeNodeCollection]$AllHostsNode = $ComputerListTreeView.Nodes 
    foreach ($root in $AllHostsNode) { 
        foreach ($Category in $root.Nodes) {
            foreach ($Entry in $Category.nodes) { 
                if ($Entry.Checked) {
                    $ComputerListCheckedBoxesSelected += $Entry.Text
                }
            }
        }
    }
    $ComputerListTreeView.Nodes.Clear()
    Initialize-ComputerTreeView
    Populate-ComputerListTreeViewDefaultData
    Foreach($Computer in $script:ComputerListTreeViewData) {
        Add-Node -RootNode $script:TreeNode -Category $Computer.OperatingSystem -Entry $Computer.Name -ToolTip $Computer.IPv4Address
    }
    Keep-CheckboxesChecked
})
$PoShACME.Controls.Add($ComputerListOSHostnameRadioButton)

#---------------------------------------------
# Active Directory OU & Hostname Radio Button
#---------------------------------------------
$ComputerListOUHostnameRadioButton          = New-Object System.Windows.Forms.RadioButton
$System_Drawing_Point                       = New-Object System.Drawing.Point
$System_Drawing_Point.X                     = $ComputerListOSHostnameRadioButton.Location.X + $ComputerListOSHostnameRadioButton.Size.Width + 5
$System_Drawing_Point.Y                     = $ComputerListOSHostnameRadioButton.Location.Y
$ComputerListOUHostnameRadioButton.Location = $System_Drawing_Point
$System_Drawing_Size                        = New-Object System.Drawing.Size
$System_Drawing_Size.Height                 = 25
$System_Drawing_Size.Width                  = 75
$ComputerListOUHostnameRadioButton.size     = $System_Drawing_Size
$ComputerListOUHostnameRadioButton.Checked  = $false
$ComputerListOUHostnameRadioButton.Text     = "OU / CN"
$ComputerListOUHostnameRadioButton.Add_Click({ 
    $ComputerListTreeViewCollapseAllButton.Text = "Collapse"
    $StatusListBox.Items.Clear()
    $StatusListBox.Items.Add("Treeview:  Active Directory Organizational Units")

    # This variable stores data on checked checkboxes, so boxes checked remain among different views
    $ComputerListCheckedBoxesSelected = @()

    [System.Windows.Forms.TreeNodeCollection]$AllHostsNode = $ComputerListTreeView.Nodes 
    foreach ($root in $AllHostsNode) { 
        foreach ($Category in $root.Nodes) {
            foreach ($Entry in $Category.nodes) { 
                if ($Entry.Checked) {
                    $ComputerListCheckedBoxesSelected += $Entry.Text
                }
            }
        }
    }            
    $ComputerListTreeView.Nodes.Clear()
    Initialize-ComputerTreeView
    Populate-ComputerListTreeViewDefaultData
    Foreach($Computer in $script:ComputerListTreeViewData) {
        Add-Node -RootNode $script:TreeNode -Category $Computer.CanonicalName -Entry $Computer.Name -ToolTip $Computer.IPv4Address
    }
    Keep-CheckboxesChecked
})
$PoShACME.Controls.Add($ComputerListOUHostnameRadioButton)

##############################################################################################################################################################
##
## Section 2 Computer List - Tab Control
##
##############################################################################################################################################################

$Section2TabControl               = New-Object System.Windows.Forms.TabControl
$System_Drawing_Point             = New-Object System.Drawing.Point
$System_Drawing_Point.X           = 1082
$System_Drawing_Point.Y           = 10
$Section2TabControl.Location      = $System_Drawing_Point
$Section2TabControl.Name          = "Main Tab Window for Computer List"
$Section2TabControl.SelectedIndex = 0
$Section2TabControl.ShowToolTips  = $True
$System_Drawing_Size              = New-Object System.Drawing.Size
$System_Drawing_Size.Height       = 349
$System_Drawing_Size.Width        = 126
$Section2TabControl.Size          = $System_Drawing_Size
$PoShACME.Controls.Add($Section2TabControl)

# Varables to Control Column 5
$Column5RightPosition     = 3
$Column5DownPositionStart = 6
$Column5DownPosition      = 6
$Column5DownPositionShift = 28

$Column5BoxWidth          = 110
$Column5BoxHeight         = 22

##############################################################################################################################################################
##
## Section 2 Computer List - Action Tab
##
##############################################################################################################################################################


$Section2ActionTab          = New-Object System.Windows.Forms.TabPage
$Section2ActionTab.Location = $System_Drawing_Point
$Section2ActionTab.Text     = "Action"

$Section2ActionTab.Location = New-Object System.Drawing.Size($Column5RightPosition,$Column5DownPosition) 
$Section2ActionTab.Size     = New-Object System.Drawing.Size($Column5BoxWidth,$Column5BoxHeight) 
$Section2ActionTab.UseVisualStyleBackColor = $True
$Section2TabControl.Controls.Add($Section2ActionTab)

#####################################################################################################################################
## Section 2 Computer List - Action Tab Buttons
#####################################################################################################################################

#============================================================================================================================================================
# Computer List - Ping Button
#============================================================================================================================================================
$ComputerListPingButton          = New-Object System.Windows.Forms.Button
$ComputerListPingButton.Location = New-Object System.Drawing.Size($Column5RightPosition,$Column5DownPosition)
$ComputerListPingButton.Size     = New-Object System.Drawing.Size($Column5BoxWidth,$Column5BoxHeight)
$ComputerListPingButton.Text     = 'Ping'
$ComputerListPingButton.add_click({
    # This array stores checkboxes that are check; a minimum of at least one checkbox will be needed later in the script
    $ComputerListCheckedBoxesSelected = @()
    [System.Windows.Forms.TreeNodeCollection]$AllHostsNode = $ComputerListTreeView.Nodes 
    foreach ($root in $AllHostsNode) { 
        if ($root.Checked) {
            foreach ($Category in $root.Nodes) { foreach ($Entry in $Category.nodes) { $ComputerListCheckedBoxesSelected += $Entry.Text } }
        }
        foreach ($Category in $root.Nodes) { 
            if ($Category.Checked) {
                foreach ($Entry in $Category.nodes) { $ComputerListCheckedBoxesSelected += $Entry.Text }       
            }
            foreach ($Entry in $Category.nodes) {
                if ($Entry.Checked) {
                    $ComputerListCheckedBoxesSelected += $Entry.Text
                }
            }       
        }         
    }
    $ComputerListCheckedBoxesSelected = $ComputerListCheckedBoxesSelected | Select-Object -Unique

    $MainListBox.Items.Clear()
    if ($ComputerListCheckedBoxesSelected.count -eq 0) {
        $StatusListBox.Items.Clear()    
        $StatusListBox.Items.Add("Ping:  Error")    
        $MainListBox.Items.Add("Error:  No hostname/IPs selected")
        $MainListBox.Items.Add("        Make sure to checkbox one or more hostname/IPs")
        $MainListBox.Items.Add("        Selecting a Category will allow you ping multiple hosts")    
    }
    else {
        $StatusListBox.Items.Clear()    
        $StatusListBox.Items.Add("Pinging:  $($ComputerListCheckedBoxesSelected.count) hosts")    
        foreach ($target in $ComputerListCheckedBoxesSelected){
            $ping = Test-Connection $target -Count 1
            foreach ($line in $target){
                if($ping){$MainListBox.Items.Insert(0,"Able to Ping:    $target")}
                else {$MainListBox.Items.Insert(0,"Unable to Ping:  $target")}
                $LogMessage = "$((Get-Date).ToString('yyyy/MM/dd HH:mm:ss')) - $ping"
                $LogMessage | Add-Content -Path $LogFile
            }
        }
        $MainListBox.Items.Insert(0,"")
        $MainListBox.Items.Insert(0,"Finished Testing Connections")
    }
})
$Section2ActionTab.Controls.Add($ComputerListPingButton) 

$Column5DownPosition += $Column5DownPositionShift

#============================================================================================================================================================
# Computer List - RDP Button
#============================================================================================================================================================
$ComputerListRDPButton          = New-Object System.Windows.Forms.Button
$ComputerListRDPButton.Location = New-Object System.Drawing.Size($Column5RightPosition,$Column5DownPosition)
$ComputerListRDPButton.Size     = New-Object System.Drawing.Size($Column5BoxWidth,$Column5BoxHeight)
$ComputerListRDPButton.Text     = 'RDP'
$ComputerListRDPButton.add_click({
    # This array stores checkboxes that are check; a minimum of at least one checkbox will be needed later in the script
    $ComputerListCheckedBoxesSelected = @()
    [System.Windows.Forms.TreeNodeCollection]$AllHostsNode = $ComputerListTreeView.Nodes 
    foreach ($root in $AllHostsNode) { 
        if ($root.Checked) {
            foreach ($Category in $root.Nodes) { foreach ($Entry in $Category.nodes) { $ComputerListCheckedBoxesSelected += $Entry.Text } }
        }
        foreach ($Category in $root.Nodes) { 
            if ($Category.Checked) {
                foreach ($Entry in $Category.nodes) { $ComputerListCheckedBoxesSelected += $Entry.Text }       
            }
            foreach ($Entry in $Category.nodes) {
                if ($Entry.Checked) {
                    $ComputerListCheckedBoxesSelected += $Entry.Text
                }
            }       
        }         
    }
    
    $MainListBox.Items.Clear()
    if ($ComputerListCheckedBoxesSelected.count -eq 1) {
        $mstsc = mstsc /v:$($ComputerListCheckedBoxesSelected):3389
        $mstsc

        $StatusListBox.Items.Clear()
        $StatusListBox.Items.Add("Remote Desktop:  $($script:ComputerListTreeViewSelected)")
        $MainListBox.Items.Clear()
        $MainListBox.Items.Add("mstsc /v:$($ComputerListCheckedBoxesSelected):3389")
        $LogMessage = "$((Get-Date).ToString('yyyy/MM/dd HH:mm:ss'))  Remote Desktop (RDP): $($script:ComputerListTreeViewSelected)"
        $LogMessage | Add-Content -Path $LogFile
    }
    elseif ($ComputerListCheckedBoxesSelected.count -eq 0) {
        $StatusListBox.Items.Clear()
        $StatusListBox.Items.Add("Remote Desktop:  Error")
        $MainListBox.Items.Clear()
        $MainListBox.Items.Add("Error:  No hostname/IP selected")
        $MainListBox.Items.Add("        Make sure to checkbox only one hostname/IP")
        $MainListBox.Items.Add("        Selecting a Category will not allow you to connect to multiple hosts")
    }
    elseif ($ComputerListCheckedBoxesSelected.count -gt 1) {
        $StatusListBox.Items.Clear()
        $StatusListBox.Items.Add("Remote Desktop:  Error")
        $MainListBox.Items.Clear()
        $MainListBox.Items.Add("Error:  Too many hostname/IPs selected")
        $MainListBox.Items.Add("        Make sure to checkbox only one hostname/IP")
        $MainListBox.Items.Add("        Selecting a Category will not allow you to connect to multiple hosts")    
    }
})
$Section2ActionTab.Controls.Add($ComputerListRDPButton) 

$Column5DownPosition += $Column5DownPositionShift

#============================================================================================================================================================
# Computer List - PSExec Button
#============================================================================================================================================================
$ComputerListPSExecButton          = New-Object System.Windows.Forms.Button
$ComputerListPSExecButton.Location = New-Object System.Drawing.Size($Column5RightPosition,$Column5DownPosition)
$ComputerListPSExecButton.Size     = New-Object System.Drawing.Size($Column5BoxWidth,$Column5BoxHeight)
$ComputerListPSExecButton.Text     = "PsExec"
$ComputerListPSExecButton.add_click({
    # This array stores checkboxes that are check; a minimum of at least one checkbox will be needed later in the script
    $ComputerListCheckedBoxesSelected = @()
    [System.Windows.Forms.TreeNodeCollection]$AllHostsNode = $ComputerListTreeView.Nodes 
    foreach ($root in $AllHostsNode) { 
        if ($root.Checked) {
            foreach ($Category in $root.Nodes) { foreach ($Entry in $Category.nodes) { $ComputerListCheckedBoxesSelected += $Entry.Text } }
        }
        foreach ($Category in $root.Nodes) { 
            if ($Category.Checked) {
                foreach ($Entry in $Category.nodes) { $ComputerListCheckedBoxesSelected += $Entry.Text }       
            }
            foreach ($Entry in $Category.nodes) {
                if ($Entry.Checked) {
                    $ComputerListCheckedBoxesSelected += $Entry.Text
                }
            }       
        }         
    }   
    if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
        if (!$Credential) { $script:Credential = Get-Credential }
        $Username = $Credential.UserName
        $Password = $Credential.GetNetworkCredential().Password
        $UseCredential = "-u $Username -p $Password"
    }
    else {
        $Credentials = ""
    }
    $PSExecPath   = "$ExternalPrograms\PsExec.exe"
    $PSExecTarget = "$($script:ComputerListTreeViewSelected)"

    $MainListBox.Items.Clear()
    if ($ComputerListCheckedBoxesSelected.count -eq 1) {

        Start-Process PowerShell -WindowStyle Hidden -ArgumentList "Start-Process '$PSExecPath' -ArgumentList '-accepteula -s \\$PSExecTarget $UseCredential cmd'"

        $StatusListBox.Items.Clear()
        $StatusListBox.Items.Add("PSExec:  $($script:ComputerListTreeViewSelected)")
        $MainListBox.Items.Clear()
        if ($Credential) { $MainListBox.Items.Add("./PsExec.exe -accepteula -s \\$PSExecTarget -u '<domain\username>' -p '<password>' cmd") }
        else { $MainListBox.Items.Add("./PsExec.exe -accepteula -s \\$PSExecTarget cmd") }
        $LogMessage = "$((Get-Date).ToString('yyyy/MM/dd HH:mm:ss'))  PSExec: $($script:ComputerListTreeViewSelected)"
        $LogMessage | Add-Content -Path $LogFile
    }
    elseif ($ComputerListCheckedBoxesSelected.count -eq 0) {
        $StatusListBox.Items.Clear()
        $StatusListBox.Items.Add("PSExec:  Error")
        $MainListBox.Items.Clear()
        $MainListBox.Items.Add("Error:  No hostname/IP selected")
        $MainListBox.Items.Add("        Make sure to checkbox only one hostname/IP")
        $MainListBox.Items.Add("        Selecting a Category will not allow you to connect to multiple hosts")    
    }
    elseif ($ComputerListCheckedBoxesSelected.count -gt 1) {
        $StatusListBox.Items.Clear()
        $StatusListBox.Items.Add("PSExec:  Error")
        $MainListBox.Items.Clear()
        $MainListBox.Items.Add("Error:  Too many hostname/IPs selected")
        $MainListBox.Items.Add("        Make sure to checkbox only one hostname/IP")
        $MainListBox.Items.Add("        Selecting a Category will not allow you to connect to multiple hosts")    
    }
})
# Test if the External Programs directory is present; if it's there load the tab
if (Test-Path "$ExternalPrograms\PsExec.exe") {
    $Section2ActionTab.Controls.Add($ComputerListPSExecButton) 
}

$Column5DownPosition += $Column5DownPositionShift

#============================================================================================================================================================
# Computer List - PS Session Button
#============================================================================================================================================================
$ComputerListPSSessionButton          = New-Object System.Windows.Forms.Button
$ComputerListPSSessionButton.Location = New-Object System.Drawing.Size($Column5RightPosition,$Column5DownPosition)
$ComputerListPSSessionButton.Size     = New-Object System.Drawing.Size($Column5BoxWidth,$Column5BoxHeight)
$ComputerListPSSessionButton.Text     = "PS Session"
$ComputerListPSSessionButton.add_click({
    # This array stores checkboxes that are check; a minimum of at least one checkbox will be needed later in the script
    $ComputerListCheckedBoxesSelected = @()
    [System.Windows.Forms.TreeNodeCollection]$AllHostsNode = $ComputerListTreeView.Nodes 
    foreach ($root in $AllHostsNode) { 
        if ($root.Checked) {
            foreach ($Category in $root.Nodes) { foreach ($Entry in $Category.nodes) { $ComputerListCheckedBoxesSelected += $Entry.Text } }
        }
        foreach ($Category in $root.Nodes) { 
            if ($Category.Checked) {
                foreach ($Entry in $Category.nodes) { $ComputerListCheckedBoxesSelected += $Entry.Text }       
            }
            foreach ($Entry in $Category.nodes) {
                if ($Entry.Checked) {
                    $ComputerListCheckedBoxesSelected += $Entry.Text
                }
            }       
        }         
    }   
    $MainListBox.Items.Clear()
    if ($ComputerListCheckedBoxesSelected.count -eq 1) {
        $SelectedComputer = "$($script:ComputerListTreeViewSelected)"
        if ($ComputerListProvideCredentialsCheckBox.Checked -eq $true) {
            if (!$Credential) { $script:Credential = Get-Credential }
            Start-Process PowerShell -ArgumentList "-noexit Enter-PSSession -ComputerName $SelectedComputer -Credential (Get-Credential)"
        }
        else {
            Start-Process PowerShell -ArgumentList "-noexit Enter-PSSession -ComputerName $SelectedComputer" 
        }
        $StatusListBox.Items.Clear()
        $StatusListBox.Items.Add("Enter-PSSession:  $($script:ComputerListTreeViewSelected)")
        $MainListBox.Items.Clear()
        if ($Credential) { $MainListBox.Items.Add("Enter-PSSession -ComputerName $SelectedComputer -Credential (Get-Credential)") }
        else { $MainListBox.Items.Add("Enter-PSSession -ComputerName $SelectedComputer") }
        $LogMessage = "$((Get-Date).ToString('yyyy/MM/dd HH:mm:ss'))  Enter-PSSession: $($script:ComputerListTreeViewSelected)"
        $LogMessage | Add-Content -Path $LogFile
    }
     elseif ($ComputerListCheckedBoxesSelected.count -eq 0) {
        $StatusListBox.Items.Clear()
        $StatusListBox.Items.Add("Enter-PSSession:  Error")
        $MainListBox.Items.Clear()
        $MainListBox.Items.Add("Error:  No hostname/IP selected")
        $MainListBox.Items.Add("        Make sure to checkbox only one hostname/IP")
        $MainListBox.Items.Add("        Selecting a Category will not allow you to connect to multiple hosts")    
    }
    elseif ($ComputerListCheckedBoxesSelected.count -gt 1) {
        $StatusListBox.Items.Clear()
        $StatusListBox.Items.Add("Enter-PSSession:  Error")
        $MainListBox.Items.Clear()
        $MainListBox.Items.Add("Error:  Too many hostname/IPs selected")
        $MainListBox.Items.Add("        Make sure to checkbox only one hostname/IP")
        $MainListBox.Items.Add("        Selecting a Category will not allow you to connect to multiple hosts")    
    }
})
$Section2ActionTab.Controls.Add($ComputerListPSSessionButton) 

$Column5DownPosition += $Column5DownPositionShift

#============================================================================================================================================================
# Computer List - Provide Creds Checkbox
#============================================================================================================================================================

$ComputerListProvideCredentialsCheckBox          = New-Object System.Windows.Forms.CheckBox
$ComputerListProvideCredentialsCheckBox.Name     = "Use Credentials"
$ComputerListProvideCredentialsCheckBox.Text     = "$($ComputerListProvideCredentialsCheckBox.Name)"
$ComputerListProvideCredentialsCheckBox.Location = New-Object System.Drawing.Size(($Column5RightPosition + 1),($Column5DownPosition + 3))
$ComputerListProvideCredentialsCheckBox.Size     = New-Object System.Drawing.Size($Column5BoxWidth,($Column5BoxHeight - 5))
$ComputerListProvideCredentialsCheckBox.Checked  = $false
$Section2ActionTab.Controls.Add($ComputerListProvideCredentialsCheckBox)

$Column5DownPosition += $Column5DownPositionShift

#============================================================================================================================================================
# Provide Creds Button
#============================================================================================================================================================
$ProvideCredsButton          = New-Object System.Windows.Forms.Button
$ProvideCredsButton.Name     = "Provide Creds"
$ProvideCredsButton.Text     = "$($ProvideCredsButton.Name)"
#$ProvideCredsButton.UseVisualStyleBackColor = $True
$ProvideCredsButton.Location = New-Object System.Drawing.Size($Column5RightPosition,($Column5DownPosition - 3))
$ProvideCredsButton.Size     = New-Object System.Drawing.Size($Column5BoxWidth,($Column5BoxHeight))
$ProvideCredsButton.add_Click({
    $script:Credential = Get-Credential
    $ComputerListProvideCredentialsCheckBox.Checked = $True
})
$Section2ActionTab.Controls.Add($ProvideCredsButton)

$Column5DownPosition += $Column5DownPositionShift
$Column5DownPosition += $Column5DownPositionShift
$Column5DownPosition += $Column5DownPositionShift
$Column5DownPosition += $Column5DownPositionShift + 17

#============================================================================================================================================================
# Execute Button
#============================================================================================================================================================
$ComputerListExecuteButton1           = New-Object System.Windows.Forms.Button
$ComputerListExecuteButton1.Name      = "Start`nCollection"
$ComputerListExecuteButton1.Text      = "$($ComputerListExecuteButton1.Name)"
#$ComputerListExecuteButto1n.UseVisualStyleBackColor = $True
$ComputerListExecuteButton1.Location  = New-Object System.Drawing.Size($Column5RightPosition,$Column5DownPosition)
$ComputerListExecuteButton1.Size      = New-Object System.Drawing.Size($Column5BoxWidth,($Column5BoxHeight * 2))
$ComputerListExecuteButton1.ForeColor = "Red"
### $ComputerListExecuteButton1.add_Click($ExecuteScriptHandler) ### Is located lower in the script
$Section2ActionTab.Controls.Add($ComputerListExecuteButton1)

##############################################################################################################################################################
##
## Section 2 Computer List - Control Tab
##
##############################################################################################################################################################

$Section2ManageListTab           = New-Object System.Windows.Forms.TabPage
$Section2ManageListTab.Text      = "Manage List"
$Section2ManageListTab.Location  = New-Object System.Drawing.Size($Column5RightPosition,$Column5DownPosition) 
$Section2ManageListTab.Size      = New-Object System.Drawing.Size($Column5BoxWidth,$Column5BoxHeight) 
$Section2ManageListTab.UseVisualStyleBackColor = $True
$Section2TabControl.Controls.Add($Section2ManageListTab)


#####################################################################################################################################
## Section 2 Computer List - Control Tab Buttons
#####################################################################################################################################

$Column5DownPosition = $Column5DownPositionStart

#============================================================================================================================================================
# ComputerList TreeView - Import .csv Button
#============================================================================================================================================================
$ComputerListTreeViewImportCsvButton          = New-Object System.Windows.Forms.Button
$ComputerListTreeViewImportCsvButton.Name     = "Import .csv"
$ComputerListTreeViewImportCsvButton.Text     = "$($ComputerListTreeViewImportCsvButton.Name)"
$ComputerListTreeViewImportCsvButton.UseVisualStyleBackColor = $True
$ComputerListTreeViewImportCsvButton.Location = New-Object System.Drawing.Size($Column5RightPosition,$Column5DownPosition)
$ComputerListTreeViewImportCsvButton.Size     = New-Object System.Drawing.Size(110,22)
$ComputerListTreeViewImportCsvButton.add_click({
    [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
    $ComputerListTreeViewImportCsvOpenFileDialog                  = New-Object System.Windows.Forms.OpenFileDialog
    $ComputerListTreeViewImportCsvOpenFileDialog.Title            = "Import .csv Data"
    $ComputerListTreeViewImportCsvOpenFileDialog.InitialDirectory = "$PoShHome"
    $ComputerListTreeViewImportCsvOpenFileDialog.filter           = "CSV (*.csv)| *.csv|Excel (*.xlsx)| *.xlsx|Excel (*.xls)| *.xls|All files (*.*)|*.*"
    $ComputerListTreeViewImportCsvOpenFileDialog.ShowHelp         = $true
    $ComputerListTreeViewImportCsvOpenFileDialog.ShowDialog()     | Out-Null
    $ComputerListTreeViewImportCsv    = Import-Csv $($ComputerListTreeViewImportCsvOpenFileDialog.filename) | Select-Object -Property Name, IPv4Address, OperatingSystem, CanonicalName | Sort-Object -Property CanonicalName

    $StatusListBox.Items.Clear()
    $MainListBox.Items.Clear()
    foreach ($Computer in $ComputerListTreeViewImportCsv) {
        if ($script:ComputerListTreeViewData.Name -contains $Computer.Name) {
            $StatusListBox.Items.Clear()
            $StatusListBox.Items.Add("Import .csv:  Warning")
            $MainListBox.Items.Add("$($Computer.Name) already exists with the following data:")
            $MainListBox.Items.Add("- OU/CN: $($($script:ComputerListTreeViewData | Where-Object {$_.Name -eq $Computer.Name}).CanonicalName)")
            $MainListBox.Items.Add("- OS:    $($($script:ComputerListTreeViewData | Where-Object {$_.Name -eq $Computer.Name}).OperatingSystem)")
            $MainListBox.Items.Add("")
        }
        else {
            if ($ComputerListOSHostnameRadioButton.Checked) {
                if ($Computer.OperatingSystem -eq "") {
                    Add-Node -RootNode $script:TreeNode -Category 'Unknown' -Entry $Computer.Name #-ToolTip $Computer.IPv4Address
                }
                else {
                    Add-Node -RootNode $script:TreeNode -Category $Computer.OperatingSystem -Entry $Computer.Name #-ToolTip $Computer.IPv4Address
                }
            }
            elseif ($ComputerListOUHostnameRadioButton.Checked) {
                $CanonicalName = $($($Computer.CanonicalName) -replace $Computer.Name,"" -replace $Computer.CanonicalName.split('/')[0],"").TrimEnd("/")
                if ($Computer.CanonicalName -eq "") {
                    Add-Node -RootNode $script:TreeNode -Category '/Unknown' -Entry $Computer.Name #-ToolTip $Computer.IPv4Address
                }
                else {
                    Add-Node -RootNode $script:TreeNode -Category $CanonicalName -Entry $Computer.Name #-ToolTip $Computer.IPv4Address
                }
            }
            $script:ComputerListTreeViewData += $Computer
        }
    }
    $ComputerListTreeView.ExpandAll()
    Populate-ComputerListTreeViewDefaultData
})
$Section2ManageListTab.Controls.Add($ComputerListTreeViewImportCsvButton)

$Column5DownPosition += $Column5DownPositionShift

#============================================================================================================================================================
# ComputerList TreeView - Import .txt Button
#============================================================================================================================================================
$ComputerListTreeViewImportTxtButton          = New-Object System.Windows.Forms.Button
$ComputerListTreeViewImportTxtButton.Name     = "Import .txt"
$ComputerListTreeViewImportTxtButton.Text     = "$($ComputerListTreeViewImportTxtButton.Name)"
$ComputerListTreeViewImportTxtButton.UseVisualStyleBackColor = $True
$ComputerListTreeViewImportTxtButton.Location = New-Object System.Drawing.Size($Column5RightPosition,$Column5DownPosition)
$ComputerListTreeViewImportTxtButton.Size     = New-Object System.Drawing.Size(110,22)
$ComputerListTreeViewImportTxtButton.add_click({
    [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
    $ComputerListTreeViewImportTxtOpenFileDialog                  = New-Object System.Windows.Forms.OpenFileDialog
    $ComputerListTreeViewImportTxtOpenFileDialog.Title            = "Import .txt Data"
    $ComputerListTreeViewImportTxtOpenFileDialog.InitialDirectory = "$PoShHome"
    $ComputerListTreeViewImportTxtOpenFileDialog.filter           = "TXT (*.txt)| *.txt|All files (*.*)|*.*"
    $ComputerListTreeViewImportTxtOpenFileDialog.ShowHelp         = $true
    $ComputerListTreeViewImportTxtOpenFileDialog.ShowDialog()     | Out-Null    
    $ComputerListTreeViewImportTxt = Import-Csv $($ComputerListTreeViewImportTxtOpenFileDialog.filename) -Header Name, OperatingSystem, CanonicalName, IPv4Address
    $ComputerListTreeViewImportTxt | Export-Csv $ComputerListTreeViewFileTemp -NoTypeInformation -Append
    $ComputerListTreeViewImportCsv = Import-Csv $ComputerListTreeViewFileTemp | Select-Object -Property Name, IPv4Address, OperatingSystem, CanonicalName

    $StatusListBox.Items.Clear()
    $MainListBox.Items.Clear()
    foreach ($Computer in $ComputerListTreeViewImportCsv) {
        if ($script:ComputerListTreeViewData.Name -contains $Computer.Name) {
            $StatusListBox.Items.Clear()
            $StatusListBox.Items.Add("Import .csv:  Warning")
            $MainListBox.Items.Add("$($Computer.Name) already exists with the following data:")
            $MainListBox.Items.Add("- OU/CN: $($($script:ComputerListTreeViewData | Where-Object {$_.Name -eq $Computer.Name}).CanonicalName)")
            $MainListBox.Items.Add("- OS:    $($($script:ComputerListTreeViewData | Where-Object {$_.Name -eq $Computer.Name}).OperatingSystem)")
            $MainListBox.Items.Add("")        }
        else {
            if ($ComputerListOSHostnameRadioButton.Checked) {
                if ($Computer.OperatingSystem -eq "") {
                    Add-Node -RootNode $script:TreeNode -Category 'Unknown' -Entry $Computer.Name #-ToolTip $Computer.IPv4Address
                }
                else {
                    Add-Node -RootNode $script:TreeNode -Category $Computer.OperatingSystem -Entry $Computer.Name #-ToolTip $Computer.IPv4Address
                }
            }
            elseif ($ComputerListOUHostnameRadioButton.Checked) {
                $CanonicalName = $($($Computer.CanonicalName) -replace $Computer.Name,"" -replace $Computer.CanonicalName.split('/')[0],"").TrimEnd("/")
                if ($Computer.CanonicalName -eq "") {
                    Add-Node -RootNode $script:TreeNode -Category '/Unknown' -Entry $Computer.Name #-ToolTip $Computer.IPv4Address
                }
                else {
                    Add-Node -RootNode $script:TreeNode -Category $CanonicalName -Entry $Computer.Name #-ToolTip $Computer.IPv4Address
                }
            }
            $script:ComputerListTreeViewData += $Computer
        }
    }
    $ComputerListTreeView.ExpandAll()
    Populate-ComputerListTreeViewDefaultData
    Remove-Item $ComputerListTreeViewFileTemp
})
$Section2ManageListTab.Controls.Add($ComputerListTreeViewImportTxtButton)

$Column5DownPosition += $Column5DownPositionShift

#============================================================================================================================================================
# Computer List - Treeview - Add Button
#============================================================================================================================================================
$ComputerListTreeViewAddHostnameIPButton          = New-Object System.Windows.Forms.Button
$ComputerListTreeViewAddHostnameIPButton.Location = New-Object System.Drawing.Size($Column5RightPosition,$Column5DownPosition)
$ComputerListTreeViewAddHostnameIPButton.Size     = New-Object System.Drawing.Size($Column5BoxWidth,$Column5BoxHeight)
$ComputerListTreeViewAddHostnameIPButton.Text     = 'Add'
$ComputerListTreeViewAddHostnameIPButton.add_click({
    $StatusListBox.Items.Clear()
    $StatusListBox.Items.Add("Add hostname/IP:")
    $MainListBox.Items.Clear()
    $MainListBox.Items.Add("Enter a hostname/IP")

    #----------------------------------
    # ComputerList TreeView Popup Form
    #----------------------------------
    $ComputerListTreeViewPopup               = New-Object system.Windows.Forms.Form
    $ComputerListTreeViewPopup.Text          = "Add Hostname/IP"
    $ComputerListTreeViewPopup.Size          = New-Object System.Drawing.Size(335,177)
    $ComputerListTreeViewPopup.StartPosition = "CenterScreen"

    #-----------------------------------------------------
    # ComputerList TreeView Popup Add Hostname/IP TextBox
    #-----------------------------------------------------
    $ComputerListTreeViewPopupAddTextBox          = New-Object System.Windows.Forms.TextBox
    $ComputerListTreeViewPopupAddTextBox.Text     = "Enter a hostname/IP"
    $ComputerListTreeViewPopupAddTextBox.Size     = New-Object System.Drawing.Size(300,25)
    $ComputerListTreeViewPopupAddTextBox.Location = New-Object System.Drawing.Size(10,10)
    $ComputerListTreeViewPopup.Controls.Add($ComputerListTreeViewPopupAddTextBox)

    #-----------------------------------------
    # ComputerList TreeView Popup OS ComboBox
    #-----------------------------------------
    $ComputerListTreeViewPopupOSComboBox          = New-Object System.Windows.Forms.ComboBox
    $ComputerListTreeViewPopupOSComboBox.Text     = "Select an Operating System (or type in a new one)"
    $ComputerListTreeViewPopupOSComboBox.Size     = New-Object System.Drawing.Size(300,25)
    $ComputerListTreeViewPopupOSComboBox.Location = New-Object System.Drawing.Size(10,($ComputerListTreeViewPopupAddTextBox.Location.Y + $ComputerListTreeViewPopupAddTextBox.Size.Height + 10))
        $ComputerListTreeViewOSCategoryList = $script:ComputerListTreeViewData | Select-Object -ExpandProperty OperatingSystem -Unique
        # Dynamically creates the OS Category combobox list used for OS Selection
        ForEach ($OS in $ComputerListTreeViewOSCategoryList) { $ComputerListTreeViewPopupOSComboBox.Items.Add($OS) }
    $ComputerListTreeViewPopup.Controls.Add($ComputerListTreeViewPopupOSComboBox)

    #-----------------------------------------
    # ComputerList TreeView Popup OU ComboBox
    #-----------------------------------------
    $ComputerListTreeViewPopupOUComboBox          = New-Object System.Windows.Forms.ComboBox
    $ComputerListTreeViewPopupOUComboBox.Text     = "Select an Organizational Unit / Canonical Name"
    $ComputerListTreeViewPopupOUComboBox.Size     = New-Object System.Drawing.Size(300,25)
    $ComputerListTreeViewPopupOUComboBox.Location = New-Object System.Drawing.Size(10,($ComputerListTreeViewPopupOSComboBox.Location.Y + $ComputerListTreeViewPopupOSComboBox.Size.Height + 10))        
        $ComputerListTreeViewOUCategoryList = $script:ComputerListTreeViewData | Select-Object -ExpandProperty CanonicalName -Unique
        # Dynamically creates the OU Category combobox list used for OU Selection
        ForEach ($OU in $ComputerListTreeViewOUCategoryList) { $ComputerListTreeViewPopupOUComboBox.Items.Add($OU) }
    $ComputerListTreeViewPopup.Controls.Add($ComputerListTreeViewPopupOUComboBox)

    #---------------------------------------------
    # function to add a hostname/IP to a category
    #---------------------------------------------
    function AddHost-ComputerListTreeView {
        if ($script:ComputerListTreeViewData.Name -contains $ComputerListTreeViewPopupAddTextBox.Text) {
            #$script:ComputerListTreeViewData = $script:ComputerListTreeViewData | Where-Object {$_.Name -ne $Entry.text}
            $StatusListBox.Items.Clear()
            $StatusListBox.Items.Add("Add Hostname/IP:  Error")
            $MainListBox.Items.Clear()
            $MainListBox.Items.Add("$($ComputerListTreeViewPopupAddTextBox.Text) already exists with the following data:")
            $MainListBox.Items.Add("- OU/CN: $($($script:ComputerListTreeViewData | Where-Object {$_.Name -eq $ComputerListTreeViewPopupAddTextBox.Text}).CanonicalName)")
            $MainListBox.Items.Add("- OS:    $($($script:ComputerListTreeViewData | Where-Object {$_.Name -eq $ComputerListTreeViewPopupAddTextBox.Text}).OperatingSystem)")
        }
        else {
            $StatusListBox.Items.Clear()
            $StatusListBox.Items.Add("Added Selection:  $($ComputerListTreeViewPopupAddTextBox.Text)")

            if ($ComputerListOSHostnameRadioButton.Checked) {
                Add-Node -RootNode $script:TreeNode -Category $ComputerListTreeViewPopupOSComboBox.Text -Entry $ComputerListTreeViewPopupAddTextBox.Text #-ToolTip "No Data Available"
                $MainListBox.Items.Clear()
                $MainListBox.Items.Add("$($ComputerListTreeViewPopupAddTextBox.Text) has been added to $($ComputerListTreeViewPopupOSComboBox.Text)")
            }
            elseif ($ComputerListOUHostnameRadioButton.Checked) {
                Add-Node -RootNode $script:TreeNode -Category $ComputerListTreeViewPopupOUComboBox.SelectedItem -Entry $ComputerListTreeViewPopupAddTextBox.Text #-ToolTip "No Data Available"            
                $MainListBox.Items.Clear()
                $MainListBox.Items.Add("$($ComputerListTreeViewPopupAddTextBox.Text) has been added to $($ComputerListTreeViewPopupOUComboBox.Text)")
            }       
            $ComputerListTreeViewAddHostnameIP = New-Object PSObject -Property @{ 
                Name            = $ComputerListTreeViewPopupAddTextBox.Text
                OperatingSystem = $ComputerListTreeViewPopupOSComboBox.Text
                CanonicalName   = $ComputerListTreeViewPopupOUComboBox.SelectedItem
                IPv4Address     = "No Data Available"
            }        
            $script:ComputerListTreeViewData += $ComputerListTreeViewAddHostnameIP
            $ComputerListTreeView.ExpandAll()
            $ComputerListTreeViewPopup.close()
        }
    }
    $ComputerListTreeView.ExpandAll()
    Populate-ComputerListTreeViewDefaultData

    # Moves the hostname/IPs to the new Category
    $ComputerListTreeViewPopupAddTextBox.Add_KeyDown({ 
        if ($_.KeyCode -eq "Enter") { 
            AddHost-ComputerListTreeView
        }
    })

    #--------------------------------------------
    # ComputerList TreeView Popup Execute Button
    #--------------------------------------------
    $ComputerListTreeViewPopupMoveButton          = New-Object System.Windows.Forms.Button
    $ComputerListTreeViewPopupMoveButton.Text     = "Execute"
    $ComputerListTreeViewPopupMoveButton.Size     = New-Object System.Drawing.Size(100,25)
    $ComputerListTreeViewPopupMoveButton.Location = New-Object System.Drawing.Size(210,($ComputerListTreeViewPopupOUComboBox.Location.Y + $ComputerListTreeViewPopupOUComboBox.Size.Height + 10))
    $ComputerListTreeViewPopupMoveButton.Add_Click({
        AddHost-ComputerListTreeView
    })
    $ComputerListTreeViewPopup.Controls.Add($ComputerListTreeViewPopupMoveButton)

    $ComputerListTreeViewPopup.ShowDialog()               
})
$Section2ManageListTab.Controls.Add($ComputerListTreeViewAddHostnameIPButton) 

$Column5DownPosition += $Column5DownPositionShift

#============================================================================================================================================================
# Computer List - Treeview - Delete Button
#============================================================================================================================================================
$ComputerListDeleteButton               = New-Object System.Windows.Forms.Button
$ComputerListDeleteButton.Location      = New-Object System.Drawing.Size($Column5RightPosition,$Column5DownPosition)
$ComputerListDeleteButton.Size          = New-Object System.Drawing.Size($Column5BoxWidth,$Column5BoxHeight)
$ComputerListDeleteButton.Text          = 'Delete'
$ComputerListDeleteButton.add_click({
    # This array stores checkboxes that are check; a minimum of at least one checkbox will be needed later in the script
    $ComputerListCheckedBoxesSelected = @()
    [System.Windows.Forms.TreeNodeCollection]$AllHostsNode = $ComputerListTreeView.Nodes 
    foreach ($root in $AllHostsNode) { 
        if ($root.Checked) {
            $ComputerListCheckedBoxesSelected += $root.Text
        }
        foreach ($Category in $root.Nodes) { 
            if ($Category.Checked) {
                $ComputerListCheckedBoxesSelected += $Category.Text
            }
            foreach ($Entry in $Category.nodes) {
                if ($Entry.Checked) {
                    $ComputerListCheckedBoxesSelected += $Entry.Text
                }
            }       
        }         
    }

    if ($ComputerListCheckedBoxesSelected.count -ge 1) {
        # Removes the original hostname/IP that was copied above
        foreach ($i in $ComputerListCheckedBoxesSelected) {
            foreach ($root in $AllHostsNode) { 
                if (($i -contains $root.text) -and ($root.Checked -eq $True)) {
                    $MainListBox.Items.Add($root.text)
                    $root.remove()
                    Initialize-ComputerTreeView
                    $Null = $ComputerListTreeView.Nodes.Add($script:TreeNode)
                    $ComputerListTreeView.ExpandAll()
                }
                foreach ($Category in $root.Nodes) { 
                    if (($i -contains $Category.text) -and ($Category.Checked -eq $True)) {
                        $MainListBox.Items.Add($Category.text)
                        $Category.remove()
                        foreach ($Entry in $Category.nodes) { 
                            $MainListBox.Items.Add($Entry.text)
                            $Entry.remove()
                            $script:ComputerListTreeViewData = $script:ComputerListTreeViewData | Where-Object {$_.Name -ne $Entry.text}
                        }
                    }
                    foreach ($Entry in $Category.nodes) { 
                        if (($i -contains $Entry.text) -and ($Entry.Checked -eq $True)) {
                            $MainListBox.Items.Add($Entry.text)
                            # This removes the host from the treeview
                            $Entry.remove()
            
                            # This removes the host from the variable storing the all the computers
                            $script:ComputerListTreeViewData = $script:ComputerListTreeViewData | Where-Object {$_.Name -ne $Entry.text}
                        }
                    }
                }
            }
        }
        $StatusListBox.Items.Clear()
        $StatusListBox.Items.Add("Deleted:  $($ComputerListCheckedBoxesSelected.Count) Selected Items")
        $MainListBox.Items.Clear()
        $MainListBox.Items.Add("The following hostnames/IPs or categories have been deleted:")

        $ComputerListTreeViewPopup.close()
    }
    else {
        $StatusListBox.Items.Clear()
        $StatusListBox.Items.Add("Delete Selection:  Error")
        $MainListBox.Items.Clear()
        $MainListBox.Items.Add("Error: No Category, hostname, or IP selected")
        $MainListBox.Items.Add("       Make sure to checkbox at least one hostname/IP or Category")
        $MainListBox.Items.Add("       Selecting a Category will remove contents within it")
    }

})
$Section2ManageListTab.Controls.Add($ComputerListDeleteButton) 

$Column5DownPosition += $Column5DownPositionShift

#============================================================================================================================================================
# Computer List - Treeview - Move Button
#============================================================================================================================================================
$ComputerListMoveButton               = New-Object System.Windows.Forms.Button
$ComputerListMoveButton.Location      = New-Object System.Drawing.Size($Column5RightPosition,$Column5DownPosition)
$ComputerListMoveButton.Size          = New-Object System.Drawing.Size($Column5BoxWidth,$Column5BoxHeight)
$ComputerListMoveButton.Text          = 'Move'
$ComputerListMoveButton.add_click({
    # Creates a list of all the checkboxes selected
    $ComputerListCheckedBoxesSelected = @()
    [System.Windows.Forms.TreeNodeCollection]$AllHostsNode = $ComputerListTreeView.Nodes 
    foreach ($root in $AllHostsNode) { 
        foreach ($Category in $root.Nodes) { 
            foreach ($Entry in $Category.nodes) { 
                if ($Entry.Checked) {
                    $ComputerListCheckedBoxesSelected += $Entry.Text
                }
            }       
        }         
    }

    if ($ComputerListCheckedBoxesSelected.count -ge 1) {
        $StatusListBox.Items.Clear()
        $StatusListBox.Items.Add("Move Selection:  ")
        $MainListBox.Items.Clear()
        $MainListBox.Items.Add("Select a Category to move the hostname/IP into")

        #----------------------------------
        # ComputerList TreeView Popup Form
        #----------------------------------
        $ComputerListTreeViewPopup               = New-Object system.Windows.Forms.Form
        $ComputerListTreeViewPopup.Text          = "Move"
        $ComputerListTreeViewPopup.Size          = New-Object System.Drawing.Size(330,107)
        $ComputerListTreeViewPopup.StartPosition = "CenterScreen"

        #----------------------------------------------
        # ComputerList TreeView Popup Execute ComboBox
        #----------------------------------------------
        $ComputerListTreeViewPopupMoveComboBox          = New-Object System.Windows.Forms.ComboBox
        $ComputerListTreeViewPopupMoveComboBox.Text     = "Select A Category"
        $ComputerListTreeViewPopupMoveComboBox.Size     = New-Object System.Drawing.Size(300,25)
        $ComputerListTreeViewPopupMoveComboBox.Location = New-Object System.Drawing.Size(10,10)

        # Dynamically creates the combobox's Category list used for the move destination
        $ComputerListTreeViewCategoryList = @()
        [System.Windows.Forms.TreeNodeCollection]$AllHostsNode = $ComputerListTreeView.Nodes 
        ForEach ($root in $AllHostsNode) { foreach ($Category in $root.Nodes) { $ComputerListTreeViewCategoryList += $Category.text } }
        ForEach ($Item in $ComputerListTreeViewCategoryList) { $ComputerListTreeViewPopupMoveComboBox.Items.Add($Item) }

        # Moves the checkboxed nodes to the selected Category
        function Move-ComputerListTreeViewSelected {                       
            # Makes a copy of the checkboxed node name in the new Category
            $ComputerListTreeViewToMove = New-Object System.Collections.ArrayList

            function Copy-TreeViewNode {
                # Adds (copies) the node to the new Category
                [System.Windows.Forms.TreeNodeCollection]$AllHostsNode = $ComputerListTreeView.Nodes 
                foreach ($root in $AllHostsNode) { 
                    if ($root.Checked) { $root.Checked = $false }
                    foreach ($Category in $root.Nodes) { 
                        if ($Category.Checked) { $Category.Checked = $false }
                        foreach ($Entry in $Category.nodes) { 
                            if ($Entry.Checked) {
                                Add-Node -RootNode $script:TreeNode -Category $ComputerListTreeViewPopupMoveComboBox.SelectedItem -Entry $Entry.text #-ToolTip "No Data Available"
                                $ComputerListTreeViewToMove.Add($Entry.text)
                            }
                        }
                    }
                }
            }
            if ($ComputerListOSHostnameRadioButton.Checked) {
                Copy-TreeViewNode
                # Removes the original hostname/IP that was copied above
                foreach ($i in $ComputerListTreeViewToMove) {
                    foreach ($root in $AllHostsNode) { 
                        foreach ($Category in $root.Nodes) { 
                            foreach ($Entry in $Category.nodes) { 
                                if (($i -contains $Entry.text) -and ($Entry.Checked)) {
                                    $($script:ComputerListTreeViewData | Where-Object {$_.Name -eq $Entry.Text}).OperatingSystem = $ComputerListTreeViewPopupMoveComboBox.SelectedItem
                                    $MainListBox.Items.Add($Entry.text)
                                    $Entry.remove()
                                }
                            }
                        }
                    }
                }
            }
            elseif ($ComputerListOUHostnameRadioButton.Checked) {
                Copy-TreeViewNode                
                # Removes the original hostname/IP that was copied above
                foreach ($i in $ComputerListTreeViewToMove) {
                    foreach ($root in $AllHostsNode) { 
                        foreach ($Category in $root.Nodes) { 
                            foreach ($Entry in $Category.nodes) { 
                                if (($i -contains $Entry.text) -and ($Entry.Checked)) {
                                    $($script:ComputerListTreeViewData | Where-Object {$_.Name -eq $Entry.Text}).CanonicalName = $ComputerListTreeViewPopupMoveComboBox.SelectedItem
                                    $MainListBox.Items.Add($Entry.text)
                                    $Entry.remove()
                                }
                            }
                        }
                    }
                }
            }
            $StatusListBox.Items.Clear()
            $StatusListBox.Items.Add("Move Selection:  $($ComputerListTreeViewToMove.Count) Hosts")
            $MainListBox.Items.Clear()
            $MainListBox.Items.Add("The following hostnames/IPs have been moved to $($ComputerListTreeViewPopupMoveComboBox.SelectedItem):")
            $ComputerListTreeViewPopup.close()
        }           
        # Moves the hostname/IPs to the new Category
        $ComputerListTreeViewPopupMoveComboBox.Add_KeyDown({ 
            if ($_.KeyCode -eq "Enter") { 
                Move-ComputerListTreeViewSelected
            }
        })
        $ComputerListTreeViewPopup.Controls.Add($ComputerListTreeViewPopupMoveComboBox)

        #--------------------------------------------
        # ComputerList TreeView Popup Execute Button
        #--------------------------------------------
        $ComputerListTreeViewPopupMoveButton          = New-Object System.Windows.Forms.Button
        $ComputerListTreeViewPopupMoveButton.Text     = "Execute"
        $ComputerListTreeViewPopupMoveButton.Size     = New-Object System.Drawing.Size(100,25)
        $ComputerListTreeViewPopupMoveButton.Location = New-Object System.Drawing.Size(210,($ComputerListTreeViewPopupMoveComboBox.Size.Height + 15))
        $ComputerListTreeViewPopupMoveButton.Add_Click({
            Move-ComputerListTreeViewSelected
        })
        $ComputerListTreeViewPopup.Controls.Add($ComputerListTreeViewPopupMoveButton)

        $ComputerListTreeViewPopup.ShowDialog()               
    }
    else {
        $StatusListBox.Items.Clear()
        $StatusListBox.Items.Add("Move Selection:  Error")
        $MainListBox.Items.Clear()
        $MainListBox.Items.Add("Error: No hostname/IP selected")
        $MainListBox.Items.Add("       Make sure to checkbox at least one hostname/IP")
        $MainListBox.Items.Add("       Selecting a Category will not move the contents within it")
    }
})
$Section2ManageListTab.Controls.Add($ComputerListMoveButton) 

$Column5DownPosition += $Column5DownPositionShift

#============================================================================================================================================================
# Computer List - Treeview - Rename Button
#============================================================================================================================================================
$ComputerListRenameButton               = New-Object System.Windows.Forms.Button
$ComputerListRenameButton.Location      = New-Object System.Drawing.Size($Column5RightPosition,$Column5DownPosition)
$ComputerListRenameButton.Size          = New-Object System.Drawing.Size($Column5BoxWidth,$Column5BoxHeight)
$ComputerListRenameButton.Text          = 'Rename'
$ComputerListRenameButton.add_click({
    # Creates a list of all the checkboxes selected
    $ComputerListCheckedBoxesSelected = @()
    [System.Windows.Forms.TreeNodeCollection]$AllHostsNode = $ComputerListTreeView.Nodes 
    foreach ($root in $AllHostsNode) { 
        foreach ($Category in $root.Nodes) { 
            foreach ($Entry in $Category.nodes) { 
                if ($Entry.Checked) {
                    $ComputerListCheckedBoxesSelected += $Entry.Text
                }
            }       
        }         
    }
    if ($ComputerListCheckedBoxesSelected.count -eq 1) {
        $StatusListBox.Items.Clear()
        $StatusListBox.Items.Add("Rename Selection:  ")
        $MainListBox.Items.Clear()
        $MainListBox.Items.Add("Enter a new name:")

        #----------------------------------
        # ComputerList TreeView Popup Form
        #----------------------------------
        $ComputerListTreeViewRenamePopup               = New-Object system.Windows.Forms.Form
        $ComputerListTreeViewRenamePopup.Text          = "Rename $($script:ComputerListTreeViewSelected)"
        $ComputerListTreeViewRenamePopup.Size          = New-Object System.Drawing.Size(330,107)
        $ComputerListTreeViewRenamePopup.StartPosition = "CenterScreen"

        #---------------------------------------------
        # ComputerList TreeView Popup Execute TextBox
        #---------------------------------------------
        $ComputerListTreeViewRenamePopupTextBox          = New-Object System.Windows.Forms.TextBox
        $ComputerListTreeViewRenamePopupTextBox.Text     = "New Hostname/IP"
        $ComputerListTreeViewRenamePopupTextBox.Size     = New-Object System.Drawing.Size(300,25)
        $ComputerListTreeViewRenamePopupTextBox.Location = New-Object System.Drawing.Size(10,10)

        #-----------------------------------------
        # Function to rename the checkboxed nodes
        #-----------------------------------------
        function Rename-ComputerListTreeViewSelected {                       
            if ($script:ComputerListTreeViewData.Name -contains $ComputerListTreeViewRenamePopupTextBox.Text) {
                #$script:ComputerListTreeViewData = $script:ComputerListTreeViewData | Where-Object {$_.Name -ne $Entry.text}
                $StatusListBox.Items.Clear()
                $StatusListBox.Items.Add("Rename Hostname/IP:  Error")
                $MainListBox.Items.Clear()
                $MainListBox.Items.Add("$($ComputerListTreeViewRenamePopupTextBox.Text) already exists with the following data:")
                $MainListBox.Items.Add("- OU/CN: $($($script:ComputerListTreeViewData | Where-Object {$_.Name -eq $ComputerListTreeViewRenamePopupTextBox.Text}).CanonicalName)")
                $MainListBox.Items.Add("- OS:    $($($script:ComputerListTreeViewData | Where-Object {$_.Name -eq $ComputerListTreeViewRenamePopupTextBox.Text}).OperatingSystem)")
            }
            else {
                # Makes a copy of the checkboxed node name in the new Category
                $ComputerListTreeViewToRename = New-Object System.Collections.ArrayList

                # Adds (copies) the node to the new Category
                [System.Windows.Forms.TreeNodeCollection]$AllHostsNode = $ComputerListTreeView.Nodes 
                foreach ($root in $AllHostsNode) { 
                    if ($root.Checked) { $root.Checked = $false }
                    foreach ($Category in $root.Nodes) { 
                        if ($Category.Checked) { $Category.Checked = $false }
                        foreach ($Entry in $Category.nodes) { 
                            if ($Entry.Checked) {
                                Add-Node -RootNode $script:TreeNode -Category $Category.Text -Entry $ComputerListTreeViewRenamePopupTextBox.text #-ToolTip "No Data Available"
                                $ComputerListTreeViewToRename.Add($Entry.text)
                            }
                        }
                    }
                }
                # Removes the original hostname/IP that was copied above
                foreach ($i in $ComputerListTreeViewToRename) {
                    foreach ($root in $AllHostsNode) { 
                        foreach ($Category in $root.Nodes) { 
                            foreach ($Entry in $Category.nodes) { 
                                if (($i -contains $Entry.text) -and ($Entry.Checked)) {
                                    $($script:ComputerListTreeViewData | Where-Object {$_.Name -eq $Entry.Text}).Name = $ComputerListTreeViewRenamePopupTextBox.text
                                    $MainListBox.Items.Add($Entry.text)
                                    $Entry.remove()
                                }
                            }
                        }
                    }
                }
                $StatusListBox.Items.Clear()
                $StatusListBox.Items.Add("Rename Selection:  $($ComputerListTreeViewToRename.Count) Hosts")
                $MainListBox.Items.Clear()
                $MainListBox.Items.Add("Computer $($ComputerListTreeViewPopupMoveComboBox.SelectedItem) has been renamed to $($ComputerListTreeViewRenamePopupTextBox.Text)")
            }
            $ComputerListTreeViewRenamePopup.close()
        }           
           
        # Moves the hostname/IPs to the new Category
        $ComputerListTreeViewRenamePopupTextBox.Add_KeyDown({ 
            if ($_.KeyCode -eq "Enter") { 
                Rename-ComputerListTreeViewSelected
            }
        })
        $ComputerListTreeViewRenamePopup.Controls.Add($ComputerListTreeViewRenamePopupTextBox)

        #--------------------------------------------
        # ComputerList TreeView Popup Execute Button
        #--------------------------------------------
        $ComputerListTreeViewRenamePopupButton          = New-Object System.Windows.Forms.Button
        $ComputerListTreeViewRenamePopupButton.Text     = "Execute"
        $ComputerListTreeViewRenamePopupButton.Size     = New-Object System.Drawing.Size(100,25)
        $ComputerListTreeViewRenamePopupButton.Location = New-Object System.Drawing.Size(210,($ComputerListTreeViewRenamePopupTextBox.Size.Height + 15))
        $ComputerListTreeViewRenamePopupButton.Add_Click({
            Rename-ComputerListTreeViewSelected
        })
        $ComputerListTreeViewRenamePopup.Controls.Add($ComputerListTreeViewRenamePopupButton)

        $ComputerListTreeViewRenamePopup.ShowDialog()               
    }
    elseif ($ComputerListCheckedBoxesSelected.count -gt 1) {
        $StatusListBox.Items.Clear()
        $StatusListBox.Items.Add("Rename Selection:  Error")
        $MainListBox.Items.Clear()
        $MainListBox.Items.Add("Error: Too many checkboxes selected")
        $MainListBox.Items.Add("       Make sure to checkbox only one hostname/IP")
    }
    elseif ($ComputerListCheckedBoxesSelected.count -lt 1) {
        $StatusListBox.Items.Clear()
        $StatusListBox.Items.Add("Rename Selection:  Error")
        $MainListBox.Items.Clear()
        $MainListBox.Items.Add("Error: No hostname/IP selected")
        $MainListBox.Items.Add("       Make sure to checkbox at least one hostname/IP")
    }
})
$Section2ManageListTab.Controls.Add($ComputerListRenameButton) 

$Column5DownPosition += $Column5DownPositionShift

#============================================================================================================================================================
# Computer List - Treeview - Deselect All Button
#============================================================================================================================================================
$ComputerListDeselectAllButton           = New-Object System.Windows.Forms.Button
$ComputerListDeselectAllButton.Location  = New-Object System.Drawing.Size($Column5RightPosition,$Column5DownPosition)
$ComputerListDeselectAllButton.Size      = New-Object System.Drawing.Size($Column5BoxWidth,$Column5BoxHeight)
$ComputerListDeselectAllButton.Text      = 'Deselect All'
$ComputerListDeselectAllButton.add_click({
    #$ComputerListTreeView.Nodes.Clear()
    [System.Windows.Forms.TreeNodeCollection]$AllHostsNode = $ComputerListTreeView.Nodes 
    foreach ($root in $AllHostsNode) { 
        if ($root.Checked) { $root.Checked = $false }
        foreach ($Category in $root.Nodes) { 
            if ($Category.Checked) { $Category.Checked = $false }
            foreach ($Entry in $Category.nodes) { 
                if ($Entry.Checked) { $Entry.Checked = $false }
            }
        }
    }
})
$Section2ManageListTab.Controls.Add($ComputerListDeselectAllButton) 

$Column5DownPosition += $Column5DownPositionShift

#============================================================================================================================================================
# Computer List - Treeview - Collapse / Expand Button
#============================================================================================================================================================
$ComputerListTreeViewCollapseAllButton          = New-Object System.Windows.Forms.Button
$ComputerListTreeViewCollapseAllButton.Location = New-Object System.Drawing.Size($Column5RightPosition,$Column5DownPosition)
$ComputerListTreeViewCollapseAllButton.Size     = New-Object System.Drawing.Size($Column5BoxWidth,$Column5BoxHeight)
$ComputerListTreeViewCollapseAllButton.Text     = "Collapse"
$ComputerListTreeViewCollapseAllButton.add_click({
<#    $ComputerListTreeViewFound = $ComputerListTreeView.Nodes.Find("WIN81-01", $true)
    $MainListBox.Items.Clear()
    [System.Windows.Forms.TreeNodeCollection]$AllHostsNode = $ComputerListTreeView.Nodes 
            foreach ($Node in $ComputerListTreeViewFound) { 
                $MainListBox.Items.Add($Node.Text)
            }       
    $MainListBox.Items.Add("")#>
    if ($ComputerListTreeViewCollapseAllButton.Text -eq "Collapse") {
        $ComputerListTreeView.CollapseAll()
        [System.Windows.Forms.TreeNodeCollection]$AllHostsNode = $ComputerListTreeView.Nodes 
        foreach ($root in $AllHostsNode) { 
            $root.Expand()
        }
        $ComputerListTreeViewCollapseAllButton.Text = "Expand"
    }
    elseif ($ComputerListTreeViewCollapseAllButton.Text -eq "Expand") {
        $ComputerListTreeView.ExpandAll()
        $ComputerListTreeViewCollapseAllButton.Text = "Collapse"
    }

})
$Section2ManageListTab.Controls.Add($ComputerListTreeViewCollapseAllButton) 

$Column5DownPosition += $Column5DownPositionShift

#============================================================================================================================================================
# Computer List - TreeView - Save Button
#============================================================================================================================================================
$ComputerListTreeViewSaveButton          = New-Object System.Windows.Forms.Button
$ComputerListTreeViewSaveButton.Location = New-Object System.Drawing.Size($Column5RightPosition,$Column5DownPosition)
$ComputerListTreeViewSaveButton.Size     = New-Object System.Drawing.Size($Column5BoxWidth,$Column5BoxHeight)
$ComputerListTreeViewSaveButton.Text     = "Save List"
$ComputerListTreeViewSaveButton.add_click({
    $script:ComputerListTreeViewData | Export-Csv $ComputerListTreeViewFileSaved -NoTypeInformation
})
$Section2ManageListTab.Controls.Add($ComputerListTreeViewSaveButton) 

$Column5DownPosition += $Column5DownPositionShift + 17

#============================================================================================================================================================
# Execute Button
#============================================================================================================================================================
$ComputerListExecuteButton2           = New-Object System.Windows.Forms.Button
$ComputerListExecuteButton2.Name      = "Start`nCollection"
$ComputerListExecuteButton2.Text      = "$($ComputerListExecuteButton2.Name)"
$ComputerListExecuteButton2.UseVisualStyleBackColor = $True
$ComputerListExecuteButton2.Location  = New-Object System.Drawing.Size($Column5RightPosition,$Column5DownPosition)
$ComputerListExecuteButton2.Size      = New-Object System.Drawing.Size($Column5BoxWidth,($Column5BoxHeight * 2))
$ComputerListExecuteButton2.ForeColor = "Red"
### $ComputerListExecuteButton2.add_Click($ExecuteScriptHandler) ### Is located lower in the script
$Section2ManageListTab.Controls.Add($ComputerListExecuteButton2)

##############################################################################################################################################################
##
## Section 3 Bottom Area
##
##############################################################################################################################################################

# Varables to Control Column 6 - Bottom Right Section
$Column6RightPosition     = 470
$Column6DownPosition      = 259
$Column6ProgressBarWidth  = 308
$Column6ProgressBarHeight = 22
$Column6DownPositionShift = 25
$Column6MainListBoxWidth  = 736
$Column6MainListBoxHeight = 240

$Column6DownPosition += $Column6DownPositionShift
$Column6DownPosition += $Column6DownPositionShift

#--------------
# Status Label
#--------------
$StatusLabel           = New-Object System.Windows.Forms.Label
$StatusLabel.Location  = New-Object System.Drawing.Size(($Column6RightPosition - 2),($Column6DownPosition - 1))
$StatusLabel.Size      = New-Object System.Drawing.Size(60,$Column6ProgressBarHeight)
$StatusLabel.Text      = "Status:"
$StatusLabel.Font      = New-Object System.Drawing.Font("$Font",12,1,3,1)
$StatusLabel.ForeColor = "Blue"
$PoShACME.Controls.Add($StatusLabel)  

#----------------
# Status Listbox
#----------------
$StatusListBox          = New-Object System.Windows.Forms.ListBox
$StatusListBox.Name     = "StatusListBox"
$StatusListBox.FormattingEnabled = $True
$StatusListBox.Location = New-Object System.Drawing.Size(($Column6RightPosition + 60),$Column6DownPosition) 
$StatusListBox.Size     = New-Object System.Drawing.Size($Column6ProgressBarWidth,$Column6ProgressBarHeight)
$StatusListBox.Items.Add("") | Out-Null
$PoShACME.Controls.Add($StatusListBox)

$Column6DownPosition += $Column6DownPositionShift

# ---------------------
# Progress Bar 1 Label
#----------------------
$ProgressBar1Label          = New-Object System.Windows.Forms.Label
$ProgressBar1Label.Location = New-Object System.Drawing.Size(($Column6RightPosition),($Column6DownPosition - 6))
$ProgressBar1Label.Size     = New-Object System.Drawing.Size(60,($Column6ProgressBarHeight - 2))
$ProgressBar1Label.Text     = "Section:"
$PoShACME.Controls.Add($ProgressBar1Label)  


#----------------------------
# Progress Bar 1 ProgressBar
#----------------------------

$ProgressBar1          = New-Object System.Windows.Forms.ProgressBar
$ProgressBar1.Style    = "Continuous"
#$ProgressBar1.Maximum  = 10
$ProgressBar1.Minimum  = 0
$ProgressBar1.Location = new-object System.Drawing.Size(($Column6RightPosition + 60),($Column6DownPosition - 2))
$ProgressBar1.size     = new-object System.Drawing.Size($Column6ProgressBarWidth,10)
#$ProgressBar1.Value     = 0
#$ProgressBar1.Step     = 1
$PoSHACME.Controls.Add($ProgressBar1)


# Shift Row Location
$Column6DownPosition += $Column6DownPositionShift - 9


#----------------------
# Progress Bar 2 Label
#----------------------

$ProgressBar2Label          = New-Object System.Windows.Forms.Label
$ProgressBar2Label.Location = New-Object System.Drawing.Size(($Column6RightPosition),($Column6DownPosition - 2))
$ProgressBar2Label.Size     = New-Object System.Drawing.Size(60,($Column6ProgressBarHeight - 4))
$ProgressBar2Label.Text     = "Overall:"
$PoShACME.Controls.Add($ProgressBar2Label)  

#----------------------------
# Progress Bar 2 ProgressBar
#----------------------------
$ProgressBar2          = New-Object System.Windows.Forms.ProgressBar
$ProgressBar2.Maximum  = $ProgressBar2Max
$ProgressBar2.Minimum  = 0
$ProgressBar2.Location = new-object System.Drawing.Size(($Column6RightPosition + 60),($Column6DownPosition - 2))
$ProgressBar2.size     = new-object System.Drawing.Size($Column6ProgressBarWidth,10)
$ProgressBar2.Count      = 0
$PoSHACME.Controls.Add($ProgressBar2)

$Column6DownPosition += $Column6DownPositionShift - 9

# ===================
# Main Message Box
# ===================
$MainListBox          = New-Object System.Windows.Forms.ListBox
$MainListBox.Name     = "MainListBox"
$MainListBox.FormattingEnabled = $True
$MainListBox.Location = New-Object System.Drawing.Size($Column6RightPosition,$Column6DownPosition) 
$MainListBox.Size     = New-Object System.Drawing.Size($Column6MainListBoxWidth,$Column6MainListBoxHeight)
$MainListBox.Font     = New-Object System.Drawing.Font("Courier New",8,[System.Drawing.FontStyle]::Regular)

$PoShACMEAboutFile     = "$ResourcesDirectory\About\PoSh-ACME.txt"
$PoShACMEAboutContents = Get-Content $PoShACMEAboutFile -ErrorAction SilentlyContinue
if (Test-Path $PoShACMEAboutFile) {
    foreach ($line in $PoShACMEAboutContents) {$MainListBox.Items.Add($line)}
}
else {
    $MainListBox.Items.Add("      ____            _____   __              ___     _____   __   ___  _____ ") | Out-Null
    $MainListBox.Items.Add("     / __ \          / ___/  / /             /   |   / ___/  /  | /  / / ___/ ") | Out-Null
    $MainListBox.Items.Add("    / / / / _____   / /_    / /_            / /| |  / /     / /||/  / / /_    ") | Out-Null
    $MainListBox.Items.Add("   / /_/ / / ___ \  \__ \  / __ \  ______  / /_| | / /     / / |_/ / / __/    ") | Out-Null
    $MainListBox.Items.Add("  / ____/ / /__/ / ___/ / / / / / /_____/ / ____ |/ /___  / /   / / / /___    ") | Out-Null
    $MainListBox.Items.Add(" /_/      \_____/ /____/ /_/ /_/         /_/   |_|\____/ /_/   /_/ /_____/    ") | Out-Null
    $MainListBox.Items.Add("==============================================================================") | Out-Null
    $MainListBox.Items.Add(" PowerShell-Analyst's Collection Made Easy (ACME) for Security Professionals. ") | Out-Null
    $MainListBox.Items.Add(" ACME: The point at which something is the Best, Perfect, or Most Successful! ") | Out-Null
    $MainListBox.Items.Add("==============================================================================") | Out-Null
    $MainListBox.Items.Add("") | Out-Null
    $MainListBox.Items.Add(" Author         : high101bro                                                  ") | Out-Null
    $MainListBox.Items.Add(" Website        : https://github.com/high101bro/PoSH-ACME                     ") | Out-Null
}
$PoShACME.Controls.Add($MainListBox)

#============================================================================================================================================================
# Convert CSV Number Strings To Intergers
#============================================================================================================================================================
function ConvertCSVNumberStringsToIntergers {
    param ($InputDataSource)
    $InputDataSource | ForEach-Object {
        if ($_.CreationDate)    { $_.CreationDate    = [datatime]$_.CreationDate}
        if ($_.Handle)          { $_.Handle          = [int]$_.Handle}
        if ($_.HandleCount)     { $_.HandleCount     = [int]$_.HandleCount}
        if ($_.ParentProcessID) { $_.ParentProcessID = [int]$_.ParentProcessID}
        if ($_.ProcessID)       { $_.ProcessID       = [int]$_.ProcessID}
        if ($_.ThreadCount)     { $_.ThreadCount     = [int]$_.ThreadCount}
        if ($_.WorkingSetSize)  { $_.WorkingSetSize  = [int]$_.WorkingSetSize}
    }
}

#============================================================================================================================================================
# Compile CSV Files
#============================================================================================================================================================
function Compile-CsvFiles([string]$LocationOfCSVsToCompile, [string]$LocationToSaveCompiledCSV) {
    # This function compiles the .csv files in the collection directory which outputs in the parent directory
    # The first line (collumn headers) is only copied once from the first file compiled, then skipped for the rest  
    Remove-Item "$LocationToSaveCompiledCSV" -Force

    $getFirstLine = $true
    Get-ChildItem "$LocationOfCSVsToCompile\*.csv" | foreach {
        if ((Get-Content $PSItem).Length -eq 0){
            Remove-Item $PSItem
        }
        else {
            $filePath = $_
            $Lines = $Lines = Get-Content $filePath  
            $LinesToWrite = switch($getFirstLine) {
                $true  {$Lines}
                $false {$Lines | Select -Skip 1}
            }
            $getFirstLine = $false
            Add-Content -Path "$LocationToSaveCompiledCSV" $LinesToWrite -Force
        }
    }  
}

#============================================================================================================================================================
# Removes Duplicate CSV Headers
#============================================================================================================================================================
function Remove-DuplicateCsvHeaders {
    $count = 1
    $output = @()
    $Contents = Get-Content "$CollectedDataTimeStampDirectory\$CollectionName.csv" 
    $Header = $Contents | Select-Object -First 1
    foreach ($line in $Contents) {
        if ($line -match $Header -and $count -eq 1) {
            $output = $line + "`r`n"
            $count ++
        }
        elseif ($line -notmatch $Header) {
            $output += $line + "`r`n"
        }
    }
    Remove-Item -Path "$CollectedDataTimeStampDirectory\$CollectionName.csv"
    $output | Out-File -FilePath "$CollectedDataTimeStampDirectory\$CollectionName.csv"
}



#============================================================================================================================================================
# Monitor Jobs of Individual Queries
#============================================================================================================================================================
function Monitor-Jobs {
    param($CollectionName)
    $ProgressBar1.Value   = 0
    $JobsLaunch = Get-Date
        do {
        Clear-Host

        $myjobs = Get-Job
        #$myjobs | Out-File $env:TEMP\scrapjobs.txt
        #Get-Content $env:TEMP\scrapjobs.txt
        $jobscount = $myjobs.count                  
        $ProgressBar1.Maximum = $jobscount

        $done = 0
        foreach ($job in $myjobs) {
            $mystate = $job.state
            if ($mystate -eq "Completed") {$done = $done +1}
        }
        $ProgressBar1.Value = $done + 1

        $currentTime = Get-Date
        $Timecount = $JobsLaunch - $currentTime
        $Timecount = [math]::Round(($Timecount.TotalMinutes),2)

        $MainListBox.Items.Insert(0,"Jobs Running:  $($jobscount - $done)")        
        $MainListBox.Items.Insert(1,"Current time:  $currentTime")
        $MainListBox.Items.Insert(2,"Elasped time:  $Timecount minutes")
        $MainListBox.Items.Insert(3,"")

        Start-Sleep -Seconds 1
        #$MainListBox.Items.RemoveAt(0)
        #$MainListBox.Items.RemoveAt(0)
        $MainListBox.Items.RemoveAt(0)
        $MainListBox.Items.RemoveAt(0)
        $MainListBox.Items.RemoveAt(0)
        $MainListBox.Items.RemoveAt(0)
    } while ( $done -lt $jobscount)
    
    Get-Job -Name "ACME-$CollectionName-*" | Remove-Job -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    $ProgressBar1.Value   = 0
}

#============================================================================================================================================================
# CheckBox Script Handler
#============================================================================================================================================================
$ExecuteScriptHandler= {
    $ComputerList = @()

    $StatusListBox.Items.Clear()
    $StatusListBox.Items.Add("Sorting though checkboxes selected...")

    [System.Windows.Forms.TreeNodeCollection]$AllHostsNode = $ComputerListTreeView.Nodes 
    # If the root computerlist checkbox is checked, all hosts will be queried
    if ($script:TreeNode.Checked) {
        foreach ($root in $AllHostsNode) { 
            foreach ($Category in $root.Nodes) { 
                foreach ($Entry in $Category.nodes) { 
                    $ComputerList += $Entry.text 
                }       
            } 
        }
    }

    foreach ($root in $AllHostsNode) {         
        # This loop will select all hosts in a Category    
        foreach ($Category in $root.Nodes) {
            if ($Category.Checked) {
                foreach ($Entry in $Category.Nodes) {
                    $ComputerList += $Entry.text
                }
            }
        }
        # This loop will check for entries that are checked
        foreach ($Category in $root.Nodes) { 
            foreach ($Entry in $Category.nodes) { 
                if ($Entry.Checked) { $ComputerList += $Entry.text }
            }
        }
    }
    # This will dedup selected checkboxes that happend from selecting categores and individual entries
    $ComputerList = $ComputerList | Sort-Object -Unique
    $MainListBox.Items.Clear()
    $MainListBox.Items.Add("Computers to be queried:  $($ComputerList.Count)")
    $MainListBox.Items.Add($ComputerList)

    # Assigns the path to save the Collections to
    $CollectedDataTimeStampDirectory = $CollectionSavedDirectoryTextBox.Text
    $IndividualHostResults           = "$CollectedDataTimeStampDirectory\Individual Host Results"

    New-Item -Type Directory -Path $CollectionSavedDirectoryTextBox.Text

    #if ($SingleHostIPCheckBox.Checked -eq $false) {
    #    # If $SingleHostIPCheckBox.Checked is true, then query a single computer, othewise query the selected computers in the computerlistbox
    #    . SelectListBoxEntry
    #}
    # Checks if any commands were selected
    if ($CommandsSelectionCheckedlistbox.CheckedItems.Count -eq 0) {
        $MainListBox.Items.Clear()
        $MainListBox.Items.Insert(0,"Error: No Queries Were Selected")
        #$PoShACME.Close()
    }
    else {
        # Checks if any computers were selected
        if (($ComputerList.Count -eq 0) -and ($SingleHostIPCheckBox.Checked -eq $false)) {
            $MainListBox.Items.Clear()
            $MainListBox.Items.Insert(0,"Error: No Computers Were Selected")
        }
        # Runs commands if it passes the above checks
        else {
            # This brings specific tabs to the front view
            $Section1TabControl.SelectedTab   = $Section1OpNotesTab
            $Section2TabControl.SelectedTab   = $Section2ActionTab

            $MainListBox.Items.Clear();
            $CollectionTimerStart = Get-Date
            $MainListBox.Items.Insert(0,"$(($CollectionTimerStart).ToString('yyyy/MM/dd HH:mm:ss'))  Collection Start Time")    
            $MainListBox.Items.Insert(0,"")
 
            # Sets / Resets count to zero
            $CountCommandQueries = 0

            # Counts Target Computers
            $CountTargetComputer = $ComputerList.Count

            # Runs the Commands
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'Accounts - Local') {AccountsLocalCommand ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'ARP Cache') {ARPCacheCommand ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'Startup Commands') {StartupCommandsCommand ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'BIOS Info') {BIOSInfoCommand ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'Computer Info') {ComputerInfoCommand ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'Dates - Install, Bootup, System') {DatesCommand ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'Disk - Logical Info') {DiskLogicalInfoCommand; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'Disk - Physical Info') {DiskPhysicalInfoCommand ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'DLLs Loaded by Processes') {DLLsLoadedByProcessesCommand ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'DNS Cache') {DNSCacheCommand ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'Drivers - Detailed') {DriversDetailedCommand ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'Drivers - Signed Info') {DriversSignedCommand ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'Drivers - Valid Signatures') {DriversValidSignaturesCommand ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'Environmental Variables') {EnvironmentalVariablesCommand ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'Firewall Rules') {FirewallRulesCommand ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'Firewall Status') {FirewallStatusCommand ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'Groups - Local') {GroupLocalCommand ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'Logon Info') {LogonInfoCommand ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'Logon Sessions') {LogonSessionsCommand ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'Logon User Status') {LogonUserStatusCommand ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'Mapped Drives') {MappedDrivesCommand ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'Memory - Capacity Info') {MemoryCapacityInfoCommand ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'Memory - Physical Info') {MemoryPhysicalInfoCommand ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'Memory - Performance Data') {MemoryPerformanceDataCommand ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'Memory - Utilization') {MemoryUtilizationCommand ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'Motherboard Info') {MotherboardInfoCommand ; $CountCommandQueries += 1}                                                                                      
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'Network Connections TCP') {NetworkConnectionsTCPCommand ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'Network Connections UDP') {NetworkConnectionsUDPCommand ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'Network Settings') {NetworkSettingsCommand ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'Network Statistics IPv4 All') {NetworkStatisticsIPv4Command ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'Network Statistics IPv4 TCP') {NetworkStatisticsIPv4TCPCommand ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'Network Statistics IPv4 UDP') {NetworkStatisticsIPv4UDPCommand ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'Network Statistics IPv4 ICMP') {NetworkStatisticsIPv4ICMPCommand ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'Network Statistics IPv6 All') {NetworkStatisticsIPv6Command ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'Network Statistics IPv6 TCP') {NetworkStatisticsIPv6TCPCommand ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'Network Statistics IPv6 UDP') {NetworkStatisticsIPv6UDPCommand ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'Network Statistics IPv6 ICMP') {NetworkStatisticsIPv6ICMPCommand ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'Plug and Play Devices') {PlugAndPlayCommand ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'Port Proxy Rules') {PortProxyRulesCommand ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'Prefetch Files') {PrefetchFilesCommand ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'Process Tree - Lineage') {ProcessTreeLineageCommand ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'Processes - Enhanced with Hashes') {ProcessesEnhancedCommand ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'Processes - Standard') {ProcessesStandardCommand ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'Processor - CPU Info') {ProcessorCPUInfoCommand ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'Remote Capability Check') {RemoteCapabilityCheckCommand ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'Scheduled Tasks - schtasks') {ScheduledTasksCommand ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'Screen Saver Info') {ScreenSaverInfoCommand ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'Security Patches') {SecurityPatchesCommand ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'Services') {ServicesCommand ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'Shares') {SharesCommand ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'Software Installed') {SoftwareInstalledCommand ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'System Info') {SystemInfoCommand ; $CountCommandQueries += 1}
            if ($CommandsSelectionCheckedlistbox.CheckedItems -match 'USB Controller Devices') {USBControllerDevicesCommand ; $CountCommandQueries += 1}        
        
            if ($FileSearchDirectoryListingCheckbox.Checked) {FileSearchDirectoryListingCommand ; $CountCommandQueries += 1}
            if ($FileSearchFileSearchCheckbox.Checked){FileSearchFileSearchCommand ; $CountCommandQueries += 1}

            if ($RekallWinPmemMemoryCaptureCheckbox.Checked){RekallWinPmemMemoryCaptureCommand ; $CountCommandQueries += 1}
            if ($SysinternalsAutorunsCheckbox.Checked){SysinternalsAutorunsCommand ; $CountCommandQueries += 1}
            if ($SysinternalsProcessMonitorCheckbox.Checked){SysinternalsProcessMonitorCommand ; $CountCommandQueries += 1}
        
            if ($EventLogsEventIDsManualEntryCheckbox.Checked) {EventLogsEventCodeManualEntryCommand ; $CountCommandQueries += 1}
            if ($EventLogsEventIDsIndividualSelectionCheckbox.Checked) {EventLogsEventCodeIndividualSelectionCommand ; $CountCommandQueries += 1}
            if ($EventLogsQuickPickSelectionCheckbox.Checked) {
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'Application Event Logs') {ApplicationEventLogsCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'Application Event Logs Errors') {ApplicationEventLogsErrorsCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'Security Event Logs') {SecurityEventLogsCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'System Event Logs') {SystemEventLogsCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'System Event Logs Errors') {SystemEventLogsErrorsCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'Account Lockout') {AccountLockoutCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'Account Management') {AccountManagementCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'Account Management Events - Other') {AccountManagementEventsOtherCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'Application Generated') {ApplicationGeneratedCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'Application Group Management') {ApplicationGroupManagementCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'Authentication Policy Change') {AuthenticationPolicyChangeCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'Authorization Policy Change') {AuthorizationPolicyChangeCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'Audit Policy Change') {AuditPolicyChangeCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'Central Access Policy Staging') {CentralAccessPolicyStagingCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'Certification Services') {CertificationServicesCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'Computer Account Management') {ComputerAccountManagementCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'Detailed Directory Service Replication') {DetailedDirectoryServiceReplicationCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'Detailed File Share') {DetailedFileShareCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'Directory Service Access') {DirectoryServiceAccessCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'Directory Service Changes') {DirectoryServiceChangesCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'Directory Service Replication') {DirectoryServiceReplicationCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'Distribution Group Management') {DistributionGroupManagementCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'DPAPI Activity') {DPAPIActivityCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'Group Membership') {GroupMembershipCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'File Share') {FileShareCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'File System') {FileSystemCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'Filtering Platform Connection') {FilteringPlatformConnectionCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'Filtering Platform Packet Drop') {FilteringPlatformPacketDropCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'Filtering Platform Policy Change') {FilteringPlatformPolicyChangeCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'Handle Manipulation') {HandleManipulationCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'IPSec Driver') {IPSecDriverCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'IPSec Extended Mode') {IPSecExtendedModeCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'IPSec Main Mode') {IPSecMainModeCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'IPSec Quick Mode') {IPSecQuickModeCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'Kerberos Authentication Service') {KerberosAuthenticationServiceCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'Kerberos Service Ticket Operations') {KerberosServiceTicketOperationsCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'Kernel Object') {KernelObjectCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'Logon and Logoff Events') {LogonLogoffEventsCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'Logon and Logoff Events - Other') {LogonLogoffEventsOtherCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'MPSSVC Rule Level Policy Change') {MPSSVCRuleLevelPolicyChangeCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'Network Policy Server') {NetworkPolicyServerCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'Other Events') {OtherEventsCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'Other Object Access Events') {OtherObjectAccessEventsCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'Other Policy Change Events') {OtherPolicyChangeEventsCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'Other System Events') {OtherSystemEventsCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'PNP Activity') {PNPActivityCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'Process Creation and Termination') {ProcessCreationTerminationCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'Registry') {RegistryCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'Removeable Storage') {RemoveableStorageCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'RPC Events') {RPCEventsCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'SAM') {SAMCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'Security Group Management') {SecurityGroupManagementCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'Security State Change') {SecurityStateChangeCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'Security System Extension') {SecuritySystemExtensionCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'Sensitive and NonSensitive Privilege Use') {SensitiveandNonSensitivePrivilegeUseCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'Special Logon') {SpecialLogonCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'System Integrity') {SystemIntegrityCommand ; $CountCommandQueries += 1}
                if ($EventLogsQuickPickSelectionCheckedlistbox.CheckedItems -match 'User and Device Claims') {UserDeviceClaimsCommand ; $CountCommandQueries += 1}
             }

            if ($ActiveDirectorySelectionCheckedlistbox.CheckedItems -match 'Active Directory - Accounts') {ActiveDirectoryAccountsCommand ; $CountCommandQueries += 1}
            if ($ActiveDirectorySelectionCheckedlistbox.CheckedItems -match 'Active Directory - Account Details and User Information') {ActiveDirectoryAccountDetailsAndUserInfoCommand ; $CountCommandQueries += 1}
            if ($ActiveDirectorySelectionCheckedlistbox.CheckedItems -match 'Active Directory - Account Logon and Passowrd Policy') {ActiveDirectoryAccountLogonAndPassowrdPolicyCommand ; $CountCommandQueries += 1}
            if ($ActiveDirectorySelectionCheckedlistbox.CheckedItems -match 'Active Directory - Account Contact Information') {ActiveDirectoryAccountContactInfoCommand ; $CountCommandQueries += 1}
            if ($ActiveDirectorySelectionCheckedlistbox.CheckedItems -match 'Active Directory - Account Email Addresses') {ActiveDirectoryAccountEmailAddressesCommand ; $CountCommandQueries += 1}
            if ($ActiveDirectorySelectionCheckedlistbox.CheckedItems -match 'Active Directory - Account Phone Numbers') {ActiveDirectoryAccountPhoneNumbersCommand ; $CountCommandQueries += 1}
            if ($ActiveDirectorySelectionCheckedlistbox.CheckedItems -match 'Active Directory - Computers') {ActiveDirectoryComputersCommand ; $CountCommandQueries += 1}
            if ($ActiveDirectorySelectionCheckedlistbox.CheckedItems -match 'Active Directory - Default Domain Password Policy') {ActiveDirectoryDefaultDomainPasswordPolicyCommand ; $CountCommandQueries += 1}
            if ($ActiveDirectorySelectionCheckedlistbox.CheckedItems -match 'Active Directory - Groups') {ActiveDirectoryGroupsCommand ; $CountCommandQueries += 1}
            if ($ActiveDirectorySelectionCheckedlistbox.CheckedItems -match 'Active Directory - Group Membership By Groups') {ActiveDirectoryGroupMembershipByGroupsCommand ; $CountCommandQueries += 1}
            if ($ActiveDirectorySelectionCheckedlistbox.CheckedItems -match 'Active Directory - Group Membership by Users') {ActiveDirectoryGroupMembershipByUsersCommand ; $CountCommandQueries += 1}
            if ($ActiveDirectorySelectionCheckedlistbox.CheckedItems -match 'Active Directory - Groups Without Account Members') {ActiveDirectoryGroupsWithoutAccountMembersCommand ; $CountCommandQueries += 1}
            if ($ActiveDirectorySelectionCheckedlistbox.CheckedItems -match 'DNS All Records (Server 2008)') {DNSAllRecordsServer2008Command ; $CountCommandQueries += 1}
            if ($ActiveDirectorySelectionCheckedlistbox.CheckedItems -match 'DNS Root Hints (Server 2008)') {DomainDNSRootHintsServer2008Command ; $CountCommandQueries += 1}
            if ($ActiveDirectorySelectionCheckedlistbox.CheckedItems -match 'DNS Zones (Server 2008)') {DomainDNSZonesServer2008Command ; $CountCommandQueries += 1}
            if ($ActiveDirectorySelectionCheckedlistbox.CheckedItems -match 'DNS Statistics (Server 2008)') {DomainDNSStatisticsServer2008Command ; $CountCommandQueries += 1}

            $CollectionTimerStop = Get-Date
            $MainListBox.Items.Insert(0,"$(($CollectionTimerStop).ToString('yyyy/MM/dd HH:mm:ss'))  Finished Collecting Data!")

            $CollectionTime = New-TimeSpan -Start $CollectionTimerStart -End $CollectionTimerStop
            $MainListBox.Items.Insert(1,"   $CollectionTime  Total Elapsed Time")
            $MainListBox.Items.Insert(2,"====================================================================================================")
            $MainListBox.Items.Insert(3,"")        
       
            #-----------------------------
            # Plays a Sound When Finished
            #-----------------------------
            [system.media.systemsounds]::Exclamation.play()

            #----------------------
            # Text To Speach (TTS)
            #----------------------
            if ($TextToSpeachCheckBox.Checked -eq $true) {
                Add-Type -AssemblyName System.speech
                $speak = New-Object System.Speech.Synthesis.SpeechSynthesizer
                Start-Sleep -Seconds 1

                # TTS for Query Count
                if ($CountCommandQueries -eq 1) {$TTSQuerySingularPlural = "query"}
                else {$TTSQuerySingularPlural = "queries"}

                # TTS for TargetComputer Count
                if ($ComputerList.Count -eq 1) {$TTSTargetComputerSingularPlural = "host"}
                else {$TTSTargetComputerSingularPlural = "hosts"}
        
                # Say Message
                if (($CountCommandQueries -eq 0) -and ($CountTargetComputer -eq 0)) {$speak.Speak("You need to select at least one query and target host.")}
                else {
                    if ($CountCommandQueries -eq 0) {$speak.Speak("You need to select at least one query.")}
                    if ($CountTargetComputer -eq 0) {$speak.Speak("You need to select at least one target host.")}
                    else {$speak.Speak("PoSh-ACME has completed $CountCommandQueries $TTSQuerySingularPlural against $CountTargetComputer $TTSTargetComputerSingularPlural.")}
                }        
            }
        }
    }
}
# This needs to be here to execute the script
# Note the Execution button itself is located in the Select Computer section
$ComputerListExecuteButton1.add_Click($ExecuteScriptHandler)
$ComputerListExecuteButton2.add_Click($ExecuteScriptHandler)


#Save the initial state of the form
$InitialFormWindowState = $PoShACME.WindowState

#Init the OnLoad event to correct the initial state of the form
$PoShACME.add_Load($OnLoadForm_StateCorrection)

#Show the Form
$PoShACME.ShowDialog()| Out-Null

} #End Function

# Call the PoSh-ACME Function
PoSh-ACME_GUI



