import Foundation
import Testing

@testable import Pillie

struct ExperimentAssignmentTests {
    @Test func missingRemoteValueStaysControl() {
        let assignment = ExperimentResolver.assignment(
            key: .paywallPresentation,
            remoteValue: nil,
            overrideValue: nil
        )

        #expect(assignment.variant == .control)
        #expect(assignment.source == .fallback)
        #expect(assignment.key == .paywallPresentation)
    }

    @Test func remoteTestVariantComesFromPostHog() {
        let assignment = ExperimentResolver.assignment(
            key: .paywallPresentation,
            remoteValue: "test",
            overrideValue: nil
        )

        #expect(assignment.variant == .test)
        #expect(assignment.source == .posthog)
    }

    @Test func overrideBeatsRemoteValue() {
        let assignment = ExperimentResolver.assignment(
            key: .paywallPresentation,
            remoteValue: "control",
            overrideValue: "test"
        )

        #expect(assignment.variant == .test)
        #expect(assignment.source == .debugOverride)
    }

    @Test func unknownRemoteValueIsControl() {
        let assignment = ExperimentResolver.assignment(
            key: .paywallPresentation,
            remoteValue: "purple",
            overrideValue: nil
        )

        #expect(assignment.variant == .control)
        #expect(assignment.source == .posthog)
    }

    @Test func hostedEngineRequiresTestAndAHostedPaywall() {
        let test = ExperimentAssignment(
            key: .paywallPresentation,
            variant: .test,
            source: .posthog
        )
        let control = ExperimentAssignment(
            key: .paywallPresentation,
            variant: .control,
            source: .fallback
        )

        #expect(
            PaywallPresentationPolicy.engine(
                assignment: test,
                offeringHasHostedPaywall: true
            ) == .hosted
        )
        #expect(
            PaywallPresentationPolicy.engine(
                assignment: test,
                offeringHasHostedPaywall: false
            ) == .honest
        )
        #expect(
            PaywallPresentationPolicy.engine(
                assignment: control,
                offeringHasHostedPaywall: true
            ) == .honest
        )
    }

    @Test func offeringIdentifiersStayClosed() {
        #expect(CommerceOfferingIdentifier.parse("default") == .default)
        #expect(CommerceOfferingIdentifier.parse("default_v2") == .defaultV2)
        #expect(CommerceOfferingIdentifier.parse("paywall_test") == .paywallTest)
        #expect(CommerceOfferingIdentifier.parse("something-new") == .unknown)
        #expect(CommerceOfferingIdentifier.parse(nil) == .unknown)
    }

    @Test func telemetryContextUsesClosedLabelsOnly() {
        let context = ExperimentTelemetryContext.make(
            assignment: ExperimentAssignment(
                key: .paywallPresentation,
                variant: .test,
                source: .posthog
            ),
            offering: CommerceOfferingAssignment(
                identifier: .paywallTest,
                hasHostedPaywall: true
            )
        )

        #expect(
            context.properties == [
                "experiment_key": .string("paywall-presentation"),
                "experiment_variant": .string("test"),
                "rc_offering": .string("paywall_test"),
                "paywall_engine": .string("hosted"),
            ]
        )
    }

    @Test func preferredOfferingFollowsVariantUnlessOverridden() {
        let test = ExperimentAssignment(
            key: .paywallPresentation,
            variant: .test,
            source: .posthog
        )
        let control = ExperimentAssignment(
            key: .paywallPresentation,
            variant: .control,
            source: .fallback
        )

        #expect(
            PaywallPresentationPolicy.preferredOfferingIdentifier(
                assignment: test,
                override: nil
            ) == .paywallTest
        )
        #expect(
            PaywallPresentationPolicy.preferredOfferingIdentifier(
                assignment: control,
                override: nil
            ) == nil
        )
        #expect(
            PaywallPresentationPolicy.preferredOfferingIdentifier(
                assignment: test,
                override: .default
            ) == .default
        )
    }

    @Test func hostedPaywallRequiresARealPaywallConfiguration() {
        #expect(HostedPaywallAvailability.isPresent(hasLegacyPaywall: true, hasComponents: false))
        #expect(HostedPaywallAvailability.isPresent(hasLegacyPaywall: false, hasComponents: true))
        #expect(!HostedPaywallAvailability.isPresent(hasLegacyPaywall: false, hasComponents: false))
    }

    @Test func offeringResolverPrefersAnAvailableOverride() {
        #expect(
            CommerceOfferingResolver.selectedIdentifier(
                preferred: .paywallTest,
                available: [.default, .paywallTest],
                current: .default
            ) == .paywallTest
        )
        #expect(
            CommerceOfferingResolver.selectedIdentifier(
                preferred: .paywallTest,
                available: [.default],
                current: .default
            ) == .default
        )
        #expect(
            CommerceOfferingResolver.selectedIdentifier(
                preferred: nil,
                available: [.default, .paywallTest],
                current: .default
            ) == .default
        )
    }

    @Test func overrideStoreRoundTripsVariantAndOffering() {
        let defaults = UserDefaults(suiteName: "ExperimentOverrideStoreTests-\(UUID().uuidString)")!

        ExperimentOverrideStore.setVariant(.test, for: .paywallPresentation, defaults: defaults)
        ExperimentOverrideStore.setPreferredOffering(.paywallTest, defaults: defaults)

        #expect(
            ExperimentOverrideStore.variantRawValue(
                for: .paywallPresentation,
                defaults: defaults
            ) == "test"
        )
        #expect(ExperimentOverrideStore.preferredOffering(defaults: defaults) == .paywallTest)

        ExperimentOverrideStore.clear(defaults: defaults)

        #expect(
            ExperimentOverrideStore.variantRawValue(
                for: .paywallPresentation,
                defaults: defaults
            ) == nil
        )
        #expect(ExperimentOverrideStore.preferredOffering(defaults: defaults) == nil)
    }
}
