import XCTest
@testable import Strand

/// Pins the human-readable clock-correlation log line. The old raw `device=… wall=…` integers hid
/// the #120 failure mode in plain sight: a strap RTC reading 1971 looks like any other 10-digit
/// number unless the reader subtracts. The line must show the strap clock as a date with explicit
/// drift, and call out a LOST RTC loudly (an un-clocked strap banks no sensor data to flash).
final class ClockCorrelationLogTests: XCTestCase {

    private let utc = TimeZone(identifier: "UTC")!

    // Healthy clock: ±a few seconds reads as plain drift, no scary wording.
    @MainActor
    func testHealthyClockShowsDateAndSignedDrift() {
        let wall = 1_781_308_113
        let line = BLEManager.clockCorrelationLogLine(device: wall + 1, wall: wall, timeZone: utc)
        XCTAssertTrue(line.contains("strap=2026-06-12 23:48:34"), line)
        XCTAssertTrue(line.contains("(drift +1s)"), line)
        XCTAssertFalse(line.contains("RTC invalid"), line)
    }

    // The hardware-observed #120 state: strap RTC in 1971, drift −1.75e9 s. The line must make
    // the lost clock unmissable in any pasted log.
    @MainActor
    func testLostRTCIsCalledOutLoudly() {
        let line = BLEManager.clockCorrelationLogLine(device: 31_779_576, wall: 1_781_308_113,
                                                      timeZone: utc)
        XCTAssertTrue(line.contains("strap=1971-01-03"), line)
        XCTAssertTrue(line.contains("(drift -1749528537s)"), line)
        XCTAssertTrue(line.contains("RTC invalid/lost"), line)
    }

    // The boundary mirrors FIX #72's gross-staleness bar: a day of drift is the line between
    // "drifted" and "lost".
    @MainActor
    func testLostCallOutStartsBeyondOneDayOfDrift() {
        let wall = 1_781_308_113
        let justUnder = BLEManager.clockCorrelationLogLine(
            device: wall - BLEManager.clockLostThresholdSeconds, wall: wall, timeZone: utc)
        let justOver = BLEManager.clockCorrelationLogLine(
            device: wall - BLEManager.clockLostThresholdSeconds - 1, wall: wall, timeZone: utc)
        XCTAssertFalse(justUnder.contains("RTC invalid"), justUnder)
        XCTAssertTrue(justOver.contains("RTC invalid"), justOver)
    }
}
