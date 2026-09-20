---
name: swift-taste
description: Portable Swift/iOS structure-taste bar for Pillie. Use when writing, reviewing, or refactoring SwiftUI features, view models, services, or file layout.
---

# Swift taste

Load this before you write or review Swift layout in Pillie. The full bar is for agents. A subset is a Linux CI gate (`make swift-taste`). Compile-only is not a structure review.

This skill is the Pillie / minox-tracker taste bar. It does not replace `pillie-ios` or `verify-pillie`.

## When to load

- New SwiftUI screen, feature folder, store, or service
- A review that asks "is this the right shape?"
- Adding files under `Pillie/Pillie/Views`, `Services`, `Models`, or `Shared`
- An error path, `@State` hoist, or initializer with more than a handful of parameters

## Rules

### 1. Colocate state

Keep `@State`, `@Observable`, and the feature store next to the owning view or feature. Do not hoist to the app root or `Environment` until a second screen needs the same value.

### 2. Shrink the public API

Fewer init parameters, fewer `public` / `package` symbols, fewer flags. A long init list or an options bag is a smell. Add a parameter only when a caller already needs it.

### 3. No deps-bag injection

Refuse `struct Dependencies { var fetch…; var save… }` (or the same bag under another name) passed into a feature. Use a protocol plus a default implementation the feature imports, or a small service type. The call site stays thin.

CI fails this when a `struct` / `class` / `enum` named `Dependencies` or `*Dependencies` stores two or more function-typed properties.

### 4. Feature folders, not flat dumps

New screens go in a feature folder (`Views/Home/`, `Views/Paywall/`, …), not as a new file dumped on `Views/`, `Helpers/`, `Utils/`, or `Utilities/`.

Existing `Models/`, `Services/`, and `Shared/` layers stay. Prefer a sibling in the feature folder when the type is feature-owned.

CI fails a new `.swift` file that is a direct child of `Views/`, `Helpers/`, `Utils/`, or `Utilities/`.

### 5. Types live beside the feature

Put shared types in `Types.swift` or `FooTypes.swift` next to the feature. Do not bury them in `*View.swift` files. One-off `private` types in a helper are fine.

CI fails `public` / `package` `struct` / `enum` / `class` / `actor` types in a `*View.swift` file other than the type named like the file (`HomeView.swift` → `HomeView`).

### 6. Reuse before invent

Search the feature folder, then `Services/`, `Shared/`, and `Models/`, before adding a new helper, wrapper, or view.

### 7. Main symbol first

After imports, the file's main type comes first. Helpers go below it.

### 8. Split non-presentation logic

Move non-view logic into a sibling `Helpers` file or a use-case type the view imports. Do not inject that logic as a deps bag (rule 3).

### 9. Prefer derivation over sync

Do not mirror the same value into a second `@State`. Derive it. Keep an explicit sync only for a system bridge (StoreKit, Screen Time, notifications, `UserDefaults` mirrors that already exist).

### 10. Errors ride a railway

No empty `catch`. Log with operation + id + cause. Use a typed error or a user-facing result. Early-return on the error branch. Do not log the happy path.

CI fails `catch { }` / `catch {\n}` / comment-only catch bodies in app Swift sources.

### 11. Gates beat taste

If Xcode, SwiftLint, or tests ban a shape, land the gate change first. Do not "taste-fix" a pattern the toolchain already forbids, and do not weaken a gate to land a layout you like.

### 12. Demo after verify

A UI change is not done on "build succeeded". Load `verify-pillie`. On Linux that is `make ns-mac-qa`. On a Mac, `make qa`. You need a simulator screenshot or recording that shows the change.

## CI gate

Linux-only. No Mac.

```bash
make swift-taste-selftest   # fixtures; proves the checker
make swift-taste            # app sources + allowlist
```

Workflow: `.github/workflows/swift-taste.yml` on pull requests to `main`.

**Fails today**

- Empty or comment-only `catch` in app Swift
- New deps-bag types (`Dependencies` / `*Dependencies` with two or more function-typed properties)
- New `.swift` files dumped on `Views/`, `Helpers/`, `Utils/`, or `Utilities/` (direct children)
- Extra `public` / `package` types in `*View.swift`

**Allows today**

- Findings listed in `Pillie/scripts/swift-taste-allowlist.txt` (pre-existing debt). HEAD was clean when this gate landed, so the file is comments only.
- `Models/`, `Services/`, `Shared/`, and `Views/<Feature>/` additions
- Non-empty `catch` that logs or returns
- Protocol + `func` default impl (not a stored-closure bag)
- `private` helper types in a view file

Refresh the allowlist only when you pay down debt or a heuristic changes, in its own commit:

```bash
python3 Pillie/scripts/check-swift-taste.py --write-allowlist
```

Do not add a new smell to the allowlist to land a feature. Fix the smell.

## Heuristics

The checker is static and conservative. It does not parse Swift fully.

- **empty-catch** — `catch` whose brace body is whitespace or comments only, after strings and comments are masked.
- **deps-bag** — `struct` / `class` / `enum` whose name is `Dependencies` or ends in `Dependencies`, with two or more `let` / `var` properties whose type annotation contains `->`. Protocols and `func` methods are ignored.
- **dump-folder** — a `.swift` file whose parent directory is named `Views`, `Helpers`, `Utils`, or `Utilities`.
- **view-exported-type** — `public` or `package` type in `*View.swift` whose name is not the file stem.

False positives: refresh the allowlist in a dedicated commit and say why. False negatives: still fix them in review; the skill is stricter than CI.
