import SwiftUI
import WidgetKit

/// 잠금화면·다이내믹 아일랜드 실시간 스코어 위젯 확장의 진입점.
@main
struct LiveScoreWidgetBundle: WidgetBundle {
  var body: some Widget {
    LiveScoreLiveActivity()
  }
}
