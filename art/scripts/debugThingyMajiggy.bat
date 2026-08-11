@echo off
color 0a
cd ...
echo Are you sure you want to Debug by terminal?

echo Press any key if you want to continue. If not, close this.
timeout 10 > nul






echo Opening Debug Terminal...
echo ------------------------------

JSEngine.exe

echo ------------------------------

echo Look like the game closed... Closing in 10 seconds.
timeout 10 > nul
