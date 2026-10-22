## Sonar

### Что нового

- **Стабильный канал.** Раньше соединения раскидывались по всем каналам по очереди и рвались при каждой смене, отсюда пропадал звук в Discord. Теперь Sonar держит один живой канал и переходит на запасной, только если этот перестал отвечать.
- **Основной канал проходит там, где его начали душить.** Провайдеры стали резать старый основной канал, теперь основной идёт по-новому и проходит и в кафе, и на работе.
- **Голос в Discord через Sonar** и в умном режиме: голосовые серверы Discord теперь идут через Sonar.
- **Windows: весь компьютер через VPN.** Переключатель в настройках: через Sonar идут и игры, и голос Discord. Sonar сам попросит права администратора.
- **Обновления не сдаются.** Загрузка докачивается после обрыва и повторяется сама. На Windows обновление ставится и при включённом VPN, когда вы отошли от компьютера, и Sonar подключается обратно сам.

Скачайте файл для своей системы. Установленный Sonar обновится сам: он проверяет новые версии при запуске и раз в 6 часов.

| Система | Файл |
|---|---|
| **Windows 10 и 11** | [Sonar-Windows-Setup-x64.exe](https://github.com/niyazvinskiy/sonar-app/releases/download/RELEASE_TAG/Sonar-Windows-Setup-x64.exe) · [портативная версия](https://github.com/niyazvinskiy/sonar-app/releases/download/RELEASE_TAG/Sonar-Windows-Portable-x64.zip) |
| **Android**, любой телефон | [Sonar-Android-universal.apk](https://github.com/niyazvinskiy/sonar-app/releases/download/RELEASE_TAG/Sonar-Android-universal.apk) |
| Android, файл поменьше | [arm64](https://github.com/niyazvinskiy/sonar-app/releases/download/RELEASE_TAG/Sonar-Android-arm64.apk) для новых телефонов · [arm7](https://github.com/niyazvinskiy/sonar-app/releases/download/RELEASE_TAG/Sonar-Android-arm7.apk) для 32-битных |
| **Linux** | [AppImage](https://github.com/niyazvinskiy/sonar-app/releases/download/RELEASE_TAG/Sonar-Linux-x64.AppImage) · [.deb](https://github.com/niyazvinskiy/sonar-app/releases/download/RELEASE_TAG/Sonar-Debian-x64.deb) |
| **macOS** | [Sonar-MacOS.dmg](https://github.com/niyazvinskiy/sonar-app/releases/download/RELEASE_TAG/Sonar-MacOS.dmg) |

После установки нажмите «Начать»: личный ключ создастся сам, умный режим уже включён.

Sonar основан на [Hiddify](https://github.com/hiddify/hiddify-app) и распространяется по его лицензии (GPLv3 с дополнительными условиями).
