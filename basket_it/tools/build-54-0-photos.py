#!/usr/bin/env python3
"""54-0 게임에 쓸 선수 사진을 내려받아 앱 자산으로 만든다.

KBL 공식 사진(api.kbl.or.kr가 알려주는 players-photo)은 CORS 헤더가 없어서
웹에서는 브라우저가 직접 그릴 수밖에 없고, 그러면 목록을 넘길 때 다른 선수의
얼굴이 남는다. 그래서 한 번 내려받아 작은 정사각형으로 잘라 앱에 넣는다.

    python3 tools/build-54-0-photos.py assets/game/kbl_players_54_0.json

사진은 선수 id로만 찾는다(기록을 준 API가 함께 준 id라, 이름·기록과 늘 같은
사람이다). 얼굴이 가운데 오도록 전신 사진은 윗부분을 잘라 쓴다.
"""

import io
import json
import sys
from concurrent.futures import ThreadPoolExecutor
import urllib.error
import urllib.request
from pathlib import Path

from PIL import Image

PHOTO_URL = 'https://kbl.or.kr/files/kbl/players-photo/{id}.png'
SIZE = 128
QUALITY = 78


def head_square(image):
    """얼굴이 들어가도록 정사각형으로 자른다.

    증명사진은 가운데를, 전신 사진은 위쪽(머리·어깨)을 쓴다.
    """
    width, height = image.size
    if height / width <= 1.2:  # 증명사진
        side = min(width, height)
        left = (width - side) // 2
        top = (height - side) // 2
    else:  # 전신 사진
        side = min(width, int(height * 0.42))
        left = (width - side) // 2
        top = int(height * 0.02)
    return image.crop((left, top, left + side, top + side))


def fetch(player_id):
    request = urllib.request.Request(
        PHOTO_URL.format(id=player_id),
        headers={'User-Agent': 'Baskit/1.0 (+KBL fan app)'},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.read()


def save(raw, path):
    image = Image.open(io.BytesIO(raw))
    if image.mode != 'RGB':
        image = image.convert('RGB')
    image = head_square(image).resize((SIZE, SIZE), Image.LANCZOS)
    image.save(path, 'JPEG', quality=QUALITY, optimize=True)


def main():
    if len(sys.argv) < 2:
        print('사용법: build-54-0-photos.py <선수 명단 JSON> [내려받을 수]')
        return 1
    source = Path(sys.argv[1])
    limit = int(sys.argv[2]) if len(sys.argv) > 2 else None
    data = json.loads(source.read_text())
    players = data['players']

    out_dir = source.parent / 'photos'
    out_dir.mkdir(parents=True, exist_ok=True)

    ids = []
    seen = set()
    for player in players:
        if player['id'] not in seen:
            seen.add(player['id'])
            ids.append(player['id'])
    if limit:
        ids = ids[:limit]

    def one(player_id):
        path = out_dir / f'{player_id}.jpg'
        if path.exists():
            return player_id, None
        try:
            save(fetch(player_id), path)
            return player_id, None
        except (urllib.error.URLError, OSError, ValueError) as error:
            return None, f'{player_id}: {error}'

    saved, failed = set(), []
    with ThreadPoolExecutor(max_workers=8) as pool:
        for index, (player_id, error) in enumerate(pool.map(one, ids), 1):
            if player_id:
                saved.add(player_id)
            else:
                failed.append(error)
            if index % 200 == 0:
                print(f'  {index}/{len(ids)}')

    # 사진이 있는 선수만 표시해 둔다(없으면 앱이 이름 첫 글자를 보여준다).
    for player in players:
        player['hasPhoto'] = player['id'] in saved
    source.write_text(json.dumps(data, ensure_ascii=False))

    total = sum(f.stat().st_size for f in out_dir.glob('*.jpg'))
    print(f'사진 {len(saved)}명 / 실패 {len(failed)} / {total // 1024}KB')
    for line in failed[:10]:
        print('  실패', line)
    return 0


if __name__ == '__main__':
    sys.exit(main())
