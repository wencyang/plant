# Bloomward

A living puzzle garden in Godot 4.7. Steer a plant as it grows in real time across luminous alien landscapes. Prune it to split it into new shoots. Cross-pollinate strange wild plants to breed the gifts each garden asks for.

![Title](screenshots/01-title.png)

## Play

Double-click **run.command** on macOS, or open `project.godot` in Godot 4.7 (Forward+) and press **F5**.

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

## How it plays

Choose a seed, read its gift readiness, then press **Plant & plan**. Place lures while the garden is paused and press **Grow** (or **Space**) when ready. Your plant then grows on its own. The **leading shoot** reaches for light, and side shoots stay shorter and burst into flowers. Each garden has one or more **sunwells**. Wake all of them to make the garden bloom and unlock the next garden. The HUD counts the sunwells still waiting; extra dew and tool-par stars are optional. Golden numbered sunwells are the goals; cyan diamond lights are your lures.

- **Lures.** Click to place a glowing lure and drag it to steer. Growth waits while you hold the pointer, so you can aim precisely. Right-click or press **Esc** during a gesture to cancel without spending a tool. Shoots that reach a lure carry on past it, so a few lures make a route of waypoints. Right-click a lure to take it back.
- **Pruning.** Draw a swipe across a living stem. Before release, amber highlights show exactly which growth will fall away, scissors mark the cuts, green arrows show the surviving new shoots, and a caption shows the sap refund. Release to apply the cut, or right-click / **Esc** to cancel. The cut piece falls away, some of its sap comes back to you, and the stump wakes up as **two new leading shoots**. That's how you send one plant two ways at once.
- **Undo.** Press **Z** or the **Undo** button to rewind the most recent lure placement, drag, recall, or prune, including growth since that action. Up to eight actions are available. You return to planning with the actual tree, sap and tool counts restored. Earned seeds remain in the vault; rewinding and touching the same wild plant again cannot reroll or duplicate that attempt’s offspring. Undo is available before the garden blooms.
- **Physical rules.**
  - A stem can only stretch so far into open air. It needs rock to lean on, or it droops.
  - Sap is limited.
  - Darkness stops growth, and lures can't be placed in it.
  - Crystal blocks the way.
  - Ordinary shoots slip off glassy rock and die.
- **Cross-pollination.** Touch a wild plant with any shoot. A fruit produces **three hybrid seeds**, saved immediately to your **Seed Vault**, even if you leave before the reveal. The growing parent stays unchanged. **Replant this garden** starts a fresh attempt with the exact selected child and restores its tools; all saved seeds and earned stars stay safe. Each seed takes every visible feature from one parent or the other: leaf shape, flower form, petal count, both colours, pattern, stem style, and gifts. The reveal screen shows which parent each feature came from. The first seed always carries every gift from both parents.
- **Gifts.**

  | Gift | Comes from | What it does |
  |---|---|---|
  | Thorns | Spinebrush | Shatters crystal |
  | Glow | Lanternwort | Lets the plant grow in the dark and lights the darkness |
  | Tendrils | Hookvine | Clings to glass and climbs it |
  | Roots | Deeproot | Grows down through soil and drinks underground water for sap |
  | Buoyant | Driftcap | Grows floating bladders, so it can reach about twice as far across open air (chasms) |
  | Waxy | Emberwax | Grows through ember vents, the walls of heat that wither other shoots |
  | Glow + Roots | Moonpetal | Carries both gifts at once |
  | Thorns + Tendrils | Briarbell | Carries both gifts at once |

  The later gardens need two or three gifts at once, so you breed across generations.

- **Reading your plant.**
  - Each leading shoot wears a **reach ring**. It drains as the shoot stretches into open air and refills (with a green pulse) when the shoot touches rock. It turns red just before the shoot droops.
  - When a shoot dies, it wilts on the spot with a label saying why: "drooped — no rock to lean on", "slipped on glass", "withered in the heat", "wedged". If the plant runs out of sap, "out of sap" appears at its tip.
- **Growing downward.** Near a lure, shoots stop pulling upward, so you can lead them down into pits and shafts.
- **Tricks in later gardens.**
  - **Dew drops** refill sap.
  - **Gold key-blooms** open stone gates elsewhere.
  - **Decoy wisps** drag shoots toward hazards.
  - **Updrafts** carry shoots so they never droop.
  - **Sleeping sunwells** only wake after the one before them.
- **Stars.** Each garden awards up to 3 stars: bloom it, collect all its dew, and use no more lures and prunes than the garden's par.

There are twenty-one gardens. The first fourteen teach the gifts: First Light, Twin Wells, Crystal Throat, Lanternless, Glass Cliff, Thirst, Shattered Spire, Heart of the Grove, Drift Chasm, Ember Vents, Moon Garden, Briar Gate, Coral Steps and The Long Bloom. The last seven are built around tricks: Lockstone (grow down into a pit to open a gate), False Dawn (a decoy over the vents), Updraft Spires, Two Keys (lures as waypoints), Sunken Bloom (down a shaft into a dark cave), Mirror Wells (sunwells that wake in a chain) and The Heartwood. Each garden unlocks the next. Your seeds, stars and progress are saved automatically.

**Next action:** the HUD changes as you play: find a missing gift, replant a useful child, touch a key-bloom, or reach the next sunwell. **Show me** (**H**) highlights the actual target or opens the useful seed choice. Relevant garden gifts and where to obtain them are explained before planting. Context labels distinguish wild donors, goals, keys, and false lights; extra labels fade so the landscape stays visible.

**Keys:** **Z** undoes, **H** shows the next action, **Space** toggles planning/growth, **F** grows ×2, **R** restarts, **S** opens the seed vault, **Esc** goes to the map. When a plant stops growing, the game explains why and suggests what to try.

## Art

Everything is drawn at runtime with HDR bloom: gene-driven plant rendering, shader-painted rock, glass, crystal, water and living darkness, plus layered megaflora silhouettes, light shafts and drifting spores. A plant's look comes straight from its genome, so hybrids visibly wear features from both parents. The music and sound effects are the original synthesized set in `assets/audio`.

## Code map

- `scripts/genome.gd`: genes, crossing, and where each feature came from.
- `scripts/plant_sim.gd`: real-time growth. Light-seeking, leading and side shoots, leaning on rock, reach limits, darkness, roots, collisions, pruning, pollination.
- `scripts/world_sim.gd`: puzzle geometry and queries.
- `scripts/levels.gd`: the twenty-one gardens and the wild species.
- `scripts/garden_guidance.gd`: authored learning goals, actual seed suitability and live next-action/recovery queries.
- `scripts/view/world_labels.gd`: lightweight labels and highlights anchored to real garden objects.
- `scripts/session.gd`: one attempt at a garden.
- `scripts/view/`: `plant_view.gd` (plant rendering), `level_view.gd`, `backdrop.gd`, `fx.gd`, `palettes.gd`.
- `shaders/`: sky, rock, glass, crystal, water, darkness, vignette.
- `scripts/main.gd`: title, map, seed choice, HUD, input, cross-pollination reveal, win and stuck screens.

## Tests

```sh
G=/Applications/Godot.app/Contents/MacOS/Godot
$G --headless --path . --script res://tests/undo_test.gd            # exact growth/RNG/tool restoration
$G --headless --path . --script res://tests/prune_preview_test.gd   # pure previews match real cuts
$G --path . --quit-after 1800 --script res://tests/experiment_flow_test.gd # aim, cancel, prune and undo with real input
$G --headless --path . --script res://tests/guidance_test.gd        # truthful guidance for all 21 gardens
$G --path . --quit-after 2400 --script res://tests/clarity_flow_test.gd # isolated plan → pollinate → replant flow + screenshots
$G --headless --path . --script res://tests/solve_test.gd           # each garden solvable with the right gifts, blocked without them
$G --path . --quit-after 6000 --script res://tests/input_test.gd     # simulated lure / drag / recall / swipe-prune
$G --path . --quit-after 20000 --script res://tests/capture.gd       # screenshots of every screen
$G --path . --quit-after 900 --script res://tests/gallery.gd         # plant gallery: species + hybrids
```

`archive/sprout-brawl/` holds the earlier auto-battler prototype. Godot ignores this folder. The original garden sim is still on `main`.
