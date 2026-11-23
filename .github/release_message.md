## Sonar

### Что нового

- **Автозапуск Windows.** Установщик размещает Sonar в Program Files и настраивает запуск при входе в вашу учётную запись. Одно подтверждение Windows при установке, дальше без повторных запросов прав. Автозапуск отключается в настройках.
- **Восстановление подключения.** После ошибки Sonar повторяет попытки с увеличивающимися паузами до 30 секунд. Кнопка отключения отменяет попытки; параллельные подключения не запускаются.
- **Больше терпения к медленным сетям.** Проверка каналов ждёт полный тайм-аут и не переключает отвечающий канал только из-за высокого пинга. Восстановление не создаёт дополнительную пропускную способность и требует доступного интернета.
- **Обновлённый интерфейс.** Крупный статус и отдельная кнопка подключения, маршруты и показатели сеанса рядом на широком окне, прокрутка и увеличенный текст на узком. Анимация учитывает системное уменьшение движения.
- **Проверенные загрузки обновлений.** Докачка проверяет диапазон байтов, размер и SHA-256, когда GitHub предоставляет хеш. Windows сохраняет журнал результата установки и восстанавливает запуск приложения.

Скачайте файл для своей системы. Установленный Sonar обновится сам: он проверяет новые версии при запуске и раз в 6 часов.

| Система | Файл |
|---|---|
| **Windows 10 и 11** | [Sonar-Windows-Setup-x64.exe](https://github.com/niyazvinskiy/sonar-app/releases/download/RELEASE_TAG/Sonar-Windows-Setup-x64.exe) · [портативная версия](https://github.com/niyazvinskiy/sonar-app/releases/download/RELEASE_TAG/Sonar-Windows-Portable-x64.zip) |
| **Android**, любой телефон | [Sonar-Android-universal.apk](https://github.com/niyazvinskiy/sonar-app/releases/download/RELEASE_TAG/Sonar-Android-universal.apk) |
| Android, файл поменьше | [arm64](https://github.com/niyazvinskiy/sonar-app/releases/download/RELEASE_TAG/Sonar-Android-arm64.apk) для новых телефонов · [arm7](https://github.com/niyazvinskiy/sonar-app/releases/download/RELEASE_TAG/Sonar-Android-arm7.apk) для 32-битных |
| **Linux** | [AppImage](https://github.com/niyazvinskiy/sonar-app/releases/download/RELEASE_TAG/Sonar-Linux-x64.AppImage) · [.deb](https://github.com/niyazvinskiy/sonar-app/releases/download/RELEASE_TAG/Sonar-Debian-x64.deb) |
| **macOS** | [Sonar-MacOS.dmg](https://github.com/niyazvinskiy/sonar-app/releases/download/RELEASE_TAG/Sonar-MacOS.dmg) |

При первой установке нажмите «Начать»: личный ключ создастся сам, умный режим уже включён. При обновлении сохраняются существующий ключ и настройки. В Windows для переноса старой установки в Program Files потребуется одно подтверждение системы.

Sonar основан на [Hiddify](https://github.com/hiddify/hiddify-app) и распространяется по его лицензии (GPLv3 с дополнительными условиями).
