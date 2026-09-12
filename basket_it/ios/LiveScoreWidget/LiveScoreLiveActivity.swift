import ActivityKit
import SwiftUI
import WidgetKit

/// 서버(functions/live-score.js)가 푸시로 보내는 경기 상태.
/// 이름은 live_activities 플러그인이 정한 것이라 바꾸면 안 된다.
struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
  public struct ContentState: Codable, Hashable {
    var appGroupId: String?
    var league: String?
    var homeName: String?
    var awayName: String?
    var homeTeamId: String?
    var awayTeamId: String?
    var homeScore: Int?
    var awayScore: Int?
    /// "3쿼터", "하프타임", "연장", "경기 종료"
    var period: String?
    /// 남은 시간 "7:12". 쉬는 시간·종료 후에는 빈 문자열.
    var clock: String?
    /// "live" | "final"
    var status: String?
  }

  var id: UUID
  /// "nba:401810123" 같은 경기 키.
  var gameKey: String?
}

struct LiveScoreLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
      LockScreenScoreView(state: context.state)
        .activityBackgroundTint(Color.black.opacity(0.78))
        .activitySystemActionForegroundColor(.white)
    } dynamicIsland: { context in
      let state = context.state
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          TeamColumn(league: state.league, teamId: state.homeTeamId, name: state.homeName, score: state.homeScore)
        }
        DynamicIslandExpandedRegion(.trailing) {
          TeamColumn(league: state.league, teamId: state.awayTeamId, name: state.awayName, score: state.awayScore)
        }
        DynamicIslandExpandedRegion(.center) {
          StatusText(state: state)
        }
      } compactLeading: {
        HStack(spacing: 4) {
          TeamLogo(league: state.league, teamId: state.homeTeamId, name: state.homeName, size: 18)
          Text("\(state.homeScore ?? 0)").font(.caption).bold()
        }
      } compactTrailing: {
        HStack(spacing: 4) {
          Text("\(state.awayScore ?? 0)").font(.caption).bold()
          TeamLogo(league: state.league, teamId: state.awayTeamId, name: state.awayName, size: 18)
        }
      } minimal: {
        Text("\(state.homeScore ?? 0):\(state.awayScore ?? 0)").font(.caption2).bold()
      }
    }
  }
}

/// 잠금화면 카드. 앱의 게임 카드처럼 홈 팀이 왼쪽, 원정 팀이 오른쪽이다.
private struct LockScreenScoreView: View {
  let state: LiveActivitiesAppAttributes.ContentState

  var body: some View {
    VStack(spacing: 6) {
      HStack {
        Text((state.league ?? "").uppercased())
          .font(.caption2).bold()
          .foregroundColor(.white.opacity(0.6))
        Spacer()
        StatusText(state: state)
      }
      HStack(alignment: .center) {
        TeamColumn(league: state.league, teamId: state.homeTeamId, name: state.homeName, score: state.homeScore)
        Spacer()
        Text(":").font(.title2).bold().foregroundColor(.white.opacity(0.5))
        Spacer()
        TeamColumn(league: state.league, teamId: state.awayTeamId, name: state.awayName, score: state.awayScore)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }
}

private struct TeamColumn: View {
  let league: String?
  let teamId: String?
  let name: String?
  let score: Int?

  var body: some View {
    HStack(spacing: 8) {
      TeamLogo(league: league, teamId: teamId, name: name, size: 34)
      VStack(alignment: .leading, spacing: 0) {
        Text(name ?? "")
          .font(.caption)
          .foregroundColor(.white.opacity(0.8))
          .lineLimit(1)
        Text("\(score ?? 0)")
          .font(.system(size: 26, weight: .bold, design: .rounded))
          .foregroundColor(.white)
          .monospacedDigit()
      }
    }
  }
}

private struct StatusText: View {
  let state: LiveActivitiesAppAttributes.ContentState

  var body: some View {
    let parts = [state.period ?? "", state.clock ?? ""].filter { !$0.isEmpty }
    Text(parts.joined(separator: " · "))
      .font(.caption).bold()
      .foregroundColor(state.status == "final" ? .white.opacity(0.7) : Color(red: 0.91, green: 0.35, blue: 0.05))
      .lineLimit(1)
  }
}

/// 위젯 확장에 넣어 둔 공식 로고("nba_13", "kbl_sk"). 없으면 팀 이름 첫 글자.
private struct TeamLogo: View {
  let league: String?
  let teamId: String?
  let name: String?
  let size: CGFloat

  var body: some View {
    if let league, let teamId, let image = UIImage(named: "\(league)_\(teamId)") {
      Image(uiImage: image)
        .resizable()
        .scaledToFit()
        .frame(width: size, height: size)
    } else {
      Text(String((name ?? "?").prefix(1)))
        .font(.system(size: size * 0.45, weight: .bold))
        .foregroundColor(.white)
        .frame(width: size, height: size)
        .background(Circle().fill(Color.white.opacity(0.2)))
    }
  }
}
