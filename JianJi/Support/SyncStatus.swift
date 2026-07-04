import Foundation

/// Records whether the SwiftData store was opened with CloudKit sync (i.e. the iCloud
/// capability + entitlement are present). Set once at launch by `JianJiApp`; read by 设置 to
/// show an honest status. Not persisted — it reflects the current build/run.
enum SyncStatus {
    static var iCloudActive = false
}
