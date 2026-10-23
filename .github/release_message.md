## Sonar

### Что нового

- **Связь без обрывов.** Sonar держит один живой канал и переходит на запасной, только если этот перестал отвечать: голос в Discord и игры больше не прерываются. Основной канал теперь самый надёжный для приложения, запасные идут другими путями.
- **Голос в Discord через Sonar** и в умном режиме.
- **Windows: одна кнопка для всего.** Теперь по умолчанию через Sonar идёт весь компьютер: игры, голос Discord, программы вроде Claude Code. Права администратора Sonar попросит один раз, дальше просто нажмите на каплю.
- **Обновления не рвут связь.** Они докачиваются после обрыва и идут через сам Sonar. Ставятся, когда VPN выключен или при следующем запуске; на телефоне когда экран погашен и ничего не качается.
- **Новый знак «Пульс»** и новый тёмный установщик.

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
