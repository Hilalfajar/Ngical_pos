; ============================================================
;  Ngical - Inno Setup Script
;
;  Cara pakai:
;  1. flutter build windows --release
;  2. Letakkan file ini di ROOT project (satu level dengan folder build\)
;  3. Buka dengan Inno Setup → Build → Compile
;  4. Hasil: installer_output\Ngical_Setup_1.0.0.exe
;
;  Catatan:
;  - Flutter default menghasilkan flutter_application_1.exe
;  - Script ini MENYALIN & MERENAME jadi Ngical.exe saat install
;  - Tidak perlu ubah CMakeLists.txt
; ============================================================

#define MyAppName       "Ngical"
#define MyAppVersion    "1.0.0"
#define MyAppPublisher  "Ngical"
#define MyExeName       "Ngical.exe"
#define MyReleaseDir    "build\windows\x64\runner\Release"

[Setup]
AppId={{A8F3C2D1-9E4B-4F6A-B7C8-1D2E3F4A5B6C}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={localappdata}\Programs\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=installer_output
OutputBaseFilename=Ngical_Setup_{#MyAppVersion}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#MyExeName}
SetupIconFile=assets\icon\app_icon.ico

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Buat ikon di Desktop"; GroupDescription: "Ikon tambahan:"; Flags: unchecked

[Files]
; 1) Semua file Release KECUALI exe Flutter default
Source: "{#MyReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "flutter_application_1.exe,ngical.exe,Ngical.exe"

; 2) Salin exe Flutter lalu rename jadi Ngical.exe
;    (dukung nama default Flutter ATAU kalau sudah di-rename manual)
Source: "{#MyReleaseDir}\flutter_application_1.exe"; DestDir: "{app}"; DestName: "Ngical.exe"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#MyReleaseDir}\Ngical.exe"; DestDir: "{app}"; DestName: "Ngical.exe"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#MyReleaseDir}\ngical.exe"; DestDir: "{app}"; DestName: "Ngical.exe"; Flags: ignoreversion skipifsourcedoesntexist

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyExeName}"; Description: "Jalankan {#MyAppName}"; Flags: nowait postinstall skipifsilent
