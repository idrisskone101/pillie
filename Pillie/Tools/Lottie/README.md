# Lottie: Early Value Proof "unlock success" payoff

`gen-payoff.mjs` procedurally generates the celebration burst played when the
user checks in on the Early Value Proof screen (issue #74).

Output is bundled at `Pillie/Pillie/Resources/unlock_success.json` and played by
`ProtectionPlanEarlyValueProofView` via lottie-ios.

## Regenerate / iterate (uses the diffusionstudio/lottie skill player)

```bash
npx degit diffusionstudio/lottie /tmp/pillie-lottie-player
cp Pillie/Tools/Lottie/gen-payoff.mjs /tmp/pillie-lottie-player/script/
cd /tmp/pillie-lottie-player && npm install && npm run dev   # preview at localhost:3030
node script/gen-payoff.mjs            # player build (has bgColor slot for preview)
APP=1 node script/gen-payoff.mjs      # app build (no slots/bg — lottie-ios safe)
cp public/projects/main-project/scene-1/lottie.json \
   <repo>/Pillie/Pillie/Resources/unlock_success.json
```

`APP=1` strips the player-only `bgColor` slot + invisible background layer; a
slot-only fill with no default value can fail lottie-ios's parser.
