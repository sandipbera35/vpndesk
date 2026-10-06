; Inno Setup script. Build: iscc windows_installer.iss /DAppVersion=1.0.0 /DArch=x64   (Arch = x64 | arm64)
#ifndef AppVersion
#define AppVersion "1.0.0"
#endif
#ifndef Arch
#define Arch "x64"
#endif
[Setup]
AppName=OnionDesk
AppVersion={#AppVersion}
DefaultDirName={autopf}\OnionDesk
DefaultGroupName=OnionDesk
OutputDir=dist
OutputBaseFilename=OnionDesk-{#AppVersion}-windows-{#Arch}-setup
Compression=lzma2
SolidCompression=yes
#if Arch == "arm64"
ArchitecturesAllowed=arm64
ArchitecturesInstallIn64BitMode=arm64
#else
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
#endif
PrivilegesRequired=lowest
UninstallDisplayIcon={app}\oniondesk.exe
UninstallDisplayName=OnionDesk
CloseApplications=yes
RestartApplications=no
[Files]
Source: "build\windows\{#Arch}\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion
[Icons]
Name: "{group}\OnionDesk"; Filename: "{app}\oniondesk.exe"
Name: "{autodesktop}\OnionDesk"; Filename: "{app}\oniondesk.exe"
[Run]
Filename: "{app}\oniondesk.exe"; Description: "Launch OnionDesk"; Flags: nowait postinstall skipifsilent

[Code]
{ Uninstalling from Settings > Apps while connected must not leave the machine without internet:
  stop OUR tor (only the one inside the install folder, never Tor Browser's) and clear our leftover SOCKS proxy. }
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  ResultCode: Integer;
  Proxy: String;
begin
  if CurUninstallStep = usUninstall then
  begin
    Exec('taskkill.exe', '/F /IM oniondesk.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    Exec('powershell.exe',
      '-NoProfile -Command "Get-Process tor -ErrorAction SilentlyContinue | Where-Object { $_.Path -like ''' + ExpandConstant('{app}') + '\tor\*'' } | Stop-Process -Force"',
      '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    if RegQueryStringValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Internet Settings', 'ProxyServer', Proxy) and (Proxy = 'socks=127.0.0.1:9050') then
      RegWriteDWordValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Internet Settings', 'ProxyEnable', 0);
  end;
end;
