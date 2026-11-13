import XCTest
@testable import Clipboard

final class ClipTextTests: XCTestCase {
    func testPreviewNormalizesWhitespace() {
        XCTAssertEqual(ClipText.preview("  hello  \n world \t"), "hello world")
    }

    func testPreviewLimitsLength() {
        XCTAssertEqual(ClipText.preview(String(repeating: "a", count: 400)).count, 180)
    }

    func testRecognizesWebURL() {
        XCTAssertEqual(ClipText.kind(for: "https://example.com/path"), .link)
        XCTAssertEqual(ClipText.kind(for: "http://example.com"), .link)
    }

    func testRegularTextIsNotLink() {
        XCTAssertEqual(ClipText.kind(for: "hello world"), .text)
        XCTAssertEqual(ClipText.kind(for: "file:///private/tmp/secret"), .text)
    }

    func testFingerprintIsDeterministic() {
        let a = ClipPayload(kind: .text, preview: "hello", body: "hello")
        let b = ClipPayload(kind: .text, preview: "hello", body: "hello")
        XCTAssertEqual(a.fingerprint, b.fingerprint)
        XCTAssertEqual(a.fingerprint.count, 64)
    }

    func testDifferentKindsHaveDifferentHashes() {
        let a = ClipPayload(kind: .text, preview: "test", body: "test")
        let b = ClipPayload(kind: .link, preview: "test", body: "test")
        XCTAssertNotEqual(a.fingerprint, b.fingerprint)
    }

    func testRichTextFingerprintIncludesRichFlavor() {
        let first = ClipPayload(
            kind: .richText, preview: "Hello", body: "Hello",
            richData: Data("<b>Hello</b>".utf8),
            richType: "public.html"
        )
        let second = ClipPayload(
            kind: .richText, preview: "Hello", body: "Hello",
            richData: Data("<i>Hello</i>".utf8),
            richType: "public.html"
        )
        XCTAssertNotEqual(first.fingerprint, second.fingerprint)
    }
}
