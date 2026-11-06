"""Makes the Roblox experience's icon and thumbnails (roblox/publish/) from the game's screenshots (docs/itch/),
in the cover's style (tools/make_cover.py): the icon is a square crop of the peeling shot with the title; the
thumbnails are the screenshots at 1920x1080, the first with the title on it.
Usage: python3 tools/make_roblox_art.py   (needs Pillow)
"""
import os
from PIL import Image, ImageDraw, ImageFont

OUT = 'roblox/publish'
os.makedirs(OUT, exist_ok=True)


def font(path, size, weight):
    f = ImageFont.truetype(path, size)
    f.set_variation_by_axes([weight])
    return f


def shade_bottom(im, start, strength):
    W, H = im.size
    grad = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(grad)
    for y in range(H):
        a = max(0.0, (y - H * start) / (H * (1 - start)))
        d.line([(0, y), (W, y)], fill=int(strength * a))
    return Image.composite(Image.new('RGB', (W, H), (20, 14, 8)), im, grad)


def title(im, size, y, sub=None, sub_size=0):
    W, H = im.size
    draw = ImageDraw.Draw(im)
    tf = font('assets/fonts/Fredoka.ttf', size, 650)
    t = 'Timber'
    draw.text(((W - draw.textlength(t, font=tf)) / 2, y), t, font=tf, fill=(255, 207, 106),
              stroke_width=max(4, size // 17), stroke_fill=(40, 26, 12))
    if sub:
        sf = font('assets/fonts/Nunito.ttf', sub_size, 800)
        draw.text(((W - draw.textlength(sub, font=sf)) / 2, y + size * 1.12), sub, font=sf, fill=(255, 255, 255),
                  stroke_width=max(2, sub_size // 12), stroke_fill=(30, 20, 10))


# the icon: 512x512, the half-peeled birch and the title
src = Image.open('docs/itch/01_peel.png').convert('RGB')
side = 640
x0 = 320
icon = src.crop((x0, 0, x0 + side, side)).resize((512, 512), Image.LANCZOS)
icon = shade_bottom(icon, 0.5, 200)
title(icon, 132, 330)
icon.save(f'{OUT}/icon_512.png')
print(f'{OUT}/icon_512.png', icon.size)

# the thumbnails: 1920x1080, in the order a player should see them
shots = ['01_peel', '02_truck', '03_factory', '04_rails_drone', '05_build', '06_shop']
for n, name in enumerate(shots, 1):
    im = Image.open(f'docs/itch/{name}.png').convert('RGB').resize((1920, 1080), Image.LANCZOS)
    if n == 1:
        im = shade_bottom(im, 0.55, 190)
        title(im, 230, 640, 'Peel it. Fell it. Build something bigger.', 54)
    path = f'{OUT}/thumbnail_{n}_{name.split("_", 1)[1]}.jpg'
    im.save(path, quality=92)
    print(path, im.size)

# "what's new": the truck screenshot with tonight's features on it (text on thumbnails is what players click for)
im = Image.open('docs/itch/02_truck.png').convert('RGB').resize((1920, 1080), Image.LANCZOS)
im = shade_bottom(im, 0.25, 215)
d = ImageDraw.Draw(im)
hf = font('assets/fonts/Fredoka.ttf', 120, 650)
d.text((110, 430), 'NEW in Timber', font=hf, fill=(255, 207, 106), stroke_width=8, stroke_fill=(40, 26, 12))
lf = font('assets/fonts/Nunito.ttf', 62, 800)
for k, line in enumerate(['Golden tree every 15 minutes: 5x bark', 'Daily jobs and rewards on your phone',
                          'Play with a friend: +10% at the mill', 'Codes: TIMBER and LUMBERJACK']):
    d.text((120, 600 + k * 92), '- ' + line, font=lf, fill=(255, 255, 255), stroke_width=4, stroke_fill=(30, 20, 10))
im.save(f'{OUT}/thumbnail_0_new.jpg', quality=92)
print(f'{OUT}/thumbnail_0_new.jpg', im.size)

# badge icons: 512x512 (Roblox shows them in a circle), one per trophy, for roblox/publish/badges/
BADGES = [
    ('welcome', 'Welcome', 'to Timber'), ('first_tree', 'Timber!', 'first tree felled'),
    ('first_machine', 'Machinist', 'first machine'), ('thousand', '$1,000', 'earned'),
    ('first_plank', 'Sawyer', 'first planks'), ('first_iron', 'Smelter', 'first iron bar'),
    ('first_furniture', 'Carpenter', 'first furniture'), ('giant', 'Giant', 'an ancient giant felled'),
    ('legend', 'Legend', 'the Legendary Tree'), ('first_oil', 'Oil!', 'first barrel of oil'),
    ('golden', 'Golden!', 'felled the golden tree'), ('week', '7 Days', 'a week in a row'),
    ('jobs', 'Hired!', "all of a day's jobs"),
]
os.makedirs(f'{OUT}/badges', exist_ok=True)
bg = Image.open('docs/itch/01_peel.png').convert('RGB').crop((320, 0, 960, 640)).resize((512, 512), Image.LANCZOS)
for key, big, small in BADGES:
    im = bg.copy()
    d = ImageDraw.Draw(im, 'RGBA')
    d.ellipse((36, 36, 476, 476), fill=(40, 26, 12, 190), outline=(255, 207, 106, 255), width=14)
    size = 112 if len(big) <= 7 else 92
    bf = font('assets/fonts/Fredoka.ttf', size, 650)
    d.text(((512 - d.textlength(big, font=bf)) / 2, 170), big, font=bf, fill=(255, 207, 106), stroke_width=6, stroke_fill=(40, 26, 12))
    sf = font('assets/fonts/Nunito.ttf', 34, 800)
    d.text(((512 - d.textlength(small, font=sf)) / 2, 318), small, font=sf, fill=(255, 255, 255), stroke_width=3, stroke_fill=(30, 20, 10))
    path = f'{OUT}/badges/{key}.png'
    im.save(path)
print(f'{OUT}/badges/: {len(BADGES)} badge icons')
