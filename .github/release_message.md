## Sonar

### Что нового

- Новый установщик для Windows: тёмный, в стиле Sonar, на русском и без лишних шагов.
- Android обновляется сам: пока работает VPN, Sonar раз в 6 часов проверяет новую версию, скачивает её и ставит, когда экран погашен. На Android 12 и новее без вопросов, на старых версиях придёт уведомление «Нажмите, чтобы обновить».
- После обновления и после перезагрузки телефона VPN включается сам, если был включён.
- Если телефон писал «Приложение не установлено», скачайте **универсальный** файл: он ставится на любой телефон.
- В настройках и «О программе» появилась ссылка на зеркало сайта, оно открывается у всех провайдеров.

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
