# ENG-57 girly-pop copy ship

Locked EN/DE/IT from ENG-58 and ENG-62 through ENG-73 goes live. The user sees the signed-off voice on Today, History, Settings, plus-gates, paywalls, onboarding, and notifications. The next engineer inherits one table and a rerunnable apply/verify script, not a pile of hand edits.

## Done predicate

Every locked triple in `tools/girly-pop-copy/catalog.py` matches the compiled catalogs. Due-action, plus-gate, and protection-card leftovers that ignored English catalogs now read those keys. Simulator AX on Today, History, Settings, and the smart-reminders gate shows the locked English. Medical-claim rules, analytics event names, and identifiers stay unchanged.

## Rigor

Copy is locked, so no design arena. The risk is a wrong key or a hardcoded English bypass. High rigor on mapping and live proof. Low rigor on wording.

## Units

1. Harness. Catalog dump, locked table, apply/verify script.
2. Apply catalogs. One writer on the three xcstrings files.
3. Wire leftovers. Due-action verbs, plus-gate bodies, EN-hardcoded cards.
4. Catalog verify script.
5. Simulator proof on the named surfaces.
6. Open the PR.

## Fan-out

None on the catalogs. They are one shared write target. Swift leftovers stay in this worktree after the table lands.

## Architect

Skipped. The copy is locked. The shape is a table of triples, not a new abstraction.
