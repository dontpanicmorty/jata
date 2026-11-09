import SwiftUI
import AppKit
import PasswordCore

@main
struct PasswordGeneratorApp: App {
    init() { NSApplication.shared.setActivationPolicy(.regular); NSApplication.shared.activate(ignoringOtherApps: true) }
    var body: some Scene {
        WindowGroup("Password Generator") { ContentView() }
            .windowStyle(.hiddenTitleBar)
            .windowResizability(.contentSize)
    }
}

// MARK: - Look

/// A rounded card on the window background, like a settings group.
private struct Card<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
            VStack(alignment: .leading, spacing: 0) { content }
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08)))
        }
    }
}

/// One row inside a card: an icon, a title, and whatever controls go on the right.
private struct Row<Trailing: View>: View {
    var icon: String
    var title: String
    var subtitle: String?
    var enabled = true
    @ViewBuilder var trailing: Trailing
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(enabled ? Color.accentColor : Color.secondary.opacity(0.5)))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }
}

private struct RowDivider: View {
    var body: some View { Divider().padding(.leading, 50) }
}

private extension Strength {
    var color: Color {
        switch self {
        case .weak: return .red
        case .fair: return .orange
        case .strong: return .green
        case .veryStrong: return .mint
        }
    }
}

// MARK: - Window

struct ContentView: View {
    // The settings chosen last time, so character types and their minimum counts are kept between launches.
    @State private var options = Settings.load().options
    @State private var password = ""
    @State private var error: String?
    @State private var copied = false
    @State private var copyGeneration = 0
    @State private var fullCycle = Settings.load().fullCycle
    @State private var cycle = Settings.load().cycle
    @State private var store = UsedPasswordStore(fileURL: UsedPasswordStore.defaultURL())
    @State private var usedCount = 0
    @State private var confirmClear = false
    @State private var showAdvanced = false

    private var maxCycle: Int { max(options.poolSize, 1) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                passwordCard
                lengthCard
                charactersCard
                advancedCard
                footer
            }
            .padding(20)
        }
        .frame(width: 500, height: 720)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { usedCount = store.count; generate() }
        .onChange(of: options) { _ in save(); generate() }
        .onChange(of: fullCycle) { _ in save(); generate() }
        .onChange(of: cycle) { _ in save(); generate() }
    }

    // MARK: header

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "key.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LinearGradient(colors: [.accentColor, .accentColor.opacity(0.7)],
                                         startPoint: .top, endPoint: .bottom)))
            VStack(alignment: .leading, spacing: 1) {
                Text("Password Generator").font(.title2.weight(.semibold))
                Label("Offline: nothing leaves this Mac", systemImage: "lock.shield")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.top, 8)
    }

    // MARK: the password

    private var passwordCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Group {
                if let error {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.system(size: 14, weight: .medium))
                } else {
                    Text(colored(password))
                        .font(.system(size: 19, weight: .medium, design: .monospaced))
                        .textSelection(.enabled)
                        .lineSpacing(3)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)

            strengthBar

            HStack(spacing: 10) {
                Button(action: copy) {
                    Label(copied ? "Copied · clears in 30s" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(error != nil || password.isEmpty)

                Button(action: generate) {
                    Label("New", systemImage: "arrow.clockwise").frame(minWidth: 70)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .keyboardShortcut(.return)
                .help("Generate a new password (Return)")

                Button(action: markUsed) {
                    Image(systemName: "checkmark.seal")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .help("Mark as used: remember this password (as a salted hash) so it is never suggested again")
                .disabled(error != nil || password.isEmpty)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.08)))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    /// Digits and special characters in their own colors, so the password is easier to read and copy by eye.
    private func colored(_ text: String) -> AttributedString {
        var out = AttributedString()
        for ch in text {
            var piece = AttributedString(String(ch))
            if ch.isNumber {
                piece.foregroundColor = .blue
            } else if !ch.isLetter {
                piece.foregroundColor = .orange
            }
            out.append(piece)
        }
        return out
    }

    private var strengthBar: some View {
        let strength = options.strength
        let bits = Int(options.entropyBits.rounded())
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                ForEach(Strength.allCases, id: \.self) { level in
                    Capsule()
                        .fill(level <= strength ? strength.color : Color.secondary.opacity(0.2))
                        .frame(height: 5)
                }
            }
            HStack {
                Text(strength.label).font(.caption.weight(.semibold)).foregroundStyle(strength.color)
                Spacer()
                Text("\(bits) bits · \(options.poolSize) possible characters")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: settings

    private var lengthCard: some View {
        Card(title: "Length") {
            HStack(spacing: 12) {
                Slider(value: Binding(get: { Double(options.length) }, set: { options.length = Int($0) }),
                       in: Double(PasswordOptions.minLength)...Double(PasswordOptions.maxLength), step: 1)
                TextField("", value: $options.length, format: .number)
                    .multilineTextAlignment(.center)
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 52)
                    .textFieldStyle(.roundedBorder)
                Stepper("", value: $options.length,
                        in: PasswordOptions.minLength...PasswordOptions.maxLength).labelsHidden()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }

    private var charactersCard: some View {
        Card(title: "Characters") {
            classRow("textformat.abc", "Lowercase", "a–z", $options.useLower, $options.minLower)
            RowDivider()
            classRow("textformat", "Uppercase", "A–Z", $options.useUpper, $options.minUpper)
            RowDivider()
            classRow("number", "Digits", "0–9", $options.useDigits, $options.minDigits)
            RowDivider()
            classRow("asterisk", "Special", nil, $options.useSpecial, $options.minSpecial)
            if options.useSpecial {
                TextField("Special characters", text: $options.specialSet)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                    .padding(.leading, 50)
                    .padding(.trailing, 12)
                    .padding(.bottom, 10)
            }
            RowDivider()
            Row(icon: "eye.slash", title: "Avoid look-alikes", subtitle: "Leaves out I l 1 O 0 |") {
                Toggle("", isOn: $options.excludeAmbiguous).toggleStyle(.switch).labelsHidden()
            }
        }
    }

    private func classRow(_ icon: String, _ title: String, _ subtitle: String?, _ on: Binding<Bool>,
                          _ min: Binding<Int>) -> some View {
        Row(icon: icon, title: title, subtitle: subtitle, enabled: on.wrappedValue) {
            if on.wrappedValue {
                HStack(spacing: 4) {
                    Text("at least").font(.caption).foregroundStyle(.secondary)
                    Text("\(min.wrappedValue)")
                        .font(.system(.body, design: .monospaced))
                        .frame(minWidth: 22, alignment: .trailing)
                    Stepper("", value: min, in: 0...PasswordOptions.maxLength).labelsHidden()
                }
            }
            Toggle("", isOn: on).toggleStyle(.switch).labelsHidden()
        }
    }

    private var advancedCard: some View {
        Card(title: nil) {
            DisclosureGroup(isExpanded: $showAdvanced) {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Use every character once before any repeats", isOn: $fullCycle)
                        .toggleStyle(.switch)
                    HStack {
                        Text("Distinct characters before a repeat")
                        Spacer()
                        Text("\(Swift.min(cycle, maxCycle))").font(.system(.body, design: .monospaced))
                        Stepper("", value: $cycle, in: 1...maxCycle).labelsHidden()
                    }
                    .disabled(fullCycle)
                    .opacity(fullCycle ? 0.5 : 1)
                    Text("Passwords shorter than the \(options.poolSize)-character pool never repeat a character "
                         + "in the default mode.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.top, 8)
            } label: {
                Label("Repeat control", systemImage: "repeat").font(.body.weight(.medium))
            }
            .padding(12)
        }
    }

    private var footer: some View {
        HStack {
            Label("\(usedCount) used password\(usedCount == 1 ? "" : "s") remembered (hashes only)",
                  systemImage: "clock.arrow.circlepath")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button("Clear history…", role: .destructive) { confirmClear = true }
                .buttonStyle(.borderless)
                .font(.caption)
                .disabled(usedCount == 0)
        }
        .padding(.horizontal, 4)
        .confirmationDialog("Forget all used passwords?", isPresented: $confirmClear) {
            Button("Clear history", role: .destructive) { try? store.clear(); usedCount = store.count }
        } message: { Text("Previously used passwords could be suggested again.") }
    }

    // MARK: actions

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
        copyGeneration += 1
        let generation = copyGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            if NSPasteboard.general.changeCount == count { NSPasteboard.general.clearContents() }
            if generation == copyGeneration { copied = false }
        }
    }
}
