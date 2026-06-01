#!/usr/bin/env python3
import plistlib
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PRIVACY_MANIFEST = ROOT / "Pillie" / "Pillie" / "PrivacyInfo.xcprivacy"
POLICY_PATHS = [
    ROOT / "docs" / "privacy-policy.md",
    ROOT / "Pillie" / "legal" / "privacy-policy.md",
]
CHECKLIST = ROOT / "docs" / "release" / "app-store-privacy-checklist.md"


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    sys.exit(1)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def normalized_text(path: Path) -> str:
    require(path.exists(), f"{path.relative_to(ROOT)} is missing")
    return path.read_text(encoding="utf-8").lower()


with PRIVACY_MANIFEST.open("rb") as manifest_file:
    manifest = plistlib.load(manifest_file)

collected_types = manifest.get("NSPrivacyCollectedDataTypes", [])
product_interaction = next(
    (
        entry
        for entry in collected_types
        if entry.get("NSPrivacyCollectedDataType")
        == "NSPrivacyCollectedDataTypeProductInteraction"
    ),
    None,
)

require(product_interaction is not None, "Privacy manifest must declare Product Interaction data")
require(
    "NSPrivacyCollectedDataTypePurposeAnalytics"
    in product_interaction.get("NSPrivacyCollectedDataTypePurposes", []),
    "Product Interaction data must be declared for Analytics",
)
require(
    product_interaction.get("NSPrivacyCollectedDataTypeLinked") is False,
    "Product Interaction data must be marked not linked to the user",
)
require(
    product_interaction.get("NSPrivacyCollectedDataTypeTracking") is False,
    "Product Interaction data must be marked not used for tracking",
)
require(manifest.get("NSPrivacyTracking") is False, "App privacy tracking must be false")

required_policy_phrases = [
    "product analytics telemetry",
    "posthog",
    "first-party analytics",
    "not for targeted advertising",
    "private routine details",
    "reminder values",
    "app-blocking selections",
    "adherence values",
    "contraception method",
    "reminder time",
    "reminder interval",
    "app-blocking app or category names",
    "taken or missed history",
    "free text",
]

for policy_path in POLICY_PATHS:
    text = normalized_text(policy_path)
    for phrase in required_policy_phrases:
        require(
            phrase in text,
            f"{policy_path.relative_to(ROOT)} must disclose or exclude '{phrase}'",
        )

checklist_text = normalized_text(CHECKLIST)
for phrase in [
    "usage data",
    "product interaction",
    "analytics",
    "not linked",
    "not used for tracking",
    "posthog",
]:
    require(phrase in checklist_text, f"Release checklist must mention '{phrase}'")

print("Privacy disclosure validation passed")
