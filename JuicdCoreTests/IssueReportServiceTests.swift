import XCTest
@testable import Juicd

final class IssueReportServiceTests: XCTestCase {
    func testRejectsBlankBody() {
        XCTAssertThrowsError(try IssueReportService.preparedBody("   \n")) { error in
            XCTAssertEqual(error as? IssueReportError, .empty)
        }
    }

    func testTrimsAndCapsLength() {
        let text = try? IssueReportService.preparedBody("  odds stuck  ")
        XCTAssertEqual(text, "odds stuck")
        let long = String(repeating: "a", count: IssueReportService.maxBodyLength + 50)
        let capped = try? IssueReportService.preparedBody(long)
        XCTAssertEqual(capped?.count, IssueReportService.maxBodyLength)
    }
}
