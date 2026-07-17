import SwiftUI

/// Export options + progress + share.
struct ExportSheet: View {
    @Bindable var state: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(String(localized: "Duration"), selection: $state.exportDuration) {
                        Text(verbatim: "3s").tag(3.0)
                        Text(verbatim: "6s").tag(6.0)
                        Text(verbatim: "12s").tag(12.0)
                    }
                    .pickerStyle(.segmented)
                    .disabled(state.isExporting)
                    Picker(String(localized: "Resolution"), selection: $state.exportResolution) {
                        ForEach(ExportResolution.allCases) { resolution in
                            Text(verbatim: resolution.displayName).tag(resolution)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(state.isExporting)
                } header: {
                    Text("Seamless Loop Video")
                }

                Section {
                    if state.isExporting {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Creating video…")
                                .font(.footnote)
                            ProgressView(value: state.exportProgress)
                        }
                    } else {
                        Button {
                            state.startExport()
                        } label: {
                            Label(String(localized: "Create Loop Video"), systemImage: "film")
                        }
                    }
                    if let url = state.exportedVideoURL {
                        ShareLink(item: url) {
                            Label(String(localized: "Share Video"), systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
            .navigationTitle(Text("Export"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Done")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

/// Saved formulas list.
struct FavoritesSheet: View {
    @Bindable var state: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        state.saveCurrentAsFavorite()
                    } label: {
                        Label(String(localized: "Save Current Formula"), systemImage: "star.fill")
                    }
                }
                Section {
                    if state.favorites.isEmpty {
                        Text("No saved formulas yet.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(state.favorites) { favorite in
                        Button {
                            state.applyFavorite(favorite)
                            dismiss()
                        } label: {
                            Text(verbatim: favorite.name)
                                .font(.system(.footnote, design: .monospaced))
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                    }
                    .onDelete { offsets in
                        state.deleteFavorites(at: offsets)
                    }
                }
            }
            .navigationTitle(Text("Favorites"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Done")) {
                        dismiss()
                    }
                }
            }
        }
    }
}
