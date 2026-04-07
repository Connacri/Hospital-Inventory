#define MyAppName "Hospital Inventory"
#define MyAppExeName "plateau.exe"

[Setup]
AppName={#MyAppName}
AppVersion=1.0
DefaultDirName={pf}\HospitalInventory
DefaultGroupName=HospitalInventory
OutputDir=output
OutputBaseFilename=installer
//walou
[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs
Source: "vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{commondesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"

[Run]
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/quiet /norestart"
Filename: "{app}\{#MyAppExeName}"; Flags: nowait postinstall skipifsilent
