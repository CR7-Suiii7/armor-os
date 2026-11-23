$ErrorActionPreference = "Stop"

$htmlPath = "c:\Users\Urvish\OS\armor-os\ARMOR_OS_Hardening_Report.html"
$docxPath = "c:\Users\Urvish\OS\armor-os\ARMOR_OS_Hardening_Report.docx"

Write-Host "[+] Initializing Microsoft Word COM engine..."
$word = New-Object -ComObject Word.Application
$word.Visible = $false

try {
    Write-Host "[+] Opening HTML template: $htmlPath"
    $doc = $word.Documents.Open($htmlPath)
    
    Write-Host "[+] Exporting native Word document: $docxPath"
    # 16 = wdFormatXMLDocument (.docx format)
    $doc.SaveAs2($docxPath, 16)
    $doc.Close()
    Write-Host "[SUCCESS] Report generated successfully."
}
finally {
    $word.Quit()
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($word) | Out-Null
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
}

Get-Item $docxPath | Select-Object Name, Length, FullName
