# This script connects to microbit USB serial port 
# and prints out all the messages received
# without a terminal app like HyperTerminal. 
# This script can be used to debug microbit serial port
# author: https://github.com/tctco
# Department of Nuclear Medicine, Wuhan Union Hospital

Write-Host 'Here are all available COM ports in your device:'

$all_coms = Get-CimInstance -Class Win32_SerialPort
if ($Null -eq $all_coms) {
  Write-Host 'No Serial Port device detected'
  exit 1
}

Write-Host $all_coms.Name

do {
  $auto_detect = Read-Host "Do you wish to auto detect microbit USB serial port? [y/n]"
  If ($auto_detect -eq 'y') {
    if ($all_coms.length -gt 1) {
      $COM = $Null
      for ($i = $all_coms.length - 1; $i -ge 0; $i--) {
        if ($all_coms[$i].Name.Contains('USB')) {
          $COM = $all_coms[$all_coms.length - 1].DeviceID
          break
        }
      }
      if ($Null -eq $COM) {
        Write-Host "No USB Serial port detected"
        exit 1
      }
      
      Write-Host "Multiple COM ports detected, using the last USB port ($($COM)) as default"
    }
    else { 
      if ($all_coms.Name.Contains('USB')) { $COM = $all_coms.DeviceID }
      else {
        Write-Host "No USB Serial port detected"
        exit 1
      }
    }
  }
  ElseIf ($auto_detect -eq 'n') { $COM = Read-Host "Please input COM number (e.g. COM4)" }
} while (-not ('y', 'n' -contains $auto_detect))

$port = new-Object System.IO.Ports.SerialPort $COM, 115200, None, 8, one
$port.Open()

Write-Host "Start listening to $($COM)"

function read-com {
  do {
    $line = $port.ReadExisting()
    if ($line.Length -gt 0) {
      Write-Host $line
    }
  }
  while ($port.IsOpen)
}

try {
  read-com
}
catch {
  Write-Output $_
}
finally {
  $port.Close()
}
