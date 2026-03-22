import SwiftUI

struct ContentView: View {
    @State private var udid: String = ""
    @State private var simName: String = "iPhone 16 Pro Max"
    @State private var scenario: String = "settings_scroll"
    @State private var isRunning = false
    @State private var logText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Video Test Runner").font(.title2).bold()

            HStack {
                Text("UDID:")
                TextField("9D1B…", text: $udid)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Text("Simulator Name:")
                TextField("iPhone 16 Pro Max", text: $simName)
                    .textFieldStyle(.roundedBorder)
            }

            Picker("Scenario", selection: $scenario) {
                Text("Settings Scroll").tag("settings_scroll")
                Text("Localization").tag("localization")
            }.pickerStyle(.segmented)

            HStack {
                Button(isRunning ? "Running…" : "Run") {
                    run()
                }
                .disabled(isRunning)

                Button("Open Last Video") { openLastVideo() }
            }

            TextEditor(text: $logText)
                .font(.system(.footnote, design: .monospaced))
                .frame(minHeight: 240)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
        }
        .padding(16)
        .frame(minWidth: 700, minHeight: 450)
    }

    private func run() {
        isRunning = true
        logText = ""
        let script = "~/moulinsart/PrivExpensIA/scripts/validation_video_ai.sh"

        var args: [String] = [script, "--scenario", scenario]
        if !udid.trimmingCharacters(in: .whitespaces).isEmpty {
            args += ["--udid", udid]
        } else if !simName.trimmingCharacters(in: .whitespaces).isEmpty {
            args += ["--simulator-name", simName]
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/bash")
        proc.arguments = ["-lc", (args.map { $0.contains(" ") ? "\"\($0)\"" : $0 }).joined(separator: " ")]

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { handle in
            if let str = String(data: handle.availableData, encoding: .utf8), !str.isEmpty {
                DispatchQueue.main.async { self.logText += str }
            }
        }

        proc.terminationHandler = { _ in
            DispatchQueue.main.async { self.isRunning = false }
        }

        do { try proc.run() } catch { logText += "\n❌ \(error.localizedDescription)"; isRunning = false }
    }

    private func openLastVideo() {
        let fm = FileManager.default
        let dir = URL(fileURLWithPath: "~/moulinsart/PrivExpensIA/validation/videos")
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else { return }
        let mp4s = files.filter { $0.pathExtension.lowercased() == "mp4" }
        guard let latest = mp4s.max(by: { (a, b) -> Bool in
            let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return da < db
        }) else { return }
        NSWorkspace.shared.open(latest)
    }
}

#Preview { ContentView() }


