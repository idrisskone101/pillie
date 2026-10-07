import XCTest

@testable import Pillie

final class ItalianCommerceRuntimeLocalizationTests: XCTestCase {
    func testPurchaseSuccessComparisonAndErrorCopyUseItalian() {
        let italian = Locale(identifier: "it_IT")

        let success = PaywallSuccessContent.make(
            receipt: .lifetime,
            isReturning: false,
            opensFromSettings: true,
            reminder: nil,
            blockingSetUp: false,
            reminderHour: 20,
            reminderMinute: 0,
            now: Date(timeIntervalSince1970: 1_791_331_200),
            calendar: Calendar(identifier: .gregorian),
            locale: italian
        )
        XCTAssertEqual(success.title, "Pillie Plus è attivo.")
        XCTAssertEqual(success.perksLabel, "Inclusi in Plus")
        XCTAssertEqual(success.receipt, "Pagato una volta. Non si rinnova.")

        XCTAssertEqual(
            CommercePresentation.comparisonTierLabel(
                freeIncluded: true,
                plusIncluded: true,
                locale: italian
            ),
            "Incluso in Free e Plus"
        )
        XCTAssertEqual(
            CommercePresentation.comparisonTierLabel(
                freeIncluded: false,
                plusIncluded: true,
                locale: italian
            ),
            "Solo Plus"
        )
        XCTAssertEqual(
            CommercePresentation.comparisonTierLabel(
                freeIncluded: true,
                plusIncluded: false,
                locale: italian
            ),
            "Solo Free"
        )
        XCTAssertEqual(
            CommercePresentation.comparisonTierLabel(
                freeIncluded: false,
                plusIncluded: false,
                locale: italian
            ),
            "Non incluso"
        )

        XCTAssertEqual(
            CommercePresentation.purchaseErrorMessage(
                SubscriptionPurchaseError.missingPlusEntitlement,
                locale: italian
            ),
            "L’acquisto è andato a buon fine, ma Pillie Plus non si è attivato. Riprova o ripristina gli acquisti."
        )
        let untranslatedStoreError = NSError(
            domain: "Store",
            code: 99,
            userInfo: [NSLocalizedDescriptionKey: "English-only store failure"]
        )
        XCTAssertEqual(
            CommercePresentation.purchaseErrorMessage(untranslatedStoreError, locale: italian),
            "Qualcosa è andato storto. Riprova tra un momento."
        )
        XCTAssertEqual(
            CommercePresentation.restoreErrorMessage(locale: italian),
            "Pillie non è riuscita a verificare i tuoi acquisti sull’App Store. Riprova oppure contattaci e sistemiamo tutto."
        )
        XCTAssertEqual(
            CommercePresentation.trialEndPerkSymbols,
            [
                "nosign",
                "iphone.radiowaves.left.and.right",
                "bell.badge",
                "text.bubble",
            ]
        )
    }
}
