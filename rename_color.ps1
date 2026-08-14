$files = Get-ChildItem -Path "c:\Users\HP\Desktop\27 may\myridedriverappletest" -Recurse -Filter "*.dart"
foreach ($f in $files) {
    $content = Get-Content -Path $f.FullName -Raw
    if ($content -match "TextColorForGrey") {
        $content = $content -replace "TextColorForGrey", "textColorForGrey"
        Set-Content -Path $f.FullName -Value $content -NoNewline
        Write-Host ("Updated: " + $f.FullName)
    }
}
Write-Host "Done renaming TextColorForGrey"
