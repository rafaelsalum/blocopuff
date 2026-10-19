"""Gera as texturas PBR procedurais dos materiais do BlocoPuff.

Cada material sai com ColorMap neutro e claro (cinza, para que a cor de cada
peça defina o tom), NormalMap no padrão OpenGL usado pelo Roblox e
RoughnessMap. Todas as imagens repetem sem emenda (tileable).

Uso:
    python3 tools/materials/generate_materials.py <pasta-de-saída>
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

SIZE = 1024
SEED = 20261018


def periodic_noise(rng: np.random.Generator, beta: float, elongate_x: float = 1.0) -> np.ndarray:
    """Ruído fractal periódico (1/f^beta) normalizado para [-1, 1].

    elongate_x > 1 estica as manchas na horizontal (veios de madeira,
    camadas de pedra).
    """
    white = rng.standard_normal((SIZE, SIZE))
    fy = np.fft.fftfreq(SIZE)[:, None]
    fx = np.fft.fftfreq(SIZE)[None, :] * elongate_x
    radius = np.sqrt(fx * fx + fy * fy)
    radius[0, 0] = 1.0
    spectrum = np.fft.fft2(white) / radius**beta
    spectrum[0, 0] = 0.0
    field = np.real(np.fft.ifft2(spectrum))
    return field / np.max(np.abs(field))


def to_color(height: np.ndarray, mean: float, spread: float) -> np.ndarray:
    value = np.clip(mean + height * spread, 0, 255)
    return np.repeat(value[:, :, None], 3, axis=2).astype(np.uint8)


def to_normal(height: np.ndarray, strength: float) -> np.ndarray:
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 0.5
    drow = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * 0.5
    nx = -dx * strength
    ny = drow * strength
    nz = np.ones_like(height)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    normal = np.stack([nx / length, ny / length, nz / length], axis=2)
    return ((normal + 1.0) * 127.5).astype(np.uint8)


def to_gray(value: np.ndarray) -> np.ndarray:
    return np.clip(value * 255, 0, 255).astype(np.uint8)


def plaster(rng: np.random.Generator) -> dict[str, np.ndarray]:
    broad = periodic_noise(rng, 1.6)
    fine = periodic_noise(rng, 0.6)
    height = broad * 0.7 + fine * 0.3
    return {
        "Color": to_color(broad * 0.8 + fine * 0.2, 226, 14),
        "Normal": to_normal(height, 6.0),
        "Roughness": to_gray(0.88 + fine * 0.05),
    }


def wood_grain(rng: np.random.Generator) -> np.ndarray:
    """Veios na horizontal: fibras finas e anéis de crescimento finos e
    escuros, que se curvam suavemente ao longo da tábua."""
    fibers = periodic_noise(rng, 0.9, elongate_x=40.0)
    bend = periodic_noise(rng, 2.2, elongate_x=4.0) * 7.0
    rows = np.arange(SIZE)[:, None] / SIZE * 2 * np.pi * 14
    rings = np.abs(np.sin((rows + bend) * 0.5)) ** 8
    return fibers * 0.55 - rings * 0.9


def wood(rng: np.random.Generator) -> dict[str, np.ndarray]:
    grain = wood_grain(rng)
    pores = periodic_noise(rng, 0.3, elongate_x=10.0)
    return {
        "Color": to_color(grain * 0.85 + pores * 0.15, 214, 26),
        "Normal": to_normal(grain * 0.4 + pores * 0.6, 3.0),
        "Roughness": to_gray(0.5 + grain * 0.08),
    }


def wood_planks(rng: np.random.Generator) -> dict[str, np.ndarray]:
    grain = wood_grain(rng)
    rows_count = 4
    board_height = SIZE // rows_count
    board_length = SIZE // 2
    tone = np.zeros((SIZE, SIZE))
    seam = np.zeros((SIZE, SIZE))
    # Cada tábua usa um trecho diferente dos veios, como peças cortadas de
    # toras diferentes.
    board_grain = np.zeros((SIZE, SIZE))
    for row in range(rows_count):
        top = row * board_height
        offset = (row * board_length // 2 + rng.integers(0, board_length // 4)) % SIZE
        for board in range(SIZE // board_length):
            start = (offset + board * board_length) % SIZE
            columns = (np.arange(board_length) + start) % SIZE
            tone[top : top + board_height, columns] = rng.uniform(-1, 1)
            shift = int(rng.integers(0, SIZE))
            board_rows = (np.arange(top, top + board_height) + shift) % SIZE
            board_grain[top : top + board_height, columns] = grain[board_rows][:, columns]
            seam[top : top + board_height, start] = 1.0
        seam[top, :] = 1.0
    seam = np.maximum(seam, np.roll(seam, 1, axis=0) * 0.6)
    seam = np.maximum(seam, np.roll(seam, 1, axis=1) * 0.6)
    surface = board_grain * 0.75 + tone * 0.25
    color = to_color(surface, 212, 26).astype(np.float64)
    color *= (1.0 - seam * 0.45)[:, :, None]
    height = board_grain * 0.15 - seam * 1.0
    return {
        "Color": color.astype(np.uint8),
        "Normal": to_normal(height, 4.0),
        "Roughness": to_gray(0.48 + seam * 0.35 + board_grain * 0.06),
    }


def slate(rng: np.random.Generator) -> dict[str, np.ndarray]:
    layers = periodic_noise(rng, 1.4, elongate_x=3.0)
    chips = periodic_noise(rng, 0.9)
    height = layers * 0.6 + chips * 0.4
    return {
        "Color": to_color(layers * 0.7 + chips * 0.3, 206, 22),
        "Normal": to_normal(height, 9.0),
        "Roughness": to_gray(0.68 + chips * 0.08),
    }


def fabric(rng: np.random.Generator) -> dict[str, np.ndarray]:
    period = 8
    ys, xs = np.mgrid[0:SIZE, 0:SIZE]
    warp = np.sin(2 * np.pi * xs / period) * np.sign(np.sin(np.pi * ys / period))
    weft = np.sin(2 * np.pi * ys / period) * -np.sign(np.sin(np.pi * xs / period))
    weave = (warp + weft) * 0.5
    fuzz = periodic_noise(rng, 1.0)
    return {
        "Color": to_color(weave * 0.4 + fuzz * 0.6, 222, 14),
        "Normal": to_normal(weave * 0.6 + fuzz * 0.4, 2.5),
        "Roughness": to_gray(0.95 + fuzz * 0.03),
    }


MATERIALS = {
    "Plaster": plaster,
    "WoodPlanks": wood_planks,
    "Wood": wood,
    "Slate": slate,
    "Fabric": fabric,
}


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("uso: generate_materials.py <pasta-de-saída>")
    output = Path(sys.argv[1])
    output.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(SEED)
    for name, build in MATERIALS.items():
        for kind, pixels in build(rng).items():
            path = output / f"BlocoPuff{name}_{kind}.png"
            Image.fromarray(pixels).save(path, optimize=True)
            print(f"{path.name} média={pixels.mean():.0f}")


if __name__ == "__main__":
    main()
