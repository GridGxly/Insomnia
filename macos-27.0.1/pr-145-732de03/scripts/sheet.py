# sheet.py OUT DIR LABEL=FILE...: rows of a label and a menu bar crop
# (640x34, the left 150 px dropped), like the earlier pill-click sheets.
import sys
from PIL import Image, ImageDraw, ImageFont
out, d, rows = sys.argv[1], sys.argv[2], [a.split("=", 1) for a in sys.argv[3:]]
font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 11)
lw, iw, rh = 260, 490, 38
sheet = Image.new("RGB", (lw + iw, rh * len(rows)), "white")
draw = ImageDraw.Draw(sheet)
for i, (label, name) in enumerate(rows):
    im = Image.open(f"{d}/{name}").convert("RGB")
    im = im.crop((im.width - iw, 0, im.width, im.height))
    sheet.paste(im, (lw, i * rh + (rh - im.height) // 2))
    draw.text((6, i * rh + rh // 2), label, fill="black", font=font, anchor="lm")
sheet.save(out)
print(out, sheet.size)
