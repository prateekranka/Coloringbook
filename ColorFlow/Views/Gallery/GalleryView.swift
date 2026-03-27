import SwiftUI

struct GalleryView: View {
    @EnvironmentObject var viewModel: GalleryViewModel
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
                    .accessibilityLabel("New project")
                }
            }
            .sheet(isPresented: $showTemplateLibrary) {
                TemplateLibraryView()
            }
            .fullScreenCover(item: $viewModel.openedProject) { item in
                CanvasView(viewModel: CanvasViewModel(project: item.project, template: item.template))
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "paintpalette")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor.opacity(0.6))
            Text("Start Coloring")
                .font(.title2.bold())
            Text("Pick a template and bring it to life.")
                .foregroundStyle(.secondary)
            Button("Browse Templates") {
                showTemplateLibrary = true
            }
            .buttonStyle(.borderedProminent)
        }
        .accessibilityElement(children: .combine)
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
        .accessibilityLabel(project.templateName)
        .accessibilityValue("Modified \(project.modifiedAt.formatted(.relative(presentation: .named)))")
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
