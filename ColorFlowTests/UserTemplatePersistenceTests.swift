import XCTest
@testable import ColorFlow

final class UserTemplatePersistenceTests: XCTestCase {

    // Each test gets its own StorageService instance; documents are shared on disk,
    // so we clean up any template directories/index we create.

    private var storage: StorageService!
    private var createdTemplateIDs: [UUID] = []

    override func setUp() {
        super.setUp()
        storage = StorageService()
        createdTemplateIDs = []
    }

    override func tearDown() {
        for id in createdTemplateIDs {
            let dir = StorageService.documentsURL
                .appendingPathComponent("UserTemplates/\(id.uuidString)")
            try? FileManager.default.removeItem(at: dir)
        }
        // Reload and re-save the index to remove our test entries.
        let remaining = storage.loadUserTemplates()
            .filter { !createdTemplateIDs.contains($0.id) }
        // (Re-save is internal; just verify cleanup via loadUserTemplates.)
        super.tearDown()
    }

    // MARK: - Save and load

    func test_saveAndLoad_roundtrip() throws {
        let template = makeTemplate(name: "Round Trip Test")
        try storage.saveUserTemplate(template, svgString: validSVG(name: "Round Trip Test"), thumbnail: nil)
        createdTemplateIDs.append(template.id)

        let loaded = storage.loadUserTemplates()
        let found = loaded.first { $0.id == template.id }

        XCTAssertNotNil(found, "Saved template should appear in loadUserTemplates()")
        XCTAssertEqual(found?.name, template.name)
        XCTAssertEqual(found?.preset, template.preset)
    }

    func test_save_writesSVGToDisk() throws {
        let template = makeTemplate(name: "SVG Disk Test")
        let svg = validSVG(name: "SVG Disk Test")
        try storage.saveUserTemplate(template, svgString: svg, thumbnail: nil)
        createdTemplateIDs.append(template.id)

        let svgURL = StorageService.documentsURL.appendingPathComponent(template.svgPath)
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: svgURL.path),
            "SVG file must exist at \(template.svgPath)"
        )
        let diskContent = try String(contentsOf: svgURL, encoding: .utf8)
        XCTAssertTrue(diskContent.contains("viewBox"), "Saved SVG must contain viewBox")
    }

    func test_save_writesToThumbnail_whenProvided() throws {
        let template  = makeTemplate(name: "Thumbnail Test")
        let thumbnail = makeThumbnail()
        try storage.saveUserTemplate(template, svgString: validSVG(name: "Thumb"), thumbnail: thumbnail)
        createdTemplateIDs.append(template.id)

        let thumbURL = StorageService.documentsURL.appendingPathComponent(template.thumbnailPath)
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: thumbURL.path),
            "Thumbnail PNG must exist at \(template.thumbnailPath)"
        )
    }

    // MARK: - Delete

    func test_delete_removesFromIndex() throws {
        let template = makeTemplate(name: "Delete Test")
        try storage.saveUserTemplate(template, svgString: validSVG(name: "Delete"), thumbnail: nil)
        createdTemplateIDs.append(template.id)

        storage.deleteUserTemplate(template)
        let remaining = storage.loadUserTemplates()
        XCTAssertNil(remaining.first { $0.id == template.id },
                     "Deleted template must not appear in the index")
    }

    func test_delete_removesDirectoryFromDisk() throws {
        let template = makeTemplate(name: "Delete Dir Test")
        try storage.saveUserTemplate(template, svgString: validSVG(name: "DelDir"), thumbnail: nil)
        // Don't add to cleanup list — the test verifies deletion itself.

        storage.deleteUserTemplate(template)
        let dir = StorageService.documentsURL.appendingPathComponent(template.directoryPath)
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: dir.path),
            "Template directory must be removed from disk after deletion"
        )
    }

    // MARK: - UUID stability

    func test_save_preservesUUID() throws {
        let template = makeTemplate(name: "UUID Stability")
        try storage.saveUserTemplate(template, svgString: validSVG(name: "UUID"), thumbnail: nil)
        createdTemplateIDs.append(template.id)

        let loaded = storage.loadUserTemplates().first { $0.id == template.id }
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.id, template.id, "UUID must survive a save/load round-trip")
    }

    // MARK: - Two templates, same name

    func test_twoTemplates_sameNameDifferentUUIDs() throws {
        let t1 = makeTemplate(name: "Dupe Name")
        let t2 = makeTemplate(name: "Dupe Name")
        try storage.saveUserTemplate(t1, svgString: validSVG(name: "Dupe"), thumbnail: nil)
        try storage.saveUserTemplate(t2, svgString: validSVG(name: "Dupe"), thumbnail: nil)
        createdTemplateIDs.append(t1.id)
        createdTemplateIDs.append(t2.id)

        let all = storage.loadUserTemplates().filter { $0.name == "Dupe Name" }
        XCTAssertGreaterThanOrEqual(all.count, 2,
            "Two templates with the same name must coexist when they have different UUIDs")
    }

    // MARK: - asTemplate conversion

    func test_asTemplate_hasSameUUID() {
        let userTemplate = makeTemplate(name: "As Template")
        let template = userTemplate.asTemplate()
        XCTAssertEqual(template.id, userTemplate.id)
        XCTAssertEqual(template.name, userTemplate.name)
        XCTAssertNotNil(template.userTemplateDirectoryPath,
                        "Converted template must have userTemplateDirectoryPath set")
    }

    func test_asTemplate_svgURLResolvesFromDocuments() throws {
        let template = makeTemplate(name: "URL Resolve")
        let svg = validSVG(name: "URL Resolve")
        try storage.saveUserTemplate(template, svgString: svg, thumbnail: nil)
        createdTemplateIDs.append(template.id)

        let converted = template.asTemplate()
        XCTAssertNotNil(converted.svgURL,
            "svgURL must resolve after the SVG is saved to Documents/")
    }

    // MARK: - Helpers

    private func makeTemplate(name: String) -> UserTemplate {
        UserTemplate(id: UUID(), name: name, preset: PhotoStylePreset.simple.rawValue)
    }

    private func validSVG(name: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
        <title>\(name)</title>
        <path id="region-1" d="M 10 10 L 90 10 L 90 90 L 10 90 Z" fill="none" stroke="#000000" stroke-width="2"/>
        </svg>
        """
    }

    private func makeThumbnail() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 400))
        return renderer.image { context in
            UIColor.lightGray.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 400, height: 400))
        }
    }
}
