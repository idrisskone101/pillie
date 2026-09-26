import XCTest

@testable import Pillie

final class ItalianCommerceRuntimeLocalizationTests: XCTestCase {
    func testPurchaseSuccessComparisonAndErrorCopyUseItalian() {
        let italian = Locale(identifier: "it_IT")

        XCTAssertEqual(
            CommercePresentation.trialEndSuccessSubtitle(
                cohort: .blockerConfigured,
                locale: italian
            ),
            "Pillie Plus è attivo. Il blocco app torna dal prossimo promemoria."
        )
        XCTAssertEqual(
            CommercePresentation.trialEndSuccessSubtitle(
                cohort: .reminderOnly,
                locale: italian
            ),
            "Pillie Plus è attivo. Puoi impostare il blocco app quando vuoi."
        )

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
            CommercePresentation.restoreErrorMessage(untranslatedStoreError, locale: italian),
            "Qualcosa è andato storto. Riprova tra un momento."
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
