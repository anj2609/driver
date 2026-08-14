$content = Get-Content -Path "c:\Users\HP\Desktop\27 may\myridedriverappletest\lib\controllers\auth_controller.dart" -Raw
$content = $content -replace '\bprint\(', 'debugPrint('
Set-Content -Path "c:\Users\HP\Desktop\27 may\myridedriverappletest\lib\controllers\auth_controller.dart" -Value $content -NoNewline
Write-Host "Replaced print with debugPrint in auth_controller.dart"
