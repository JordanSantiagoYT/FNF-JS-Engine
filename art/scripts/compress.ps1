param(
    [string]$Root = (Get-Location).Path,
    [int]$Mp3Bitrate = 128,
    [int]$OggBitrate = 96
)

$ErrorActionPreference = "Stop"

$Root = (Resolve-Path $Root).Path

if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: ffmpeg was not found in PATH." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Audio Compressor" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Root: $Root"
Write-Host ""

# Recursively find every MP3 and OGG
$files = Get-ChildItem -Path $Root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Extension -eq ".mp3" -or $_.Extension -eq ".ogg"
    }

if ($null -eq $files -or $files.Count -eq 0) {
    Write-Host "No MP3 or OGG files found." -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($files.Count) audio files." -ForegroundColor Green
Write-Host ""

$totalOriginal = 0
$totalFinal = 0
$processed = 0
$replaced = 0
$skipped = 0
$failed = 0

$tempDir = Join-Path $env:TEMP "audio-compress-$([Guid]::NewGuid())"

New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

foreach ($file in $files) {

    $processed++

    $relative = $file.FullName.Substring($Root.Length).TrimStart('\')

    Write-Host "[$processed/$($files.Count)] $relative" -ForegroundColor Cyan

    $originalSize = [int64]$file.Length
    $totalOriginal += $originalSize

    $tempFile = Join-Path $tempDir "$([Guid]::NewGuid())$($file.Extension)"

    try {

        if ($file.Extension -eq ".mp3") {

            Write-Host "  MP3 -> MP3 ($Mp3Bitrate kbps)" -ForegroundColor DarkGray

            & ffmpeg -hide_banner -loglevel error -y `
                -i "$($file.FullName)" `
                -map 0:a:0 `
                -vn `
                -c:a libmp3lame `
                -b:a "${Mp3Bitrate}k" `
                -ar 44100 `
                -ac 2 `
                "$tempFile"
        }
        else {

            Write-Host "  OGG Vorbis -> OGG Vorbis ($OggBitrate kbps)" -ForegroundColor DarkGray

            & ffmpeg -hide_banner -loglevel error -y `
                -i "$($file.FullName)" `
                -map 0:a:0 `
                -vn `
                -c:a libvorbis `
                -b:a "${OggBitrate}k" `
                -ar 44100 `
                -ac 2 `
                "$tempFile"
        }

        if ($LASTEXITCODE -ne 0) {
            throw "FFmpeg returned exit code $LASTEXITCODE"
        }

        if (-not (Test-Path $tempFile)) {
            throw "FFmpeg did not create an output file."
        }

        $compressedSize = [int64](Get-Item $tempFile).Length

        if ($compressedSize -lt $originalSize) {

            $oldCreation = $file.CreationTime
            $oldWrite = $file.LastWriteTime
            $oldAccess = $file.LastAccessTime

            Move-Item -Force $tempFile $file.FullName

            $file.CreationTime = $oldCreation
            $file.LastWriteTime = $oldWrite
            $file.LastAccessTime = $oldAccess

            $totalFinal += $compressedSize
            $replaced++

            $saved = $originalSize - $compressedSize
            $percent = ($saved / $originalSize) * 100

            $oldMB = $originalSize / 1MB
            $newMB = $compressedSize / 1MB

            Write-Host ("  {0:N2} MB -> {1:N2} MB" -f $oldMB, $newMB) -ForegroundColor Green
            Write-Host ("  Saved {0:N2}%" -f $percent) -ForegroundColor Green
        }
        else {

            Remove-Item -Force $tempFile

            $totalFinal += $originalSize
            $skipped++

            Write-Host "  Skipped: compressed file was not smaller." -ForegroundColor Yellow
        }

    }
    catch {

        if (Test-Path $tempFile) {
            Remove-Item -Force $tempFile
        }

        $totalFinal += $originalSize
        $failed++

        Write-Host "  FAILED: $($_.Exception.Message)" -ForegroundColor Red
    }

    Write-Host ""
}

if (Test-Path $tempDir) {
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

$totalSaved = $totalOriginal - $totalFinal

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Compression complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "Files processed : $processed"
Write-Host "Files replaced  : $replaced"
Write-Host "Files skipped   : $skipped"
Write-Host "Files failed    : $failed"
Write-Host ""

Write-Host ("Original size   : {0:N2} MB" -f ($totalOriginal / 1MB))
Write-Host ("Final size      : {0:N2} MB" -f ($totalFinal / 1MB))
Write-Host ("Space saved     : {0:N2} MB" -f ($totalSaved / 1MB))

if ($totalOriginal -gt 0) {
    $reduction = ($totalSaved / $totalOriginal) * 100
    Write-Host ("Reduction       : {0:N2}%" -f $reduction)
}