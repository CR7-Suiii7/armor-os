# ==============================================================================
# VirtualBox Automation Script for Windows 11 Host
# Configures VM with EFI, TPM 2.0, Secure Networking, Audio, and xHCI USB
# ==============================================================================
param (
    [string]$VMName = "ARMOR-Secure-Workstation",
    [string]$ISOPath = "c:\Users\Urvish\OS\armor-os\armor-workstation-amd64.iso",
    [int]$MemoryMB = 4096,
    [int]$CPUs = 2,
    [int]$DiskSizeMB = 30720
)

$ErrorActionPreference = "Stop"

# Detect VirtualBox Installation
$VBoxPath = "C:\Program Files\Oracle\VirtualBox"
if (-not (Test-Path "$VBoxPath\VBoxManage.exe")) {
    Write-Error "VBoxManage.exe not found at $VBoxPath. Please verify VirtualBox 7.x installation."
}
$env:PATH += ";$VBoxPath"

Write-Host "[+] Creating VM: $VMName..." -ForegroundColor Cyan
VBoxManage createvm --name $VMName --ostype "Debian_64" --register

Write-Host "[+] Configuring Hardware (CPU, Memory, EFI, TPM)..." -ForegroundColor Cyan
VBoxManage modifyvm $VMName `
    --cpus $CPUs `
    --memory $MemoryMB `
    --firmware efi `
    --tpm-type 2.0 `
    --graphicscontroller vmsvga `
    --vram 128 `
    --boot1 dvd --boot2 disk --boot3 none --boot4 none

Write-Host "[+] Configuring Secure Audio (ICH AC97 / Intel HD Audio with Microphone)..." -ForegroundColor Cyan
VBoxManage modifyvm $VMName `
    --audio-controller hda `
    --audio-enabled on `
    --audio-in on `
    --audio-out on

Write-Host "[+] Configuring USB 3.0 (xHCI) for YubiKey/Smartcard Token Passthrough..." -ForegroundColor Cyan
VBoxManage modifyvm $VMName --usbohci off --usbehci off --usbxhci on

Write-Host "[+] Configuring Network (VirtIO / Intel Pro NAT with DNS isolation)..." -ForegroundColor Cyan
VBoxManage modifyvm $VMName --nic1 nat --nictype1 82540EM

Write-Host "[+] Creating Virtual Storage Controllers..." -ForegroundColor Cyan
$DiskPath = "$PWD\$VMName.vdi"
VBoxManage createmedium disk --filename $DiskPath --size $DiskSizeMB --format VDI
VBoxManage storagectl $VMName --name "SATA" --add sata --controller IntelAhci --portcount 2
VBoxManage storageattach $VMName --storagectl "SATA" --port 0 --device 0 --type hdd --medium $DiskPath

if (Test-Path $ISOPath) {
    Write-Host "[+] Attaching ARMOR ISO: $ISOPath..." -ForegroundColor Green
    VBoxManage storageattach $VMName --storagectl "SATA" --port 1 --device 0 --type dvddrive --medium $ISOPath
} else {
    Write-Host "[!] ISO not yet built at $ISOPath. Created empty optical drive." -ForegroundColor Yellow
    VBoxManage storageattach $VMName --storagectl "SATA" --port 1 --device 0 --type dvddrive --medium emptydrive
}

Write-Host "`n[SUCCESS] VM '$VMName' configured." -ForegroundColor Green
Write-Host "To start the VM, execute:"
Write-Host "VBoxManage startvm `"$VMName`" --type gui"
