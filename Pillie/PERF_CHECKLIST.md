# Performance Profiling Checklist (iPhone XR/11 Baseline)

## Scenario
1. Launch app cold.
2. Complete onboarding flow.
3. Navigate Home -> History.
4. Swipe months left/right for 2 minutes.
5. Navigate to Settings and edit reminder time + interval + refill threshold.
6. Navigate back to Home and toggle `Mark as Taken` / undo 20 times.
7. Return to History and swipe for 2 more minutes.

## Instruments
1. Time Profiler (Release build on iPhone XR/11 class simulator/device).
2. Allocations with recorded generations at each step boundary.
3. Optional: Points of Interest track signposts:
`PillStorePerf.scheduleSnapshot`, `PillStorePerf.monthAdherence`, `NotificationPerf.reminderRebuild`.

## Acceptance Gates
1. Steady-state resident memory <= 95 MB.
2. Memory returns within 8 MB of idle after heavy interaction segments.
3. `Mark as Taken` interaction p95 <= 100 ms.
4. Month swipe interaction shows no visible frame drops (target >= 55 FPS equivalent).

## Recording Template
- Build SHA:
- Device / OS:
- Idle memory:
- Peak memory:
- Post-interaction memory:
- `Mark as Taken` p95:
- Notes / regressions:
