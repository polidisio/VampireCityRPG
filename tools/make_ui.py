"""Genera los 9-slice de botón (assets/ui/btn_*.png), 8x8, esquinas recortadas y bisel."""
from PIL import Image
STATES = {  # fondo, luz, sombra, borde
    "normal":  ((52, 31, 52), (92, 56, 82), (30, 16, 32), (115, 51, 77)),
    "hover":   ((102, 38, 56), (158, 80, 92), (60, 20, 34), (230, 102, 102)),
    "pressed": ((140, 51, 64), (90, 28, 44), (170, 76, 84), (255, 153, 128)),
}
for name, (bg, lit, sh, bd) in STATES.items():
    im = Image.new("RGBA", (8, 8), bg + (255,))
    for i in range(8):
        for j in range(8):
            if i in (0, 7) or j in (0, 7):
                im.putpixel((i, j), bd + (255,))
            elif j == 1 or i == 1:
                im.putpixel((i, j), lit + (255,))
            elif j == 6 or i == 6:
                im.putpixel((i, j), sh + (255,))
    for c in [(0, 0), (7, 0), (0, 7), (7, 7)]:
        im.putpixel(c, (0, 0, 0, 0))  # esquina recortada
    im.save(f"assets/ui/btn_{name}.png")
