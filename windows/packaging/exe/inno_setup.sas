; Sonar: картинки установщика лежат в windows/packaging/exe/art, путь к ним строим
; от значка, Inno Setup находит их тем же способом, что и сам значок
#define SonarIcon "{{SETUP_ICON_FILE}}"
#define SonarArt ExtractFilePath(SonarIcon) + "..\..\packaging\exe\art\"

[Setup]
AppId={{APP_ID}}
AppVersion={{APP_VERSION}}
AppName={{DISPLAY_NAME}}
AppPublisher={{PUBLISHER_NAME}}
AppPublisherURL={{PUBLISHER_URL}}
AppSupportURL={{PUBLISHER_URL}}
AppUpdatesURL={{PUBLISHER_URL}}
DefaultDirName={{INSTALL_DIR_NAME}}
DisableProgramGroupPage=yes
OutputDir=.
OutputBaseFilename={{OUTPUT_BASE_FILENAME}}
Compression=lzma
SolidCompression=yes
SetupIconFile={{SETUP_ICON_FILE}}
UninstallDisplayIcon={app}\{{EXECUTABLE_NAME}}
UninstallDisplayName={{DISPLAY_NAME}}
; Тёмный мастер в цветах Sonar: ночная вода, капля, бирюза (нужен Inno Setup 6.7+)
WizardStyle=modern dark windows11 includetitlebar
WizardBackColor=#070B16
; через #emit: встроенная подстановка ISPP похожа на комментарий шаблонизатора сборщика
#emit "WizardBackImageFile=" + SonarArt + "back-596.png," + SonarArt + "back-894.png," + SonarArt + "back-1192.png," + SonarArt + "back-1630.png"
#emit "WizardImageFile=" + SonarArt + "drop-*.png"
#emit "WizardSmallImageFile=" + SonarArt + "small-*.png"
; Язык по языку Windows, без лишнего окна выбора; папка своя, в профиле
ShowLanguageDialog=no
DisableDirPage=yes
DisableReadyPage=yes
PrivilegesRequired={{PRIVILEGES_REQUIRED}}
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
CloseApplications=force

[Languages]
{% for locale in LOCALES %}
{% if locale == 'en' %}Name: "english"; MessagesFile: "compiler:Default.isl"{% endif %}
{% if locale == 'hy' %}Name: "armenian"; MessagesFile: "compiler:Languages\\Armenian.isl"{% endif %}
{% if locale == 'bg' %}Name: "bulgarian"; MessagesFile: "compiler:Languages\\Bulgarian.isl"{% endif %}
{% if locale == 'ca' %}Name: "catalan"; MessagesFile: "compiler:Languages\\Catalan.isl"{% endif %}
{% if locale == 'zh' %}Name: "chinesesimplified"; MessagesFile: "compiler:Languages\\ChineseSimplified.isl"{% endif %}
{% if locale == 'co' %}Name: "corsican"; MessagesFile: "compiler:Languages\\Corsican.isl"{% endif %}
{% if locale == 'cs' %}Name: "czech"; MessagesFile: "compiler:Languages\\Czech.isl"{% endif %}
{% if locale == 'da' %}Name: "danish"; MessagesFile: "compiler:Languages\\Danish.isl"{% endif %}
{% if locale == 'nl' %}Name: "dutch"; MessagesFile: "compiler:Languages\\Dutch.isl"{% endif %}
{% if locale == 'fi' %}Name: "finnish"; MessagesFile: "compiler:Languages\\Finnish.isl"{% endif %}
{% if locale == 'fr' %}Name: "french"; MessagesFile: "compiler:Languages\\French.isl"{% endif %}
{% if locale == 'de' %}Name: "german"; MessagesFile: "compiler:Languages\\German.isl"{% endif %}
{% if locale == 'he' %}Name: "hebrew"; MessagesFile: "compiler:Languages\\Hebrew.isl"{% endif %}
{% if locale == 'is' %}Name: "icelandic"; MessagesFile: "compiler:Languages\\Icelandic.isl"{% endif %}
{% if locale == 'it' %}Name: "italian"; MessagesFile: "compiler:Languages\\Italian.isl"{% endif %}
{% if locale == 'ja' %}Name: "japanese"; MessagesFile: "compiler:Languages\\Japanese.isl"{% endif %}
{% if locale == 'no' %}Name: "norwegian"; MessagesFile: "compiler:Languages\\Norwegian.isl"{% endif %}
{% if locale == 'pl' %}Name: "polish"; MessagesFile: "compiler:Languages\\Polish.isl"{% endif %}
{% if locale == 'pt' %}Name: "portuguese"; MessagesFile: "compiler:Languages\\Portuguese.isl"{% endif %}
{% if locale == 'ru' %}Name: "russian"; MessagesFile: "compiler:Languages\\Russian.isl"{% endif %}
{% if locale == 'sk' %}Name: "slovak"; MessagesFile: "compiler:Languages\\Slovak.isl"{% endif %}
{% if locale == 'sl' %}Name: "slovenian"; MessagesFile: "compiler:Languages\\Slovenian.isl"{% endif %}
{% if locale == 'es' %}Name: "spanish"; MessagesFile: "compiler:Languages\\Spanish.isl"{% endif %}
{% if locale == 'tr' %}Name: "turkish"; MessagesFile: "compiler:Languages\\Turkish.isl"{% endif %}
{% if locale == 'uk' %}Name: "ukrainian"; MessagesFile: "compiler:Languages\\Ukrainian.isl"{% endif %}
{% endfor %}

[Messages]
russian.WelcomeLabel1=Sonar
russian.WelcomeLabel2=Всё открыто. Пинг на месте.%n%nYouTube, Discord, Instagram и нейросети откроются через Sonar, а игры и российские сайты пойдут напрямую, без потери скорости.%n%nУстановка займёт меньше минуты, права администратора не нужны.
russian.FinishedHeadingLabel=Sonar установлен
russian.FinishedLabelNoIcons=Запустите Sonar и нажмите «Начать»: личный ключ создастся сам. Дальше приложение обновляется без вашего участия.
russian.FinishedLabel=Запустите Sonar и нажмите «Начать»: личный ключ создастся сам. Дальше приложение обновляется без вашего участия.
english.WelcomeLabel1=Sonar
english.WelcomeLabel2=Everything opens. Your ping stays put.%n%nYouTube, Discord, Instagram and AI services go through Sonar, while games and Russian sites go direct at full speed.%n%nSetup takes less than a minute and needs no administrator rights.
english.FinishedHeadingLabel=Sonar is installed
english.FinishedLabelNoIcons=Open Sonar and press Start: your personal key is created automatically. From then on the app updates itself.
english.FinishedLabel=Open Sonar and press Start: your personal key is created automatically. From then on the app updates itself.

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: {% if CREATE_DESKTOP_ICON != true %}unchecked{% else %}checkedonce{% endif %}
Name: "launchAtStartup"; Description: "{cm:AutoStartProgram,{{DISPLAY_NAME}}}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: {% if LAUNCH_AT_STARTUP != true %}unchecked{% else %}checkedonce{% endif %}
[Files]
Source: "{{SOURCE_DIR}}\\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Icons]
Name: "{autoprograms}\\{{DISPLAY_NAME}}"; Filename: "{app}\\{{EXECUTABLE_NAME}}"
Name: "{autodesktop}\\{{DISPLAY_NAME}}"; Filename: "{app}\\{{EXECUTABLE_NAME}}"; Tasks: desktopicon
Name: "{userstartup}\\{{DISPLAY_NAME}}"; Filename: "{app}\\{{EXECUTABLE_NAME}}"; WorkingDir: "{app}"; Tasks: launchAtStartup
[Run]
Filename: "{app}\\{{EXECUTABLE_NAME}}"; Description: "{cm:LaunchProgram,{{DISPLAY_NAME}}}"; Flags: {% if PRIVILEGES_REQUIRED == 'admin' %}runascurrentuser{% endif %} nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{userappdata}\Sonar"

[Code]
// Работающий Sonar закрываем прямо перед копированием файлов, а не при открытии
// установщика: просто запущенный мастер не должен рвать VPN
function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  ResultCode: Integer;
begin
  Exec('taskkill', '/F /IM Sonar.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode)
  Exec('taskkill', '/F /IM HiddifyCli.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode)
  Exec('net', 'stop "HiddifyTunnelService"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode)
  Exec('sc.exe', 'delete "HiddifyTunnelService"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode)
  Result := '';
end;