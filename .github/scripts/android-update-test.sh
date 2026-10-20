#!/usr/bin/env bash
# Проверка автообновления Sonar на Android, как у живого человека:
# ставим сборку старой версии, жмём «Начать», ждём VPN, гасим экран и ждём,
# что Sonar сам скачает последний выпуск, сам поставит его без вопросов,
# а VPN после обновления включится обратно.
set -u
APK="$1"
PKG=app.sonar.vpn

log() { echo "== $(date +%H:%M:%S) $*"; }
version() { adb shell dumpsys package "$PKG" | grep -m1 versionName | tr -d ' \r' | cut -d= -f2; }
OUT=/tmp/sonar-test
mkdir -p "$OUT"
# туннель VPN: интерфейс tunN или сеть VPN в состоянии CONNECTED
vpn_up() {
  adb shell ip -o link 2>/dev/null | grep -q -E ': tun[0-9]+' && return 0
  adb shell dumpsys connectivity 2>/dev/null | grep -E 'VPN' | grep -q 'CONNECTED'
}
shot() { adb exec-out screencap -p > "$OUT/$1.png" 2>/dev/null; log "снимок экрана: $1.png"; }

# Нажать на элемент по тексту: Flutter отдаёт подписи в content-desc
tap_text() {
  for _ in $(seq 1 40); do
    adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
    adb pull /sdcard/ui.xml /tmp/ui.xml >/dev/null 2>&1
    xy=$(python3 - "$1" <<'PY'
import re, sys, xml.etree.ElementTree as ET
want = sys.argv[1]
try:
    root = ET.parse("/tmp/ui.xml").getroot()
except Exception:
    sys.exit()
for n in root.iter("node"):
    label = (n.get("text") or "") + " " + (n.get("content-desc") or "")
    if want in label:
        x1, y1, x2, y2 = map(int, re.findall(r"\d+", n.get("bounds")))
        print((x1 + x2) // 2, (y1 + y2) // 2)
        break
PY
)
    if [ -n "$xy" ]; then
      log "нажимаю «$1» в $xy"
      adb shell input tap $xy
      return 0
    fi
    sleep 3
  done
  log "не нашёл «$1» на экране"
  return 1
}

finish() {
  [ "$1" = 0 ] || shot "fail"
  log "журнал Sonar (logcat)"
  adb logcat -d -s A/SonarUpdate:* A/BoxService:* AndroidRuntime:E PackageInstaller:* 2>/dev/null | tail -60
  pid=$(adb shell pidof "$PKG" | tr -d '\r')
  [ -n "$pid" ] && adb logcat -d --pid="$pid" > "$OUT/app.log" 2>/dev/null
  adb logcat -d > "$OUT/all.log" 2>/dev/null
  adb shell ip addr > "$OUT/ip.txt" 2>/dev/null
  adb shell dumpsys connectivity > "$OUT/connectivity.txt" 2>/dev/null
  if [ "$1" != 0 ]; then
    log "ошибки приложения"
    grep -a -E ' E |flutter|Hiddify|hiddify|core|Exception' "$OUT/app.log" 2>/dev/null | tail -60
    log "сети"
    grep -a -E 'tun|VPN' "$OUT/ip.txt" "$OUT/connectivity.txt" 2>/dev/null | head -20
  fi
  exit "$1"
}

log "ставлю тестовую сборку $APK"
adb install -r "$APK" || finish 1
log "версия до: $(version)"
adb shell pm grant "$PKG" android.permission.POST_NOTIFICATIONS
# разрешение на VPN, которое человек даёт кнопкой «ОК» при первом подключении
adb shell appops set "$PKG" ACTIVATE_VPN allow
# Разрешение «Установка из этого источника» нарочно НЕ даём: обновление себя
# должно идти без него, как на телефонах друзей

adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null
sleep 15
shot "intro"
tap_text "Начать" || finish 1
sleep 20
shot "after-start"

log "жду, пока поднимется VPN"
for i in $(seq 1 60); do vpn_up && break; sleep 3; done
if ! vpn_up; then log "VPN не поднялся"; finish 1; fi
log "VPN работает (tun0 есть)"

# Экран гаснет: служба VPN ставит обновление только при погашенном экране
sleep 5
adb shell input keyevent KEYCODE_SLEEP
log "экран погашен, жду обновления (проверка через 3 минуты после подключения)"

before=$(version)
for i in $(seq 1 90); do
  v=$(version)
  if [ -n "$v" ] && [ "$v" != "$before" ]; then
    log "версия сменилась: $before -> $v"
    break
  fi
  sleep 10
done
after=$(version)
if [ "$after" = "$before" ]; then
  log "за 15 минут обновление не поставилось"
  adb shell dumpsys notification --noredact 2>/dev/null | grep -A3 -i "sonar" | head -20
  finish 1
fi

log "жду, что VPN включится сам после обновления"
for i in $(seq 1 40); do vpn_up && break; sleep 3; done
if vpn_up; then
  log "VPN снова работает после обновления"
else
  log "VPN после обновления не включился"
  finish 1
fi
log "ИТОГ: обновление $before -> $after прошло само, без вопросов, VPN включился"
finish 0
