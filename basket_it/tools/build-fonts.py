#!/usr/bin/env python3
"""앱 글꼴(Pretendard)을 한글 표준 2,350자 + 자주 쓰는 기호만 남겨 줄인다.

정식 Pretendard는 한글 11,172자가 다 들어 있어 굵기마다 1.5MB다. 4개면 6MB라
웹 앱이 켜질 때마다 받기 무겁다. KS X 1001 완성형 2,350자에 없는 드문 글자는
Flutter가 Noto Sans KR로 대신 그린다.

사용: pip install fonttools
      python3 tools/build-fonts.py <정식 Pretendard-*.otf가 있는 폴더>
원본: https://github.com/orioncactus/pretendard (SIL OFL 1.1, assets/fonts/OFL.txt)
"""
import pathlib
import sys

from fontTools import subset

# 500·900은 뺀다(가까운 굵기로 그린다). 굵기 하나가 400KB라 켜질 때 받는 양을 줄인다.
WEIGHTS = ['Regular', 'SemiBold', 'Bold', 'ExtraBold']
OUT = pathlib.Path(__file__).resolve().parent.parent / 'assets' / 'fonts'


def ks_x_1001_hangul():
    """EUC-KR 완성형 한글 영역(B0A1–C8FE)을 풀면 2,350자가 나온다."""
    chars = set()
    for lead in range(0xB0, 0xC9):
        for trail in range(0xA1, 0xFF):
            try:
                chars.add(ord(bytes([lead, trail]).decode('euc-kr')))
            except UnicodeDecodeError:
                pass
    return chars


def ranges(*pairs):
    return {c for lo, hi in pairs for c in range(lo, hi + 1)}


UNICODES = ks_x_1001_hangul() | ranges(
    (0x0020, 0x00FF),  # 영문·숫자·라틴-1
    (0x2000, 0x206F),  # 따옴표·말줄임표 등 문장부호
    (0x2100, 0x214F),  # ℃ № ™
    (0x2190, 0x21FF),  # 화살표
    (0x2200, 0x22FF),  # 수학 기호(∼ × ÷)
    (0x2460, 0x24FF),  # ①②
    (0x25A0, 0x25FF),  # ■ ▲ ●
    (0x2600, 0x26FF),  # ★ ☆
    (0x3000, 0x303F),  # 「」 『』 〈〉
    (0x3131, 0x318E),  # ㄱ ㅋ ㅠ
    (0x3200, 0x32FF),  # ㈜ ㉠
    (0xFF01, 0xFF5E),  # 전각 기호
)


def main():
    src = pathlib.Path(sys.argv[1])
    for weight in WEIGHTS:
        out = OUT / f'Pretendard-{weight}.otf'
        options = subset.Options()
        options.layout_features = ['*']  # 숫자 고정폭(tnum) 등을 남긴다
        options.name_IDs = ['*']
        font = subset.load_font(str(src / f'Pretendard-{weight}.otf'), options)
        subsetter = subset.Subsetter(options)
        subsetter.populate(unicodes=UNICODES)
        subsetter.subset(font)
        # 지난번엔 한글이 없는 Pretendard Std를 넣어 한글이 전부 글꼴 내려받기로
        # 그려졌다. 한글이 다 들어갔는지 확인한다.
        hangul = sum(1 for c in font.getBestCmap() if 0xAC00 <= c <= 0xD7A3)
        assert hangul == 2350, f'{weight}: 한글 {hangul}자'
        subset.save_font(font, str(out), options)
        print(out.name, out.stat().st_size // 1024, 'KB')


if __name__ == '__main__':
    main()
