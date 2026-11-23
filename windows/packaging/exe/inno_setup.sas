; Sonar: картинки установщика лежат в windows/packaging/exe/art, путь к ним строим
; от значка, Inno Setup находит их тем же способом, что и сам значок
#define SonarIcon "{{SETUP_ICON_FILE}}"
#define SonarArt ExtractFilePath(SonarIcon) + "..\..\packaging\exe\art\"
; В заголовке и списке программ версия без номера сборки: 1.2.2, а не 1.2.2+12002
#define SonarFull "{{APP_VERSION}}"
#if Pos("+", SonarFull) > 0
#define SonarVersion Copy(SonarFull, 1, Pos("+", SonarFull) - 1)
#else
#define SonarVersion SonarFull
#endif

[Setup]
AppId={{APP_ID}}
#emit "AppVersion=" + SonarVersion
#emit "AppVerName={{DISPLAY_NAME}} " + SonarVersion
AppName={{DISPLAY_NAME}}
AppPublisher={{PUBLISHER_NAME}}
AppPublisherURL={{PUBLISHER_URL}}
AppSupportURL={{PUBLISHER_URL}}
AppUpdatesURL={{PUBLISHER_URL}}
DefaultDirName={{INSTALL_DIR_NAME}}
UsePreviousAppDir=no
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
; Три экрана: приветствие с каплей, установка, готово. Язык по языку Windows,
; папка своя, в профиле, поэтому ни выбора языка, ни папки, ни «Готово к установке»
DisableWelcomePage=no
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
russian.WelcomeLabel2=Всё открыто. Пинг на месте.%n%nSonar подключается при входе в Windows и восстанавливает связь после обрывов.%n%nПодтвердите установку один раз. Дальше VPN запускается без повторных запросов прав.
russian.FinishedHeadingLabel=Sonar установлен
russian.FinishedLabelNoIcons=Запустите Sonar и нажмите «Начать»: личный ключ создастся сам. Дальше приложение обновляется без вашего участия.
russian.FinishedLabel=Запустите Sonar и нажмите «Начать»: личный ключ создастся сам. Дальше приложение обновляется без вашего участия.
english.WelcomeLabel1=Sonar
english.WelcomeLabel2=Everything opens. Your ping stays put.%n%nSonar connects when you sign in to Windows and recovers after interruptions.%n%nApprove setup once. Future VPN starts need no elevation prompts.
english.FinishedHeadingLabel=Sonar is installed
english.FinishedLabelNoIcons=Open Sonar and press Start: your personal key is created automatically. From then on the app updates itself.
english.FinishedLabel=Open Sonar and press Start: your personal key is created automatically. From then on the app updates itself.
; после приветствия сразу установка, поэтому и кнопка называется «Установить»
russian.ClickNext=Нажмите «Установить», чтобы начать.
english.ClickNext=Click Install to begin.

; Sonar: шага с галочками нет. Значок на рабочем столе ставится при обычной установке,
; а тихое автообновление его не трогает: удалённый значок не возвращается сам.
; Автозапуск включается в настройках Sonar.
[Files]
Source: "{{SOURCE_DIR}}\\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
#emit "Source: " + SonarArt + "..\sonar-startup.ps1; DestDir: " + "{app}; Flags: ignoreversion"
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Icons]
Name: "{autoprograms}\\{{DISPLAY_NAME}}"; Filename: "{app}\\{{EXECUTABLE_NAME}}"
Name: "{autodesktop}\\{{DISPLAY_NAME}}"; Filename: "{app}\\{{EXECUTABLE_NAME}}"; Check: not WizardSilent
[Run]
Filename: "{sys}\\WindowsPowerShell\\v1.0\\powershell.exe"; Parameters: "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File ""{app}\sonar-startup.ps1"""; Flags: runhidden waituntilterminated

[UninstallDelete]
Type: filesandordirs; Name: "{userappdata}\Sonar"
; ярлыки от прошлых установок, которые новый журнал удаления не знает
Type: files; Name: "{autodesktop}\{{DISPLAY_NAME}}.lnk"
Type: files; Name: "{userstartup}\{{DISPLAY_NAME}}.lnk"

[UninstallRun]
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File ""{app}\sonar-startup.ps1"" -Uninstall"; Flags: runhidden waituntilterminated

[Code]
procedure CurPageChanged(CurPageID: Integer);
begin
  if CurPageID = wpWelcome then
    WizardForm.NextButton.Caption := SetupMessage(msgButtonInstall);
end;

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
