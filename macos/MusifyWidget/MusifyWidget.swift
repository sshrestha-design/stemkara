import WidgetKit
import SwiftUI
import AppIntents

struct MusifyEntry: TimelineEntry {
    let date: Date
    let title: String
    let artist: String
    let album: String
    let isPlaying: Bool
    let artwork: NSImage?
    let duration: Double
    let position: Double
}

struct MusifyTimelineProvider: TimelineProvider {
    typealias Entry = MusifyEntry

    private var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.stemkara.app")
    }

    private func readCurrentEntry() -> MusifyEntry {
        guard let containerURL = sharedContainerURL else {
            return placeholderEntry()
        }

        let jsonURL = containerURL.appendingPathComponent("widget_data.json")
        guard let data = try? Data(contentsOf: jsonURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return placeholderEntry()
        }

        let title = json["title"] as? String ?? "No Track Playing"
        let artist = json["artist"] as? String ?? "Musify"
        let album = json["album"] as? String ?? ""
        let isPlaying = json["isPlaying"] as? Bool ?? false
        let duration = json["duration"] as? Double ?? 0
        let position = json["position"] as? Double ?? 0

        var artworkImage: NSImage? = nil
        let artworkURL = containerURL.appendingPathComponent("artwork.jpg")
        if FileManager.default.fileExists(atPath: artworkURL.path) {
            artworkImage = NSImage(contentsOf: artworkURL)
        }

        return MusifyEntry(
            date: Date(),
            title: title,
            artist: artist,
            album: album,
            isPlaying: isPlaying,
            artwork: artworkImage,
            duration: duration,
            position: position
        )
    }

    private func placeholderEntry() -> MusifyEntry {
        MusifyEntry(
            date: Date(),
            title: "Musify Music",
            artist: "Play your favorite songs",
            album: "",
            isPlaying: false,
            artwork: nil,
            duration: 0,
            position: 0
        )
    }

    func placeholder(in context: Context) -> MusifyEntry {
        placeholderEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping (MusifyEntry) -> Void) {
        completion(readCurrentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MusifyEntry>) -> Void) {
        let entry = readCurrentEntry()
        // Refresh every 15 minutes or when notified
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - App Intents for Interactive Controls (macOS 14+)

@available(macOS 14.0, *)
struct TogglePlayPauseIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Play/Pause"
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        if let url = URL(string: "musify://playback/toggle") {
            NSWorkspace.shared.open(url)
        }
        return .result()
    }
}

@available(macOS 14.0, *)
struct SkipNextIntent: AppIntent {
    static var title: LocalizedStringResource = "Skip Next"
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        if let url = URL(string: "musify://playback/next") {
            NSWorkspace.shared.open(url)
        }
        return .result()
    }
}

@available(macOS 14.0, *)
struct SkipPreviousIntent: AppIntent {
    static var title: LocalizedStringResource = "Skip Previous"
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        if let url = URL(string: "musify://playback/prev") {
            NSWorkspace.shared.open(url)
        }
        return .result()
    }
}

// MARK: - Widget Views

struct MusifyWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: MusifyEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            LargeWidgetView(entry: entry)
        }
    }
}

struct SmallWidgetView: View {
    var entry: MusifyEntry

    var body: some View {
        ZStack {
            if let artwork = entry.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .overlay(
                        LinearGradient(
                            colors: [.black.opacity(0.1), .black.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            } else {
                LinearGradient(
                    colors: [Color.blue.opacity(0.7), Color.purple.opacity(0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Image(systemName: entry.isPlaying ? "waveform" : "music.note")
                        .foregroundColor(.white)
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Circle()
                        .fill(entry.isPlaying ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                }

                Spacer()

                Text(entry.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(entry.artist)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
            }
            .padding(12)
        }
        .widgetURL(URL(string: "musify://"))
    }
}

struct MediumWidgetView: View {
    var entry: MusifyEntry

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor).opacity(0.5)

            HStack(spacing: 14) {
                // Artwork
                if let artwork = entry.artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.6), Color.blue.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 96, height: 96)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                        )
                }

                // Info & Controls
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("MUSIFY")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundColor(.secondary)
                            .tracking(1)

                        Spacer()

                        if entry.isPlaying {
                            HStack(spacing: 4) {
                                Circle().fill(Color.green).frame(width: 6, height: 6)
                                Text("PLAYING")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.green)
                            }
                        }
                    }

                    Text(entry.title)
                        .font(.system(size: 14, weight: .bold))
                        .lineLimit(1)

                    Text(entry.artist)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    Spacer()

                    // Controls Row
                    HStack(spacing: 16) {
                        Link(destination: URL(string: "musify://playback/prev")!) {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                        }

                        Link(destination: URL(string: "musify://playback/toggle")!) {
                            Image(systemName: entry.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.accentColor)
                        }

                        Link(destination: URL(string: "musify://playback/next")!) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                        }

                        Spacer()
                    }
                }
                .padding(.vertical, 8)
            }
            .padding(12)
        }
        .widgetURL(URL(string: "musify://"))
    }
}

struct LargeWidgetView: View {
    var entry: MusifyEntry

    var body: some View {
        VStack(spacing: 12) {
            if let artwork = entry.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(radius: 6)
            } else {
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(colors: [.indigo, .purple], startPoint: .top, endPoint: .bottom))
                    .frame(height: 180)
                    .overlay(
                        Image(systemName: "music.note.list")
                            .font(.system(size: 48))
                            .foregroundColor(.white)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.system(size: 16, weight: .bold))
                    .lineLimit(1)
                Text(entry.artist)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            HStack(spacing: 24) {
                Link(destination: URL(string: "musify://playback/prev")!) {
                    Image(systemName: "backward.fill").font(.system(size: 18))
                }
                Link(destination: URL(string: "musify://playback/toggle")!) {
                    Image(systemName: entry.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.accentColor)
                }
                Link(destination: URL(string: "musify://playback/next")!) {
                    Image(systemName: "forward.fill").font(.system(size: 18))
                }
            }
            .padding(.bottom, 6)
        }
        .padding(14)
        .widgetURL(URL(string: "musify://"))
    }
}

@main
struct MusifyWidget: Widget {
    let kind: String = "MusifyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MusifyTimelineProvider()) { entry in
            MusifyWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Musify")
        .description("View current playing song and control playback directly from your Mac desktop.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
