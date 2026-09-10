import 'package:flutter/foundation.dart';

/// 신고 대상 종류.
enum ReportTargetType { post, comment, predictionComment }

extension ReportTargetTypeCodec on ReportTargetType {
  String get code => name;

  static ReportTargetType fromCode(Object? code) => switch (code) {
    'comment' => ReportTargetType.comment,
    'predictionComment' => ReportTargetType.predictionComment,
    _ => ReportTargetType.post,
  };
}

/// 신고 사유.
enum ReportReason { spam, abuse, sexual, falseInfo, other }

extension ReportReasonLabel on ReportReason {
  String get label => switch (this) {
    ReportReason.spam => '스팸·광고',
    ReportReason.abuse => '욕설·비방',
    ReportReason.sexual => '음란물',
    ReportReason.falseInfo => '허위 정보',
    ReportReason.other => '기타',
  };

  String get code => name;
}

/// 사용자가 접수한 신고 한 건. 문서 id는 "{targetId}_{신고자uid}"라
/// 같은 사람이 같은 글을 여러 번 신고해도 한 건으로만 쌓인다.
@immutable
class Report {
  final String targetId;
  final ReportTargetType targetType;

  /// 신고당한 글/댓글의 작성자.
  final String targetUid;

  /// 신고한 사람.
  final String reporterUid;
  final ReportReason reason;
  final String detail;

  const Report({
    required this.targetId,
    required this.targetType,
    required this.targetUid,
    required this.reporterUid,
    required this.reason,
    this.detail = '',
  });

  String get docId => '${targetId}_$reporterUid';

  Map<String, Object?> toMap() => {
    'targetId': targetId,
    'targetType': targetType.code,
    'targetUid': targetUid,
    'reporterUid': reporterUid,
    'reason': reason.code,
    'detail': detail,
    'status': 'pending',
  };
}
