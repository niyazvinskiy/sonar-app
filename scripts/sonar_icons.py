"""Иконки Sonar для всех платформ из одного рисунка.

Сфера с двумя кольцами-импульсами над линией волны, на ночном фоне, как на сайте
и в прототипе. Запуск из корня репозитория: python scripts/sonar_icons.py
"""
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
NIGHT_TOP = (30, 45, 74)      # --w2
NIGHT = (14, 22, 48)          # --w1
DEEP = (7, 11, 22)            # --w0
PAPER = (246, 247, 249)
FEATHER = (174, 182, 194)


def lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def radial(size, center, radius, stops):
    """Радиальный градиент: stops = [(доля радиуса, цвет RGBA)]."""
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    d = np.clip(np.hypot(xx - center[0], yy - center[1]) / radius, 0, 1)
    ts = [t for t, _ in stops]
    chans = [np.interp(d, ts, [c[i] for _, c in stops]) for i in range(4)]
    return Image.fromarray(np.stack(chans, axis=-1).round().astype(np.uint8), "RGBA")


def background(size, rounded):
    bg = radial(size, (size * 0.5, size * 0.18), size * 1.05,
                [(0, NIGHT_TOP + (255,)), (0.55, NIGHT + (255,)), (1, DEEP + (255,))])
    if rounded:
        mask = Image.new("L", (size, size), 0)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, size - 1, size - 1), radius=size * 0.225, fill=255)
        bg.putalpha(mask)
    return bg


def mark(size, scale=1.0, glyph=False, color=PAPER, dim=1.0):
    """Сфера, кольца и волна на прозрачном фоне. scale ужимает рисунок к центру."""
    S = size
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = S / 2
    r = S * 0.13 * scale                      # радиус сферы
    cx, cy = c + S * 0.06 * scale, c - S * 0.07 * scale

    # кольца-импульсы
    for k, (rr, a) in enumerate([(2.05, 150), (3.1, 70)]):
        w = max(1, round(S * (0.018 if glyph else 0.012) * scale))
        alpha = round(a * dim) if not glyph else (255 if k == 0 else 160)
        d.ellipse((cx - r * rr, cy - r * rr, cx + r * rr, cy + r * rr), outline=color + (alpha,), width=w)

    # волна под сферой
    pts = []
    x0, x1 = c - S * 0.36 * scale, c + S * 0.36 * scale
    base = c + S * 0.17 * scale
    for i in range(121):
        t = i / 120
        x = x0 + (x1 - x0) * t
        y = base + math.sin(t * math.pi * 2.2 + 0.4) * S * 0.045 * scale * (1 - abs(t - 0.5))
        pts.append((x, y))
    wave_color = color if glyph else FEATHER
    d.line(pts, fill=wave_color + (round(255 * (0.95 if glyph else 0.85 * dim)),),
           width=max(1, round(S * (0.03 if glyph else 0.022) * scale)), joint="curve")

    # сфера
    if glyph:
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=color + (255,))
    else:
        glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        ImageDraw.Draw(glow).ellipse((cx - r * 1.9, cy - r * 1.9, cx + r * 1.9, cy + r * 1.9),
                                     fill=(201, 211, 234, round(90 * dim)))
        img = Image.alpha_composite(glow.filter(ImageFilter.GaussianBlur(S * 0.05)), img)
        sphere = radial(S, (cx - r * 0.32, cy - r * 0.4), r * 1.35,
                        [(0, (255, 255, 255, 255)), (0.45, (201, 211, 234, 255)), (1, (143, 161, 201, 255))])
        m = Image.new("L", (S, S), 0)
        ImageDraw.Draw(m).ellipse((cx - r, cy - r, cx + r, cy + r), fill=255)
        img.paste(sphere, (0, 0), m)
    return img


def render(size, *, rounded=True, bg=True, scale=1.0, glyph=False, color=PAPER, dim=1.0):
    big = size * 4
    base = background(big, rounded) if bg else Image.new("RGBA", (big, big), (0, 0, 0, 0))
    out = Image.alpha_composite(base, mark(big, scale, glyph, color, dim))
    return out.resize((size, size), Image.LANCZOS)


def save(img, rel, **kw):
    p = ROOT / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    img.save(p, **kw)
    print("  ", rel)


def main():
    print("Мастер-иконка")
    master = render(1024)
    save(master, "assets/images/source/sonar_icon_1024.png")
    save(render(512), "assets/images/source/ic_launcher_border.png")

    print("Android")
    dens = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
    for name, k in dens.items():
        res = f"android/app/src/main/res/mipmap-{name}"
        save(render(round(48 * k)), f"{res}/ic_launcher.webp", quality=95)
        save(render(round(48 * k), rounded=False).resize((round(48 * k),) * 2), f"{res}/ic_launcher_round.webp", quality=95)
        # адаптивный передний план: 108 dp, рисунок в безопасной зоне 66 dp
        save(render(round(108 * k), rounded=False, bg=False, scale=0.62), f"{res}/ic_launcher_foreground.png")
        # значок в шторке уведомлений: белый силуэт
        save(render(round(24 * k), rounded=False, bg=False, scale=1.25, glyph=True),
             f"android/app/src/main/res/drawable-{name}/ic_stat_logo.png")

    print("Windows")
    ico = render(256)
    save(ico, "windows/runner/resources/app_icon.ico", sizes=[(s, s) for s in (16, 24, 32, 48, 64, 128, 256)])
    save(ico, "assets/images/source/sonar.ico", sizes=[(s, s) for s in (16, 24, 32, 48, 64, 128, 256)])

    print("Трей: обычный, подключён, отключён, для светлой панели")
    tray = {
        "tray_icon": render(64, bg=False, rounded=False, scale=1.3, glyph=True),
        "tray_icon_connected": render(64, bg=False, rounded=False, scale=1.3),
        "tray_icon_disconnected": render(64, bg=False, rounded=False, scale=1.3, glyph=True, color=FEATHER),
        "tray_icon_dark": render(64, bg=False, rounded=False, scale=1.3, glyph=True, color=DEEP),
    }
    for name, img in tray.items():
        save(img, f"assets/images/{name}.png")
        save(img, f"assets/images/{name}.ico", sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64)])
        save(img, f"assets/images/source/{name}.png")

    print("macOS")
    mac = ROOT / "macos/Runner/Assets.xcassets/AppIcon.appiconset"
    if mac.exists():
        for f in mac.glob("*.png"):
            w = Image.open(f).size[0]
            save(render(w), str(f.relative_to(ROOT)))


if __name__ == "__main__":
    main()
