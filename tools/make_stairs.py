"""Trampilla de bajada vista desde arriba (marco de piedra, hueco negro y escalera de mano) -> assets/sprites/npcs/escaleras_map.png
Uso: python3 tools/make_stairs.py   (necesita Pillow)
"""
import os
from PIL import Image, ImageDraw

im = Image.new("RGBA", (26, 24), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
d.rounded_rectangle((0, 0, 25, 23), 3, fill=(12, 10, 24))      # contorno
d.rounded_rectangle((1, 1, 24, 22), 2, fill=(78, 74, 110))     # marco de piedra
d.line((3, 1, 22, 1), fill=(118, 112, 160))                    # luz en el borde superior
d.rectangle((4, 4, 21, 19), fill=(4, 3, 10))                   # hueco
for x in (8, 17):                                              # largueros
    d.line((x, 5, x, 18), fill=(120, 100, 80))
for y in range(7, 19, 3):                                      # peldaños
    d.line((8, y, 17, y), fill=(150, 125, 95))
for p in ((3, 3), (22, 3), (3, 20), (22, 20)):                 # remaches
    d.point(p, fill=(150, 150, 190))
im.save(os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "npcs", "escaleras_map.png"))
