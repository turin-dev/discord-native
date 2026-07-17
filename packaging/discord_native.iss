#ifndef SourceDir
  #define SourceDir "..\build\windows\x64\runner\Release"
#endif
#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#ifndef OutputDir
  #define OutputDir "..\dist"
#endif

[Setup]
AppId={{79B15D8B-738A-4E52-9EB5-F1D31F7B1C96}
AppName=Discord Native
AppVersion={#AppVersion}
AppPublisher=Discord Native
DefaultDirName={localappdata}\Programs\Discord Native
DefaultGroupName=Discord Native
DisableProgramGroupPage=yes
OutputDir={#OutputDir}
OutputBaseFilename=discord-native-{#AppVersion}-windows-x64-setup
SetupIconFile=..\windows\runner\resources\app_icon.ico
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\discord_native.exe
CloseApplications=yes
RestartApplications=no

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Discord Native"; Filename: "{app}\discord_native.exe"
Name: "{autodesktop}\Discord Native"; Filename: "{app}\discord_native.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "바탕 화면 바로가기 만들기"; GroupDescription: "추가 바로가기:"

[Run]
Filename: "{app}\discord_native.exe"; Description: "Discord Native 실행"; Flags: nowait postinstall skipifsilent
