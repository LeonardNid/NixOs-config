# Clipboard-Sync: Sender (Windows -> Linux)
# Pollt das Windows-Clipboard (500ms) und sendet Änderungen an Host:5557.
# Start als STA-Prozess: powershell.exe -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File clipboard-sender.ps1

Add-Type -AssemblyName System.Windows.Forms

$guardFile = Join-Path $env:TEMP "clip-guard.txt"
$last = ""

while ($true) {
  Start-Sleep -Milliseconds 500
  $text = ""
  try { $text = [System.Windows.Forms.Clipboard]::GetText() } catch {}
  if ($text -eq "" -or $text -eq $last) { continue }

  # Guard: nicht zurückschicken, was wir gerade vom Host empfangen haben
  $guard = ""
  if (Test-Path $guardFile) { $guard = Get-Content $guardFile -Raw }
  if ($text -eq $guard) { $last = $text; continue }

  $last = $text
  try {
    $c = [System.Net.Sockets.TcpClient]::new("192.168.122.1", 5557)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
    $c.GetStream().Write($bytes, 0, $bytes.Length)
    $c.Close()
  } catch {}
}
