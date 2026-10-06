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
[Files]
Source: "build\windows\{#Arch}\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion
[Icons]
Name: "{group}\OnionDesk"; Filename: "{app}\oniondesk.exe"
Name: "{autodesktop}\OnionDesk"; Filename: "{app}\oniondesk.exe"
[Run]
Filename: "{app}\oniondesk.exe"; Description: "Launch OnionDesk"; Flags: nowait postinstall skipifsilent
