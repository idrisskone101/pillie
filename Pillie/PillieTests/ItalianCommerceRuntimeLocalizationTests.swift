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
            "Pillie Plus è attivo: il blocco delle app è di nuovo attivo per il promemoria di stasera."
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
            "Disponibilità: Free e Plus"
        )
        XCTAssertEqual(
            CommercePresentation.comparisonTierLabel(
                freeIncluded: false,
                plusIncluded: true,
                locale: italian
            ),
            "Disponibilità: solo Plus"
        )
        XCTAssertEqual(
            CommercePresentation.comparisonTierLabel(
                freeIncluded: true,
                plusIncluded: false,
                locale: italian
            ),
            "Disponibilità: solo Free"
        )
        XCTAssertEqual(
            CommercePresentation.comparisonTierLabel(
                freeIncluded: false,
                plusIncluded: false,
                locale: italian
            ),
            "Disponibilità: nessuna"
        )

        XCTAssertEqual(
            CommercePresentation.purchaseErrorMessage(
                SubscriptionPurchaseError.missingPlusEntitlement,
                locale: italian
            ),
            "L’acquisto è stato completato, ma Pillie Plus non è stato attivato. Riprova o ripristina gli acquisti."
        )
        let untranslatedStoreError = NSError(
            domain: "Store",
            code: 99,
            userInfo: [NSLocalizedDescriptionKey: "English-only store failure"]
        )
        XCTAssertEqual(
            CommercePresentation.purchaseErrorMessage(untranslatedStoreError, locale: italian),
            "Qualcosa è andato storto. Riprova."
        )
        XCTAssertEqual(
            CommercePresentation.restoreErrorMessage(untranslatedStoreError, locale: italian),
            "Qualcosa è andato storto. Riprova."
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
