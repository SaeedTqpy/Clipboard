import XCTest
@testable import Clipboard

final class ClipboardPermissionAuditTests: XCTestCase {
    func testTranslocatedBuildIsNotConsideredInstalled() {
        XCTAssertEqual(
            ClipboardPermissionAudit.installLocation(
                for: "/private/var/folders/x/AppTranslocation/123/d/Clipboard.app"
            ), .translocated
        )
    }

    func testOnlyExactSystemApplicationsPathIsRecognized() {
        XCTAssertEqual(
            ClipboardPermissionAudit.installLocation(for: "/Applications/Clipboard.app"),
            .applications
        )
        XCTAssertEqual(
            ClipboardPermissionAudit.installLocation(
                for: "/Users/test/Downloads/Clipboard.app"
            ), .other
        )
    }

    func testAdHocIdentityIsExplicitlyVersionSpecific() {
        XCTAssertEqual(
            ClipboardPermissionAudit.classifySignature(
                "Identifier=dev.clipboard.app\nSignature=adhoc", exitCode: 0
            ), .adHoc
        )
    }

    func testUnsignedFailureIsNotMistakenForWorkingIdentity() {
        XCTAssertEqual(
            ClipboardPermissionAudit.classifySignature(
                "code object is not signed at all", exitCode: 1
            ), .unsigned
        )
    }

    func testCertificateSignedBuildIsDistinguishedFromAdHoc() {
        XCTAssertEqual(
            ClipboardPermissionAudit.classifySignature(
                "Identifier=dev.clipboard.app\nAuthority=Developer ID Application: Example",
                exitCode: 0
            ), .certificate
        )
    }
}
