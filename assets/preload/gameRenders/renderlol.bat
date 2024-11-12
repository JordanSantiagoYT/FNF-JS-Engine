@echo off

echo Hello there!
echo PS: this will only work if you have ffmpeg installed and are using the classic rendering mode.

echo Enter the name of the song you'd like to render! (this is the folder that you'll use)
set /p "renderFolder="

echo.
echo What would you like to name your rendered video?
set /p "renderName="

echo.
echo What is the framerate of your images/video?
set /p "vidFPS="

echo. 
echo Are you rendering your video in a lossless format? (y/n, default n, makes the renderer find pngs instead of jpgs)
set /p "useLossless="
if /i not "%useLossless%"=="y" set "useLossless=n"

if /i "%useLossless%"=="y" (
    set "fExt=png"
) else (
    set "fExt=jpg"
)

echo.
echo Starting...
echo.

ffmpeg -r %vidFPS% -i "%~dp0%renderFolder%\%%07d.%fExt%" "%renderName%.mp4"

pause