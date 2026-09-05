# ENG-57 copy ship workflow

Done when every locked EN/DE/IT triple from ENG-58 and ENG-62 through ENG-73 is in the catalogs (or a new key this work adds), English no longer uses Swift fallbacks on those surfaces, and the iPhone 17 Pro simulator shows the locked words.

Rigor is high on key mapping and live proof. Low on design. The copy is locked.

architect skipped. The strings are already chosen.

## Units

1. Scaffold the locked-copy table and apply/verify scripts.
2. Apply catalog triples. Verify with the script against the table.
3. Add due-action and plus-gate keys that do not exist yet.
4. Delete EN Swift fallbacks so EN uses the same catalog path as DE/IT.
5. Point FAB, status card, streak label, and plus-gate bodies at the right keys. Drop uppercase modifiers that fight locked lowercase.
6. Wire leftover onboarding screens that still use `.default`.
7. Update tests that pin old English or German.
8. Prove each slice on the simulator.
9. Open the PR.

One worktree. One writer on the xcstrings files.

## Predicate

- `python3 Pillie/scripts/copy-rewrite/apply-locked-copy.py verify` exits 0.
- German and Italian localization contract scripts still pass placeholders and claim bans.
- Simulator AX / screenshot for Today, History, Settings, plus-gates, paywall, trial, onboarding matches the locked EN words.
- No analytics event names, code identifiers, or medical-claim rules changed.
