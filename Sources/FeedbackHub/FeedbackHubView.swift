#if canImport(SwiftUI)
import SwiftUI

@available(iOS 15.0, macOS 12.0, *)
public struct FeedbackHubView: View {
    @State private var features: [Feature] = []
    @State private var loading = true
    @State private var tab: Tab = .list
    @State private var title = ""
    @State private var details = ""
    @State private var submitting = false
    @Environment(\.dismiss) private var dismiss

    private let hub = FeedbackHub.shared

    public init() {}

    private enum Tab: Hashable { case list, suggest }

    private var primary: Color {
        Color(hex: hub.theme.primary ?? "#0D9488") ?? .accentColor
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $tab) {
                    Text("Top requests").tag(Tab.list)
                    Text("Suggest").tag(Tab.suggest)
                }
                .pickerStyle(.segmented)
                .padding()

                if tab == .list {
                    listView
                } else {
                    suggestForm
                }
            }
            .navigationTitle(hub.projectName.isEmpty ? "Feedback" : hub.projectName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task { await refresh() }
        }
    }

    private var listView: some View {
        Group {
            if loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if features.isEmpty {
                ContentEmpty(text: "No requests yet — be the first!")
            } else {
                List(features) { f in
                    HStack(spacing: 12) {
                        Button {
                            Task { await vote(f) }
                        } label: {
                            VStack(spacing: 0) {
                                Image(systemName: "chevron.up").font(.caption.bold())
                                Text("\(f.vote_count)").font(.caption.bold())
                            }
                            .frame(width: 44, height: 44)
                            .foregroundStyle(f.voted ? .white : primary)
                            .background(f.voted ? primary : primary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(f.title).font(.headline)
                            if !f.description.isEmpty {
                                Text(f.description).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private var suggestForm: some View {
        Form {
            Section("Title") {
                TextField("Short, descriptive title", text: $title)
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
                        Text(submitting ? "Submitting…" : "Submit feedback").bold()
                        Spacer()
                    }
                }
                .disabled(title.isEmpty || submitting)
                .tint(primary)
            }
        }
    }

    private func refresh() async {
        loading = true
        defer { loading = false }
        features = (try? await hub.list()) ?? []
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
            _ = try await hub.submit(title: title, description: details)
            title = ""; details = ""
            tab = .list
            await refresh()
        } catch {}
    }
}

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
