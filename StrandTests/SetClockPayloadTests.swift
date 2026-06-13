import XCTest
@testable import Strand

/// Pins both SET_CLOCK payload encodings (docs/BLE_REVERSE_ENGINEERING.md §SET_CLOCK). The payload
/// LENGTH is firmware-specific and load-bearing: newer WHOOP 4 firmware latches the 8-byte form and
/// ignores the 9-byte one; fw 41.17.x does the exact opposite — it ignores the 8-byte form outright
/// (no COMMAND_RESPONSE), leaving the strap un-clocked, and an un-clocked strap stops banking sensor
/// data to flash entirely (the silent no-history/no-sleep state behind #120). The app therefore sends
/// BOTH forms on every WHOOP 4 clock set; these tests pin each encoding so neither can drift.
final class SetClockPayloadTests: XCTestCase {

    // 8-byte form: [seconds u32 LE][subseconds u32 = 0]. The form newer firmware latches.
    @MainActor
    func testEightByteFormEncodesSecondsLEWithZeroSubseconds() {
        let p = BLEManager.setClockPayload(now: 0x6969_2A4C)
        XCTAssertEqual(p.count, 8)
        XCTAssertEqual(Array(p[0..<4]), [0x4C, 0x2A, 0x69, 0x69])
        XCTAssertEqual(Array(p[4...]), [0, 0, 0, 0])
    }

    // 9-byte legacy form: same u32 LE seconds + 5 zero bytes. The form fw 41.17.x REQUIRES —
    // hardware-verified 2026-06-13 (the latch that un-stuck a strap whose RTC read 1971).
    @MainActor
    func testNineByteLegacyFormSharesSecondsAndPadsFiveZeros() {
        let now: UInt32 = 1_781_308_115
        let modern = BLEManager.setClockPayload(now: now)
        let legacy = BLEManager.setClockPayloadLegacy(now: now)
        XCTAssertEqual(legacy.count, 9)
        XCTAssertEqual(Array(legacy[0..<4]), Array(modern[0..<4]))
        XCTAssertEqual(Array(legacy[4...]), [0, 0, 0, 0, 0])
    }
}
