; Inno Setup script. Build: iscc windows_installer.iss /DAppVersion=1.0.0
#ifndef AppVersion
#define AppVersion "1.0.0"
#endif
[Setup]
AppName=OnionDesk
AppVersion={#AppVersion}
DefaultDirName={autopf}\OnionDesk
DefaultGroupName=OnionDesk
OutputDir=dist
OutputBaseFilename=OnionDesk-{#AppVersion}-windows-setup
Compression=lzma2
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion
[Icons]
Name: "{group}\OnionDesk"; Filename: "{app}\oniondesk.exe"
Name: "{autodesktop}\OnionDesk"; Filename: "{app}\oniondesk.exe"
[Run]
Filename: "{app}\oniondesk.exe"; Description: "Launch OnionDesk"; Flags: nowait postinstall skipifsilent
