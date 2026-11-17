# The Quiet Conservatory

A playable Godot 4.7 implementation of [the plant auto-battler spec](plant-auto-battler-spec.md). A persistent alien garden is the entire game: breed organisms worth keeping, arrange their ecology, and let their roots meet another garden.

## Play

Double-click **run.command** on macOS, or import **project.godot** in Godot 4.7 and press **F5** to play. No add-ons or downloaded assets are required.

```sh
godot --path .
```

- Drag a specimen packet into a soil cell, onto the display bed, or back into the tray to bench it. Tap-to-select and tap-to-place also work. **Move** swaps occupied cells.
- Tap a plant for its compact inspection; **Examine**, or a long press, opens its genome, stats, history, and three generations of ancestors and descendants. Rename or pin favorites there.
- Open **Laboratory** to crossbreed, graft, or mutate. Parent slots accept dragged specimens and selectors. Odds and costs are shown before each experiment. Offspring mature after 12 seconds, including time away from the game.
- **Seed bank** plants saved lineage tendencies. **Codex** records seven founding species, patterns, pigments, and permanent collection milestones.
- **Battle** scouts a deterministic rival, then unfolds their garden above yours. Positioning, inherited skills, and three-of-a-type synergies shape combat. Pause, play at 2×, or release the single team Bloom Burst after 25 seconds. Battles end by 150 seconds; withered specimens always recover.
- Use **Observe** beside the display bed to gather beauty milestones. Gather collection rewards, daily growth, and seeds from mature plants. These fund further breeding without a shop.

The interface responds to desktop and portrait windows down to 390 × 780. Escape closes an overlay. Buttons and specimen cells accept keyboard focus and Enter.

## Implemented

- Seven base species and eight behavioral types; carnivorous plants appear through radiation reversion or inherited lineage, never as starters.
- Deterministic procedural botanical rendering from saved genes: six tissue patterns, independent pigment, petal, shape, form, surface, size, and glow traits. Living plants breathe and sway; graft joins and deformities remain visible.
- Diploid expressed/carried alleles, independent inheritance, ±10% parental stat variance, skills, recessive traits, G3+ combined patterns, and reduced graft inheritance. Generations grant no flat stat bonus.
- Crossbreeding, two-graft limit, 90%/65% base graft compatibility with second-graft rejection, protected favorite donors and cooldowns. Mutation uses 70% change / 20% unchanged / 10% deformity; radiation has an 8% carnivorous chance within the change outcome.
- Six display slots, live diversity/harmony/rarity scoring, beauty thresholds, species pattern pages, complete pattern-family and atlas rewards.
- Fixed-step deterministic plant combat with shade, entangling, root sustain, drifting spores, toxins, parasitic draining, devouring, inherited skills, and all eight type synergies. Opponent generations use the same inheritance code as owned plants.
- Atomic local saves, previous-save recovery, full pedigrees, discoveries that survive mutation, saved bed positions, display selection, and tray order. Saves live at Godot's `user://conservatory_v1.json`; on macOS this is normally `~/Library/Application Support/Godot/app_userdata/The Quiet Conservatory/`.

This is the offline prototype. Rivals are generated AI gardens with inspectable genes and pedigrees. Online asynchronous player snapshots and optional weekly rankings need a future service. The project is ready for Godot export; platform export templates are installed separately through Godot.

## Verification

```sh
godot --headless --path . --script res://tests/model_test.gd
godot --headless --path . --script res://tests/battle_test.gd
godot --headless --path . --script res://tests/integration_test.gd
```

Model checks exercise inheritance, risks, rewards, complete lineage saves, corruption recovery, opponent purity, and permanent collection progress. Combat checks exercise positioning, skill effects, synergies, fixed-step determinism, and specimen preservation. Integration checks run the breeding → planting → scouting → battle → rewards loop and enforce desktop/mobile overlay and garden bounds.

`tests/visual_preview.gd` renders desktop/mobile screenshots to `screenshots/` using the native renderer and a separate temporary save, leaving the player's garden untouched.
