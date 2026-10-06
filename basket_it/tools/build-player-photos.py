#!/usr/bin/env python3
"""지금 뛰는 선수 사진을 내려받아 앱 자산으로 만든다.

KBL 공식 사진(players-photo)은 CORS 헤더가 없다. 웹에서는 Flutter가 사진을
직접 받지 못해 브라우저에게 <img>로 맡기는데, 그 요소가 목록마다 겹겹이
깔리면서 스크롤이 끊기고 다른 선수의 얼굴이 남기도 했다. 한 번 내려받아
작은 정사각형으로 잘라 앱에 넣으면 둘 다 사라진다.

    python3 tools/build-player-photos.py

선수 명단은 수집기가 올려 둔 kbl/players.json(현역 전원)에서 읽는다. 사진은
선수 id로만 찾는다(기록을 준 API가 함께 준 id라 이름·기록과 늘 같은 사람이다).
얼굴이 가운데 오도록 전신 사진은 윗부분을 잘라 쓴다.

받은 id는 lib/data/player_photos.dart에 적어 둔다. 앱은 그 목록에 있는
선수만 자산을 쓰고, 없으면 KBL 서버에서 불러온다.
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
ROSTER_URL = (
    'https://junmin061101-del.github.io/Basketball-Application/kbl/players.json'
)
OUT_DIR = Path('assets/photos')
ID_LIST = Path('lib/data/player_photos.dart')
# 54-0 게임 명단(지난 시즌 기록). 리그를 떠난 선수가 섞여 있어 함께 받아 둔다.
GAME_LIST = Path('assets/game/kbl_players_54_0.json')
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


def wanted_ids():
    """사진이 필요한 선수 id. 현역 명단과 54-0 게임 명단을 합친다."""
    request = urllib.request.Request(
        ROSTER_URL, headers={'User-Agent': 'Baskit/1.0 (+KBL fan app)'}
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        players = json.loads(response.read())['players']
    if GAME_LIST.exists():
        players += json.loads(GAME_LIST.read_text())['players']
    seen, ids = set(), []
    for player in players:
        if player['id'] not in seen:
            seen.add(player['id'])
            ids.append(player['id'])
    return ids


def write_id_list(ids):
    body = ',\n  '.join(f"'{i}'" for i in sorted(ids))
    ID_LIST.write_text(
        "// tools/build-player-photos.py가 만든다. 직접 고치지 않는다.\n"
        "\n"
        "/// 앱에 얼굴 사진을 넣어 둔 선수.\n"
        "///\n"
        "/// KBL 사진 서버는 CORS 헤더가 없어서, 웹에서 바로 불러오면 브라우저가\n"
        "/// 그리는 <img> 요소가 목록마다 깔려 스크롤이 끊긴다.\n"
        "const playerPhotoIds = <String>{\n"
        f"  {body},\n"
        "};\n"
        "\n"
        "/// 넣어 둔 사진 경로. 없으면 null(KBL 서버에서 불러온다).\n"
        "String? playerPhotoAsset(String id) =>\n"
        "    playerPhotoIds.contains(id) ? 'assets/photos/$id.jpg' : null;\n"
    )


def main():
    ids = wanted_ids()
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    def one(player_id):
        path = OUT_DIR / f'{player_id}.jpg'
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
            if index % 50 == 0:
                print(f'  {index}/{len(ids)}')

    # 명단에서 빠진 선수의 사진은 지운다(은퇴·이적으로 더는 안 쓴다).
    for file in OUT_DIR.glob('*.jpg'):
        if file.stem not in saved:
            file.unlink()

    write_id_list(saved)
    total = sum(f.stat().st_size for f in OUT_DIR.glob('*.jpg'))
    print(f'사진 {len(saved)}명 / 사진 없음 {len(failed)} / {total // 1024}KB')
    return 0


if __name__ == '__main__':
    sys.exit(main())
