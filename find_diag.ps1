$content = [System.IO.File]::ReadAllLines('C:\Users\JIM\my_spots\logs_utf8.txt', [System.Text.Encoding]::UTF8)
$found = @()
foreach ($line in $content) {
  if ($line -match 'MARINE-TILELAYER' -or $line -match 'MARINE-PROVIDER' -or $line -match 'OFFLINE-READ' -or $line -match 'FMTC-ERROR' -or $line -match 'OFFLINE-URL') {
    $found += $line
  }
}
$found | Out-File -FilePath 'C:\Users\JIM\my_spots\diag_results.txt' -Encoding UTF8
Write-Host \"Found $($found.Count) lines\"
foreach ($f in $found) { Write-Host $f }