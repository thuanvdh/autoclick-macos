import SwiftUI

struct ContentView: View {
    enum Tab { case auto, record }

    @EnvironmentObject private var state: AppState
    @State private var tab: Tab = .auto

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("AutoClick").font(.headline)
                Spacer()
                statusBadge
            }

            if !state.hasAccessibility {
                PermissionBanner()
            }

            Picker("", selection: $tab) {
                Text("Auto Click").tag(Tab.auto)
                Text("Ghi & Phát lại").tag(Tab.record)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch tab {
            case .auto: AutoClickTab()
            case .record: RecordTab()
            }

            Divider()

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("⌃⌥S Auto click · ⌃⌥R Ghi · ⌃⌥P Phát")
                    Text("Dừng khẩn cấp: Esc, hoặc đưa chuột lên góc trên-trái")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                Spacer()
                Button("Thoát") { NSApp.terminate(nil) }
                    .controlSize(.small)
            }
        }
        .padding(14)
        .frame(width: 340)
    }

    @ViewBuilder private var statusBadge: some View {
        if state.isClicking {
            badge("Đang click", .green)
        } else if state.isRecording {
            badge("Đang ghi", .red)
        } else if state.isPlaying {
            badge("Đang phát", .blue)
        }
    }

    private func badge(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.2), in: Capsule())
            .foregroundStyle(color)
    }
}

private struct PermissionBanner: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Chưa cấp quyền Accessibility", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.callout.bold())
            Text("System Settings → Privacy & Security → Accessibility → bật AutoClick.")
                .font(.caption)
            Button("Mở System Settings") { Permissions.openSettings() }
                .controlSize(.small)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct AutoClickTab: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        let s = $state.settings

        VStack(alignment: .leading, spacing: 12) {
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    Text("Kiểu click")
                    Picker("", selection: s.clickType) {
                        ForEach(ClickType.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                GridRow {
                    Text("Mỗi")
                    HStack { NumberField(value: s.intervalMs, range: 1...3_600_000); Text("ms") }
                }
                GridRow {
                    Text("Ngẫu nhiên")
                    HStack { Text("±"); NumberField(value: s.jitterMs); Text("ms") }
                }
                GridRow {
                    Text("Vị trí")
                    Picker("", selection: s.positionMode) {
                        ForEach(PositionMode.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                if state.settings.positionMode == .fixed {
                    GridRow {
                        Text("")
                        HStack {
                            Text("x \(Int(state.settings.fixedX))  y \(Int(state.settings.fixedY))")
                                .monospacedDigit()
                            Spacer()
                            Button(state.pickCountdown.map { "Chọn sau \($0)s…" } ?? "Chọn điểm") {
                                state.pickFixedPoint()
                            }
                            .controlSize(.small)
                            .help("Đưa chuột tới vị trí cần click trong 3 giây")
                        }
                    }
                }
                GridRow {
                    Text("Dừng sau")
                    Picker("", selection: s.stopMode) {
                        ForEach(StopMode.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                if state.settings.stopMode == .count {
                    GridRow {
                        Text("")
                        HStack { NumberField(value: s.stopCount, range: 1...10_000_000); Text("lần") }
                    }
                } else if state.settings.stopMode == .duration {
                    GridRow {
                        Text("")
                        HStack { NumberField(value: s.stopSeconds, range: 1...864_000); Text("giây") }
                    }
                }
            }

            Button {
                state.toggleClicking()
            } label: {
                Label(state.isClicking ? "Dừng (⌃⌥S)" : "Bắt đầu (⌃⌥S)",
                      systemImage: state.isClicking ? "stop.fill" : "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(state.isClicking ? .red : .accentColor)
            .controlSize(.large)

            Text("Đã click: \(state.clickCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

private struct RecordTab: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        let s = $state.settings

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button {
                    state.toggleRecording()
                } label: {
                    Label(state.isRecording ? "Dừng ghi (⌃⌥R)" : "Ghi mới (⌃⌥R)",
                          systemImage: state.isRecording ? "stop.circle" : "record.circle")
                }
                Spacer()
                Button("Xoá", role: .destructive) { state.clearRecording() }
                    .disabled(state.recording.isEmpty || state.isRecording)
            }

            if state.isRecording {
                Text("Đang ghi… hãy click vào các app khác. Nhấn ⌃⌥R để dừng.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            recordingList

            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    Text("Lặp lại")
                    HStack {
                        NumberField(value: s.playbackRepeat, range: 0...1_000_000)
                        Text("lần (0 = vô hạn)").foregroundStyle(.secondary)
                    }
                }
                GridRow {
                    Text("Tốc độ")
                    HStack {
                        Slider(value: s.playbackSpeed, in: 0.25...4, step: 0.25)
                        Text(String(format: "%.2fx", state.settings.playbackSpeed))
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }
                }
            }

            Button {
                state.togglePlayback()
            } label: {
                Label(state.isPlaying ? "Dừng (⌃⌥P)" : "Phát lại (⌃⌥P)",
                      systemImage: state.isPlaying ? "stop.fill" : "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(state.isPlaying ? .red : .accentColor)
            .controlSize(.large)
            .disabled(state.recording.isEmpty || state.isRecording)

            if !state.playbackStatus.isEmpty {
                Text(state.playbackStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private var recordingList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 3) {
                if state.recording.isEmpty {
                    Text("Chưa có thao tác nào")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                }
                ForEach(Array(state.recording.enumerated()), id: \.element.id) { index, item in
                    HStack {
                        Text("\(index + 1).").frame(width: 28, alignment: .trailing)
                        Text(label(for: item)).frame(width: 48, alignment: .leading)
                        Text("(\(Int(item.x)), \(Int(item.y)))")
                        Spacer()
                        Text(String(format: "+%.2fs", item.delay)).foregroundStyle(.secondary)
                    }
                    .font(.caption.monospacedDigit())
                }
            }
            .padding(6)
        }
        .frame(height: 130)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
    }

    private func label(for item: RecordedClick) -> String {
        if item.button == .right { return "Phải" }
        return item.clickCount > 1 ? "Double" : "Trái"
    }
}

private struct NumberField: View {
    @Binding var value: Int
    var range: ClosedRange<Int> = 0...1_000_000

    var body: some View {
        TextField("", value: Binding(
            get: { value },
            set: { value = min(max($0, range.lowerBound), range.upperBound) }
        ), format: .number)
        .textFieldStyle(.roundedBorder)
        .multilineTextAlignment(.trailing)
        .frame(width: 80)
    }
}
