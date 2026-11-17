# Plant Auto-Battler — Full Game Spec

A breeding-first auto-battler where plants fight plants, and beauty is a mechanic.

Players crossbreed, graft, mutate, and collect seeds to create new generations of plants. Each plant's appearance — flower color, pattern, petal shape, and form — is determined by its genes. Plants are then arranged in a garden, battle other plants automatically using only plant-native abilities, and are displayed and scored for diversity, harmony, and rarity.

This is not a tower-defense game and not a plants-vs-zombies game. There are no zombies, insects, pests, or waves of monsters. If battle ever conflicts with the plant itself, the plant wins.

The main interface is the garden itself. The player does not navigate to the game from a menu — they live in the garden. Breeding, arranging, battling, and displaying all start from, and return to, that one persistent garden screen (Section 13).

Art reference for the whole game: *Scavengers Reign*. The garden is not a cute, sunlit lawn. It is a strange, damp, living alien ecology — hand-drawn, luminous, and slightly unsettling — where every plant looks like it evolved for a reason, even when that reason is not yet understood. Section 14 is the binding art direction; where any other section describes visuals, Section 14 wins.

## 1. Design pillars

**Plants are the product.** The charm of the plant itself — its pattern, color, silhouette, and rarity — is the core reward. A player should want to keep a plant because it is beautiful or strange, not only because its numbers are high. In the *Scavengers Reign* sense, beauty and strangeness are the same thing: an unfamiliar organism, drawn convincingly enough that the player believes it lives.

**Breeding is building.** Crossbreeding, grafting, and mutation are how the player builds their roster. Every battle unit was created by the player through a breeding decision.

**Plants fight like plants.** Combat uses growth, roots, vines, shade, spores, toxins, parasitism, and devouring. No plant punches, shoots bullets, or behaves like a human soldier or a turret.

**Beauty is scored, not decorative.** Pattern, color harmony, diversity, and rarity feed directly into the display garden score, collection progress, and rewards.

**Short battles, long lineages.** A battle lasts 2–3 minutes. A lineage can last dozens of generations. The long-term game is genealogy.

## 2. Target and scope

| Item | Target |
|---|---|
| Genre | Breeding collection + auto-battler |
| Platform | Mobile first, playable on desktop web for prototyping |
| Session length | 3–5 minutes |
| Battle length | 2–3 minutes |
| Player fantasy | Botanist-breeder creating living art that can also win |
| Core audience | Collection, breeding, and auto-battler players |
| Engine note | Designed to be buildable in Godot 4 |

### Explicitly out of scope

- Plants vs. zombies, insects, pests, or monster waves
- Tower defense lanes and base-defense waves
- Manual real-time combat control as the main skill test
- Selling power directly; monetization, if added later, should favor cosmetics, garden space, and convenience

## 3. Core loop

1. **Collect** — Obtain seeds and starter plants from battles, the display garden, events, and the seed bank.
2. **Breed** — Choose two parents and crossbreed them, graft a trait from one plant onto another, or mutate a plant with radiation or chemicals.
3. **Grow** — Raise the offspring to maturity. Its genes resolve into appearance, type, stats, and skills.
4. **Arrange** — In the garden home, place plants in the battle bed and in the 6-slot display bed.
5. **Battle** — From the same garden, watch plants fight other plants automatically. Positioning, synergy, and lineage decide the result.
6. **Display** — Earn a display score for diversity, harmony, and rarity. High scores unlock seeds, materials, and garden space.
7. **Re-breed** — Use winners and beautiful outliers as parents for the next generation.

The loop must close in one session: a player should be able to breed a new plant, see it fight, and earn a seed from it within 5 minutes.

## 4. Plant structure

Every plant is a unique individual generated from genes, not a fixed unit with a skin.

### 4.1 Identity fields

| Field | Description |
|---|---|
| Species | Base species lineage, e.g. base flower, vine, spore plant |
| Generation | G1, G2, G3, and so on from its parents |
| Parents | Two parent plant IDs, or one parent plus graft donor |
| Type(s) | One primary type, optionally one secondary type |
| Rarity | Common, Uncommon, Rare, Epic, Legendary |
| Pattern genes | Color, pattern, petal, and form genes (Section 5) |
| Stat genes | Growth, vitality, toxin, root, and bloom genes |
| Skills | 1–3 inherited or mutated skills |
| Graft history | Donor traits and graft count |
| Mutation history | Agent used, result, and generation applied |

### 4.2 Stats

| Stat | What it does |
|---|---|
| Vitality (HP) | How long the plant survives in battle |
| Growth | Attack speed / growth-tick rate and root spread |
| Toxin | Damage and duration of poison and spore effects |
| Root Strength | Entangle, parasitism, and territory control strength |
| Bloom | Energy gain rate and ultimate (Bloom Burst) power |
| Shade | How strongly it suppresses adjacent enemy growth |

Stats are derived from genes with a small random variance at birth, typically ±10% around the inherited value, so siblings are similar but never identical.

## 5. Visual genetics — pattern is gameplay

Appearance is generated from genes. The player must be able to look at a plant and read part of its lineage.

### 5.1 Visual gene slots

| Gene slot | Values in prototype scope |
|---|---|
| Primary color | Inherited from either parent, blends possible |
| Secondary color | Accent, center, edge, or vein color |
| Pattern | Solid, Striped, Spotted, Gradient, Starburst, Bicolor Ring |
| Petal count | Inherited range, mutation can push outside range |
| Petal shape | Round, Pointed, Frilled, Split |
| Leaf / stem form | Upright, Trailing, Rosette, Climbing |
| Glow / marking | None by default; rare mutation outcome — bioluminescent veins, spore dust, or a pulsing bloom core in the Section 14 palette, never a neon outline |
| Surface / texture | Matte, waxy, translucent, fibrous, or wet — inherited like color; translucency and wet sheen are how alien anatomy reads as real |
| Size | Small, Standard, Large — affects garden presence |

### 5.2 Inheritance rules for appearance

- Each visual slot is inherited independently from one parent, with a small chance of blending where the slot supports it, such as gradient color.
- Pattern is a discrete trait: a Striped × Spotted cross can produce Striped, Spotted, or, at low probability, a combined pattern in later generations.
- Recessive patterns can skip a generation and reappear, which makes pedigree tracking meaningful.
- Mutation can rewrite a single visual slot completely, including creating a pattern neither parent had.
- Grafting does not change the host's base pattern, but can add a visible donor feature, such as donor-colored blooms on one branch.

### 5.3 Readability rules

- Pattern must be visible at battle size, not only in a zoomed detail view.
- Color and pattern are never the only carrier of type information; silhouette and icon also signal type.
- Rare patterns need a distinct silhouette or marking, not only a palette swap.
- Every plant needs a detail view showing the full pattern, its gene list, and its parents.
- Alien does not mean unreadable. A strange form still shows, at a glance, where it takes in light, where it stores water or toxin, and how it would catch, spread, or devour. If a form has no readable function, it is decoration, not biology — redesign it (Section 14.3).
- Bioluminescence is a trait, not a UI highlight. It lives in veins, spore clouds, and bloom cores, pulses slowly like breathing, and is absent from most common plants so that a glowing plant still feels rare.

## 6. Types and species

### 6.1 Types

The prototype uses 8 types. Type determines battle behavior, synergy, and breeding tendencies.

| Type | Battle identity | Typical visual cue |
|---|---|---|
| Leaf | Balanced growth, steady damage | Broad green foliage |
| Bloom | Energy and burst focused | Large showy flowers |
| Vine | Entangle and reach | Long trailing stems |
| Root | Durable, territory and sustain | Thick root crown |
| Spore | Area spores and spread | Caps, puffs, fine dust |
| Toxin | Poison and zone denial | Dark or warning colors |
| Parasite | Drains and attaches to enemies | Pale tendrils |
| Carnivorous | Rare, devours weakened plants | Traps, pitchers, jaws |

Type advantage is handled through skills and interactions, not a hard rock-paper-scissors wheel in the prototype. A formal type chart is an open decision (Section 17).

### 6.2 Base species

The prototype collection contains 7 base species as starting lineages. Base species are entry points, not the ceiling: crossbreeding between species is where new forms come from.

Each base species defines:

- Default type and stat bias
- Default pattern pool and petal range
- One signature skill
- Breeding compatibility range
- A codex entry with silhouette and undiscovered-variant slots

### 6.3 Carnivorous plants

Carnivorous is a rare lineage, not a normal starter type.

- It cannot be selected as a starting plant.
- It appears through specific crossbreeding combinations or through mutation, including reversion.
- Prototype mutation rule: radiation carries an 8% chance to convert a plant toward the carnivorous lineage.
- Its signature mechanic is Devour: finishing a weakened enemy restores vitality and can trigger growth.
- It should be visually unmistakable — traps or pitchers are part of the silhouette.

## 7. Breeding system

### 7.1 Crossbreeding (hybridization)

The player selects two mature parent plants. The offspring is a new individual.

| Element | Rule |
|---|---|
| Cost | Seeds / sunlight (Section 12) and one breeding slot |
| Type | Inherits primary type from one parent; may gain the other parent's type as secondary |
| Stats | Average of parents, ±10% variance per stat |
| Skills | Can inherit from either parent; dual inheritance is possible |
| Appearance | Each visual gene slot resolves independently (Section 5.2) |
| Species | Follows the dominant lineage, or forms a hybrid lineage |
| Generation | One higher than the higher parent generation |

Design intent: crossbreeding is recombination. The player is hunting for a specific combination — a pattern from one parent, a skill from the other, a stat line from both.

Breeding restrictions:

- A plant must be mature to breed.
- Close inbreeding is allowed in the prototype, but a future inbreeding penalty is an open decision.
- Distant crosses have lower seed yield and higher variance.

### 7.2 Dominant and recessive genes

- Each gene slot carries a dominant and a recessive value.
- The dominant value is expressed in appearance and stats.
- The recessive value is carried silently and can be expressed in offspring if paired with another recessive.
- The detail view shows expressed genes clearly; carried recessives can be shown as a pedigree hint, so skilled breeders can plan two generations ahead.
- Skills follow the same logic: a plant can carry a skill gene it does not express.

### 7.3 Seed collection

- Winning battles, display scoring, and mature plants produce seeds.
- A seed stores a lineage snapshot: species tendency, type tendency, and pattern tendency, not a guaranteed plant.
- Seeds are categorized by lineage and rarity in the seed bank.
- The player can hold, plant, trade in, or use seeds as breeding material.
- Rare seeds come from rare parents, high display scores, and mutation events — never only from a shop.

## 8. Grafting system

Grafting transplants one trait from a donor plant onto a host plant. It is targeted breeding: slower and more precise than crossbreeding.

| Element | Rule |
|---|---|
| Limit | Maximum 2 grafts per plant |
| Donor | Donor plant is consumed or put on a long cooldown |
| Trait choice | One trait per graft: a skill, a stat bias, or a visible feature |
| Same-type success | 90% |
| Cross-type success | 65% |
| Failure | Graft does not take; host is unharmed, donor material is lost |
| Compatibility | Closer lineage means higher success; distant grafts risk rejection |

Rules:

- A grafted trait is visible on the plant where the design supports it, such as a donor-colored branch.
- A grafted trait can be inherited by offspring at reduced probability.
- Graft count and donor history are permanent parts of the plant's record.
- Rejection risk rises with each additional graft and with lineage distance.

Design intent: crossbreeding is for discovery, grafting is for fixing a specific plant the player already loves.

## 9. Mutation system

Mutation is controlled gambling. The player applies an agent to a plant or seed and accepts an unpredictable result.

### 9.1 Agents

| Agent | Character | Best used on |
|---|---|---|
| Radiation | Wild, high variance, can change lineage | Plants where any change is welcome |
| Chemical agent | Narrower, trait-focused change | Plants needing a specific slot rerolled |

### 9.2 Outcome table

| Outcome | Probability | Effect |
|---|---:|---|
| New trait gained | 70% | One random trait, skill, or visual slot changes to a new value |
| No change | 20% | Agent is consumed, plant is unchanged |
| Deformity | 10% | One negative trait: reduced stat, distorted pattern, or unstable skill |

Additional rules:

- Radiation carries an 8% chance, rolled within the new-trait outcome, to push the plant toward the carnivorous lineage (reversion).
- Mutation can create a pattern, color, or skill that neither parent had — it is the only source of truly new visual traits besides events.
- Deformity is visible. A deformed plant can still be valuable as breeding material if it carries a rare recessive.
- Mutation history is recorded permanently. A mutated plant's offspring can inherit the mutated trait normally.
- There is no way to pay to remove all risk. Risk is the mechanic.

Design intent: mutation is how a stagnant lineage gets a new future, and how the rarest plants in the game come to exist.

## 10. Plant-vs-plant battle system

Battles are auto-battler matches between two gardens. Both sides are plants.

### 10.1 Format

| Element | Rule |
|---|---|
| Sides | Player garden vs. opponent garden (AI garden or async player garden) |
| Field | Grid garden bed; prototype battle used a 3×3 bed |
| Team size | Set by mode; display garden is separate at 6 slots |
| Control | Pre-battle arrangement only, plus one timed ultimate |
| Speed control | 1× and 2× playback |
| Win condition | All opposing plants withered, or higher remaining vitality at time limit |

### 10.2 Plant-native combat mechanics

Only these verbs are allowed in combat design:

| Mechanic | Effect |
|---|---|
| Entangle | Vine roots slow or hold an enemy plant in place |
| Shade | A tall or broad plant suppresses enemy growth and energy gain nearby |
| Spore Cloud | Area spores damage or debuff a cluster over time |
| Toxin | Poisoned soil or tissue damages over time and denies a zone |
| Parasitism | Tendrils attach and drain vitality from an enemy to the parasite |
| Devour | A carnivorous plant consumes a weakened enemy and grows |
| Root Network | Connected allied roots share healing or energy |
| Bloom Burst | Stored energy released as a full bloom: burst damage, healing, or buff |

No mechanic should be reskinned gunfire. Animation is growth: vines reach, spores drift, traps close, flowers open.

### 10.3 Energy and Bloom Burst

- Plants gain energy over time and when they act, at a rate set by their Bloom stat.
- At full energy, a plant can trigger its Bloom Burst automatically, or the player can trigger a team Bloom Burst as their one in-battle intervention.
- Bloom Burst effects depend on type and inherited skills: a Bloom type bursts for damage, a Root type bursts for team healing, a Spore type bursts as a large cloud.

### 10.4 Synergies

- Fielding 3 plants of the same type activates a type synergy.
- Prototype examples: 3 Toxin plants create a persistent poison mist; 3 Root plants create a shared root network that heals.
- Synergies reward breeding toward a theme without forcing a single-type team, because display scoring rewards diversity at the same time.
- Pattern and color synergies are a display-garden feature first; battle pattern synergies are an open decision.

### 10.5 Opponents

- Early opponents are AI gardens built from the same breeding rules, so players learn by reading enemy lineages.
- Later opponents can be asynchronous snapshots of other players' gardens.
- Every enemy plant can be inspected before battle: genes, pattern, skills, and lineage are visible. There are no hidden-stat enemies.

## 11. Display garden and beauty scoring

The display garden is a second team-building puzzle where the goal is beauty, not victory.

### 11.1 Format

- 6 display slots, arranged as a presentation bed, separate from the battle bed in function but visible in the same garden home (Section 13.3) — display is not a separate screen.
- Any mature plant can be displayed. Displayed plants can still battle and breed.
- The garden home is what other players see when they visit or face the player asynchronously.

### 11.2 Scoring

| Score | What it measures |
|---|---|
| Diversity | Distinct types, species, patterns, and colors on display |
| Harmony | Colors and patterns that could grow in the same ecology (Section 14.4); shared palettes and repeated motifs score well |
| Rarity | Rare patterns, rare lineages, high generations, and carnivorous plants |
| Total | Weighted sum; exact weights are a balancing target (Section 15) |

Scoring rules:

- Diversity and harmony pull in opposite directions on purpose: six unrelated plants score diversity but lose harmony; six identical plants score harmony but lose diversity. The best gardens balance both.
- A plant's individual pattern quality contributes: rare patterns and clean combined patterns score higher than common solids.
- Scores are recalculated live as plants are swapped, with a breakdown shown per category, so the player can experiment.

### 11.3 Rewards from display

- Score thresholds unlock seeds, mutation agents, grafting materials, and extra garden or seed-bank space.
- A weekly display ranking is an optional extension, not a prototype requirement.
- Breeding a beautiful plant must always be a valid way to progress, even for a player who rarely battles.

## 12. Progression, economy, and collection

### 12.1 Resources

| Resource | Earned from | Spent on |
|---|---|---|
| Sunlight | Battles, display score, daily growth | Crossbreeding, growing, garden actions |
| Seeds | Battles, display, mature plants | Planting new individuals |
| Mutation agents | Display thresholds, events, rare drops | Radiation and chemical mutation |
| Grafting material | Battles, display thresholds | Graft attempts |

No resource should be earnable only through payment. Premium currency, if added later, is out of prototype scope.

### 12.2 Collection codex

- The codex tracks discovered species, patterns, colors, and lineages.
- Prototype scope: 7 base species with discovery progress per species.
- Undiscovered entries show silhouettes only.
- Completing a pattern family or a species page rewards seeds and agents.
- A lineage tree view shows ancestors and descendants for any plant, at least 3 generations in each direction.

### 12.3 Progression structure

- Early game: 2–3 base species, first crossbreed within the first session, first battle immediately after.
- Mid game: grafting unlocks, chemical mutation unlocks, display garden expands to the full 6 slots.
- Late game: radiation mutation, carnivorous lineage hunting, high-generation pedigree breeding, async PvP gardens.
- Difficulty comes from opponent garden composition and synergy, not from inflated enemy stats.

## 13. UI and user experience — the garden is the main interface

### 13.1 Principle: one garden, no lobby

The garden home is the game. There is no separate main menu, lobby, or hub map that the player passes through to reach play.

- On launch, the player lands directly in their garden, with their plants already visible, growing, and tappable.
- Battle bed, display bed, seed tray, resources, and entry points to the Laboratory, Seed Bank, and Codex are all present on, or reachable in one tap from, this single screen.
- Every loop returns here: after breeding, after a battle, after scoring, the player is back in the same garden, and the new plant is already planted in it.
- The garden persists and changes between sessions — growth stages advance, a new bloom opens, display score updates — so returning feels like checking on living plants, not reloading a menu.

### 13.2 What to borrow — and what not to borrow

Layout lessons are borrowed from two references. Their themes and combat models are not.

| Source | Borrow (layout / readability) | Do not borrow |
|---|---|---|
| Hearthstone | A single framed board as the whole screen; two opposing sides read top vs. bottom at a glance; a hand / tray along the bottom edge; large, tappable cards with cost, attack / health equivalents always visible; drag-to-play; a clear end-turn / start-battle button in a fixed corner; history / detail on tap-and-hold | Card-game turn structure as the core loop; hero characters as the focus instead of plants; fantasy tavern framing |
| Plants vs. Zombies (garden / lawn only) | A gridded planting bed the player can read cell by cell; plants placed in soil cells, not floating in a list; a seed-packet bar where each packet shows the plant's portrait, cost, and cooldown at a glance; left-to-right / top-to-bottom spatial readability; a calm home bed between fights — calm in pacing only; its look follows Section 14 (deep, damp, alien), not a bright suburban lawn | Tower-defense lanes; waves; zombies, pests, or any non-plant enemy; plants as turrets that shoot projectiles; base-defense lose condition; the bright, cute, cartoon-lawn art style |

In short: borrow Hearthstone's board clarity and PvZ's planting-bed readability. Keep plant-vs-plant auto-battle, breeding, and beauty scoring as defined in Sections 1, 7–11.

### 13.3 Garden home layout

Portrait mobile first; the same zones reflow to landscape / desktop by widening the bed, not by redesigning the screen.

```text
┌─────────────────────────────────────────┐
│ Top bar: Sunlight · Seeds · Agents      │  Resources + settings
│          Display score (live)           │
├─────────────────────────────────────────┤
│ OPPONENT / VISITOR STRIP (contextual)   │  Async rival garden preview,
│  rival name · score · [Scout] [Battle]  │  or seasonal showcase
├─────────────────────────────────────────┤
│                                         │
│         DISPLAY BED — 6 slots           │  Presentation row(s):
│      [P1] [P2] [P3] [P4] [P5] [P6]      │  beauty-scored plants
│                                         │
│         BATTLE BED — grid               │  Main planting grid
│      [ ] [ ] [ ]                        │  (prototype 3×3):
│      [ ] [ ] [ ]   soil cells,          │  drag plants here,
│      [ ] [ ] [ ]   roots / shade shown  │  synergy highlights
│                                         │
├─────────────────────────────────────────┤
│ SEED / PLANT TRAY (hand)                │  Horizontal scroll:
│ [packet] [packet] [packet] [packet] →   │  portrait · type · cost
├─────────────────────────────────────────┤
│ Bottom nav: [Lab] [Seed Bank] [Codex]   │  One tap, overlays —
│        [ ▶ BATTLE ]  (primary, fixed)   │  garden stays behind
└─────────────────────────────────────────┘
```

Zone rules:

- **Top bar.** Resources only (Sunlight, Seeds, mutation agents, grafting material — Section 12.1) plus the live display score. No store or event clutter in the prototype.
- **Display bed.** The 6-slot presentation bed from Section 11 sits visibly in the same garden, above or beside the battle bed — not on a separate screen. Swapping a plant here updates the score breakdown in place.
- **Battle bed.** A soil grid, not a list or a card row. Empty cells show soil; occupied cells show the plant at battle-readable size (Section 5.3), its vitality, and root / shade footprint on hover or tap. Valid drop cells and synergy groups (Section 10.4) highlight while dragging.
- **Seed / plant tray.** The Hearthstone-hand / PvZ-seed-packet hybrid: each owned, battle-ready plant is a packet-card along the bottom showing portrait (actual generated pattern, not a generic icon), primary type, Sunlight cost, and readiness. Drag a packet onto a soil cell to plant it; drag it back to the tray to bench it. On narrow screens the tray scrolls horizontally and never covers the bed.
- **Primary action.** One fixed Battle button. When the bed is valid it is active; when it is not, tapping it explains why in place (empty bed, immature plant) instead of navigating away.
- **Navigation.** Laboratory, Seed Bank, and Codex open as full-screen overlays or slide-over panels anchored to the garden. Closing them returns to the exact garden state the player left — same scroll, same selection.

### 13.4 Interaction model

- **Tap a plant** (in bed, display, or tray) — opens a compact popover: pattern, type(s), vitality / energy, skills, and [Detail] [Breed] [Move]. Full Plant Detail (Section 13.5) is one tap further, never the first response to a tap during arrangement.
- **Tap-and-hold / long-press** — full detail preview without leaving the garden, in the Hearthstone card-inspection sense: large pattern render, gene list, lineage summary.
- **Drag-and-drop is primary; tap-to-select, tap-to-place is the fallback** for accessibility and small screens. Both must work for planting, display swapping, and choosing breeding parents.
- **Breeding starts from the garden.** Selecting Breed on any two plants — from bed, tray, or detail — carries them pre-filled into the Laboratory. The player should never have to hunt for a loved plant inside the Lab list first.
- **Battle transition is in place.** Pressing Battle does not cut to a different arena: the opponent's bed slides in opposite the player's bed on the same board (player bottom, opponent top, Hearthstone-style), the tray is replaced by battle controls (speed 1× / 2×, Bloom Burst — Section 10.3), and on victory or defeat the opponent bed slides out and the home garden is restored. The player's plants never leave their soil cells.
- **Scouting uses the same board.** An async opponent (Section 10.5) is scouted by viewing their garden in this same layout, read-only, so genes and positioning are learned in the spatial form the battle will actually use.

### 13.5 Main screens

The garden home is the primary screen. All others are supporting screens reached from it.

| Screen | Purpose | Relation to garden home |
|---|---|---|
| Garden Home | Battle bed, display bed, tray, resources, daily growth — the main interface | Primary; launch screen |
| Laboratory | Crossbreeding, grafting, and mutation in one place | Overlay from garden; parents can be pre-filled from garden |
| Plant Detail | Full pattern view, genes, stats, skills, lineage, and history | Popover / overlay from any plant, anywhere |
| Seed Bank | Stored seeds by lineage and rarity, with planting actions | Overlay; planting a seed places it in the garden |
| Battle | Auto-battle view with speed control and Bloom Burst | In-place transformation of garden home (Section 13.4) |
| Codex | Species, pattern, and lineage discovery progress | Overlay from garden |

### 13.6 UX rules

- The breeding result preview shows possible inherited patterns and types as ranges, never as a guaranteed outcome.
- Every random outcome — crossbreed, graft, mutation — shows its odds before the player confirms.
- A new plant reveal is a moment: pattern resolves visually, gene by gene, so the player sees what they got and why. The reveal ends with the plant already in the garden or tray, not in an inventory list.
- Battle readability comes first: entangle, toxin, shade, and parasitism each need a distinct visual language, legible on the shared board at battle size — and in the Section 14 language: drifting spore light, darkening toxin seep, a literal shadow canopy, and pale draining tendrils, not colored explosion icons.
- Any plant can be renamed by the player. Favorite plants can be locked so they cannot be consumed as donors or parents by accident.
- No information needed to arrange the bed — type, cost, synergy, maturity, vitality — may be hidden behind the detail screen only. It must be readable from the tray packet or the bed cell itself.
- The garden must be fully usable with no opponent present. Battle is an action taken from the garden, not a mode the garden depends on.

## 14. Art direction — *Scavengers Reign*

The reference is *Scavengers Reign*: hand-drawn science-fiction ecology in the Moebius-influenced French animation tradition. A world that is lush, wet, and luminous, populated by organisms that are beautiful precisely because they are unfamiliar — and convincing because every unfamiliar part looks like it does a job.

This section replaces any earlier "clean, bright, cute garden" reading. Where another section's wording conflicts with this one, this section wins.

### 14.1 Style target in one line

Strange but believable alien botany, drawn by hand, on a deep and damp ground, lit from inside the plants themselves.

- Not cartoon, not chibi, not a bright mobile-casual garden.
- Not clean flat vector, not glossy 3D, not neon cyberpunk.
- Not horror for its own sake. The unease comes from unfamiliar biology, never from gore.

### 14.2 Line, texture, and rendering

- Hand-drawn linework with visible, slightly irregular contours. Plants are inked, not outlined in a uniform digital stroke.
- Flat color fields with soft, painterly shading and fine hatching or stipple for shadow, moisture, and translucency — the printed-comic / cel-animation feel of the reference.
- Surfaces look grown, not manufactured: waxy cuticles, fibrous stems, translucent membranes, wet sheen on traps and pitchers, dry papery seed husks.
- No hard white specular highlights, no plastic gloss, no airbrushed gradients. Light wraps and seeps; it does not shine off a toy.
- Backgrounds are layered and atmospheric — soft distant silhouettes, drifting motes, depth haze — so the garden feels like a place inside a larger, unexplored ecology.

### 14.3 Plant design language — every form has a function

Each plant is designed as an organism first and a game unit second.

- Start from a real biological job — trapping light, storing water, catching prey, spreading spores, climbing, parasitizing a host — then push the form one step past familiar Earth botany. One step, not ten: the player should almost recognize it.
- Anatomy must be readable (Section 5.3): mouths, traps, tendrils, spore sacs, root crowns, and bloom cores are placed where they would work, and they move the way they would work.
- Symbiosis and interdependence are visual, not just systemic. Roots intertwine, a parasite's tendrils match its host's coloring, a shade canopy is shaped by what grows under it. A garden should look like an ecology, not a row of unrelated characters.
- Silhouettes stay distinct per type (Section 6.1), but within the alien register: a Vine is a long, searching, finger-like growth, not a smiling cartoon creeper; a Carnivorous plant is elegant and patient, its trap open like an organ, not a snapping mascot head.
- Eyes, faces, arms, and human expressions are prohibited. Plants express themselves through posture, opening and closing, color change, and growth — never through a face.

### 14.4 Color and light

The palette is two layers in deliberate contrast: a deep, muted ground, and luminous living accents that sit on it.

| Layer | Direction |
|---|---|
| Ground and environment | Deep teal-green, moss, wet earth brown, dusky blue-grey, faded ochre. Desaturated, humid, shadowed. The garden bed, soil, and board surround all live here. |
| Foliage base | Layered greens and blue-greens with yellowed, bruised, or rusted edges. No single flat "leaf green" across species. |
| Living accents | Bioluminescent cyan and teal, warm amber, soft magenta-pink, pale spore white. Used only where the organism produces light, pigment, or spores — veins, cores, sacs, bloom interiors. |
| Warning and toxin | Sickly yellow-green, bruise purple, dark warning reds, used sparingly so they still read as danger. |
| Sky and ambient light | Pale, washed, slightly alien — cream, bleached peach, or grey-green — never a saturated cartoon blue. |

Rules:

- Darkness is the canvas. A plant's pattern (Section 5) is drawn in pigment and light against that ground, which is why patterns must still read at battle size: luminous markings and pale patterns carry at distance, dark-on-dark patterns do not ship.
- Bioluminescence pulses slowly, like breathing or a heartbeat, and brightens when a plant acts, gains energy, or is about to Bloom Burst. It never strobes, never outlines a selected unit, and is never used as a UI cursor color.
- Day in this garden is soft and overcast-alien; there is no hard noon sunlight. Sunlight as a resource is shown as gathered light in leaves and cores, not as a sun icon over a lawn.
- Harmony scoring (Section 11.2) is judged inside this palette. "Harmonious" means colors that could plausibly grow in the same ecology; "clashing" means a combination no shared environment would produce — not simply complementary vs. non-complementary on a color wheel.

### 14.5 The garden environment

Because the garden is the main interface (Section 13), its environment art carries the game.

- The board is a living bed inside a larger wild growth, framed like a crafted play surface in the Hearthstone sense — but the craft is organic: root-bound edges, grown dividers, damp soil cells, stone or chitin-like framing — not wood panels, gold trim, or tavern furniture.
- Beyond the bed, the background keeps growing: out-of-focus alien flora, hanging growths, drifting spores, slow movement the player did not cause. The garden feels tended; the world beyond it does not.
- Between battles the garden is quiet and beautiful, with idle motion everywhere — unfurling, swaying in no visible wind, a trap slowly closing on nothing. Battle does not change the place, only what the plants in it are doing.
- Weather and time are mood tools, used lightly: mist, fine rain sheen, and a dusk shift for high-rarity reveals or carnivorous appearances. They never obscure the bed or a plant's pattern.

### 14.6 Pattern as art, in this style

- Stripes, spots, gradients, starbursts, and rings (Section 5.1) are drawn as real markings — pigment in tissue, light in veins, spores on a surface — integrated into petals, leaves, and sacs, never printed on top like a decal or a skin.
- A combined or rare pattern should look like a new organism, not a recolor: change the tissue, the translucency, or where the light comes from, alongside the marking.
- Mutation is visible as biology, not as a sparkle effect: a new eye-spot-like marking, a translucent window in a leaf, a second, smaller bloom growing from a stem, a trap where a flower should be. Deformity is drawn with the same care — asymmetry, stunted or doubled growth — strange and a little sad, never comical and never gory.
- Grafting is visible as a join: a seam, a change of texture and color above it, donor blooms on host growth (Section 8). The player should be able to point at the graft.

### 14.7 UI art treatment

UI serves the ecology; it does not sit on top of it in a different style.

- Panels, tray, and cards use the environment's materials and palette — dark, matte, slightly organic surfaces with thin luminous accents — with hand-drawn iconography. No bright white panels, no saturated candy buttons, no generic fantasy gold.
- Plant packet-cards in the tray (Section 13.3) show the actual generated plant, rendered in this style, against a deep ground so its pattern and glow read immediately. The card frame never outshines the plant.
- Type, rarity, and synergy icons are small biological glyphs — a spore cluster, a root knot, a trap silhouette — drawn in the same line, not emoji, not flat app icons.
- Text stays highly legible against the deep ground; legibility is the one place the style yields. If a background texture fights the text, the texture goes.
- The primary Battle button is the most luminous element on the home screen, and its glow uses the bloom-core language of the plants themselves, so starting a battle feels like triggering a bloom, not pressing a web button.

### 14.8 Animation and battle effects

- Growth is the main animation language: unfurling, reaching, swelling, blooming, a trap closing with weight and delay. Movements are slow, deliberate, and slightly uncanny — plants in the reference tradition do not bounce, squash, or stretch like cartoon characters.
- Idle animation is continuous and subtle for every plant on screen. A still plant should look dormant or dead, so stillness is reserved for withered plants in battle.
- Battle effects are produced by bodies, not layered over them: spore clouds drift and settle, toxin seeps into soil and darkens it, shade is a real canopy shadow moving over enemy cells, parasitism is a visible tendril connection that thickens as it drains, Devour is a trap or pitcher closing and staying closed while it digests.
- Bloom Burst is the visual peak: the plant opens fully, its core light flares and spills onto neighboring plants and soil, petals or sacs release what they were holding — then it dims and closes, visibly spent. It should feel like a flowering event in an alien ecology, not an explosion or a spell effect.
- Withering is quiet: color drains toward grey and brown, glow fades out, the form folds and settles into the bed. No shattering, no poof, no cartoon ghost.

### 14.9 What to avoid — rejection checklist

Reject a piece of art, an asset, or a screen if any of these are true:

- It could pass for a cute casual-garden, farm, or tower-defense game at a glance.
- A plant has a face, eyes, a smile, or a mascot silhouette.
- Color is bright and saturated everywhere, with no deep ground for the luminous accents to sit on.
- Glow is used as decoration, selection highlight, or generic magic, rather than as something an organism produces.
- A form is strange but functionless — the artist cannot say what the unfamiliar part is for.
- Surfaces look plastic, glossy, or cleanly 3D-rendered.
- Battle effects read as gunfire, explosions, lasers, or spell icons instead of growth, seepage, drift, and closing.
- The garden background is a static, pretty wallpaper with no life of its own.

### 14.10 Reference use

- Primary reference: *Scavengers Reign* — its alien flora, creature ecology, palette, and hand-drawn rendering.
- Use it as a direction for original designs, not as a source to copy: no plant, creature, shot, or composition from the show is reproduced. Every species in this game is an original organism that could plausibly share that world.
- Secondary influences, only where they agree with the primary reference: Moebius-style science-fiction illustration and classic botanical plates, both for line and for the discipline of drawing a specimen as if it were real.

## 15. Balancing targets

These are starting targets from the prototype, to be tuned in playtesting. They are not final numbers.

| Parameter | Target |
|---|---|
| Battle length | 2–3 minutes at 1× speed |
| Crossbreed stat variance | ±10% around parental average |
| Graft success, same type | 90% |
| Graft success, cross type | 65% |
| Grafts per plant | Maximum 2 |
| Mutation: new trait / no change / deformity | 70% / 20% / 10% |
| Radiation to carnivorous lineage | 8% within new-trait outcome |
| Display slots | 6 |
| Type synergy threshold | 3 plants of one type |
| Base species in prototype | 7 |
| Types in prototype | 8 |

Balance principles:

- No single type, pattern, or lineage should dominate both battle and display at once.
- A high-generation plant should be better because of better gene combinations, not because generation alone adds flat stats.
- Deformity and graft failure must sting but never destroy a player's favorite plant.

## 16. Technical notes

- Plant generation must be deterministic from a stored gene seed, so the same plant renders identically on every device and in async battles.
- Genes, lineage, and history are data; appearance and battle behavior are derived from that data. Never store appearance as a baked image only.
- Async battles use a snapshot of the opponent garden's gene data, simulated with the same rules as local battles.
- Save data must preserve full pedigrees. Losing lineage history breaks the core fantasy.
- Prototype implementation should prioritize the garden home, the laboratory, and the plant detail view over meta systems. If the garden does not feel like a place, or breeding does not feel good, nothing else matters.
- Garden home state — bed placement, display selection, tray order — is saved data, restored exactly on relaunch and shared as the async visiting / scouting view.

## 17. Open decisions

These questions are intentionally unresolved and need a decision before production:

1. Should there be a formal type-advantage chart, or should type interaction stay skill-based only?
2. Should inbreeding carry a penalty, such as higher deformity rates?
3. Can pattern or color synergies affect battle, or should they stay display-only?
4. What are the exact display score weights for diversity, harmony, and rarity?
5. Should grafted traits be inheritable at full probability, reduced probability, or not at all?
6. Is weekly display ranking competitive and rewarded, or purely a showcase?
7. What is the long-term release and retirement model for plants — can a plant die permanently, or only be retired to the codex?
8. Monetization model, if any, beyond cosmetics and garden space.
9. On small portrait screens, do the display bed and battle bed stack vertically (Section 13.3 default), share one bed with a toggle, or paginate — and which survives playtesting?
10. Does the seed / plant tray stay capped and scrollable, or does a large collection need filtering and sorting in the tray itself?

## 18. Prototype acceptance checklist

A prototype is successful only if all of these are true in playtesting:

- A player can explain why their second-generation plant looks different from its parents.
- A player keeps at least one plant for its pattern, not its stats.
- A battle result can be explained by positioning, synergy, or lineage — not by randomness alone.
- A player chooses to mutate or graft a favorite plant despite the risk, because the upside is clear.
- No tester describes the game as plants vs. zombies or as tower defense.
- A first-time player can, from the garden home alone and without a tutorial screen, plant a plant from the tray into the battle bed, swap a display plant, and start a battle.
- A tester describes the home screen as "my garden," not as a menu or lobby.
- A tester describes the art as a strange, living alien ecology in the *Scavengers Reign* sense — beautiful and a little unsettling — and no tester describes it as cute, cartoonish, or like a farm or tower-defense garden (Section 14.9).

