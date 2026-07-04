import SwiftUI

/// iCloud 同步说明 & 状态。Sync itself is driven by SwiftData + CloudKit at the container
/// level (see `JianJiApp`); this page just explains it and reports whether it's active.
struct ICloudSyncView: View {
    @Environment(\.theme) private var t

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: SyncStatus.iCloudActive ? "checkmark.icloud.fill" : "icloud.slash.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(SyncStatus.iCloudActive ? t.green : t.ter)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(SyncStatus.iCloudActive ? "iCloud 同步已开启" : "iCloud 同步未启用")
                            .font(.system(size: 16, weight: .semibold))
                        Text(SyncStatus.iCloudActive
                             ? "账单在同一 Apple ID 的设备间自动同步。"
                             : "当前为本机存储，账单不会同步到其他设备。")
                            .font(.system(size: 13)).foregroundStyle(t.sec)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("说明") {
                bullet("checkmark.seal.fill", t.green, "同步基于系统 iCloud（CloudKit 私有库），数据只在你的账号内，简记没有服务器、不收集数据。")
                bullet("bolt.fill", t.accent, "新增、修改、删除会在联网时自动增量同步，无需手动操作。")
                bullet("lock.fill", Color(hex: "FF3B30"), "隐私账单同样加密同步；解锁验证仍在每台设备本地进行。")
            }

            if !SyncStatus.iCloudActive {
                Section {
                    Text("如何开启")
                        .font(.system(size: 14, weight: .semibold))
                    step(1, "在 Xcode 选中 JianJi target → Signing & Capabilities。")
                    step(2, "+ Capability 添加 iCloud，勾选 CloudKit，容器填 iCloud.com.jianji.app。")
                    step(3, "+ Capability 添加 Background Modes，勾选 Remote notifications。")
                    step(4, "真机登录 iCloud 后重装，即自动开启。现有本地账单会一并上传。")
                } footer: {
                    Text("开启后本页状态会变为「已开启」。")
                }
            }
        }
        .navigationTitle("iCloud 同步")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func bullet(_ symbol: String, _ color: Color, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(color).font(.system(size: 15)).frame(width: 20)
            Text(text).font(.system(size: 14))
        }
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                .frame(width: 20, height: 20).background(t.accent, in: Circle())
            Text(text).font(.system(size: 14))
        }
    }
}
