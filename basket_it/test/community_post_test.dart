import 'package:basket_it/data/models/community_post.dart';
import 'package:basket_it/data/models/league.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('게시글 맵 변환이 왕복한다', () {
    const post = CommunityPost(
      id: 'p1',
      uid: 'u1',
      displayName: '강*수',
      category: PostCategory.question,
      title: '오늘 경기 어디서 보나요',
      body: '중계 채널 아시는 분',
      commentCount: 3,
      likedBy: ['u2', 'u3'],
    );

    final restored = CommunityPost.fromMap('p1', post.toMap());

    expect(restored, isNotNull);
    expect(restored!.title, '오늘 경기 어디서 보나요');
    expect(restored.category, PostCategory.question);
    expect(restored.likeCount, 2);
    expect(restored.commentCount, 3);
    expect(restored.league, League.kbl);
  });

  test('리그는 왕복하고, 리그를 나누기 전 글은 KBL 게시판 글이다', () {
    const nba = CommunityPost(
      id: 'p2',
      uid: 'u1',
      displayName: 'a',
      category: PostCategory.free,
      league: League.nba,
      title: 't',
      body: 'b',
    );
    expect(CommunityPost.fromMap('p2', nba.toMap())!.league, League.nba);
    final old = CommunityPost.fromMap('p0', {
      'uid': 'u',
      'title': 't',
      'body': '',
    });
    expect(old!.league, League.kbl);
  });

  test('필수 필드가 없으면 null을 돌려준다', () {
    expect(CommunityPost.fromMap('p1', {'uid': 'u1'}), isNull);
    expect(PostComment.fromMap('c1', {'postId': 'p1'}), isNull);
  });

  test('모르는 말머리는 자유 게시판으로 처리한다', () {
    final post = CommunityPost.fromMap('p1', {
      'uid': 'u1',
      'title': '제목',
      'body': '',
      'category': 'unknown-value',
    });
    expect(post!.category, PostCategory.free);
  });

  test('좋아요 여부는 내 uid 기준으로 판단한다', () {
    const post = CommunityPost(
      id: 'p1',
      uid: 'u1',
      displayName: '김*윤',
      category: PostCategory.free,
      title: 't',
      body: 'b',
      likedBy: ['u2'],
    );
    expect(post.likedByMe('u2'), isTrue);
    expect(post.likedByMe('u9'), isFalse);
    expect(post.likedByMe(null), isFalse);
  });
}
