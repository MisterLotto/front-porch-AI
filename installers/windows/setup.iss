; Inno Setup Script for Front Porch AI
; Produces a Windows installer with AGPL V3 license acceptance

#define MyAppName "Front Porch AI"
#define MyAppPublisher "linux4life1"
#define MyAppURL "https://github.com/linux4life1/front-porch-AI"
#define MyAppExeName "Front Porch AI.exe"

[Setup]
AppId={{B7E2F8A1-4D3C-4E5B-9F1A-2C8D6E0F3B9A}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}/issues
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
LicenseFile={#MyAppLicenseFile}
OutputBaseFilename=Front_Porch_AI_Setup
OutputDir=.
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
SetupIconFile={#MyAppIconFile}
UninstallDisplayIcon={app}\{#MyAppExeName}
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
CloseApplications=yes
RestartApplications=yes
AppMutex=FrontPorchAI_{{B7E2F8A1-4D3C-4E5B-9F1A-2C8D6E0F3B9A}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#MyAppBuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[INI]
; Marker file so the app knows it was installed (not from zip)
; Self-update is disabled without this file
Filename: "{app}\.installed"; Section: "install"; Key: "method"; String: "innosetup"

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
