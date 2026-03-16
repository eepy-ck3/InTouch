import Foundation
import Observation

@Observable
final class AppRouter {
    var selectedTab: Int = 0
    var pendingActivityId: UUID? = nil
}
