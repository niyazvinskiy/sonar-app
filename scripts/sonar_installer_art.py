"""Картинки установщика Windows: фон «ночная вода», капля Sonar и значок для шапки.

Inno Setup 6.7 в тёмном стиле кладёт фон под все страницы, каплю показывает на
приветствии и в конце, значок в шапке остальных шагов. Под каждый масштаб экрана
свой файл, установщик сам берёт подходящий.
Запуск из корня репозитория: python scripts/sonar_installer_art.py
"""
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parent.parent / "windows" / "packaging" / "exe" / "art"
NIGHT0 = np.array((7, 11, 22), np.float32)
NIGHT1 = np.array((14, 22, 48), np.float32)
NIGHT2 = np.array((30, 45, 74), np.float32)
INDIGO = np.array((124, 140, 255), np.float32)
AQUA = np.array((94, 234, 212), np.float32)
LAVENDER = np.array((214, 220, 255), np.float32)


def blob(w, h, cx, cy, r, color, alpha):
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.hypot(xx - cx, yy - cy) / r
    a = np.clip(1 - d, 0, 1) ** 2.2 * alpha
    return a[..., None], color


def background(w, h):
    """Ночная вода: сверху светлее, внизу глубже, по краям медленное сияние."""
    yy = np.linspace(0, 1, h, dtype=np.float32)[:, None, None]
    img = NIGHT1 * (1 - yy) + NIGHT0 * yy
    img = np.broadcast_to(img, (h, w, 3)).copy()
    for cx, cy, r, color, alpha in [
        (w * 0.08, h * 1.02, w * 0.62, INDIGO, 0.30),
        (w * 0.98, h * 0.02, w * 0.48, AQUA, 0.13),
        (w * 0.55, h * 1.15, w * 0.55, AQUA, 0.10),
    ]:
        a, c = blob(w, h, cx, cy, r, color, alpha)
        img = img * (1 - a) + c * a
    # тонкая волна у нижнего края, как на сайте
    pic = Image.fromarray(img.clip(0, 255).astype(np.uint8), "RGB").convert("RGBA")
    line = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(line)
    pts = []
    for i in range(241):
        t = i / 240
        y = h * 0.9 + math.sin(t * math.pi * 3.1 + 0.6) * h * 0.018 * (0.4 + t)
        pts.append((w * t, y))
    d.line(pts, fill=(221, 226, 232, 46), width=max(1, round(h / 360)), joint="curve")
    pic = Image.alpha_composite(pic, line.filter(ImageFilter.GaussianBlur(h / 900)))
    # лёгкое зерно против полос на градиенте
    noise = np.random.default_rng(7).normal(0, 1.4, (h, w, 1)).astype(np.float32)
    arr = np.asarray(pic.convert("RGB"), np.float32) + noise
    return Image.fromarray(arr.clip(0, 255).astype(np.uint8), "RGB")


def sphere(size):
    """Перламутровая капля: сиреневый свет сверху, бирюза снизу, блик и ободок."""
    s = size
    yy, xx = np.mgrid[0:s, 0:s].astype(np.float32)
    c = (s - 1) / 2
    nx, ny = (xx - c) / (s / 2), (yy - c) / (s / 2)
    rr = np.hypot(nx, ny)
    inside = np.clip((1 - rr) * s / 2, 0, 1)  # мягкий край в один пиксель
    z = np.sqrt(np.clip(1 - rr**2, 0, 1))
    # свет падает сверху слева
    lx, ly, lz = -0.45, -0.55, 0.7
    ln = math.sqrt(lx * lx + ly * ly + lz * lz)
    diffuse = np.clip((nx * lx + ny * ly + z * lz) / ln, 0, 1)
    t_aqua = np.clip((nx * 0.6 + ny * 0.8 + 0.3) * 0.9, 0, 1)[..., None]
    base = LAVENDER * (1 - t_aqua) + AQUA * t_aqua
    shade = 0.32 + 0.78 * diffuse[..., None]
    col = base * shade
    # блик
    hx, hy = nx + 0.36, ny + 0.42
    spec = np.exp(-(hx**2 + hy**2) / 0.035)[..., None]
    col = col * (1 - spec * 0.85) + 255 * spec * 0.85
    # ободок: край чуть светлее, как у жемчуга
    rim = np.clip((rr - 0.82) / 0.18, 0, 1)[..., None] ** 2 * (1 - diffuse[..., None]) * 0.5
    col = col * (1 - rim) + INDIGO * rim
    rgba = np.dstack([col.clip(0, 255), inside * 255]).astype(np.uint8)
    return Image.fromarray(rgba, "RGBA")


def drop(w, h):
    """Капля с кольцами-импульсами и сиянием на прозрачном фоне: левая колонка мастера."""
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    cx, cy = w / 2, h * 0.43
    r = w * 0.21
    # сияние гаснет раньше края картинки, иначе на фоне виден её прямоугольник
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse((cx - r * 1.5, cy - r * 1.5, cx + r * 1.5, cy + r * 1.5), fill=(124, 140, 255, 46))
    img = Image.alpha_composite(img, glow.filter(ImageFilter.GaussianBlur(w * 0.06)))
    rings = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(rings)
    for k, (rr, a) in enumerate([(1.45, 120), (1.85, 56), (2.25, 22)]):
        width = max(1, round(w * (0.012 if k == 0 else 0.008)))
        color = (94, 234, 212, a) if k == 0 else (221, 226, 232, a)
        d.ellipse((cx - r * rr, cy - r * rr, cx + r * rr, cy + r * rr), outline=color, width=width)
    img = Image.alpha_composite(img, rings)
    ball = sphere(round(r * 2))
    img.alpha_composite(ball, (round(cx - r), round(cy - r)))
    # волна под каплей
    wave = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    pts = []
    base = cy + r * 2.6
    for i in range(121):
        t = i / 120
        x = w * 0.08 + w * 0.84 * t
        y = base + math.sin(t * math.pi * 2.2 + 0.4) * w * 0.035 * (1 - abs(t - 0.5) * 1.4)
        pts.append((x, y))
    ImageDraw.Draw(wave).line(pts, fill=(221, 226, 232, 150), width=max(1, round(w * 0.012)), joint="curve")
    img = Image.alpha_composite(img, wave)
    return img


def small(size):
    """Значок в шапке шагов: капля с одним кольцом."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    c = size / 2
    r = size * 0.27
    ImageDraw.Draw(img).ellipse(
        (c - r * 1.6, c - r * 1.6, c + r * 1.6, c + r * 1.6),
        outline=(94, 234, 212, 150),
        width=max(1, round(size * 0.035)),
    )
    ball = sphere(round(r * 2))
    img.alpha_composite(ball, (round(c - r), round(c - r)))
    return img


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    # фон: соотношение 497:360, размеры для 100, 150, 200 и 250 %
    for w in (596, 894, 1192, 1630):
        background(w, round(w * 360 / 497)).save(OUT / f"back-{w}.png", optimize=True)
    # левая колонка приветствия: 164:314
    for w in (202, 269, 336, 430, 534):
        drop(w, round(w * 314 / 164)).save(OUT / f"drop-{w}.png", optimize=True)
    for s in (58, 73, 87, 116, 145):
        small(s).save(OUT / f"small-{s}.png", optimize=True)
    print("готово:", sorted(p.name for p in OUT.iterdir()))


if __name__ == "__main__":
    main()
