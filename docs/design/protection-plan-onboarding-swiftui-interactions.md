# Protection Plan Onboarding SwiftUI Interaction Blueprint

The Superdesign screens are the static composition reference. The shipped onboarding should add a SwiftUI-native interaction layer across the whole flow so the experience feels alive, premium, and app-native rather than like static slides.

Use Pillie's existing brand colors, typography, `PillieMotion`, `InteractionFeedback`, `PerformanceTier`, and `OnboardingBackground`. New motion should be expressive but purposeful: it should clarify the protection plan, not decorate the screen.

## Global Interaction System

**Plan Builder Thread**:
A small persistent visual thread should connect the calibration screens. As the user answers, a tiny plan capsule or shield marker fills segment-by-segment using `matchedGeometryEffect`, `contentTransition`, and `PillieMotion.commitSpring`. It should make the long flow feel like a plan being built, not a quiz.

**Selected State Motion**:
Single-select rows should use a springy card settle, icon morph, and check/radio transition. Multi-select chips should lock into place with a soft haptic and a subtle scale pulse. Disabled CTAs should remain quiet; when the required answer is selected, the CTA should brighten and spring in once.

**Progress Motion**:
The calibration progress bar should advance with a moving pill/shield bead instead of only changing width. This can be implemented with `matchedGeometryEffect` or a small animated overlay. The setup branch after paywall should switch to status steps, not the calibration progress bar.

**Background Motion**:
Keep the existing soft blob background but make it respond lightly to screen type: calmer on consent/review, slightly more kinetic on proof and plan reveal, almost still on permission/denied states. Respect `PerformanceTier.constrained` and Reduce Motion by freezing spatial motion and using opacity/crossfade only.

**Haptics**:
Use `choice` for selection, `meaningfulCommit` for moving to a committed plan step, `success` for saved blocker config or plan ready, and avoid heavy feedback except rare completion moments.

## Screen-Specific Interaction Direction

**Welcome**:
Show Pillie as the thing that interrupts drift. A small social-app stack can float toward the reminder, then a coral shield slides between the apps and the pill-time card. This should loop slowly and read clearly without user input.

**Analytics Consent**:
Use a calm trust animation: privacy points reveal one by one, and a small lock/checkmark settles into place. Do not make this feel like a system permission prompt.

**Early Value Proof**:
Make this the most creative proof screen. Use a mini interactive scene: a thumb trail or attention dot moves toward a TikTok/Instagram card, the due-action reminder rings, Pillie catches the drift with a shield checkpoint, and the state resolves into `Taken`. A user tap can advance phases, while `PhaseAnimator` can autoplay the sequence once. The point is simple: Pillie protects the moment after the reminder.

**Review Prompt**:
Use a restrained star bloom or rating-card lift. Keep it soft and skippable, with no fake social proof.

**Question Screens**:
Each answer should feel like it is being added to the plan. After selection, a tiny token can animate into the plan capsule at the top. For multi-select screens, selected chips can gain a small lock/check badge and arrange with a custom flow layout.

**Distraction Choices**:
Named app choices should feel concrete, while behavior choices should feel personal. Use different icon treatments but the same selected-state rules.

**Delay Consequence**:
Selection should shift the screen tone subtly, not dramatically. The answer is emotionally specific, so avoid playful celebration here.

**Failure Frequency**:
Use Cal AI-style calibration feedback: selecting a frequency can update a small `Calibrating reminder backup` meter, but do not imply a fake score.

**Risk Window**:
Use a timeline strip that highlights the selected moment after the reminder. Label this as plan calibration, not scheduling.

**Draft Blocked Apps**:
App/category chips should gain a soft lock ring when selected. `Other` should show a small inline reassurance: exact apps are chosen later with Screen Time.

**Acquisition Source**:
Keep motion minimal. This is an optional broad product signal; the interaction should not feel like tracking.

**Routine Basics**:
Method selection can use `matchedGeometryEffect` to morph the selected card into the details surface. Reminder time should use `contentTransition(.numericText())` when the time changes and a subtle orbiting shield/pill around the chosen time.

**Personalized Diagnosis**:
Use a plan assembly animation. Previously selected answers should fly or fade into a single Draft Pill Protection Plan card. A short `Building your plan` phase can run once, then reveal the personalized diagnosis. This should feel like Cal AI's plan reveal without fake precision or scores.

**Mechanism Proof**:
Use a three-phase SwiftUI scene:
1. Reminder card rings.
2. Selected app tiles slide behind a soft lock/shield.
3. `Mark taken` unlocks the tiles and resolves to a clean home-state card.
This should be tappable and replayable. It is the clearest place to demonstrate the blocker mechanism before paywall and permission.

**Protection Paywall**:
Bring the Draft Pill Protection Plan card into the paywall with `matchedGeometryEffect` so the paywall feels like unlocking the plan the user just built. Do not introduce shake-to-confirm or unrelated Plus perks.

**Reminder Plan Ready**:
Use a calm completion animation. The reminder row checks off; the app-blocking row remains visibly incomplete but not alarming.

**Screen Time Primer / Authorization Pending**:
Use setup-status motion, not calibration motion. The primer can show a shield connecting to the iOS Screen Time glyph. The native authorization pending screen should be quiet and honest: Pillie is waiting for the iOS prompt.

**Denied Recovery**:
Motion should downshift. Show the shield incomplete or paused, then offer `Try again` and `Continue with reminders`. Avoid red/error-heavy styling.

**Real App Selection**:
After a non-empty native selection, animate the generic app count into the blocker plan. If empty, keep the CTA disabled and show the inline empty state without a punitive animation.

**Pill Protection Plan Ready**:
Use the strongest success moment in the flow: the lock ring opens, the selected app count card settles, and the plan summary resolves. Use `success` haptic and restrained confetti only if performance and Reduce Motion allow it.

## Implementation Constraints

- Every spatial animation needs a Reduce Motion fallback.
- Every animated proof scene needs a static readable state for VoiceOver and screenshots.
- Avoid animation that blocks the primary CTA longer than a short one-time reveal.
- Keep loops subtle and pause expensive `TimelineView`/`Canvas` work when off-screen.
- Use generic app counts and draft app labels only; never depend on real FamilyControls app names.
- Do not add fake scores, fake statistics, fake social proof, or medical-risk claims.
