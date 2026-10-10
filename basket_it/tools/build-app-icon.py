#!/usr/bin/env python3
"""Baskit 앱 아이콘을 만든다(웹 홈 화면 추가 + iOS 앱 아이콘).

    python3 tools/build-app-icon.py

스플래시 화면과 같은 모양이다. 주황 바탕(#F97316)에 흰 농구공.
구단 엠블럼이 아니라 이 앱의 아이콘이라 직접 그린다.
"""

import json
from pathlib import Path

from PIL import Image, ImageDraw

ORANGE = (249, 115, 22)
WHITE = (255, 255, 255)
BASE = 1024


def ball(size, inset):
    """주황 바탕에 흰 농구공. [inset]은 공 둘레의 여백 비율."""
    image = Image.new('RGB', (BASE, BASE), ORANGE)
    pad = int(BASE * inset)
    box = (pad, pad, BASE - pad, BASE - pad)
    ImageDraw.Draw(image).ellipse(box, fill=WHITE)

    r = (BASE - 2 * pad) / 2
    cx = cy = BASE / 2
    width = max(6, int(r * 0.1))

    # 솔기는 따로 그린 뒤 공 모양으로 잘라 낸다(밖으로 삐져나가지 않게).
    seams = Image.new('L', (BASE, BASE), 0)
    pen = ImageDraw.Draw(seams)
    pen.line([(cx, cy - r), (cx, cy + r)], fill=255, width=width)
    pen.line([(cx - r, cy), (cx + r, cy)], fill=255, width=width)
    bow, off = r * 0.7, r
    pen.arc(
        [cx - off - bow, cy - r * 1.02, cx - off + bow, cy + r * 1.02],
        start=-90, end=90, fill=255, width=width,
    )
    pen.arc(
        [cx + off - bow, cy - r * 1.02, cx + off + bow, cy + r * 1.02],
        start=90, end=270, fill=255, width=width,
    )
    ball_mask = Image.new('L', (BASE, BASE), 0)
    ImageDraw.Draw(ball_mask).ellipse(box, fill=255)
    seams = Image.composite(seams, Image.new('L', (BASE, BASE), 0), ball_mask)
    image.paste(Image.new('RGB', (BASE, BASE), ORANGE), (0, 0), seams)
    return image.resize((size, size), Image.LANCZOS)


def main():
    web = Path('web/icons')
    web.mkdir(parents=True, exist_ok=True)
    # 홈 화면 아이콘은 iOS가 알아서 둥글게 깎는다. 바탕을 꽉 채워 둔다.
    ball(192, 0.16).save(web / 'Icon-192.png')
    ball(512, 0.16).save(web / 'Icon-512.png')
    # 마스커블: 안드로이드가 더 깎아 내므로 여백을 넉넉히.
    ball(192, 0.26).save(web / 'Icon-maskable-192.png')
    ball(512, 0.26).save(web / 'Icon-maskable-512.png')
    ball(180, 0.16).save(web / 'apple-touch-icon.png')
    ball(32, 0.14).save(Path('web/favicon.png'))

    icons = Path('ios/Runner/Assets.xcassets/AppIcon.appiconset')
    contents = json.loads((icons / 'Contents.json').read_text())
    made = 0
    for item in contents['images']:
        name = item.get('filename')
        if not name:
            continue
        side, _, _ = item['size'].partition('x')
        scale = int(item['scale'].rstrip('x'))
        pixels = round(float(side) * scale)
        ball(pixels, 0.16).save(icons / name)
        made += 1
    print(f'웹 아이콘 6개, iOS 아이콘 {made}개를 만들었습니다.')


if __name__ == '__main__':
    main()
