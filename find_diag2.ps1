$file = 'C:\Users\JIM\my_spots\logs_test.txt'
$lines = [System.IO.File]::ReadAllLines($file, [System.Text.Encoding]::UTF8)
$matched = @()
foreach ($line in $lines) {
  $upper = $line.ToUpper()
  if ($upper.Contains('MARINE-TILELAYER') -or $upper.Contains('MARINE-PROVIDER') -or $upper.Contains('OFFLINE-READ') -or $upper.Contains('OFFLINE-URL') -or $upper.Contains('FMTC-ERROR')) {
    $matched += $line
  }
}
Write-Host "Total lines: $($lines.Length)"
Write-Host "Matched lines: $($matched.Length)"
Write-Host ""
foreach ($m in $matched) {
  Write-Host $m
}