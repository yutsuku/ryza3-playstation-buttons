@echo OFF
:: This batch file exists to run patch.ps1 without hassle
pushd %~dp0
set updater_script="%~dp0\bin\patch.ps1"
powershell -noprofile -nologo -executionpolicy bypass -File %updater_script%
timeout 5
