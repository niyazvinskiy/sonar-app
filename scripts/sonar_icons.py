"""Знак Sonar «Пульс» для всех платформ из одного рисунка.

Перламутровая капля в трёх переливающихся кольцах: бирюза, индиго и туман дышат
со сдвигом, как «Моя волна». Крупно знак полный, к 24–96 px кольца сливаются в
одну переливающуюся петлю, а к 16–48 px остаются одна толстая петля и капля,
иначе на панели задач их не разобрать.

Скрипт пишет PNG, ICO и WebP для Android, Windows, Linux и трея, а ещё SVG
(assets/images/logo.svg и набор в assets/images/brand/): геометрия у них общая.
Надпись SONAR в SVG переведена в кривые из Jost 500, для этого нужен fontTools.
Запуск из корня репозитория: python scripts/sonar_icons.py
"""
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
FONT = ROOT / "assets/fonts/Jost-500.ttf"
DEEP = (7, 11, 22)            # --w0
NIGHT = (14, 22, 48)          # --w1
NIGHT_TOP = (34, 52, 90)
FOG = (221, 226, 232)
PAPER = (246, 247, 249)
FEATHER = (174, 182, 194)
AQUA = (94, 234, 212)
INDIGO = (124, 140, 255)

# Геометрия в долях стороны рисунка, центр в 0.5. Гармоники: (k, амплитуда, фаза).
RINGS = (
    (0.300, ((3, 0.013, 0.4), (5, 0.005, 1.7)), AQUA, 0.90),
    (0.305, ((3, 0.014, 2.5), (4, 0.006, 0.3)), INDIGO, 0.95),
    (0.310, ((3, 0.012, 4.6), (5, 0.006, 3.1)), FOG, 0.80),
)
HALO = (0.410, ((4, 0.010, 1.2), (3, 0.006, 3.6)), FOG, 0.22)
LOOP = (0.355, ((3, 0.016, 0.4), (5, 0.006, 1.7)))  # одна петля мелкого знака
# уровень детализации: толщина колец, радиус капли, сила сияния
LEVELS = {
    "L": dict(ring=0.013, pearl=0.170, glow=0.55),   # от 128 px
    "M": dict(ring=0.030, pearl=0.190, glow=0.40),   # 24–96 px: кольца сливаются в одну петлю
    "S": dict(ring=0.095, pearl=0.195, glow=0.0),    # 16–48 px: одна толстая петля
}


def level_for(px):
    return "S" if px <= 48 else "M" if px < 128 else "L"


# ---------- растр ----------

def wobble(t, r, harm):
    return r + sum(a * np.sin(k * t + ph) for k, a, ph in harm)


def loop_mask(S, r, harm, width, n=1440):
    """Маска петли: залитый контур r+w/2 минус контур r-w/2 (смещение по радиусу)."""
    t = np.linspace(0, math.tau, n, endpoint=False)
    rr = wobble(t, r, harm) * S
    m = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(m)
    c = S / 2
    for dr, fill in ((width * S / 2, 255), (-width * S / 2, 0)):
        d.polygon(list(zip(c + (rr + dr) * np.cos(t), c + (rr + dr) * np.sin(t))), fill=fill)
    return m


def solid(S, color, mask, alpha=1.0):
    layer = Image.new("RGBA", (S, S), color + (0,))
    layer.putalpha(mask.point(lambda v: round(v * alpha)))
    return layer


def diagonal(S, stops):
    """Градиент сверху слева вниз направо: stops = [(доля, RGB)]."""
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
    t = (xx + yy) / (2 * S)
    ts = [p for p, _ in stops]
    ch = [np.interp(t, ts, [c[i] for _, c in stops]) for i in range(3)]
    return np.stack(ch, -1)


def pearl(d):
    """Перламутровая капля диаметром d: блик сверху слева, индиго в тени, бирюза снизу справа."""
    yy, xx = np.mgrid[0:d, 0:d].astype(np.float32)
    c = (d - 1) / 2
    nx, ny = (xx - c) / (d / 2), (yy - c) / (d / 2)
    rr = np.hypot(nx, ny)
    inside = np.clip((1 - rr) * d / 2, 0, 1)
    z = np.sqrt(np.clip(1 - rr**2, 0, 1))
    lx, ly, lz = -0.45, -0.55, 0.70
    ln = math.sqrt(lx * lx + ly * ly + lz * lz)
    lit = np.clip((nx * lx + ny * ly + z * lz) / ln, 0, 1)
    stops = [(0, (74, 82, 182)), (0.45, (150, 160, 240)), (0.78, (226, 230, 255)), (1, (255, 255, 255))]
    col = np.stack([np.interp(lit, [s for s, _ in stops], [c_[i] for _, c_ in stops]) for i in range(3)], -1)
    iris = (np.exp(-((nx - 0.48) ** 2 + (ny - 0.6) ** 2) / 0.2) * 0.78)[..., None]
    col = col * (1 - iris) + np.array(AQUA, np.float32) * iris
    spec = np.exp(-(((nx + 0.36) * 1.25) ** 2 + ((ny + 0.44) * 1.9) ** 2) / 0.022)[..., None]
    col = col * (1 - spec * 0.9) + 255 * spec * 0.9
    rim = (np.clip((rr - 0.9) / 0.1, 0, 1) ** 2 * 0.35)[..., None]
    col = col * (1 - rim) + 255 * rim
    return Image.fromarray(np.dstack([col.clip(0, 255), inside * 255]).astype(np.uint8), "RGBA")


def glow(S, r, strength, color=INDIGO):
    """Мягкое сияние радиуса r; к краю рисунка гаснет полностью, чтобы не было видно квадрата."""
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
    d = np.hypot(xx - S / 2, yy - S / 2)
    a = strength * np.exp(-((d / r) ** 2) * 2.2) * np.clip((S / 2 - d) / (S * 0.12), 0, 1)
    rgb = np.broadcast_to(np.array(color, np.float32), (S, S, 3))
    return Image.fromarray(np.dstack([rgb, a * 255]).round().astype(np.uint8), "RGBA")


def mark(S, level="L", mono=None):
    """Знак на прозрачном фоне, сторона S. mono: один цвет вместо перламутра (трей, шторка)."""
    p = LEVELS[level]
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    c = S / 2
    rp = p["pearl"] * S
    if mono:
        r, harm = (LOOP if level == "S" else RINGS[0][:2])
        img = Image.alpha_composite(img, solid(S, mono, loop_mask(S, r, harm, p["ring"] if level == "S" else 0.055)))
        ImageDraw.Draw(img).ellipse((c - rp, c - rp, c + rp, c + rp), fill=mono + (255,))
        return img
    if p["glow"]:
        img = Image.alpha_composite(img, glow(S, rp * 2.1, p["glow"]))
    if level == "S":
        grad = diagonal(S, [(0.15, FOG), (0.5, INDIGO), (0.85, AQUA)])
        a = np.asarray(loop_mask(S, *LOOP, p["ring"]), np.float32)
        img = Image.alpha_composite(img, Image.fromarray(np.dstack([grad, a]).clip(0, 255).astype(np.uint8), "RGBA"))
    else:
        if level == "L":
            r, harm, color, alpha = HALO
            img = Image.alpha_composite(img, solid(S, color, loop_mask(S, r, harm, 0.008), alpha))
        for r, harm, color, alpha in RINGS:
            img = Image.alpha_composite(img, solid(S, color, loop_mask(S, r, harm, p["ring"]), alpha))
    ball = pearl(round(rp * 2))
    img.alpha_composite(ball, (round(c - rp), round(c - rp)))
    return img


def tile(S, rounded=True):
    """Ночная плитка: свет сверху, глубина снизу, тонкий светлый край."""
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
    d = np.clip(np.hypot(xx - S * 0.5, yy - S * 0.12) / (S * 1.08), 0, 1)
    stops = [(0, NIGHT_TOP), (0.5, NIGHT), (1, DEEP)]
    rgb = np.stack([np.interp(d, [s for s, _ in stops], [c[i] for _, c in stops]) for i in range(3)], -1)
    img = Image.fromarray(np.dstack([rgb, np.full((S, S), 255.0)]).round().astype(np.uint8), "RGBA")
    if rounded:
        R = S * 0.225
        mask = Image.new("L", (S, S), 0)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, S - 1, S - 1), radius=R, fill=255)
        img.putalpha(mask)
        # край: светлее сверху, почти пропадает к середине
        w = max(1, round(S * 0.006))
        edge = Image.new("L", (S, S), 0)
        ImageDraw.Draw(edge).rounded_rectangle((w / 2, w / 2, S - 1 - w / 2, S - 1 - w / 2), radius=R - w / 2, outline=255, width=w)
        fade = np.interp(np.linspace(0, 1, S), [0, 0.45, 1], [0.24, 0.04, 0.09])[:, None]
        a = (np.asarray(edge, np.float32) * fade).astype(np.uint8)
        img = Image.alpha_composite(img, solid(S, (255, 255, 255), Image.fromarray(a)))
    return img


def render(size, *, rounded=True, bg=True, scale=None, mono=None, level=None):
    """Иконка size×size: плитка и знак, нарисованные вчетверо крупнее и уменьшенные."""
    big = size * 4
    level = level or level_for(size)
    if scale is None:
        scale = 0.86 if level == "S" else 0.74
    base = tile(big, rounded) if bg else Image.new("RGBA", (big, big), (0, 0, 0, 0))
    m = round(big * scale)
    base.alpha_composite(mark(m, level, mono), ((big - m) // 2, (big - m) // 2))
    return base.resize((size, size), Image.LANCZOS)


def wordmark(height, color, tracking=0.42):
    """Надпись SONAR из Jost 500 с разрядкой; height — высота заглавных букв в px."""
    size = round(height / 0.7)
    font = ImageFont.truetype(str(FONT), size)
    widths = [font.getlength(ch) for ch in "SONAR"]
    track = size * tracking
    w = round(sum(widths) + track * 4) + 4
    img = Image.new("RGBA", (w, round(size * 1.1)), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    x = 2
    for ch, cw in zip("SONAR", widths):
        d.text((x, 0), ch, font=font, fill=color)
        x += cw + track
    return img.crop(img.getbbox())


# ---------- SVG ----------

def svg_loop(r, harm, n=48):
    """Петля в координатах 0..100: Catmull-Rom через n точек, переведённый в кубические Безье."""
    pts = []
    for i in range(n):
        t = i / n * math.tau
        rr = float(wobble(t, r, harm)) * 100
        pts.append((50 + rr * math.cos(t), 50 + rr * math.sin(t)))
    d = f"M{pts[0][0]:.2f} {pts[0][1]:.2f}"
    for i in range(n):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[(i + 1) % n], pts[(i + 2) % n]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        d += f"C{c1[0]:.2f} {c1[1]:.2f} {c2[0]:.2f} {c2[1]:.2f} {p2[0]:.2f} {p2[1]:.2f}"
    return d + "Z"


def hexc(c):
    return "#%02X%02X%02X" % c


def svg_defs(id_):
    return f"""<defs>
<radialGradient id="{id_}p" cx=".42" cy=".36" r=".74" fx=".33" fy=".27"><stop offset="0" stop-color="#FFFFFF"/><stop offset=".24" stop-color="#EEF0FF"/><stop offset=".6" stop-color="#AEB8F5"/><stop offset="1" stop-color="#4A52B6"/></radialGradient>
<radialGradient id="{id_}i" cx=".74" cy=".8" r=".6"><stop offset="0" stop-color="#5EEAD4" stop-opacity=".85"/><stop offset=".55" stop-color="#5EEAD4" stop-opacity=".18"/><stop offset="1" stop-color="#5EEAD4" stop-opacity="0"/></radialGradient>
<radialGradient id="{id_}g" cx=".5" cy=".5" r=".5"><stop offset="0" stop-color="#7C8CFF" stop-opacity=".5"/><stop offset="1" stop-color="#7C8CFF" stop-opacity="0"/></radialGradient>
<linearGradient id="{id_}l" x1="0" y1="0" x2="1" y2="1"><stop offset=".15" stop-color="#DDE2E8"/><stop offset=".5" stop-color="#7C8CFF"/><stop offset=".85" stop-color="#5EEAD4"/></linearGradient>
<radialGradient id="{id_}t" cx=".5" cy=".12" r="1.08"><stop offset="0" stop-color="#22345A"/><stop offset=".5" stop-color="#0E1630"/><stop offset="1" stop-color="#070B16"/></radialGradient>
<linearGradient id="{id_}e" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".24"/><stop offset=".45" stop-color="#fff" stop-opacity=".04"/><stop offset="1" stop-color="#fff" stop-opacity=".09"/></linearGradient>
</defs>"""


def svg_pearl(id_, r):
    c = 50
    hx, hy = c - r * 0.36, c - r * 0.44
    return (f'<circle cx="{c}" cy="{c}" r="{r:.2f}" fill="url(#{id_}p)"/>'
            f'<circle cx="{c}" cy="{c}" r="{r:.2f}" fill="url(#{id_}i)"/>'
            f'<ellipse cx="{hx:.2f}" cy="{hy:.2f}" rx="{r * .2:.2f}" ry="{r * .12:.2f}" fill="#fff" fill-opacity=".9" transform="rotate(-35 {hx:.2f} {hy:.2f})"/>'
            f'<circle cx="{c}" cy="{c}" r="{r - .3:.2f}" fill="none" stroke="#fff" stroke-opacity=".3" stroke-width=".6"/>')


def svg_mark_body(level, id_="s", mono=None):
    """Содержимое знака в рамке 0..100, без <svg>. mono — цвет или currentColor."""
    p = LEVELS[level]
    rp = p["pearl"] * 100
    if mono:
        r, harm = LOOP if level == "S" else RINGS[0][:2]
        w = p["ring"] * 100 if level == "S" else 5.5
        return (f'<path d="{svg_loop(r, harm)}" fill="none" stroke="{mono}" stroke-width="{w:.2f}"/>'
                f'<circle cx="50" cy="50" r="{rp:.2f}" fill="{mono}"/>')
    s = ""
    if p["glow"]:
        s += f'<circle cx="50" cy="50" r="{rp * 2.1:.2f}" fill="url(#{id_}g)" opacity="{p["glow"] / 0.55:.2f}"/>'
    if level == "S":
        s += f'<path d="{svg_loop(*LOOP)}" fill="none" stroke="url(#{id_}l)" stroke-width="{p["ring"] * 100:.2f}"/>'
    else:
        if level == "L":
            r, harm, color, alpha = HALO
            s += f'<path d="{svg_loop(r, harm)}" fill="none" stroke="{hexc(color)}" stroke-opacity="{alpha}" stroke-width=".8"/>'
        for r, harm, color, alpha in RINGS:
            s += f'<path d="{svg_loop(r, harm)}" fill="none" stroke="{hexc(color)}" stroke-opacity="{alpha}" stroke-width="{p["ring"] * 100:.2f}"/>'
    return s + svg_pearl(id_, rp)


def svg_doc(body, vb="0 0 100 100", id_="s"):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{vb}">{svg_defs(id_)}{body}</svg>\n'


def svg_icon(level, id_="s"):
    scale = 0.86 if level == "S" else 0.74
    off = 50 * (1 - scale)
    return svg_doc(f'<rect width="100" height="100" rx="22.5" fill="url(#{id_}t)"/>'
                   f'<rect x=".35" y=".35" width="99.3" height="99.3" rx="22.15" fill="none" stroke="url(#{id_}e)" stroke-width=".7"/>'
                   f'<g transform="translate({off:.2f} {off:.2f}) scale({scale})">{svg_mark_body(level, id_)}</g>', id_=id_)


def svg_wordmark(cap, color, tracking=0.42):
    """Надпись SONAR кривыми: возвращает (path d, ширина) при высоте заглавных cap."""
    from fontTools.pens.svgPathPen import SVGPathPen
    from fontTools.pens.transformPen import TransformPen
    from fontTools.ttLib import TTFont

    f = TTFont(str(FONT))
    gs, cmap = f.getGlyphSet(), f.getBestCmap()
    k = cap / f["OS/2"].sCapHeight
    x, d = 0.0, ""
    for i, ch in enumerate("SONAR"):
        name = cmap[ord(ch)]
        pen = SVGPathPen(gs, ntos=lambda v: f"{v:.2f}".rstrip("0").rstrip("."))
        gs[name].draw(TransformPen(pen, (k, 0, 0, -k, x, cap)))
        d += pen.getCommands()
        x += gs[name].width * k + (cap / 0.7) * tracking * (i < 4)
    return d, x


def svg_lockup(word_color, id_="s", mono=None):
    """Знак слева, SONAR справа; высота 100. mono: знак одним цветом, для светлого фона."""
    cap = 26
    d, w = svg_wordmark(cap, word_color)
    gap = 30
    body = (f'<g>{svg_mark_body("M", id_, mono)}</g>'
            f'<path transform="translate({100 + gap - 12} {50 - cap / 2})" d="{d}" fill="{word_color}"/>')
    return svg_doc(body, vb=f"0 0 {100 + gap - 12 + w + 4:.0f} 100", id_=id_)


def write(rel, text):
    p = ROOT / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text, encoding="utf-8")
    print("  ", rel)


# ---------- выгрузка ----------

def save(img, rel, **kw):
    p = ROOT / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    img.save(p, **kw)
    print("  ", rel)


def banner(w=320, h=180):
    """Баннер Android TV: ночь, знак и SONAR по центру."""
    k = 4
    W, H = w * k, h * k
    img = tile(W, rounded=False).resize((W, H))
    m = round(H * 0.5)
    word = wordmark(round(H * 0.085), FOG + (255,))
    gap = round(W * 0.035)
    x = (W - m - gap - word.size[0]) // 2
    img.alpha_composite(mark(m, "M"), (x, (H - m) // 2))
    img.alpha_composite(word, (x + m + gap, (H - word.size[1]) // 2))
    return img.resize((w, h), Image.LANCZOS)


def main():
    print("SVG")
    # в приложении знак стоит в круглой плашке 30 px: поля срезаны, кольца почти до края
    write("assets/images/logo.svg", svg_doc(svg_mark_body("M", "lg"), vb="15 15 70 70", id_="lg"))
    write("assets/images/brand/sonar-mark.svg", svg_doc(svg_mark_body("L")))
    write("assets/images/brand/sonar-mark-small.svg", svg_doc(svg_mark_body("S")))
    write("assets/images/brand/sonar-mark-mono.svg", svg_doc(svg_mark_body("M", mono="currentColor")))
    write("assets/images/brand/sonar-icon.svg", svg_icon("L"))
    write("assets/images/brand/sonar-icon-small.svg", svg_icon("S"))
    write("assets/images/brand/sonar-logo.svg", svg_lockup(hexc(PAPER)))
    write("assets/images/brand/sonar-logo-ink.svg", svg_lockup(hexc(NIGHT), mono=hexc(NIGHT)))

    print("Мастер-иконка")
    save(render(1024), "assets/images/source/sonar_icon_1024.png")
    save(render(512), "assets/images/source/ic_launcher_border.png")

    print("Android")
    dens = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
    for name, k in dens.items():
        res = f"android/app/src/main/res/mipmap-{name}"
        n = round(48 * k)
        save(render(n), f"{res}/ic_launcher.webp", quality=95)
        round_mask = Image.new("L", (n * 4, n * 4), 0)
        ImageDraw.Draw(round_mask).ellipse((0, 0, n * 4 - 1, n * 4 - 1), fill=255)
        rnd = render(n, rounded=False)
        rnd.putalpha(round_mask.resize((n, n), Image.LANCZOS))
        save(rnd, f"{res}/ic_launcher_round.webp", quality=95)
        # адаптивный передний план: 108 dp, рисунок в безопасной зоне 66 dp
        f = round(108 * k)
        save(render(f, rounded=False, bg=False, scale=0.6, level="L" if f >= 256 else "M"), f"{res}/ic_launcher_foreground.png")
        # значок в шторке уведомлений: белый силуэт
        save(render(round(24 * k), rounded=False, bg=False, scale=1.0, mono=(255, 255, 255), level="S"),
             f"android/app/src/main/res/drawable-{name}/ic_stat_logo.png")
    # заставка до Android 12 (фон #070B16 в launch_background) и баннер Android TV
    save(render(432, rounded=False, bg=False, scale=0.6, level="L"), "android/app/src/main/res/drawable-xxxhdpi/splash.png")
    save(banner(), "android/app/src/main/res/mipmap-xhdpi/ic_banner.png")

    print("Windows")
    # каждый размер рисуется отдельно: маленьким нужна толстая петля и крупная капля
    sizes = (16, 24, 32, 48, 64, 128, 256)
    frames = [render(n) for n in sizes]
    for rel in ("windows/runner/resources/app_icon.ico", "assets/images/source/sonar.ico"):
        save(frames[-1], rel, sizes=[(n, n) for n in sizes], append_images=frames[:-1])

    print("Трей: обычный, подключён, отключён, для светлой панели")
    tray = {
        "tray_icon": dict(mono=PAPER),
        "tray_icon_connected": dict(),
        "tray_icon_disconnected": dict(mono=FEATHER),
        "tray_icon_dark": dict(mono=DEEP),
    }
    for name, kw in tray.items():
        frames = [render(n, bg=False, rounded=False, scale=1.0, level="S", **kw) for n in (16, 24, 32, 48, 64)]
        save(frames[-1], f"assets/images/{name}.png")
        save(frames[-1], f"assets/images/{name}.ico", sizes=[(n, n) for n in (16, 24, 32, 48, 64)], append_images=frames[:-1])
        save(frames[-1], f"assets/images/source/{name}.png")

    print("macOS")
    mac = ROOT / "macos/Runner/Assets.xcassets/AppIcon.appiconset"
    if mac.exists():
        for f in mac.glob("*.png"):
            w = Image.open(f).size[0]
            save(render(w), str(f.relative_to(ROOT)))


if __name__ == "__main__":
    main()
