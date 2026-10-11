import math
from PIL import Image, ImageDraw
S = 1024 * 4
BLUE = (51, 95, 255)
def square(side, deg=15):
    c, h, a = S / 2, side * S / 2, math.radians(deg)
    return [(c + x * math.cos(a) - y * math.sin(a), c + x * math.sin(a) + y * math.cos(a))
            for x, y in ((-h, -h), (h, -h), (h, h), (-h, h))]
icon = Image.new("RGB", (S, S), BLUE)
d = ImageDraw.Draw(icon)
d.polygon(square(0.6125), fill=(255, 255, 255))
d.polygon(square(0.1875), fill=BLUE)
icon.resize((1024, 1024), Image.LANCZOS).save("App/Assets.xcassets/AppIcon.appiconset/icon.png")
