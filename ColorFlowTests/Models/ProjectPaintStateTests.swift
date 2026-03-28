import XCTest
@testable import ColorFlow

final class ProjectPaintStateTests: XCTestCase {

    func test_encode_excludesSelectedRegionID() throws {
        var state = ProjectPaintState()
        state.selectedRegionID = "region-1"
        let data = try JSONEncoder().encode(state)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertNil(dict["selectedRegionID"])
    }

    func test_decode_withoutSelectedRegionID_defaultsToNil() throws {
        let json = #"{"regionFills":{}}"#.data(using: .utf8)!
        let state = try JSONDecoder().decode(ProjectPaintState.self, from: json)
        XCTAssertNil(state.selectedRegionID)
    }

    func test_roundTrip_regionFillsPreserved() throws {
        var state = ProjectPaintState()
        state.regionFills = ["r1": "#FF0000", "r2": "#00FF00"]
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(ProjectPaintState.self, from: data)
        XCTAssertEqual(decoded.regionFills["r1"], "#FF0000")
        XCTAssertEqual(decoded.regionFills["r2"], "#00FF00")
    }

    func test_roundTrip_freehandDrawingDataPreserved() throws {
        var state = ProjectPaintState()
        state.freehandDrawingData = Data([0x01, 0x02, 0x03])
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(ProjectPaintState.self, from: data)
        XCTAssertEqual(decoded.freehandDrawingData, Data([0x01, 0x02, 0x03]))
    }

    func test_decode_emptyJSON_defaults() throws {
        let json = "{}".data(using: .utf8)!
        let state = try JSONDecoder().decode(ProjectPaintState.self, from: json)
        XCTAssertTrue(state.regionFills.isEmpty)
        XCTAssertNil(state.freehandDrawingData)
        XCTAssertNil(state.selectedRegionID)
    }

    func test_selectedRegionID_isTrulyTransient() throws {
        var state = ProjectPaintState()
        state.selectedRegionID = "region-42"
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(ProjectPaintState.self, from: data)
        XCTAssertNil(decoded.selectedRegionID)
    }

    func test_encode_emptyState() {
        let state = ProjectPaintState()
        XCTAssertNoThrow(try JSONEncoder().encode(state))
    }
}
