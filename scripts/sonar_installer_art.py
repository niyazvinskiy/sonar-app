"""Картинки установщика Windows: фон «ночная вода», знак Sonar и значок для шапки.

Inno Setup 6.7 в тёмном стиле кладёт фон под все страницы, знак показывает на
приветствии и в конце, значок в шапке остальных шагов. Под каждый масштаб экрана
свой файл, установщик сам берёт подходящий.
Запуск из корня репозитория: python scripts/sonar_installer_art.py
"""
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from sonar_icons import mark, render, wordmark

OUT = Path(__file__).resolve().parent.parent / "windows" / "packaging" / "exe" / "art"
NIGHT0 = np.array((7, 11, 22), np.float32)
NIGHT1 = np.array((14, 22, 48), np.float32)
NIGHT2 = np.array((30, 45, 74), np.float32)
INDIGO = np.array((124, 140, 255), np.float32)
AQUA = np.array((94, 234, 212), np.float32)


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


def drop(w, h):
    """Знак Sonar с сиянием и надписью на прозрачном фоне: левая колонка мастера."""
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    k = 4  # рисуем вчетверо крупнее, потом уменьшаем
    m = round(w * 0.86) * k
    big = Image.new("RGBA", (w * k, h * k), (0, 0, 0, 0))
    cy = round(h * k * 0.42)
    big.alpha_composite(mark(m, "L"), ((w * k - m) // 2, cy - m // 2))
    word = wordmark(round(w * k * 0.055), (221, 226, 232, 230))
    big.alpha_composite(word, ((w * k - word.size[0]) // 2, cy + round(m * 0.5) + round(w * k * 0.06)))
    return Image.alpha_composite(img, big.resize((w, h), Image.LANCZOS))


def small(size):
    """Значок в шапке шагов: знак без плитки."""
    return render(size, bg=False, rounded=False, scale=1.0, level="M" if size >= 72 else "S")


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
