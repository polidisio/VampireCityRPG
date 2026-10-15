"""Procesa los JPEG generados (~/Downloads/nivel1) en sprites del piso 1.
Uso: python3 tools/make_floor1.py [carpeta_origen]   (necesita Pillow y numpy)
"""
import sys, os, glob
from collections import deque
import numpy as np
from PIL import Image

SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/Downloads/nivel1")
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "floor1")
os.makedirs(OUT, exist_ok=True)

def load(name):
    return Image.open(os.path.join(SRC, name)).convert("RGB")

def seamless(im, size, axes="xy"):
    """Hace repetible una imagen mezclando con su versión desplazada medio tile (borde invisible)."""
    a = np.asarray(im.resize(size, Image.LANCZOS), dtype=np.float32)
    h, w = a.shape[:2]
    sh = np.roll(a, (h // 2 if "y" in axes else 0, w // 2 if "x" in axes else 0), axis=(0, 1))
    mx = np.minimum(np.arange(w), np.arange(w)[::-1]) / (w / 2) if "x" in axes else np.ones(w)
    my = np.minimum(np.arange(h), np.arange(h)[::-1]) / (h / 2) if "y" in axes else np.ones(h)
    m = np.minimum(my[:, None], mx[None, :])[..., None]
    m = np.clip(m * 1.6, 0, 1)  # el centro del original domina; la costura queda en el desplazado
    return Image.fromarray((a * m + sh * (1 - m)).astype(np.uint8))

def key_bg(im, thresh=75):
    """Quita el fondo morado/magenta por inundación desde los bordes. Devuelve RGBA."""
    a = np.asarray(im, dtype=np.int32)
    h, w = a.shape[:2]
    bg = np.median(np.concatenate([a[:6, :6].reshape(-1, 3), a[:6, -6:].reshape(-1, 3), a[-6:, :6].reshape(-1, 3)]), axis=0)
    near = np.abs(a - bg).sum(axis=2) < thresh
    seen = np.zeros((h, w), bool)
    q = deque([(y, x) for y in range(h) for x in (0, w - 1)] + [(y, x) for x in range(w) for y in (0, h - 1)])
    while q:
        y, x = q.popleft()
        if 0 <= y < h and 0 <= x < w and not seen[y, x] and near[y, x]:
            seen[y, x] = True
            q.extend([(y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)])
    alpha = np.where(seen, 0, 255).astype(np.uint8)
    out = np.dstack([a.astype(np.uint8), alpha])
    return Image.fromarray(out, "RGBA")

def components(rgba, grow=7, min_area=900):
    """Cajas (x0,y0,x1,y1) de objetos sueltos; `grow` funde llamas y partes cercanas."""
    al = np.asarray(rgba)[..., 3] > 0
    h, w = al.shape
    pad = np.pad(al, grow)
    d = np.zeros_like(al)
    for dy in range(-grow, grow + 1):
        for dx in range(-grow, grow + 1):
            d |= pad[grow + dy:grow + dy + h, grow + dx:grow + dx + w]
    seen = np.zeros_like(d)
    boxes = []
    for sy in range(h):
        for sx in range(w):
            if d[sy, sx] and not seen[sy, sx]:
                q, pts = deque([(sy, sx)]), []
                seen[sy, sx] = True
                while q:
                    y, x = q.popleft(); pts.append((y, x))
                    for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                        if 0 <= ny < h and 0 <= nx < w and d[ny, nx] and not seen[ny, nx]:
                            seen[ny, nx] = True; q.append((ny, nx))
                ys, xs = zip(*pts)
                if len(pts) > min_area:
                    boxes.append((min(xs), min(ys), max(xs) + 1, max(ys) + 1))
    return sorted(boxes, key=lambda b: (b[1] // 120, b[0]))

def sheet(name, prefix, scale, keep, grow=7, min_area=900):
    """Recorta los objetos de una hoja; `keep` = índices de la detección que se conservan (se renumeran)."""
    rgba = key_bg(load(name))
    boxes = components(rgba, grow=grow, min_area=min_area)
    for i, (x0, y0, x1, y1) in enumerate([boxes[k] for k in keep]):
        sp = rgba.crop((x0, y0, x1, y1))
        sp = sp.resize((max(1, round(sp.width * scale)), max(1, round(sp.height * scale))), Image.LANCZOS)
        sp.save(os.path.join(OUT, f"{prefix}_{i}.png"))
        print(prefix, i, sp.size)

# suelo: recortes sin antorchas ni marco, repetibles
seamless(load("ground_a.jpeg").crop((295, 150, 602, 457)), (64, 64)).save(os.path.join(OUT, "ground_a.png"))
seamless(load("ground_b.jpeg").crop((300, 130, 570, 400)), (64, 64)).save(os.path.join(OUT, "ground_b.png"))
# props sin la lápida flanqueada por velas (6, se fusiona con ellas); decals: salpicadura, sangre+huesos x2, telaraña (el resto son trozos de muro)
sheet("props.jpeg", "prop", 0.2, [0, 1, 2, 3, 4, 5, 7, 8, 9, 10, 11, 12, 13], grow=4, min_area=300)
sheet("decals..jpeg", "decal", 0.3, [0, 4, 5, 7])
# muros: cima de muro (repetible en horizontal) y ladrillo liso (repetible en ambos ejes), de block_h entre sus dos antorchas
wall = load("block_h.jpeg")
cap = wall.crop((330, 172, 458, 204))  # repetible en x reflejándola (mezclar aquí deshace las piedras de la cima)
mir = Image.new("RGB", (256, 32)); mir.paste(cap, (0, 0)); mir.paste(cap.transpose(Image.FLIP_LEFT_RIGHT), (128, 0))
mir.resize((128, 16), Image.LANCZOS).save(os.path.join(OUT, "wall_cap.png"))
seamless(wall.crop((330, 212, 458, 340)), (64, 64)).save(os.path.join(OUT, "wall_brick.png"))
