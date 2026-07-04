import SwiftUI

/// Jump straight to any month (明细 / 图表 currently only step month-by-month). Year + month
/// wheels, plus a "回到本月" shortcut.
struct MonthPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var t
    @Binding var month: Date                 // first day of the selected month

    private let cal = Calendar.current
    @State private var year: Int
    @State private var mon: Int

    init(month: Binding<Date>) {
        _month = month
        let c = Calendar.current.dateComponents([.year, .month], from: month.wrappedValue)
        _year = State(initialValue: c.year ?? Calendar.current.component(.year, from: .now))
        _mon  = State(initialValue: c.month ?? 1)
    }

    private var years: [Int] {
        let y = cal.component(.year, from: .now)
        return Array((y - 10)...y)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                HStack(spacing: 0) {
                    Picker("年", selection: $year) {
                        ForEach(years, id: \.self) { Text("\($0)年").tag($0) }
                    }
                    .pickerStyle(.wheel)
                    Picker("月", selection: $mon) {
                        ForEach(1...12, id: \.self) { Text("\($0)月").tag($0) }
                    }
                    .pickerStyle(.wheel)
                }
                Button("回到本月") {
                    let n = Date()
                    year = cal.component(.year, from: n)
                    mon = cal.component(.month, from: n)
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(t.accent)
                .padding(.bottom, 8)
            }
            .padding(.top, 8)
            .navigationTitle("选择月份")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("完成") { apply() } }
            }
        }
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.visible)
    }

    private func apply() {
        var c = DateComponents(); c.year = year; c.month = mon; c.day = 1
        if let d = cal.date(from: c) { month = d }
        Haptics.tap()
        dismiss()
    }
}
