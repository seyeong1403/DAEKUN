@echo off
chcp 65001 > nul
title DAEKUN MS - Admin Share
cd /d "%~dp0.."
powershell -NoProfile -File "%~dp0share.ps1" %*
if errorlevel 1 pause
