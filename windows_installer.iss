; Inno Setup script. Build: iscc windows_installer.iss /DAppVersion=1.0.0
#ifndef AppVersion
#define AppVersion "1.0.0"
#endif
[Setup]
AppName=VPN Desk
AppVersion={#AppVersion}
DefaultDirName={autopf}\VPN Desk
DefaultGroupName=VPN Desk
OutputDir=dist
OutputBaseFilename=VPN-Desk-{#AppVersion}-windows-setup
Compression=lzma2
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion
[Icons]
Name: "{group}\VPN Desk"; Filename: "{app}\vpn_desk.exe"
Name: "{autodesktop}\VPN Desk"; Filename: "{app}\vpn_desk.exe"
[Run]
Filename: "{app}\vpn_desk.exe"; Description: "Launch VPN Desk"; Flags: nowait postinstall skipifsilent
