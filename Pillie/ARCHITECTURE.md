# Pillie Architecture (Sync-First)

## Core Principle
`PillStore` is the single source of truth for schedule read state and dose mutations.
UI views should not compute schedule status directly from `PillPack.days` or `DoseScheduleEngine`.

## Read Path
1. Views request `PillScheduleSnapshot` through `PillStore` query APIs.
2. `PillStore` resolves the correct pack for a date (`pack(for:)`).
3. `PillStore` combines persisted day records and `DoseScheduleEngine` fallback rules into one snapshot.
4. Home, Calendar, and Settings render from snapshot fields (`status`, `dueAction`, `actionType`).

## Mutation Path
1. User actions (`markTodayAsTaken`, protocol edits, reminder settings) call `PillStore` methods.
2. `PillStore` updates SwiftData models and persists.
3. `NotificationManager` is rescheduled after relevant mutations.

## Guardrails
- Treat `.upcoming` records as non-terminal and recompute status for past dates.
- Keep `pack(for:)` authoritative for historical timeline lookups.
- Keep calendar read-only in this architecture pass.
- Reuse shared helpers/components for onboarding header, reminder time conversion, and regimen subtitle text.
