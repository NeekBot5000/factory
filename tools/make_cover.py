"""Makes the itch.io cover (docs/itch/cover_630x500.png) from the peeling screenshot, with the title on it.
Usage: python3 tools/make_cover.py   (needs Pillow)
"""
from PIL import Image, ImageDraw, ImageFont

src = Image.open('docs/itch/01_peel.png').convert('RGB')
W, H = 630, 500
scale = H / 720 * 1.15
im = src.resize((int(1280 * scale), int(720 * scale)), Image.LANCZOS)
x0 = int(im.width * 0.5 - W * 0.5) - 40
y0 = int((im.height - H) * 0.5)
im = im.crop((x0, y0, x0 + W, y0 + H))
# darken the bottom half for the title
grad = Image.new('L', (W, H), 0)
d = ImageDraw.Draw(grad)
for y in range(H):
    a = max(0, (y - H * 0.45) / (H * 0.55))
    d.line([(0, y), (W, y)], fill=int(210 * a))
im = Image.composite(Image.new('RGB', (W, H), (20, 14, 8)), im, grad)
draw = ImageDraw.Draw(im)
title_font = ImageFont.truetype('assets/fonts/Fredoka.ttf', 118)
title_font.set_variation_by_axes([650])
sub_font = ImageFont.truetype('assets/fonts/Nunito.ttf', 26)
sub_font.set_variation_by_axes([800])
t = 'Timber'
draw.text(((W - draw.textlength(t, font=title_font)) / 2, H - 205), t, font=title_font, fill=(255, 207, 106), stroke_width=7, stroke_fill=(40, 26, 12))
s = 'Peel it. Fell it. Build something bigger.'
draw.text(((W - draw.textlength(s, font=sub_font)) / 2, H - 62), s, font=sub_font, fill=(255, 255, 255), stroke_width=2, stroke_fill=(30, 20, 10))
im.save('docs/itch/cover_630x500.png')
print('docs/itch/cover_630x500.png', im.size)
