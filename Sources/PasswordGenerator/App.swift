import SwiftUI
import AppKit
import PasswordCore

@main
struct PasswordGeneratorApp: App {
    init() { NSApplication.shared.setActivationPolicy(.regular); NSApplication.shared.activate(ignoringOtherApps: true) }
    var body: some Scene {
        WindowGroup("Password Generator") { ContentView() }
            .windowResizability(.contentSize)
    }
}

struct ContentView: View {
    // The settings chosen last time, so character types and their minimum counts are kept between launches.
    @State private var options = Settings.load().options
    @State private var password = ""
    @State private var error: String?
    @State private var copied = false
    @State private var fullCycle = Settings.load().fullCycle
    @State private var cycle = Settings.load().cycle
    @State private var store = UsedPasswordStore(fileURL: UsedPasswordStore.defaultURL())
    @State private var usedCount = 0
    @State private var confirmClear = false

    private var maxCycle: Int { max(options.poolSize, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text(error ?? password)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(error == nil ? .primary : .red)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
                    HStack {
                        Button("Generate") { generate() }.keyboardShortcut(.return)
                        Button(copied ? "Copied (clears in 30s)" : "Copy") { copy() }
                            .disabled(error != nil || password.isEmpty)
                        Button("Mark as used") { markUsed() }
                            .help("Remember this password (as a salted hash) so it is never suggested again")
                            .disabled(error != nil || password.isEmpty)
                    }
                }.padding(4)
            }

            HStack {
                Text("Length").frame(width: 60, alignment: .leading)
                Slider(value: Binding(get: { Double(options.length) },
                                      set: { options.length = Int($0) }),
                       in: Double(PasswordOptions.minLength)...Double(PasswordOptions.maxLength), step: 1)
                TextField("", value: $options.length, format: .number).frame(width: 52)
                Stepper("", value: $options.length,
                        in: PasswordOptions.minLength...PasswordOptions.maxLength).labelsHidden()
            }

            GroupBox("Character types  (minimum count each)") {
                VStack(alignment: .leading, spacing: 6) {
                    row("Lowercase  a–z", $options.useLower, $options.minLower)
                    row("Uppercase  A–Z", $options.useUpper, $options.minUpper)
                    row("Digits  0–9", $options.useDigits, $options.minDigits)
                    row("Special", $options.useSpecial, $options.minSpecial)
                    TextField("Special characters", text: $options.specialSet)
                        .font(.system(.body, design: .monospaced))
                        .disabled(!options.useSpecial)
                    Toggle("Exclude look-alikes (I l 1 O 0 |)", isOn: $options.excludeAmbiguous)
                }.padding(4)
            }

            HStack {
                Text("\(usedCount) used password\(usedCount == 1 ? "" : "s") remembered (hashes only)")
                    .font(.caption).foregroundColor(.secondary)
                Spacer()
                Button("Clear history…") { confirmClear = true }.disabled(usedCount == 0)
            }
            .confirmationDialog("Forget all used passwords?", isPresented: $confirmClear) {
                Button("Clear history", role: .destructive) { try? store.clear(); usedCount = store.count }
            } message: { Text("Previously used passwords could be suggested again.") }

            GroupBox("Repeat control") {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Use every character once before any repeats", isOn: $fullCycle)
                    HStack {
                        Text("Distinct characters before a repeat:")
                        Stepper(value: $cycle, in: 1...maxCycle) { Text("\(min(cycle, maxCycle))") }
                    }.disabled(fullCycle)
                    Text("Pool: \(options.poolSize) characters. Passwords shorter than the pool never repeat in full-cycle mode.")
                        .font(.caption).foregroundColor(.secondary)
                }.padding(4)
            }
        }
        .padding(16)
        .frame(width: 480)
        .onAppear { usedCount = store.count; generate() }
        .onChange(of: options) { _ in save(); generate() }
        .onChange(of: fullCycle) { _ in save(); generate() }
        .onChange(of: cycle) { _ in save(); generate() }
    }

    private func row(_ title: String, _ on: Binding<Bool>, _ min: Binding<Int>) -> some View {
        HStack {
            Toggle(title, isOn: on)
            Spacer()
            Stepper(value: min, in: 0...PasswordOptions.maxLength) { Text("\(min.wrappedValue)").frame(width: 30, alignment: .trailing) }
                .disabled(!on.wrappedValue)
        }
    }

    private func save() {
        var settings = Settings()
        settings.options = options
        settings.fullCycle = fullCycle
        settings.cycle = cycle
        settings.save()
    }

    private func generate() {
        options.length = Swift.min(Swift.max(options.length, PasswordOptions.minLength), PasswordOptions.maxLength)
        var o = options
        o.cycleSize = fullCycle ? nil : Swift.min(cycle, maxCycle)
        do { password = try PasswordGenerator.generateUnused(o, store: store); error = nil }
        catch { password = ""; self.error = "\(error)" }
        copied = false
    }

    private func markUsed() {
        do { try store.markUsed(password); usedCount = store.count; generate() }
        catch { self.error = "Could not save: \(error.localizedDescription)" }
    }

    private func copy() {
        let pb = NSPasteboard.general
        pb.clearContents(); pb.setString(password, forType: .string)
        let count = pb.changeCount
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            if NSPasteboard.general.changeCount == count { NSPasteboard.general.clearContents() }
            copied = false
        }
    }
}
