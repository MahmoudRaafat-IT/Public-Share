@echo off
title Windows Quick Fix
echo ==========================================
echo   🚀 Windows Maintenance & Optimization Toolkit
echo ==========================================
echo.

:: Clean Temp Files
echo Cleaning Temp Files...
del /s /q %temp%\*.* >nul 2>&1
rd /s /q %temp% >nul 2>&1
md %temp%

:: Clean Prefetch
echo Cleaning Prefetch...
del /s /q C:\Windows\Prefetch\*.* >nul 2>&1

:: Disk Cleanup
echo Running Disk Cleanup...
cleanmgr /sagerun:1

:: Flush DNS Cache
echo Flushing DNS Cache...
ipconfig /flushdns

:: Check & Repair Disk
echo Checking Disk (Scheduled for next restart)...
chkdsk C: /f

:: Scan System Files
echo Running System File Checker...
sfc /scannow

:: Repair System Image
echo Repairing Windows Image...
DISM /Online /Cleanup-Image /RestoreHealth

echo.
echo ==========================================
echo ✅ All processes completed successfully.
echo ==========================================
echo.

:: Ask for Restart
choice /M "Do you want to restart your PC now?"
if %errorlevel%==1 shutdown /r /t 5
if %errorlevel%==2 echo Restart skipped. Please restart manually later.

pause
