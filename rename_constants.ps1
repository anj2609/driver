$files = Get-ChildItem -Path "c:\Users\HP\Desktop\27 may\myridedriverappletest\lib" -Recurse -Filter "*.dart"
foreach ($f in $files) {
    $content = Get-Content -Path $f.FullName -Raw
    $changed = $false
    if ($content -match "ApiConstants\.UserLogin") {
        $content = $content -replace "ApiConstants\.UserLogin", "ApiConstants.userLogin"
        $changed = $true
    }
    if ($content -match "ApiConstants\.UserRegister") {
        $content = $content -replace "ApiConstants\.UserRegister", "ApiConstants.userRegister"
        $changed = $true
    }
    if ($changed) {
        Set-Content -Path $f.FullName -Value $content -NoNewline
        Write-Host ("Updated: " + $f.FullName)
    }
}
Write-Host "Done"
