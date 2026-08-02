import XCTest

final class GermanInfoPlistLocalizationTests: XCTestCase {
    func testMainAppPackagesGermanPermissionUsageDescriptions() throws {
        let resourceURL = try XCTUnwrap(
            Bundle.main.url(
                forResource: "InfoPlist",
                withExtension: "strings",
                subdirectory: nil,
                localization: "de"
            ),
            "The main app must package a German InfoPlist.strings resource"
        )
        let data = try Data(contentsOf: resourceURL)
        let values = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil)
                as? [String: String]
        )

        XCTAssertEqual(
            values["NSMotionUsageDescription"],
            "Pillie verwendet Bewegungssensoren, um Schütteln zu erkennen, wenn du eine Aktion bestätigst."
        )
        XCTAssertEqual(
            values["NSUserTrackingUsageDescription"],
            "Erlaube das Tracking, damit wir nachvollziehen können, über welche Kanäle du Pillie gefunden hast, und die App verbessern können. Wir verkaufen deine personenbezogenen Daten niemals."
        )
    }

    func testEmbeddedExtensionsPackageNeutralGermanDisplayNames() throws {
        let plugInsURL = try XCTUnwrap(Bundle.main.builtInPlugInsURL)
        let extensionNames = [
            "PillieDeviceActivityMonitor",
            "PillieShieldAction",
            "PillieShieldConfiguration",
        ]

        for extensionName in extensionNames {
            let bundleURL = plugInsURL.appendingPathComponent("\(extensionName).appex")
            let bundle = try XCTUnwrap(Bundle(url: bundleURL), extensionName)
            let stringsURL = try XCTUnwrap(
                bundle.url(
                    forResource: "InfoPlist",
                    withExtension: "strings",
                    subdirectory: nil,
                    localization: "de"
                ),
                "\(extensionName) must package German InfoPlist.strings"
            )
            let data = try Data(contentsOf: stringsURL)
            let values = try XCTUnwrap(
                PropertyListSerialization.propertyList(from: data, format: nil)
                    as? [String: String]
            )
            XCTAssertEqual(values["CFBundleDisplayName"], "Pillie", extensionName)
        }
    }
}
