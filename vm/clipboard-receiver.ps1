# Clipboard-Sync: Empfänger (Linux -> Windows)
# Lauscht auf TCP 5556, schreibt empfangenen Text ins Windows-Clipboard.
# Start als STA-Prozess: powershell.exe -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File clipboard-receiver.ps1

Add-Type -AssemblyName System.Windows.Forms

$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, 5556)
$listener.Start()
$guardFile = Join-Path $env:TEMP "clip-guard.txt"

while ($true) {
  try {
    $client = $listener.AcceptTcpClient()
    $reader = [System.IO.StreamReader]::new($client.GetStream(), [System.Text.Encoding]::UTF8)
    $data = $reader.ReadToEnd()
    $client.Close()
    if ($data.Length -gt 0) {
      # Guard VOR SetText setzen, damit der Sender den Echo unterdrückt
      Set-Content -Path $guardFile -Value $data -NoNewline -Encoding UTF8
      [System.Windows.Forms.Clipboard]::SetText($data)
    }
  } catch {
    Start-Sleep -Milliseconds 200
  }
}
