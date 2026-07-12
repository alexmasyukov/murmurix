import Testing
import AppKit
@testable import Murmurix

// Verifies that paste() preserves the user's original clipboard regardless of type.
// Exercises TextPaster.capturePasteboard/restorePasteboard on a scratch pasteboard so
// we don't disturb the shared system clipboard during the test run.

struct ClipboardRestoreTests {

    private func scratchPasteboard() -> NSPasteboard {
        NSPasteboard(name: NSPasteboard.Name("MurmurixTest-\(UUID().uuidString)"))
    }

    @Test func restoresNonStringContentAfterPaste() {
        let pb = scratchPasteboard()
        defer { pb.releaseGlobally() }

        // User's original clipboard: an image + a string on one item.
        let imageData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A]) // PNG-ish magic bytes
        let original = NSPasteboardItem()
        original.setData(imageData, forType: .tiff)
        original.setString("original text", forType: .string)
        pb.clearContents()
        pb.writeObjects([original])

        // Snapshot, then simulate our paste overwriting the clipboard with the result.
        let snapshot = TextPaster.capturePasteboard(pb)
        pb.clearContents()
        pb.setString("recognized speech", forType: .string)
        #expect(pb.data(forType: .tiff) == nil) // image was clobbered by our paste

        // Restore — the image AND the original text must come back.
        TextPaster.restorePasteboard(snapshot, on: pb)
        #expect(pb.data(forType: .tiff) == imageData)
        #expect(pb.string(forType: .string) == "original text")
    }

    @Test func restoresMultipleItems() {
        let pb = scratchPasteboard()
        defer { pb.releaseGlobally() }

        let itemA = NSPasteboardItem(); itemA.setString("first", forType: .string)
        let itemB = NSPasteboardItem(); itemB.setString("second", forType: .string)
        pb.clearContents()
        pb.writeObjects([itemA, itemB])

        let snapshot = TextPaster.capturePasteboard(pb)
        pb.clearContents()
        pb.setString("recognized", forType: .string)

        TextPaster.restorePasteboard(snapshot, on: pb)
        #expect(pb.pasteboardItems?.count == 2)
        let strings = (pb.pasteboardItems ?? []).compactMap { $0.string(forType: .string) }
        #expect(strings == ["first", "second"])
    }

    @Test func emptyClipboardIsRestoredByClearing() {
        let pb = scratchPasteboard()
        defer { pb.releaseGlobally() }

        pb.clearContents() // originally empty
        let snapshot = TextPaster.capturePasteboard(pb)
        #expect(snapshot.isEmpty)

        pb.clearContents()
        pb.setString("recognized", forType: .string)
        TextPaster.restorePasteboard(snapshot, on: pb)
        #expect(pb.string(forType: .string) == nil) // faithfully back to empty
    }
}
