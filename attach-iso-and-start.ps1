param (
    [string]$VMName = "ARMOR-Workstation",
    [string]$ISOPath = "c:\Users\Urvish\OS\armor-os\debian-12.8.0-amd64-netinst.iso"
)

$VBoxManage = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"

if (-not (Test-Path $ISOPath)) {
    Write-Host "[!] ISO file not found at $ISOPath. Waiting for download to complete..." -ForegroundColor Yellow
    exit 1
}

Write-Host "[+] Attaching Debian 12 ARMOR Base ISO to $VMName..." -ForegroundColor Cyan
& $VBoxManage storageattach $VMName --storagectl "SATA" --port 1 --device 0 --type dvddrive --medium $ISOPath

Write-Host "[+] Starting VirtualBox VM in GUI mode..." -ForegroundColor Green
& $VBoxManage startvm $VMName --type gui

Write-Host "[SUCCESS] ARMOR VM is now running." -ForegroundColor Green
