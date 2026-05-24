import SwiftUI
import FeedbackHub

struct ContentView: View {
    @State private var feedbackOpen = false
    @State private var inlineFeatures: [Feature] = []
    @State private var loading = false
    @State private var errorMessage: String?
    @State private var lastQuick: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Try the widget") {
                    Button {
                        feedbackOpen = true
                    } label: {
                        Label("Open feedback panel", systemImage: "bubble.left.and.bubble.right.fill")
                    }
                }

                Section("Quick submit (headless)") {
                    let kinds = FeedbackHub.shared.enabledKinds.isEmpty
                        ? FeatureKind.allCases
                        : FeedbackHub.shared.enabledKinds
                    ForEach(kinds, id: \.self) { k in
                        Button {
                            Task { await quickSubmit(kind: k) }
                        } label: {
                            HStack {
                                KindBadge(kind: k)
                                Text(quickSubmitLabel(for: k))
                            }
                        }
                    }

                    if let lastQuick {
                        Text("✓ Submitted: \(lastQuick)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Headless API") {
                    Button {
                        Task { await loadFeatures() }
                    } label: {
                        if loading {
                            HStack {
                                ProgressView()
                                Text("Loading…")
                            }
                        } else {
                            Label("Fetch top requests", systemImage: "arrow.down.circle")
                        }
                    }
                    .disabled(loading)

                    ForEach(inlineFeatures) { f in
                        FeatureRow(feature: f) {
                            Task { await toggleVote(for: f) }
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section("Session") {
                    LabeledContent("Project", value: FeedbackHub.shared.projectName)
                    LabeledContent("End-user id", value: FeedbackHub.shared.endUserId ?? "—")
                        .font(.system(.body, design: .monospaced))
                }
            }
            .navigationTitle("Feedback Hub Demo")
            .sheet(isPresented: $feedbackOpen) {
                FeedbackHubView()
            }
        }
    }

    private func loadFeatures() async {
        loading = true
        errorMessage = nil
        defer { loading = false }
        do {
            inlineFeatures = try await FeedbackHub.shared.list()
        } catch {
            errorMessage = "Failed to load: \(error)"
        }
    }

    private func toggleVote(for feature: Feature) async {
        do {
            let result = try await FeedbackHub.shared.vote(featureId: feature.id)
            if let i = inlineFeatures.firstIndex(where: { $0.id == feature.id }) {
                inlineFeatures[i].voted = result.voted
                inlineFeatures[i].vote_count = result.count
            }
        } catch {
            errorMessage = "Vote failed: \(error)"
        }
    }

    private func quickSubmit(kind: FeatureKind) async {
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        let title = "\(kind.label) from iOS demo"
        let body = "Sent at \(timestamp)"
        do {
            let f = try await FeedbackHub.shared.submit(
                title: title,
                description: body,
                kind: kind
            )
            lastQuick = "\(f.featureKind.label) — \(f.title)"
            // refresh the list section if it's been loaded
            if !inlineFeatures.isEmpty {
                await loadFeatures()
            }
        } catch {
            errorMessage = "Quick submit failed: \(error)"
        }
    }

    private func quickSubmitLabel(for kind: FeatureKind) -> String {
        "Send a sample \(kind.label.lowercased())"
    }
}

private struct FeatureRow: View {
    let feature: Feature
    let onVote: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onVote) {
                VStack(spacing: 0) {
                    Image(systemName: "chevron.up").font(.caption2.bold())
                    Text("\(feature.vote_count)").font(.caption2.bold())
                }
                .frame(width: 36, height: 36)
                .foregroundStyle(feature.voted ? .white : .accentColor)
                .background(feature.voted ? Color.accentColor : Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(feature.title).font(.subheadline.weight(.semibold))
                    KindBadge(kind: feature.featureKind)
                }
                if !feature.description.isEmpty {
                    Text(feature.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
}
