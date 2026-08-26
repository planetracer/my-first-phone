import SwiftUI
import UserNotifications

@main
struct ToddlerPhoneApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
                // The app uses a fixed light palette; keep system controls matching.
                .preferredColorScheme(.light)
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = NotificationHandler.shared
        return true
    }

    // CloudKit subscription pushes land here; refresh chat and call state.
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any]
    ) async -> UIBackgroundFetchResult {
        await FamilyStore.shared.refresh()
        await CallEngine.shared.checkForIncoming()
        return .newData
    }
}

final class NotificationHandler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationHandler()

    // Suppress banners for records this device just created itself.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let userInfo = notification.request.content.userInfo
        if let ck = userInfo["ck"] as? [String: Any],
           let qry = ck["qry"] as? [String: Any],
           let fields = qry["af"] as? [String: Any],
           let sender = fields["sender"] as? String {
            let mine = await MainActor.run { FamilyStore.shared.displayName }
            if sender == mine { return [] }
        }
        return [.banner, .sound]
    }
}
