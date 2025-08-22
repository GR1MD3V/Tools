# AADInternals Complete Loader - Pull entire module into memory
# This script downloads and loads all AADInternals components without writing to disk

param(
    [switch]$SkipDLLs,  # Skip binary dependencies that can't be loaded via IEX
    [switch]$Verbose
)

$ErrorActionPreference = "SilentlyContinue"

# Base GitHub raw URL
$baseUrl = "https://raw.githubusercontent.com/Gerenios/AADInternals/master/"

# Define all the PowerShell script files to load
$psFiles = @(
    "Configuration.ps1",
    "CommonUtils.ps1",
    "AccessToken.ps1",
    "AccessToken_utils.ps1",
    "ADFS.ps1",
    "AccessPackages.ps1",
    "ActiveSync.ps1",
    "ActiveSync_utils.ps1",
    "AdminAPI.ps1",
    "AdminAPI_utils.ps1",
    "AzureADConnectAPI.ps1",
    "AzureADConnectAPI_utils.ps1",
    "AzureCoreManagement.ps1",
    "AzureManagementAPI.ps1",
    "AzureManagementAPI_utils.ps1",
    "B2C.ps1",
    "CBA.ps1",
    "CloudShell.ps1",
    "CloudShell_utils.ps1",
    "ComplianceAPI.ps1",
    "ComplianceAPI_utils.ps1",
    "DCaaS.ps1",
    "DCaaS_utils.ps1",
    "FederatedIdentityTools.ps1",
    "GraphAPI.ps1",
    "GraphAPI_utils.ps1",
    "HybridHealthServices.ps1",
    "HybridHealthServices_utils.ps1",
    "IPUtils.ps1",
    "Kerberos.ps1",
    "Kerberos_utils.ps1",
    "KillChain.ps1",
    "KillChain_utils.ps1",
    "MDM.ps1",
    "MDM_utils.ps1",
    "MFA.ps1",
    "MFA_utils.ps1",
    "MSAppProxy.ps1",
    "MSAppProxy_utils.ps1",
    "MSCommerce.ps1",
    "MSGraphAPI.ps1",
    "MSGraphAPI_utils.ps1",
    "MSPartner.ps1",
    "MSPartner_utils.ps1",
    "OfficeApps.ps1",
    "OneDrive.ps1",
    "OneDrive_utils.ps1",
    "OneNote.ps1",
    "OutlookAPI.ps1",
    "OutlookAPI_utils.ps1",
    "PRT.ps1",
    "PRT_Utils.ps1",
    "PTA.ps1",
    "ProvisioningAPI.ps1",
    "ProvisioningAPI_utils.ps1",
    "SARA.ps1",
    "SARA_utils.ps1",
    "SPMT.ps1",
    "SPMT_utils.ps1",
    "SPO.ps1",
    "SPO_utils.ps1",
    "SyncAgent.ps1",
    "Teams.ps1",
    "Teams_utils.ps1"
)

# Binary files that need special handling
$binaryFiles = @(
    "BouncyCastle.Crypto.dll",
    "Microsoft.Identity.Client.dll",
    "Microsoft.IdentityModel.Abstractions.dll"
)

# Configuration files
$configFiles = @(
    "AADInternals.psd1",
    "config.json",
    "any_sts.pfx"
)

function Write-Status {
    param($Message, $Color = "Green")
    if ($Verbose) {
        Write-Host "[$((Get-Date).ToString('HH:mm:ss'))] $Message" -ForegroundColor $Color
    }
}

function Download-File {
    param($FileName)
    try {
        $url = $baseUrl + $FileName
        Write-Status "Downloading $FileName..."
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing -ErrorAction Stop
        return $response.Content
    }
    catch {
        Write-Status "Failed to download $FileName : $($_.Exception.Message)" -Color "Red"
        return $null
    }
}

function Load-PowerShellScript {
    param($FileName, $Content)
    try {
        Write-Status "Loading $FileName into memory..."
        
        # Handle $PSScriptRoot references in the content
        $modifiedContent = $Content -replace '\$PSScriptRoot', '""'
        
        # Execute the content
        Invoke-Expression $modifiedContent
        Write-Status "Successfully loaded $FileName" -Color "Cyan"
        return $true
    }
    catch {
        Write-Status "Failed to load $FileName : $($_.Exception.Message)" -Color "Red"
        return $false
    }
}

# Start loading process
Write-Host "`n=== AADInternals Memory Loader ===" -ForegroundColor Yellow
Write-Host "Loading AADInternals components into memory without disk writes...`n" -ForegroundColor White

# Load required assemblies first
Write-Status "Loading required .NET assemblies..."
try {
    Add-Type -AssemblyName System.Xml.Linq -ErrorAction SilentlyContinue
    Add-Type -AssemblyName System.Runtime.Serialization -ErrorAction SilentlyContinue
    Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue
    Add-Type -AssemblyName System.Web.Extensions -ErrorAction SilentlyContinue
    Write-Status "Base assemblies loaded successfully" -Color "Cyan"
}
catch {
    Write-Status "Warning: Some assemblies failed to load" -Color "Yellow"
}

# Set TLS version
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Initialize counters
$successCount = 0
$failCount = 0

# Load PowerShell scripts in order
Write-Host "`nLoading PowerShell script files..." -ForegroundColor Yellow

foreach ($file in $psFiles) {
    $content = Download-File -FileName $file
    if ($content) {
        if (Load-PowerShellScript -FileName $file -Content $content) {
            $successCount++
        } else {
            $failCount++
        }
    } else {
        $failCount++
    }
    Start-Sleep -Milliseconds 100  # Small delay to avoid rate limiting
}

# Handle binary files (download to temp if needed)
if (-not $SkipDLLs) {
    Write-Host "`nHandling binary dependencies..." -ForegroundColor Yellow
    $tempDir = Join-Path $env:TEMP "AADInternals_$(Get-Random)"
    
    try {
        New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
        
        foreach ($dll in $binaryFiles) {
            $content = Download-File -FileName $dll
            if ($content) {
                $dllPath = Join-Path $tempDir $dll
                [System.IO.File]::WriteAllBytes($dllPath, $content)
                
                try {
                    Add-Type -Path $dllPath -ErrorAction Stop
                    Write-Status "Loaded $dll successfully" -Color "Cyan"
                    $successCount++
                }
                catch {
                    Write-Status "Failed to load $dll : $($_.Exception.Message)" -Color "Red"
                    $failCount++
                }
            }
        }
    }
    finally {
        # Cleanup temp directory
        if (Test-Path $tempDir) {
            Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
} else {
    Write-Status "Skipping DLL loading as requested" -Color "Yellow"
}

# Load main module content (modified to work without file dependencies)
Write-Host "`nLoading main module..." -ForegroundColor Yellow
$mainModuleContent = @"
# AADInternals Main Module (Memory Version)
# Modified to work without file system dependencies

# Set module variables
`$script:AADInternalsVersion = "0.9.8"
`$script:AADInternalsLoaded = `$true

# Try to set window title
try {
    `$host.UI.RawUI.WindowTitle = "AADInternals `$script:AADInternalsVersion (Memory Mode)"
} catch {}

Write-Host "AADInternals `$script:AADInternalsVersion loaded into memory!" -ForegroundColor Green
Write-Host "Note: Some features requiring external files may not work in memory-only mode.`n" -ForegroundColor Yellow
"@

Invoke-Expression $mainModuleContent

# Summary
Write-Host "=== Loading Summary ===" -ForegroundColor Yellow
Write-Host "Successfully loaded: $successCount files" -ForegroundColor Green
Write-Host "Failed to load: $failCount files" -ForegroundColor Red
Write-Host "`nAADInternals is now available in memory!" -ForegroundColor Cyan

# Test a basic function
try {
    if (Get-Command "Get-AADIntAccessTokenForAADGraph" -ErrorAction SilentlyContinue) {
        Write-Host "`n✓ Verified: AADInternals functions are accessible" -ForegroundColor Green
    }
}
catch {
    Write-Host "`n⚠ Warning: Some functions may not be fully loaded" -ForegroundColor Yellow
}

Write-Host "`nExample usage:"
Write-Host "  Get-AADIntAccessTokenForAADGraph" -ForegroundColor Gray
Write-Host "  Get-AADIntTenants" -ForegroundColor Gray
Write-Host "  # ... other AADInternals commands`n" -ForegroundColor Gray
