from PIL import Image, ImageDraw
S = 1024
big = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(big)
d.rounded_rectangle((212, 212, 812, 812), radius=70, fill=(25, 25, 28, 255))
d.rectangle((432, 432, 592, 592), fill=(0, 0, 0, 0))
tile = big.rotate(-15, resample=Image.BICUBIC)
icon = Image.new("RGB", (S, S), (255, 255, 255))
icon.paste(tile, (0, 0), tile)
icon.save("App/Assets.xcassets/AppIcon.appiconset/icon.png")
