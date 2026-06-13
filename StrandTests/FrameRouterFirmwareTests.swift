import XCTest
import WhoopProtocol
@testable import Strand

/// REPORT_VERSION_INFO routing: FrameRouter must surface the strap firmware (LiveState + the
/// one-shot log hook) so every strap log identifies the firmware family — protocol quirks are
/// firmware-specific (the SET_CLOCK/GET_CLOCK payload lengths, #120). The field decode itself is
/// pinned by WhoopProtocolTests/PostHooksTests.testCommandResponseReportVersionInfo; this covers
/// the glue from a decoded response to LiveState and the log.
final class FrameRouterFirmwareTests: XCTestCase {

    /// A valid COMMAND_RESPONSE(REPORT_VERSION_INFO) frame: harvard 41.17.6.0 / boylston 5.6.7.8
    /// (the same synthetic payload shape as PostHooksTests). frameFromPayload leaves a placeholder
    /// header CRC, which FrameRouter rejects — patch in the real one so the frame routes.
    private static func versionFrame() -> [UInt8] {
        var pay: [UInt8] = [0x0a, 0x01, 0x00]
        for v in [UInt32(41), 17, 6, 0, 5, 6, 7, 8] {
            pay += [UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF),
                    UInt8((v >> 16) & 0xFF), UInt8((v >> 24) & 0xFF)]
        }
        var frame = frameFromPayload(pay, type: 36, seq: 1, cmd: 7)
        frame[3] = crc8([frame[1], frame[2]])
        return frame
    }

    @MainActor
    func testVersionResponseSetsStateAndFiresHookOnce() {
        let state = LiveState()
        let router = FrameRouter(state: state)
        var logged: [String] = []
        router.onFirmwareVersion = { logged.append($0) }

        router.handle(frame: Self.versionFrame())
        XCTAssertEqual(state.firmwareVersion, "harvard 41.17.6.0 / boylston 5.6.7.8")
        XCTAssertEqual(logged, ["harvard 41.17.6.0 / boylston 5.6.7.8"])

        // A re-query on reconnect repeats the same response — it must not spam the log.
        router.handle(frame: Self.versionFrame())
        XCTAssertEqual(logged.count, 1)
    }
}
