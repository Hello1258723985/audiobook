@echo off
rem Double-click this file to create read-along subtitles with SubPlz.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-subplz.ps1" %*
