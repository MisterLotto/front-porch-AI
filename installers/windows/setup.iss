; Inno Setup Script for Front Porch AI
; Produces a Windows installer with AGPL V3 license acceptance

#define MyAppName "Front Porch AI"
#define MyAppPublisher "linux4life1"
#define MyAppURL "https://github.com/linux4life1/front-porch-AI"
#define MyAppExeName "front_porch_ai.exe"

[Setup]
AppId={{B7E2F8A1-4D3C-4E5B-9F1A-2C8D6E0F3B9A}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}/issues
; Use user-local install directory so no elevation is needed
DefaultDirName={#ifdef PRE_RELEASE}{localappdata}\{#MyAppName} Beta{#else}{localappdata}\{#MyAppName}{#endif}
DefaultGroupName={#MyAppName}
LicenseFile={#MyAppLicenseFile}
OutputBaseFilename={#ifdef PRE_RELEASE}Front_Porch_AI_Beta_Setup{#else}Front_Porch_AI_Setup{#endif}
OutputDir=.
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
SetupIconFile={#MyAppIconFile}
UninstallDisplayIcon={app}\{#MyAppExeName}
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Install per-user — avoids UAC elevation requirement and install failures
; Users can opt-in to a machine-wide install via the dialog
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
CloseApplications=yes
RestartApplications=yes
AppMutex=FrontPorchAI_{{B7E2F8A1-4D3C-4E5B-9F1A-2C8D6E0F3B9A}
; Require Windows 10 or later (Flutter + ANGLE requires it)
MinVersion=10.0

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; Main application files
Source: "{#MyAppBuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; Bundle VC++ 2015-2022 Redistributable alongside the installer
; Downloaded by the CI build step before calling ISCC
Source: "{#MyAppBuildDir}\..\vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[INI]
; Marker file so the app knows it was installed (not from zip)
; Self-update is disabled without this file
Filename: "{app}\.installed"; Section: "install"; Key: "method"; String: "innosetup"

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; Install Visual C++ 2015-2022 Redistributable silently first.
; /install /quiet /norestart — suppresses all UI and reboot prompts.
; The check flag ensures we skip this if it's already installed at the required version.
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; \
  StatusMsg: "Installing Visual C++ Runtime (required)..."; \
  Check: VCRedistNeedsInstall; Flags: waituntilterminated

; Launch the app after install (user can uncheck this)
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; These are only deleted if the user selects the "Wipe User Data" option in the uninstaller UI
Type: filesandordirs; Name: "{userdocs}\FrontPorchAI-Beta"; Check: WipeUserDataRequested

[Code]
var
  WipeDataCheckBox: TCheckBox;

// Returns true if VC++ 2015-2022 x64 Redistributable is NOT already installed.
function VCRedistNeedsInstall: Boolean;
var
  Installed: Cardinal;
begin
  Result := not RegQueryDWordValue(
    HKLM,
    'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\X64',
    'Installed',
    Installed
  ) or (Installed <> 1);
end;

// Create a checkbox on the uninstallation confirmation page
procedure InitializeUninstallProgressForm();
var
  UninstallMsgLabel: TStringLabel;
begin
  if not UninstallSilent then
  begin
    UninstallMsgLabel := UninstallProgressForm.StatusLabel;
    
    WipeDataCheckBox := TCheckBox.Create(UninstallProgressForm);
    WipeDataCheckBox.Parent := UninstallProgressForm;
    WipeDataCheckBox.Caption := 'Wipe all user data (chats, models, and settings)';
    WipeDataCheckBox.Top := UninstallProgressForm.ClientHeight - WipeDataCheckBox.Height - 10;
    WipeDataCheckBox.Left := 10;
    WipeDataCheckBox.Width := UninstallProgressForm.ClientWidth - 20;
    WipeDataCheckBox.Checked := False;
    WipeDataCheckBox.Hint := 'WARNING: This will permanently delete your character library and chat history.';
    WipeDataCheckBox.ShowHint := True;
  end;
end;

// Check function for [UninstallDelete]
function WipeUserDataRequested: Boolean;
begin
  Result := Assigned(WipeDataCheckBox) and WipeDataCheckBox.Checked;
end;
