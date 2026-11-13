
# ============================================================
# COMPLETE PC HARDWARE INVENTORY
# Windows PowerShell 5.1
# CONSOLE DISPLAY ONLY - NO FILE EXPORTS
# ============================================================

$ErrorActionPreference = "SilentlyContinue"

function GB($bytes) {
    if ($null -eq $bytes) { return "N/A" }
    return "{0:N2} GB" -f ($bytes / 1GB)
}

function Section($name) {
    Write-Host ""
    Write-Host ("=" * 75) -ForegroundColor Cyan
    Write-Host "  $name" -ForegroundColor Yellow
    Write-Host ("=" * 75) -ForegroundColor Cyan
}

function Show-Table($data) {
    if ($null -ne $data -and @($data).Count -gt 0) {
        $data | Format-Table -AutoSize -Wrap | Out-Host
    } else {
        Write-Host "  No information available." -ForegroundColor DarkGray
    }
}

# ------------------------------------------------------------
# COLLECT DATA
# ------------------------------------------------------------

$PC = Get-CimInstance Win32_ComputerSystem
$OS = Get-CimInstance Win32_OperatingSystem
$CPU = @(Get-CimInstance Win32_Processor)
$GPU = @(Get-CimInstance Win32_VideoController)
$RAM = @(Get-CimInstance Win32_PhysicalMemory)
$RAMArray = @(Get-CimInstance Win32_PhysicalMemoryArray)
$Board = Get-CimInstance Win32_BaseBoard
$BIOS = Get-CimInstance Win32_BIOS
$Disks = @(Get-CimInstance Win32_DiskDrive)

$PhysicalDisks = @(Get-PhysicalDisk)
$LogicalDisks = @(Get-CimInstance Win32_LogicalDisk)
$Partitions = @(Get-Partition)
$MonitorIDs = @(Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID)

$InstalledRAM = ($RAM | Measure-Object Capacity -Sum).Sum
$MaxRAM = ($RAMArray | Measure-Object MaxCapacity -Sum).Sum
$Slots = ($RAMArray | Measure-Object MemoryDevices -Sum).Sum

# ------------------------------------------------------------
# HEADER
# ------------------------------------------------------------

Clear-Host

Write-Host ""
Write-Host "#######################################################################" -ForegroundColor Cyan
Write-Host "#                                                                     #" -ForegroundColor Cyan
Write-Host "#                  COMPLETE HARDWARE INVENTORY                       #" -ForegroundColor White
Write-Host "#                                                                     #" -ForegroundColor Cyan
Write-Host "#######################################################################" -ForegroundColor Cyan

Write-Host ""
Write-Host " Computer : $env:COMPUTERNAME" -ForegroundColor Green
Write-Host " Date     : $(Get-Date)" -ForegroundColor Green
Write-Host " User     : $env:USERNAME" -ForegroundColor Green

# ------------------------------------------------------------
# SYSTEM
# ------------------------------------------------------------

Section "SYSTEM INFORMATION"

[PSCustomObject]@{
    Manufacturer = $PC.Manufacturer
    Model = $PC.Model
    SystemType = $PC.SystemType
    ComputerName = $PC.Name
    Domain = $PC.Domain
    TotalRAM = GB $PC.TotalPhysicalMemory
} | Format-List | Out-Host

# ------------------------------------------------------------
# OPERATING SYSTEM
# ------------------------------------------------------------

Section "WINDOWS INFORMATION"

[PSCustomObject]@{
    Windows = $OS.Caption
    Version = $OS.Version
    Build = $OS.BuildNumber
    Architecture = $OS.OSArchitecture
    InstallDate = $OS.InstallDate
    LastBoot = $OS.LastBootUpTime
    FreeRAM = GB ($OS.FreePhysicalMemory * 1KB)
    TotalVisibleRAM = GB ($OS.TotalVisibleMemorySize * 1KB)
    PowerShell = $PSVersionTable.PSVersion.ToString()
    WindowsDirectory = $OS.WindowsDirectory
    SystemDirectory = $OS.SystemDirectory
    Locale = $OS.Locale
    TimeZone = (Get-TimeZone).DisplayName
} | Format-List | Out-Host

# ------------------------------------------------------------
# CPU
# ------------------------------------------------------------

Section "PROCESSOR / CPU"

Show-Table ($CPU | Select-Object `
    Name,
    Manufacturer,
    NumberOfCores,
    NumberOfLogicalProcessors,
    MaxClockSpeed,
    CurrentClockSpeed,
    L2CacheSize,
    L3CacheSize,
    SocketDesignation,
    VirtualizationFirmwareEnabled,
    VMMonitorModeExtensions,
    AddressWidth,
    DataWidth,
    @{N="CurrentLoadPercent";E={$_.LoadPercentage}})

# ------------------------------------------------------------
# GPU
# ------------------------------------------------------------

Section "GRAPHICS CARDS / GPU"

Show-Table ($GPU | Select-Object `
    Name,
    AdapterCompatibility,
    VideoProcessor,
    @{N="ReportedVRAM_GB";E={
        if ($_.AdapterRAM -ge 2147483648) {
            "2.00 GB (WMI limit reached - actual VRAM may differ)"
        } else {
            GB $_.AdapterRAM
        }
    }},
    DriverVersion,
    DriverDate,
    CurrentHorizontalResolution,
    CurrentVerticalResolution,
    CurrentRefreshRate,
    CurrentBitsPerPixel,
    Status)

# ------------------------------------------------------------
# RAM SUMMARY
# ------------------------------------------------------------

Section "MEMORY / RAM SUMMARY"

[PSCustomObject]@{
    InstalledRAM = GB $InstalledRAM
    FreeRAM = GB ($OS.FreePhysicalMemory * 1KB)
    UsedRAM = GB ($InstalledRAM - ($OS.FreePhysicalMemory * 1KB))
    DetectedModules = $RAM.Count
    ReportedMemoryDevices = $Slots
    ReportedMaximumRAM = GB ($MaxRAM * 1KB)
} | Format-List | Out-Host

# ------------------------------------------------------------
# RAM MODULES
# ------------------------------------------------------------

Section "INDIVIDUAL RAM MODULES"

Show-Table ($RAM | Select-Object `
    Manufacturer,
    PartNumber,
    DeviceLocator,
    @{N="Capacity";E={GB $_.Capacity}},
    Speed,
    ConfiguredClockSpeed,
    FormFactor,
    DataWidth,
    TotalWidth,
    ConfiguredVoltage,
    BankLabel,
    SerialNumber)

# ------------------------------------------------------------
# MOTHERBOARD
# ------------------------------------------------------------

Section "MOTHERBOARD"

Show-Table ($Board | Select-Object `
    Manufacturer,
    Product,
    Version,
    SerialNumber,
    HostingBoard)

# ------------------------------------------------------------
# BIOS
# ------------------------------------------------------------

Section "BIOS / FIRMWARE"

Show-Table ($BIOS | Select-Object `
    Manufacturer,
    Name,
    SMBIOSBIOSVersion,
    Version,
    ReleaseDate,
    SerialNumber,
    SMBIOSMajorVersion,
    SMBIOSMinorVersion)

# ------------------------------------------------------------
# PHYSICAL DISKS
# ------------------------------------------------------------

Section "PHYSICAL STORAGE DEVICES"

Show-Table ($Disks | Select-Object `
    Model,
    Manufacturer,
    InterfaceType,
    MediaType,
    @{N="Capacity";E={GB $_.Size}},
    FirmwareRevision,
    Partitions,
    SerialNumber,
    Status)

# ------------------------------------------------------------
# PHYSICAL DISK HEALTH
# ------------------------------------------------------------

Section "DISK HEALTH / STORAGE DETAILS"

Show-Table ($PhysicalDisks | Select-Object `
    FriendlyName,
    Manufacturer,
    Model,
    MediaType,
    BusType,
    HealthStatus,
    OperationalStatus,
    FirmwareVersion,
    @{N="Capacity";E={GB $_.Size}},
    SpindleSpeed)

# ------------------------------------------------------------
# LOGICAL DRIVES
# ------------------------------------------------------------

Section "DRIVES / PARTITIONS"

Show-Table ($LogicalDisks | Select-Object `
    DeviceID,
    VolumeName,
    FileSystem,
    @{N="Total";E={GB $_.Size}},
    @{N="Used";E={GB ($_.Size - $_.FreeSpace)}},
    @{N="Free";E={GB $_.FreeSpace}},
    DriveType)

# ------------------------------------------------------------
# PARTITIONS
# ------------------------------------------------------------

Section "PARTITION INFORMATION"

Show-Table ($Partitions | Select-Object `
    DiskNumber,
    PartitionNumber,
    DriveLetter,
    Type,
    @{N="Size";E={GB $_.Size}},
    IsBoot,
    IsSystem)

# ------------------------------------------------------------
# MONITORS
# ------------------------------------------------------------

Section "MONITOR INFORMATION"

Show-Table ($MonitorIDs | ForEach-Object {
    [PSCustomObject]@{
        Manufacturer = (-join ($_.ManufacturerName |
            Where-Object {$_ -ne 0} |
            ForEach-Object {[char]$_}))
        Model = (-join ($_.UserFriendlyName |
            Where-Object {$_ -ne 0} |
            ForEach-Object {[char]$_}))
        SerialNumber = (-join ($_.SerialNumberID |
            Where-Object {$_ -ne 0} |
            ForEach-Object {[char]$_}))
        Active = $_.Active
    }
})

# ------------------------------------------------------------
# NETWORK
# ------------------------------------------------------------

Section "NETWORK ADAPTERS"

Show-Table (Get-CimInstance Win32_NetworkAdapter |
    Where-Object PhysicalAdapter |
    Select-Object `
    Name,
    Manufacturer,
    MACAddress,
    @{N="Speed";E={
        if ($_.Speed -gt 0 -and $_.Speed -lt 100000000000) {
            "{0:N0} Mbps" -f ($_.Speed / 1000000)
        } else {
            "Unknown"
        }
    }},
    NetEnabled,
    PNPDeviceID)

# ------------------------------------------------------------
# IP CONFIGURATION
# ------------------------------------------------------------

Section "NETWORK / IP CONFIGURATION"

Show-Table (Get-NetIPConfiguration |
    Select-Object `
    InterfaceAlias,
    @{N="IPv4";E={$_.IPv4Address.IPAddress -join ", "}},
    @{N="Gateway";E={$_.IPv4DefaultGateway.NextHop -join ", "}},
    @{N="DNS";E={$_.DNSServer.ServerAddresses -join ", "}})

# ------------------------------------------------------------
# AUDIO
# ------------------------------------------------------------

Section "AUDIO DEVICES"

Show-Table (Get-CimInstance Win32_SoundDevice |
    Select-Object Name, Manufacturer, Status)

# ------------------------------------------------------------
# USB
# ------------------------------------------------------------

Section "USB CONTROLLERS"

Show-Table (Get-CimInstance Win32_USBController |
    Select-Object Name, Manufacturer, Status, PNPDeviceID)

# ------------------------------------------------------------
# BATTERY
# ------------------------------------------------------------

Section "BATTERY"

$Battery = @(Get-CimInstance Win32_Battery)

if ($Battery.Count -gt 0) {
    Show-Table ($Battery | Select-Object `
        Name,
        Manufacturer,
        EstimatedChargeRemaining,
        BatteryStatus,
        DesignCapacity,
        FullChargeCapacity)
} else {
    Write-Host "No battery detected (normal for desktop PCs)." -ForegroundColor DarkGray
}

# ------------------------------------------------------------
# PCI DEVICES
# ------------------------------------------------------------

Section "PCI HARDWARE DEVICES"

Show-Table (Get-CimInstance Win32_PnPEntity |
    Where-Object {$_.PNPDeviceID -like "PCI*"} |
    Select-Object Name, Manufacturer, Status)

# ------------------------------------------------------------
# SERVICE SUMMARY
# ------------------------------------------------------------

Section "WINDOWS SERVICES"

$Services = @(Get-Service)

[PSCustomObject]@{
    Running = @($Services | Where-Object Status -eq Running).Count
    Stopped = @($Services | Where-Object Status -eq Stopped).Count
    Total = $Services.Count
} | Format-List | Out-Host

# ------------------------------------------------------------
# FINAL SUMMARY
# ------------------------------------------------------------

Section "HARDWARE SUMMARY"

$DiskCount = $Disks.Count
$DiskTotal = ($Disks | Measure-Object Size -Sum).Sum

Write-Host " COMPUTER : $($PC.Manufacturer) $($PC.Model)" -ForegroundColor Green
Write-Host " CPU      : $($CPU[0].Name)" -ForegroundColor Green
Write-Host " CORES    : $($CPU[0].NumberOfCores)" -ForegroundColor Green
Write-Host " THREADS  : $($CPU[0].NumberOfLogicalProcessors)" -ForegroundColor Green
Write-Host " GPU      : $($GPU[0].Name)" -ForegroundColor Green
Write-Host " RAM      : $(GB $InstalledRAM)" -ForegroundColor Green
Write-Host " RAM SPEED: $($RAM[0].ConfiguredClockSpeed) MHz" -ForegroundColor Green
Write-Host " SSD/HDD  : $DiskCount detected physical disks" -ForegroundColor Green
Write-Host " CAPACITY : $(GB $DiskTotal)" -ForegroundColor Green

Write-Host ""
Write-Host "#######################################################################" -ForegroundColor Cyan
Write-Host "#                 HARDWARE SCAN COMPLETED                             #" -ForegroundColor Green
Write-Host "#######################################################################" -ForegroundColor Cyan
Write-Host ""
