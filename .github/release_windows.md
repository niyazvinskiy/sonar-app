## Sonar для Windows

Исправление перехода со старой установки: установщик ждёт запуска новой копии в Program Files и обновляет существующие пользовательские ярлыки. Старая копия больше не должна перехватывать запуск сразу после обновления.

Включены изменения 1.4.0: автозапуск с нужными правами после одного подтверждения Windows, автоматическое подключение и повторные попытки, сохранение ручного отключения, обновлённый интерфейс и проверка загруженных установщиков.

- [Установщик Windows](https://github.com/niyazvinskiy/sonar-app/releases/download/RELEASE_TAG/Sonar-Windows-Setup-x64.exe)
- [Портативная версия](https://github.com/niyazvinskiy/sonar-app/releases/download/RELEASE_TAG/Sonar-Windows-Portable-x64.zip)

Для автоматического запуска VPN используйте установщик. Переход из старой папки в Program Files требует одного подтверждения Windows. Не включайте два VPN с пересекающимися адресами адаптеров одновременно.

Это исправление для Windows. [Сборки Android 1.4.0](https://github.com/niyazvinskiy/sonar-app/releases/tag/sonar-v1.4.0) остаются доступны отдельно.

Sonar основан на [Hiddify](https://github.com/hiddify/hiddify-app) и распространяется по его лицензии.
