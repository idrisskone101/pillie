import XCTest

final class ItalianInfoPlistLocalizationTests: XCTestCase {
    func testMainAppPackagesItalianPermissionUsageDescriptions() throws {
        let resourceURL = try XCTUnwrap(
            Bundle.main.url(
                forResource: "InfoPlist",
                withExtension: "strings",
                subdirectory: nil,
                localization: "it"
            ),
            "The main app must package an Italian InfoPlist.strings resource"
        )
        let data = try Data(contentsOf: resourceURL)
        let values = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil)
                as? [String: String]
        )

        XCTAssertEqual(
            values["NSMotionUsageDescription"],
            "Pillie usa il movimento per rilevare le scosse quando confermi una registrazione."
        )
        XCTAssertEqual(
            values["NSUserTrackingUsageDescription"],
            "Consenti il tracciamento per aiutare Pillie a capire quali canali ti hanno fatto conoscere Pillie e migliorare l’app. Non vendiamo mai i tuoi dati personali."
        )
    }

    func testEmbeddedExtensionsPackageNeutralItalianDisplayNames() throws {
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
                    localization: "it"
                ),
                "\(extensionName) must package Italian InfoPlist.strings"
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
