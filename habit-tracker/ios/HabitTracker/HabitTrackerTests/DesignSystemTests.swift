// [review:need-review] PHASE-01/32-ios-lime-tech-design-pass
// summary: unit tests for DesignSystem hex-literal color parsing (palette tokens resolve to correct RGB)
import SwiftUI
import UIKit
import XCTest

@testable import HabitTracker

final class DesignSystemTests: XCTestCase {
    private func rgb(_ color: Color) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b)
    }

    func testLimeTokenResolvesToReferenceRGB() {
        let (r, g, b) = rgb(DS.Palette.lime)
        XCTAssertEqual(r, 0xB8 / 255.0, accuracy: 0.01)
        XCTAssertEqual(g, 0xFF / 255.0, accuracy: 0.01)
        XCTAssertEqual(b, 0x36 / 255.0, accuracy: 0.01)
    }

    func testBackgroundTokenIsNearBlack() {
        let (r, g, b) = rgb(DS.Palette.background)
        XCTAssertEqual(r, 0x09 / 255.0, accuracy: 0.01)
        XCTAssertEqual(g, 0x09 / 255.0, accuracy: 0.01)
        XCTAssertEqual(b, 0x09 / 255.0, accuracy: 0.01)
    }

    func testHexLiteralInitParsesArbitraryValue() {
        let (r, g, b) = rgb(Color(hex6: 0x60A5FA))
        XCTAssertEqual(r, 0x60 / 255.0, accuracy: 0.01)
        XCTAssertEqual(g, 0xA5 / 255.0, accuracy: 0.01)
        XCTAssertEqual(b, 0xFA / 255.0, accuracy: 0.01)
    }
}
