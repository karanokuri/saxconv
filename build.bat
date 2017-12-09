@pushd %~dp0
@setlocal
@  if not exist build_tools mkdir build_tools
@  pushd build_tools
@    powershell "iex((@('')*3+(cat '%~f0'|?{$_ -notlike '@*'}))-join[char]10)"
@    set PATH=%CD%\mingw32\bin;%CD%\dmd2\windows\bin;%PATH%
@  popd
@  echo Building saxconv ...
@  windres -i src\main.rc -o src\main.res
@  set "FILES=src\main.res"
@  set "FILES=%FILES% src\main.d"
@  set "FILES=%FILES% src\gui.d"
@  set "FILES=%FILES% src\wave.d"
@  set "FILES=%FILES% src\signalprocessing.d"
@  set "FLAGS=-Isrc"
@  set "FLAGS=%FLAGS% -version=DFL_UNICODE -Idfl\import lib\dfl.lib"
@  set "FLAGS=%FLAGS% -O -release -inline"
@  set "FLAGS=%FLAGS% -L/exet:nt/su:windows:4.0"
@  dmd -ofsaxconv %FLAGS% %FILES%
@endlocal
@popd
@exit /b %ERRORLEVEL%

$DebugPreference = "Stop"

$7zUrl  = "https://sevenzip.osdn.jp/howto/9.20/"
$DMDUrl = "http://downloads.dlang.org/releases/2.x/2.063/dmd.2.063.2.zip"
$UtlUrl = "https://sourceforge.net/projects/mingw-w64/files/Toolchains%20targetting%20Win32/Personal%20Builds/mingw-builds/5.1.0/threads-posix/dwarf/i686-5.1.0-release-posix-dwarf-rt_v4-rev0.7z/download"

if(!(Test-Path "7z.exe"))
{
  Write-Host "downloading ${7zUrl}7z.exe ..."
  (New-Object Net.WebClient).DownloadFile("${7zUrl}7z.exe", "7z.exe")
}
if(!(Test-Path "7z.dll"))
{
  Write-Host "downloading ${7zUrl}7z.dll ..."
  (New-Object Net.WebClient).DownloadFile("${7zUrl}7z.dll", "7z.dll")
}

if(!(Test-Path "dmd2"))
{
  if(!(Test-Path "dmd.zip"))
  {
    Write-Host "downloading $DMDUrl ..."
    (New-Object Net.WebClient).DownloadFile($DMDUrl, "dmd.zip")
  }

  Write-Host "Extracting dmd.zip ..."
  & .\7z x -y dmd.zip | Out-Null
}

if(!(Test-Path "mingw32"))
{
  if(!(Test-Path "mingw32.7z"))
  {
    Write-Host "downloading $UtlUrl ..."
    (New-Object Net.WebClient).DownloadFile($UtlUrl, "mingw32.7z")
  }

  Write-Host "Extracting mingw32.7z ..."
  & .\7z x -y mingw32.7z | Out-Null
}

# vim:set ft=ps1:
