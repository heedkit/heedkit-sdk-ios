#if canImport(SwiftUI)
import SwiftUI

// MARK: - Per-kind / per-interaction view metadata

@available(iOS 15.0, macOS 12.0, *)
private extension FeatureKind {
    var tabIcon: String {
        switch self {
        case .featureRequest: return "sparkles"
        case .bugReport:      return "ant.fill"
        case .improvement:    return "lightbulb.fill"
        case .appreciation:   return "heart.fill"
        case .other:          return "bubble.left.fill"
        }
    }
}

@available(iOS 15.0, macOS 12.0, *)
private extension Interaction {
    var systemImage: String {
        switch self {
        case .upvote:   return "chevron.up"
        case .downvote: return "chevron.down"
        case .plusOne:  return "plus"
        case .like:     return "heart.fill"
        }
    }
    var accessibilityLabel: String {
        switch self {
        case .upvote: return "Upvote"
        case .downvote: return "Downvote"
        case .plusOne: return "Plus one"
        case .like: return "Like"
        }
    }
}

// MARK: - Top-level HeedKitView

@available(iOS 15.0, macOS 12.0, *)
public struct HeedKitView: View {
    @State private var features: [Feature] = []
    @State private var loading = true
    @State private var mode: Mode = .browse
    @State private var activeKind: KindFilter
    @State private var title = ""
    @State private var details = ""
    @State private var kind: FeatureKind
    @State private var submitting = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var systemColorScheme

    private let hub = HeedKit.shared
    private let onClose: (() -> Void)?

    /// - Parameter onClose: for hosts that present the view themselves (e.g. an
    ///   `NSHostingController` behind `HeedKit.present(in:)` on macOS): Close and Esc
    ///   run this instead of SwiftUI's `dismiss`.
    public init(onClose: (() -> Void)? = nil) {
        self.onClose = onClose
        let kinds = HeedKit.shared.enabledKinds
        let first = kinds.first ?? .featureRequest
        let mode = HeedKit.shared.theme.groupMode
        _activeKind = State(initialValue: mode == .tabs && !kinds.isEmpty ? .specific(first) : .all)
        _kind = State(initialValue: first)
    }

    private enum Mode: Hashable { case browse, suggest }
    private enum KindFilter: Hashable {
        case all
        case specific(FeatureKind)
        var asKind: FeatureKind? {
            if case .specific(let k) = self { return k } else { return nil }
        }
    }

    private var primary: Color {
        Color(hex: hub.theme.primary ?? "#0D9488") ?? .accentColor
    }

    private var resolvedScheme: ColorScheme {
        // theme.mode "system" defers to the OS via @Environment, otherwise we
        // pin to the admin's choice.
        switch hub.theme.mode {
        case "dark":  return .dark
        case "light": return .light
        default:      return systemColorScheme
        }
    }

    private var enabledKinds: [FeatureKind] {
        hub.enabledKinds.isEmpty ? FeatureKind.allCases : hub.enabledKinds
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                    .padding(.horizontal)
                    .padding(.top, 14)
                modePicker
                    .padding(.horizontal)
                    .padding(.top, 10)
                if mode == .browse, hub.theme.groupMode == .tabs {
                    kindTabsBar
                }
                Group {
                    if mode == .browse { listView } else { suggestForm }
                }
                footer
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { close() }
                        .keyboardShortcut(.cancelAction)
                }
            }
            #endif
            .task { await refresh() }
            .onChange(of: activeKind) { _ in Task { await refresh() } }
        }
        #if os(macOS)
        // A macOS sheet takes its size from its content; without this the widget
        // opens as a tiny window.
        .frame(minWidth: 480, idealWidth: 520, minHeight: 560, idealHeight: 640)
        #endif
        .preferredColorScheme(resolvedScheme)
    }

    // MARK: - Sections

    /// The workspace icon (else the host app's) and the workspace name. Lives in the
    /// content rather than the toolbar: macOS sheets don't render toolbar items other
    /// than the action buttons, and this way every presentation (SwiftUI sheet, AppKit
    /// window, iOS) gets the same header.
    private var header: some View {
        HStack(spacing: 8) {
            if let url = hub.workspaceIconURL {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        headerIcon(image)
                    } else if let icon = hostAppIcon {
                        headerIcon(icon)
                    }
                }
            } else if let icon = hostAppIcon {
                headerIcon(icon)
            }
            Text(hub.displayName).font(.headline).accessibilityAddTraits(.isHeader)
            Spacer()
        }
    }

    private func headerIcon(_ image: Image) -> some View {
        image.resizable().aspectRatio(contentMode: .fit)
            .frame(width: 22, height: 22)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .accessibilityHidden(true)
    }

    /// "Powered by HeedKit" (when the workspace's plan shows it) and, on macOS, the
    /// Close button — one row, no rules, so a sheet doesn't end in two stacked bars.
    @ViewBuilder
    private var footer: some View {
        #if os(macOS)
        ZStack {
            if showPoweredBy { poweredByLink }
            HStack {
                Spacer()
                Button("Close") { close() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        #else
        if showPoweredBy {
            poweredByLink.padding(.vertical, 8)
        }
        #endif
    }

    private var showPoweredBy: Bool { hub.branding?.show_powered_by != false }

    private var poweredByLink: some View {
        Link(destination: poweredByURL) { poweredByLabel }
            .font(.caption2)
            .foregroundColor(.secondary)
    }

    private var modePicker: some View {
        Picker("", selection: $mode) {
            Text("Browse").tag(Mode.browse)
            Text("Suggest").tag(Mode.suggest)
        }
        .pickerStyle(.segmented)
    }

    private var kindTabsBar: some View {
        ViewThatFits(in: .horizontal) {
            // Few enough tabs to fit (e.g. only two kinds enabled): share the full width.
            HStack(spacing: 6) { kindTabs(fill: true) }
                .padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) { kindTabs(fill: false) }
                    .padding(.horizontal)
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private func kindTabs(fill: Bool) -> some View {
        kindTab(.all, label: "All", icon: nil, fill: fill)
        ForEach(enabledKinds, id: \.self) { k in
            kindTab(.specific(k), label: k.label, icon: k.tabIcon, fill: fill)
        }
    }

    @ViewBuilder
    private func kindTab(_ filter: KindFilter, label: String, icon: String?, fill: Bool) -> some View {
        let active = activeKind == filter
        Button { activeKind = filter } label: {
            HStack(spacing: 4) {
                if let icon = icon { Image(systemName: icon).font(.system(size: 11)) }
                Text(label).font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .frame(maxWidth: fill ? .infinity : nil)
            .foregroundStyle(active ? .white : .primary)
            .background(active ? primary : Color.secondary.opacity(0.12))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var listView: some View {
        Group {
            if loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if features.isEmpty {
                ContentEmpty(text: "No items yet — be the first!")
            } else {
                List(features) { f in
                    FeatureRow(
                        feature: f,
                        interactions: hub.interactions(for: f.featureKind),
                        showCount: hub.theme.showCount(for: f.featureKind),
                        primary: primary,
                        onInteraction: { _ in Task { await vote(f) } }
                    )
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
            }
        }
    }

    private var suggestForm: some View {
        Form {
            Section("What's this about?") {
                Picker("Kind", selection: $kind) {
                    ForEach(enabledKinds, id: \.self) { k in
                        Text(k.label).tag(k)
                    }
                }
                .pickerStyle(.menu)
            }
            Section("Title") {
                TextField(kind.titlePlaceholder, text: $title)
            }
            Section("Description") {
                TextEditor(text: $details).frame(minHeight: 120)
            }
            Section {
                Button {
                    Task { await submit() }
                } label: {
                    HStack {
                        Spacer()
                        Text(submitting ? "Submitting…" : submitLabel).bold()
                        Spacer()
                    }
                }
                .disabled(title.isEmpty || submitting)
                .tint(primary)
            }
        }
        #if os(macOS)
        .formStyle(.grouped)
        #endif
        .onAppear {
            if !enabledKinds.contains(kind), let first = enabledKinds.first { kind = first }
        }
    }

    private var submitLabel: String {
        switch kind {
        case .featureRequest: return "Submit feature request"
        case .bugReport:      return "Report bug"
        case .improvement:    return "Suggest improvement"
        case .appreciation:   return "Send appreciation"
        case .other:          return "Send"
        }
    }

    /// The host app's icon (macOS: the running app's; iOS: the primary icon from
    /// Info.plist). Nil when the bundle has none, e.g. a bare test executable on iOS.
    private var hostAppIcon: Image? {
        #if os(macOS)
        return Image(nsImage: NSApp.applicationIconImage)
        #elseif canImport(UIKit)
        guard let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
              let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
              let files = primary["CFBundleIconFiles"] as? [String],
              let name = files.last, let image = UIImage(named: name) else { return nil }
        return Image(uiImage: image)
        #else
        return nil
        #endif
    }

    private var poweredByURL: URL {
        hub.branding?.url.flatMap(URL.init(string:)) ?? URL(string: "https://heedkit.com/?ref=widget")!
    }

    private var poweredByLabel: Text {
        let label = hub.branding?.label ?? "Powered by HeedKit"
        // Keep the brand name semibold when the label has the canonical shape.
        if label.hasPrefix("Powered by ") {
            return Text("Powered by ") + Text(label.dropFirst("Powered by ".count)).fontWeight(.semibold)
        }
        return Text(label)
    }

    // MARK: - Actions

    private func close() {
        if let onClose { onClose() } else { dismiss() }
    }

    private func refresh() async {
        loading = true
        defer { loading = false }
        features = (try? await hub.list(kind: activeKind.asKind)) ?? []
    }

    private func vote(_ f: Feature) async {
        guard let r = try? await hub.vote(featureId: f.id) else { return }
        if let i = features.firstIndex(where: { $0.id == f.id }) {
            features[i].voted = r.voted
            features[i].vote_count = r.count
        }
    }

    private func submit() async {
        submitting = true
        defer { submitting = false }
        do {
            _ = try await hub.submit(title: title, description: details, kind: kind)
            title = ""; details = ""
            mode = .browse
            // Land them on the tab matching what they just posted.
            if hub.theme.groupMode == .tabs { activeKind = .specific(kind) }
            await refresh()
        } catch {}
    }
}

// MARK: - Single row

@available(iOS 15.0, macOS 12.0, *)
private struct FeatureRow: View {
    let feature: Feature
    let interactions: [Interaction]
    let showCount: Bool
    let primary: Color
    let onInteraction: (Interaction) -> Void

    @State private var commentsOpen = false
    @State private var comments: [Comment] = []
    @State private var commentsLoaded = false
    @State private var commentDraft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                actionsColumn
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(feature.title).font(.headline)
                        KindBadge(kind: feature.featureKind)
                        if feature.status != "open" {
                            Text(feature.status.replacingOccurrences(of: "_", with: " "))
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                    if !feature.description.isEmpty {
                        Text(feature.description).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { Task { await toggleComments() } }
            }
            if commentsOpen { commentsSection }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var actionsColumn: some View {
        if interactions.isEmpty {
            // Read-only mode (no interactions enabled). Show count only when asked to.
            if showCount {
                Text("\(feature.vote_count)")
                    .font(.caption.bold())
                    .frame(width: 44, height: 36)
                    .background(Color.secondary.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        } else {
            VStack(spacing: 4) {
                ForEach(interactions, id: \.self) { i in
                    Button { onInteraction(i) } label: {
                        VStack(spacing: 0) {
                            Image(systemName: i.systemImage).font(.caption.bold())
                            if showCount {
                                Text("\(feature.vote_count)").font(.caption2.bold())
                            }
                        }
                        .frame(width: 44, height: 36)
                        .foregroundStyle(feature.voted ? .white : primary)
                        .background(feature.voted ? primary : primary.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .accessibilityLabel(i.accessibilityLabel)
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            if !commentsLoaded {
                ProgressView().padding(.vertical, 6)
            } else if comments.isEmpty {
                Text("No replies yet.").font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(comments) { c in
                    HStack(alignment: .top, spacing: 6) {
                        Text(c.author_name ?? "Anonymous").font(.caption.bold())
                        Text(c.body).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            HStack {
                TextField("Add a reply…", text: $commentDraft)
                    .textFieldStyle(.roundedBorder)
                Button("Reply") {
                    Task { await sendComment() }
                }
                .disabled(commentDraft.isEmpty)
                .tint(primary)
            }
        }
        .padding(.leading, 56)
    }

    private func toggleComments() async {
        commentsOpen.toggle()
        if commentsOpen, !commentsLoaded {
            comments = (try? await HeedKit.shared.listComments(featureId: feature.id)) ?? []
            commentsLoaded = true
        }
    }

    private func sendComment() async {
        let body = commentDraft
        commentDraft = ""
        if let c = try? await HeedKit.shared.comment(featureId: feature.id, body: body) {
            comments.append(c)
        }
    }
}

// MARK: - Helpers

@available(iOS 15.0, macOS 12.0, *)
private struct ContentEmpty: View {
    let text: String
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles").font(.title).foregroundStyle(.secondary)
            Text(text).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Small pill showing a submission's kind. Public so apps can reuse it
/// (e.g. in their own headless list UI alongside `HeedKit.shared.list()`).
@available(iOS 15.0, macOS 12.0, *)
public struct KindBadge: View {
    public let kind: FeatureKind
    public init(kind: FeatureKind) { self.kind = kind }

    public var body: some View {
        HStack(spacing: 3) {
            Image(systemName: kindIcon).font(.system(size: 9, weight: .semibold))
            Text(kind.label).font(.system(size: 10, weight: .medium))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .foregroundStyle(kindForeground)
        .background(kindBackground)
        .clipShape(Capsule())
    }

    private var kindIcon: String {
        switch kind {
        case .featureRequest: return "sparkles"
        case .bugReport:      return "ant.fill"
        case .improvement:    return "lightbulb.fill"
        case .appreciation:   return "heart.fill"
        case .other:          return "bubble.left.fill"
        }
    }

    private var kindBackground: Color {
        switch kind {
        case .featureRequest: return Color(red: 0.898, green: 0.824, blue: 0.933)
        case .bugReport:      return Color(red: 1.000, green: 0.839, blue: 0.863)
        case .improvement:    return Color(red: 1.000, green: 0.902, blue: 0.620)
        case .appreciation:   return Color(red: 0.812, green: 0.914, blue: 0.835)
        case .other:          return Color(red: 0.800, green: 0.875, blue: 0.949)
        }
    }

    private var kindForeground: Color {
        switch kind {
        case .featureRequest: return Color(red: 0.314, green: 0.157, blue: 0.427)
        case .bugReport:      return Color(red: 0.522, green: 0.129, blue: 0.227)
        case .improvement:    return Color(red: 0.420, green: 0.329, blue: 0.000)
        case .appreciation:   return Color(red: 0.122, green: 0.353, blue: 0.212)
        case .other:          return Color(red: 0.106, green: 0.275, blue: 0.435)
        }
    }
}

private extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces).uppercased()
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(
            red: Double((v >> 16) & 0xff) / 255,
            green: Double((v >> 8) & 0xff) / 255,
            blue: Double(v & 0xff) / 255
        )
    }
}
#endif
