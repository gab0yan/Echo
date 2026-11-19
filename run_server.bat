@echo off
rem Starts the Echo room server. Players connect to this PC on UDP port 7777.
rem Forward UDP 7777 on your router to this PC so friends can reach it.
"C:\Users\User\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path "%~dp0." -- --server
pause
