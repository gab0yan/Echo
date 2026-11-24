@echo off
rem Starts the Echo room server. Players connect to this PC on TCP port 7777 (WebSocket).
rem Forward TCP 7777 on your router (or put a wss:// tunnel in front of it) to this PC so friends can reach it.
"C:\Users\User\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path "%~dp0." -- --server
pause
