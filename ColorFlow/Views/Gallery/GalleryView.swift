import SwiftUI

struct GalleryView: View {
    @Environment(GalleryViewModel.self) var viewModel
    @State private var showTemplateLibrary = false

    let columns = [GridItem(.adaptive(minimum: 200), spacing: 16)]

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.projects.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(viewModel.projects) { project in
                                ProjectCell(project: project) {
                                    viewModel.open(project)
                                } onDelete: {
                                    viewModel.delete(project)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("My Gallery")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showTemplateLibrary = true
                    } label: {
                        Label("New", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showTemplateLibrary) {
                TemplateLibraryView()
            }
            .fullScreenCover(item: Bindable(viewModel).openedProject) { item in
                CanvasView(viewModel: CanvasViewModel(project: item.project, template: item.template))
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.14))
                    .frame(width: 140, height: 140)
                Image(systemName: "paintpalette")
                    .font(.system(size: 56))
                    .foregroundStyle(AppTheme.accent)
            }
            Text("Start Coloring")
                .font(AppTheme.displayFont(size: 26, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text("Pick a template and bring it to life.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
            Button {
                showTemplateLibrary = true
            } label: {
                Text("Browse Templates")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(AppTheme.accentGradient))
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
}

// MARK: - Project Cell

private struct ProjectCell: View {
    let project: Project
    let onOpen: () -> Void
    let onDelete: () -> Void
    @State private var thumbnail: UIImage?

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.1))
                        .aspectRatio(1, contentMode: .fit)

                    if let thumb = thumbnail {
                        Image(uiImage: thumb)
                            .resizable()
                            .scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Image(systemName: "paintpalette")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(project.templateName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                Text(project.modifiedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) { onDelete() } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .task { await loadThumbnail() }
    }

    private func loadThumbnail() async {
        let url = StorageService.documentsURL.appendingPathComponent(project.thumbnailPath)
        if let data = try? Data(contentsOf: url) {
            thumbnail = UIImage(data: data)
        }
    }
}
