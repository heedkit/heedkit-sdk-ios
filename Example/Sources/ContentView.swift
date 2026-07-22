import SwiftUI
import HeedKit

/// Thin UI over `DemoSession`. Walks the full SDK flow:
///   1) configure + init (DemoSession.start, fired from the App)
///   2) identify end-user  -> Session section
///   3) fetch features     -> Roadmap section
///   4) submit a feature   -> SubmitSheet
///   5) upvote (toggle)    -> FeatureRow vote button
///   6) comment            -> CommentSheet (headless) + the bundled HeedKitView
struct ContentView: View {
    @EnvironmentObject private var session: DemoSession

    @State private var widgetOpen = false
    @State private var submitOpen = false
    @State private var commentTarget: Feature?
    @State private var sort = "top"

    var body: some View {
        NavigationStack {
            List {
                if Config.keyIsPlaceholder { setupBanner }
                statusSection
                widgetSection
                roadmapSection
                sessionSection
            }
            .navigationTitle("HeedKit Demo")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { submitOpen = true } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(session.phase != .ready)
                }
            }
            .sheet(isPresented: $widgetOpen) {
                // The SDK's batteries-included widget: browse + suggest + vote +
                // comment, themed by the workspace's /sdk/init response.
                HeedKitView()
            }
            .sheet(isPresented: $submitOpen) {
                SubmitSheet().environmentObject(session)
            }
            .sheet(item: $commentTarget) { feature in
                CommentSheet(feature: feature).environmentObject(session)
            }
        }
    }

    // MARK: Sections

    private var setupBanner: some View {
        Section {
            Label {
                Text("Set `Config.workspaceKey` (or the HEEDKIT_WORKSPACE_KEY env var) to a real key, then relaunch.")
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            }
            .font(.footnote)
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        switch session.phase {
        case .idle, .initializing:
            Section {
                HStack { ProgressView(); Text("Connecting to \(Config.apiUrl)…") }
            }
        case .failed(let message):
            Section {
                Label(message, systemImage: "xmark.octagon.fill")
                    .foregroundStyle(.red).font(.footnote)
            }
        case .ready:
            if let action = session.lastAction {
                Section {
                    Label(action, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green).font(.footnote)
                }
            }
        }
    }

    private var widgetSection: some View {
        Section("Bundled widget") {
            Button { widgetOpen = true } label: {
                Label("Open HeedKitView", systemImage: "bubble.left.and.bubble.right.fill")
            }
            .disabled(session.phase != .ready)
        }
    }

    private var roadmapSection: some View {
        Section {
            Picker("Sort", selection: $sort) {
                Text("Top").tag("top")
                Text("New").tag("new")
            }
            .pickerStyle(.segmented)
            .onChange(of: sort) { newValue in
                Task { await session.reload(sort: newValue) }
            }

            if session.loadingFeatures {
                HStack { ProgressView(); Text("Loading…") }
            } else if session.features.isEmpty {
                Text("No items yet — submit one with the + button.")
                    .foregroundStyle(.secondary).font(.footnote)
            } else {
                ForEach(session.features) { feature in
                    FeatureRow(
                        feature: feature,
                        onVote: { Task { await session.toggleVote(feature) } },
                        onComment: { commentTarget = feature }
                    )
                }
            }

            if let error = session.errorMessage {
                Text(error).foregroundStyle(.red).font(.footnote)
            }
        } header: {
            HStack {
                Text("Roadmap (headless)")
                Spacer()
                Button {
                    Task { await session.reload(sort: sort) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(session.phase != .ready)
            }
        }
    }

    private var sessionSection: some View {
        Section("Session") {
            LabeledContent("Workspace", value: session.workspaceName.isEmpty ? "—" : session.workspaceName)
            LabeledContent("End-user id", value: session.endUserId ?? "—")
                .font(.system(.body, design: .monospaced))
            LabeledContent("Endpoint", value: Config.apiUrl)
                .font(.system(.footnote, design: .monospaced))
        }
    }
}

// MARK: - Feature row

private struct FeatureRow: View {
    let feature: Feature
    let onVote: () -> Void
    let onComment: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onVote) {
                VStack(spacing: 0) {
                    Image(systemName: "chevron.up").font(.caption2.bold())
                    Text("\(feature.vote_count)").font(.caption2.bold())
                }
                .frame(width: 40, height: 38)
                .foregroundStyle(feature.voted ? .white : .accentColor)
                .background(feature.voted ? Color.accentColor : Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(feature.title).font(.subheadline.weight(.semibold))
                    KindBadge(kind: feature.featureKind)
                }
                if !feature.description.isEmpty {
                    Text(feature.description)
                        .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Button(action: onComment) {
                    Label("Comments", systemImage: "text.bubble")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Submit sheet (step 4)

private struct SubmitSheet: View {
    @EnvironmentObject private var session: DemoSession
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var details = ""
    @State private var kind: FeatureKind = .featureRequest
    @State private var submitting = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Kind") {
                    Picker("Kind", selection: $kind) {
                        ForEach(session.enabledKinds, id: \.self) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.menu)
                }
                Section("Title") {
                    TextField(kind.titlePlaceholder, text: $title)
                }
                Section("Description") {
                    TextEditor(text: $details).frame(minHeight: 100)
                }
            }
            .navigationTitle("New submission")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(submitting ? "Sending…" : "Submit") {
                        Task {
                            submitting = true
                            let created = await session.submit(title: title, description: details, kind: kind)
                            submitting = false
                            if created != nil { dismiss() }
                        }
                    }
                    .disabled(title.isEmpty || submitting)
                }
            }
            .onAppear {
                if !session.enabledKinds.contains(kind), let first = session.enabledKinds.first {
                    kind = first
                }
            }
        }
    }
}

// MARK: - Comment sheet (step 6, headless)

private struct CommentSheet: View {
    let feature: Feature
    @EnvironmentObject private var session: DemoSession
    @Environment(\.dismiss) private var dismiss

    @State private var comments: [Comment] = []
    @State private var loaded = false
    @State private var draft = ""
    @State private var sending = false

    var body: some View {
        NavigationStack {
            List {
                Section(feature.title) {
                    if !loaded {
                        HStack { ProgressView(); Text("Loading…") }
                    } else if comments.isEmpty {
                        Text("No comments yet.").foregroundStyle(.secondary).font(.footnote)
                    } else {
                        ForEach(comments) { c in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.author_name ?? "Anonymous").font(.caption.bold())
                                Text(c.body).font(.callout)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Comments")
            .safeAreaInset(edge: .bottom) {
                HStack {
                    TextField("Add a comment…", text: $draft)
                        .textFieldStyle(.roundedBorder)
                    Button("Send") {
                        Task {
                            sending = true
                            if let c = await session.addComment(to: feature, body: draft) {
                                comments.append(c)
                                draft = ""
                            }
                            sending = false
                        }
                    }
                    .disabled(draft.isEmpty || sending)
                }
                .padding()
                .background(.bar)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                comments = await session.loadComments(for: feature)
                loaded = true
            }
        }
    }
}
