import SwiftUI

// MARK: - Settings sheet

struct SettingsSheet: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var engine: PlayerEngine
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var urlString: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var showPassword = false
    @State private var testing = false
    @State private var status: String?
    @State private var statusOK = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Navidrome / Subsonic connection")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.themeMutedFg)

                    field("Server name", text: $name, placeholder: "SmartHub")
                    field("Server URL", text: $urlString, placeholder: "https://music.example.com",
                          keyboard: .URL, autocap: .never)
                    field("Username", text: $username, placeholder: "listener", keyboard: .default, autocap: .never)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.fg)
                        HStack {
                            Group {
                                if showPassword { TextField("", text: $password) } else { SecureField("", text: $password) }
                            }
                            .textFieldStyle(.plain)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .accessibilityLabel("Password")
                            Button {
                                showPassword.toggle()
                                Haptics.soft()
                            } label: {
                                Text(showPassword ? "Hide" : "Show")
                                    .font(.system(size: 11, weight: .bold))
                                    .textCase(.uppercase)
                                    .foregroundStyle(Theme.cream)
                            }
                            .accessibilityLabel(showPassword ? "Hide password" : "Show password")
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.muted))
                    }

                    Button {
                        Haptics.tap()
                        Task { await testConnection() }
                    } label: {
                        HStack {
                            if testing { ProgressView().tint(Theme.cream) }
                            Text(testing ? "Testing…" : "Test connection")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Capsule().fill(Theme.cream))
                        .foregroundStyle(Color(red: 0x15/255, green: 0x16/255, blue: 0x17/255))
                    }
                    .disabled(testing)
                    .accessibilityLabel("Test connection to server")

                    if let status {
                        Text(status)
                            .font(.system(size: 13))
                            .foregroundStyle(statusOK ? Theme.fg : Color.themeMutedFg)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.muted))
                            .accessibilityLabel("Connection result: \(status)")
                    }

                    Text("Direct streaming is always used — no transcoding.")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.themeMutedFg)
                }
                .padding(20)
            }
            .background(Theme.bg)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Close settings")
                }
            }
            .onAppear {
                name = app.server.name
                urlString = app.server.url
                username = app.server.username
                password = app.server.password
            }
        }
        .preferredColorScheme(.dark)
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String,
                       keyboard: UIKeyboardType = .default, autocap: TextInputAutocapitalization = .sentences) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.fg)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .keyboardType(keyboard)
                .textInputAutocapitalization(autocap)
                .autocorrectionDisabled()
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.muted))
        }
    }

    private func testConnection() async {
        // Save first so the rest of the app picks the config up.
        var cfg = app.server
        cfg.name = name.isEmpty ? "SmartHub" : name
        cfg.url = urlString.trimmingCharacters(in: .whitespaces)
        cfg.username = username.trimmingCharacters(in: .whitespaces)
        cfg.password = password
        app.server = cfg
        engine.configure(server: cfg)

        guard cfg.isValid else {
            statusOK = false
            status = "Fill in a valid URL (http/https), username and password."
            return
        }
        testing = true
        status = nil
        do {
            let client = SubsonicClient(config: cfg)
            let ping = try await client.ping()
            statusOK = true
            status = "Connected to \(ping.isNavidrome ? "Navidrome" : "Subsonic server") v\(ping.serverVersion). ✅"
            app.showUnreachableBanner = false
            Haptics.success()
        } catch {
            statusOK = false
            status = (error as? SubsonicError)?.errorDescription ?? "Connection failed."
            app.showUnreachableBanner = true
        }
        testing = false
    }
}

// MARK: - Lyrics sheet (OpenSubsonic getLyricsBySongId — .lrc sidecars via Navidrome)

struct LyricsSheet: View {
    @EnvironmentObject private var engine: PlayerEngine
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var lyrics: SubsonicClient.LyricsResult?
    @State private var loaded = false
    @State private var activeLine = 0

    var body: some View {
        NavigationStack {
            Group {
                if !loaded {
                    ProgressView().tint(Theme.cream).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let lyrics, lyrics.hasContent {
                    lyricsView(lyrics)
                } else {
                    EmptyState(icon: "text.bubble", title: "No lyrics",
                               text: "No .lrc or embedded lyrics found for this song on the server.")
                }
            }
            .background(Theme.bg)
            .navigationTitle("Lyrics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Close lyrics")
                }
            }
        }
        .preferredColorScheme(.dark)
        .task(id: engine.currentTrack?.id) { await fetchLyrics() }
    }

    private func lyricsView(_ l: SubsonicClient.LyricsResult) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 18) {
                    Text(engine.currentTrack?.title ?? "")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.8)
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.cream)
                    let lines = l.lines
                    ForEach(Array(lines.enumerated()), id: \.offset) { idx, line in
                        Text(line.1)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(l.isSynced && idx == activeLine ? Theme.cream : Color.themeMutedFg)
                            .multilineTextAlignment(.center)
                            .id(idx)
                            .accessibilityElement(children: .combine)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
                .onChange(of: engine.position) { _, pos in
                    guard l.isSynced else { return }
                    // Highlight the current line from .lrc timestamps.
                    var best = 0
                    for (i, line) in l.lines.enumerated() {
                        if let ms = line.0, Double(ms) / 1000 <= pos { best = i } else { break }
                    }
                    if best != activeLine {
                        activeLine = best
                        withAnimation(.easeInOut(duration: 0.25)) { proxy.scrollTo(best, anchor: .center) }
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Lyrics for \(engine.currentTrack?.title ?? "track")")
        }
    }

    private func fetchLyrics() async {
        loaded = false
        lyrics = nil
        guard let song = engine.currentTrack else {
            loaded = true
            return
        }
        let client = engine.clientForViews
        lyrics = try? await client.getLyricsBySongId(id: song.id)
        loaded = true
    }
}