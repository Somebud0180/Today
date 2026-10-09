import AppIntents
import Combine
import UIKit

/// Shared by Home Screen quick actions, Siri, and the entry composer.
enum RecordingDestination: String {
    case video = "record-video-entry"
    case audio = "record-audio-entry"
}

@MainActor
final class RecordingActionRouter: ObservableObject {
    static let shared = RecordingActionRouter()

    struct Request: Equatable {
        let id = UUID()
        let destination: RecordingDestination
    }

    @Published private(set) var pendingRequest: Request?

    func request(_ destination: RecordingDestination) {
        pendingRequest = Request(destination: destination)
    }

    @discardableResult
    func handle(shortcutType: String) -> Bool {
        guard let destination = RecordingDestination(rawValue: shortcutType) else { return false }
        request(destination)
        return true
    }

    func consume(_ request: Request) {
        guard pendingRequest == request else { return }
        pendingRequest = nil
    }
}

final class TodayAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = connectingSceneSession.configuration
        configuration.delegateClass = RecordingSceneDelegate.self
        return configuration
    }
}

final class RecordingSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let shortcut = connectionOptions.shortcutItem {
            RecordingActionRouter.shared.handle(shortcutType: shortcut.type)
        }
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(RecordingActionRouter.shared.handle(shortcutType: shortcutItem.type))
    }
}

struct RecordVideoEntryIntent: AppIntent {
    static let title: LocalizedStringResource = "Record video entry"
    static let description = IntentDescription("Opens the video recorder in Today. Tap Start Recording when you’re ready.")
    static var supportedModes: IntentModes { .foreground }

    @MainActor
    func perform() async throws -> some IntentResult {
        RecordingActionRouter.shared.request(.video)
        return .result()
    }
}

struct RecordAudioEntryIntent: AppIntent {
    static let title: LocalizedStringResource = "Record audio entry"
    static let description = IntentDescription("Opens the audio recorder in Today. Tap Start Recording when you’re ready.")
    static var supportedModes: IntentModes { .foreground }

    @MainActor
    func perform() async throws -> some IntentResult {
        RecordingActionRouter.shared.request(.audio)
        return .result()
    }
}

struct TodayRecordingShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RecordVideoEntryIntent(),
            phrases: ["Record a video entry in \(.applicationName)", "Record video in \(.applicationName)"],
            shortTitle: "Record video entry",
            systemImageName: "video.fill"
        )
        AppShortcut(
            intent: RecordAudioEntryIntent(),
            phrases: ["Record an audio entry in \(.applicationName)", "Record audio in \(.applicationName)"],
            shortTitle: "Record audio entry",
            systemImageName: "mic.fill"
        )
    }
}
