import SwiftUI
import SwiftData

@main
struct FoursomeApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(.fairway800)
        }
        .modelContainer(for: [Player.self, Round.self, OpenRound.self,
                              Friendship.self, PlayerGroup.self])
    }
}
