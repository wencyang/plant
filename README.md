# The Quiet Conservatory

A playful Godot 4.7 plant breeding and collecting adventure with ink-drawn botanical art and illustrated landscapes. Plant a seed, make a new family, explore eight wild habitats, trade your harvest, and meet friendly Garden Fair visitors. Its core is **cross → fruit → seed → plant → cross the descendants again**. The later peaceful gardening direction supersedes the original auto-battler specification, which remains as historical design context.

## Play

Double-click **run.command** on macOS, or import **project.godot** in Godot 4.7 and press **F5** to play. No add-ons or downloaded assets are required.

```sh
godot --path .
```

- Open **Stream story → / Adventure** in the top bar to play **Moonbell Crossing**. Walk with WASD/arrows or tap to move; E meets a nearby plant. Four riverside plants offer free, fully inherited cuttings. Cross River Fan + Floatcap for round waxy Leaf/Spore offspring that can grow a **living raft**, or Gripvine + Stone Root for climbing fibrous Vine/Root offspring that can grow a **vine bridge**. Any other owned plants with the same expressed traits and enough ancestry work too. Both routes physically cross the stream.
- The **field breeding bench** uses normal costs and timers: 10 light to pollinate, 18 seconds for fruit, then **Harvest & grow both siblings** extracts and sows the exact two embryos for 20 light (with the normal 30-light harvest gift). Seedlings grow for 12 seconds. Both parents and children stay in your garden. The bench can resume fruit or seeds handled in the ordinary nursery and benches seedlings safely if soil is full. **Meet siblings** compares their actual inherited traits and links directly to trying an ability.
- Meet **Moonbell** beyond the stream, then cross it with a G2 plant. A grown G3+ descendant that shows **Soft Glow** lights the old gate and restores a real, walkable courtyard. Each seed inherits independently; unlit children retain their carried genes and can cross again. Crossings and restored scenery persist after later aging, mutation or sale of the original descendant. Name your successful cultivar in the discovery panel.
- Field cuttings arrive fully cared for (60 minutes of active life), can be replaced if lost or changed beyond their original useful traits, and cannot be sold for free coins; their offspring remain tradable. The rest of the garden keeps its existing lifecycle.
- Click **Plant a seed**, or tap an empty plot in the grow patch. **Choose this seed** shows its grown appearance, the exact plot, the **10 light** cost, and the **12-second** growth time. Pick another empty square in the little plot map if you want a different spot, then press **Plant here**. **Watch it grow** returns to the garden with the new seedling selected and a countdown on its cell. It grows automatically; **Care for this plant → Sunshine lamp** can mature it immediately for 5 light.
- Empty soil clearly says **+ Plant a seed**. Empty display shelves say **+ Add a plant** and offer mature plants to move there for free. The planting selector also offers **Move an existing plant here instead**. If the grow patch is full, choose a plant to bench and free its plot; if the seed box is empty, the game points to fruit extraction or the market.
- Choose **Crossbreeding** to select any two distinct mature plants, including wild specimens, grafted plants, and previous hybrids. Pollination costs **10 gathered light**, keeps both parents, and grows a hybrid fruit on the mother in **18 seconds**. There is no species compatibility lock. Each mother can carry one cross fruit at a time; the same father can pollinate other mothers.
- Open **Fruit & seeds** to harvest a ripe fruit, extract its seeds, then sow them for **10 light** each. A hybrid fruit contains **two independently inherited seeds** and harvest gives **30 light**. Seeds store the complete offspring genome, both parent IDs, generation, skills, and mixed ancestry; planting never resets a hybrid to a founding species. Seedlings mature in **12 seconds**, then can cross again with any other mature plant. G2 × another plant produces G3, and later generations retain their earlier ancestral contributions.
- Mature plants also grow a **natural fruit every 45 seconds**. Harvesting one gives **10 light** and one lineage seed after extraction. Natural fruit and cross fruit are independent crops, so repeated breeding can continue without battling. Growing fruit, harvested fruit, extracted seeds, and seedlings all persist through closing the game.
- Each plant has a life cycle: seedling → mature → aging → naturally withered. Maturity starts **20 minutes of active play** before aging, followed by **5 minutes** before withering. Plants rest when the game is closed or its window is in the background; fruit ripening and seedling growth still use elapsed time. A withered plant leaves active beds but keeps its DNA and pedigree in the archive and offers one final natural fruit, so its successor can carry the lineage forward with a fresh lifespan.
- Visit the **Garden Fair** to meet **Mira**, **Jun**, and **Pip**. They bring three daily show-and-tell requests based on real plant traits, height, weight, wild origins, and breeding journeys. Pick a matching living grown plant, show it, and receive coins, light, or supplies. **You keep the plant, its fruit, and its family history.** A visitor pays once each UTC day; rewards never depend on battles.
- Open **My ribbons** at the fair for seven permanent gardening milestones: grow a planted seed, raise a two-parent offspring, grow mixed ancestry, reach generation 3, collect a wild friend, discover four patterns, and meet seven founding families. Eligible ribbons have one-time gifts and remain earned after a plant is later sold or withers. **Say hello** gives a plant a happy little reaction without spending resources.
- Open the **Tool shed**, or choose **Give this plant some love** while inspecting a plant. Every individual has a persistent **height in centimeters and weight in grams**, shaped by its genes, mixed ancestry, growth stage, and its own natural variation. **Stretch feed** costs 12 light and adds 15% of natural height per dose; **Chunky compost** costs 12 light and adds 20% of natural weight. Each allows four uses, and the plant visibly grows taller or fuller. These care bonuses belong to the individual; its seeds still inherit its DNA.
- The **Watering can** is free and adds one minute of life, with a 60-second refill and five uses per plant. **Life tonic** costs 10 light, adds ten minutes per dose, and allows three doses. Together they can extend a plant's lifetime from 25 to **60 minutes of active play**, delaying aging too. Care cannot revive a naturally withered plant. **Sunshine lamp** matures a seedling for 5 light; **Ripening spray** makes its growing natural and hybrid fruit ready to harvest for 8 light, with a 30-second refill and five uses. Tool cards show the benefit, cost, availability, and the plant's remaining life before use.
- Open **Market** to sell an individual plant, harvested fruit, or stored seed for **coins**. **See offer** opens an itemized quote; **Sell** completes that specific trade. Plants start at 20 coins, fruit at 8, and seeds at 4. Rarity, genetic traits, vigor, mixed ancestry, bounded generation premiums, and natural plant size add value. Seedlings and older plants receive condition adjustments; withered plants receive a small compost offer. Care-grown size adds at most three coins. Fruit premiums reflect its best seed and how many seeds it contains; selling a fruit transfers all its seeds too.
- The market's deterministic **daily wish list** adds 6 coins for the wanted type and 4 for the wanted pattern. Each sale reduces the next offer in that category by four percentage points, stopping at 60% after ten sales; demand resets at 00:00 UTC. The **Prices** tab explains the rules, and every review shows exact additions and deductions. Quotes stay stable when the stall reopens; a changed item or offer requires a fresh review. Seed references follow the exact snapshot rather than a shifting inventory slot.
- Sold plants leave the owned garden and beds, while their DNA and full family relationships remain readable through **Receipts → Visit its family record**. Favorites must be unpinned before sale, and hybrid fruit or ripe natural fruit must be harvested first. The market shop exchanges coins for sunlight, field kits, founding seeds, grafting material, and mutation agents. Wallet, supply history, sales, purchases, and sold ownership persist locally; older saves start with an empty coin wallet. This is an offline NPC market.
- Open **Traits & breeding** on a plant or stored seed to understand what it shows, which alternatives it carries, and what it can pass on. Pigments have names and color swatches; trait cards explain leaf shape, flowers, sheen, glow, size, inherited talents, and parental origins. Dormant flower genes are grouped separately. Genome identifiers and encoded ACTG records are available under the optional **Advanced · encoded records** section.
- Choose **Choose a mate & predict offspring** or **Preview offspring traits** in the laboratory to compare real inherited chances, choose a target trait, and see the best available mates for it. For example, Solid/Striped × Solid/Solid has a **25%** chance of visibly striped G2 offspring; choosing a Striped/Striped mate raises it to **75%**. A carrier’s 50% chance of passing an allele is distinct from the child’s chance of showing it. The preview includes possible offspring appearances, ability outcomes and inherited stat ranges; **Use this pair in the laboratory** prefills the actual parents without spending resources.
- The **Graft** laboratory tab accepts different plant types as host and donor. A successful graft records the donor's anatomy and genes, and its trait can pass to future descendants at reduced probability. Mutation is available in the same laboratory.
- Choose **Explore** to walk into a top-down pixel world and find new parents. Move with **WASD / arrow keys**, click or tap a destination, or use the touch D-pad. Press **E / Space / Enter** near a marked plant to investigate. **Home** returns to the exact garden you left.
- Wild plants grow at **182 patches across eight biomes**: Mosswood, Amber Hollow, Sporefen, Sunken Glade, Glassfall Coast, Moonfen, Ember Ridge, and Ancient Grove. The world is **160 × 128 tiles—16 times its original area**. Press **M / Map** to plan a route; visit the nine camps to unlock fast travel. **Study** is free and improves collection odds; **Collect** spends one field kit. A mature Vine can assist for one kit and five light. Exact odds appear before each attempt. Successful cuttings immediately become mature owned plants, with their original genes and wild provenance. **Supplies** packs five kits for 20 gathered light; collected patches regrow next field day.
- Open **Settings → Language → 简体中文** for Simplified Chinese, or select **English**. Language switches immediately and is saved; original plant IDs, names, and genes remain intact. A bundled Noto Chinese font is included for reliable glyph rendering.
- **Settings** also controls master, music, ambience, and effect volumes, plus mute. Original garden and wilderness music crossfade between contexts. Footsteps, discoveries, collecting, breeding, grafting, mutation, and blooms have distinct sounds.
- Drag a specimen packet into a soil cell, onto the display bed, or back into the tray to bench it. Tap-to-select and tap-to-place also work. **Move** swaps occupied cells.
- Tap a plant for its compact inspection; **Examine**, or a long press, opens its genome, stats, history, and three generations of ancestors and descendants. Rename or pin favorites there.
- Parent slots accept dragged specimens and selectors. Inheritance, costs, fruit progress, and mixed ancestry appear before and after propagation. **Codex** records seven founding species, patterns, pigments, and permanent collection milestones. Older reward seeds remain plantable as lineage tendencies.
- Use **Observe** beside the display bed to gather beauty milestones. Collection rewards and daily growth provide extra light and seeds alongside fruit harvests.

On desktop, the game opens in a large window up to **2880 × 2000 physical pixels**, fitted to the monitor. The interface scales automatically while the canvas renders at full window resolution. **Settings → Display & resolution** offers window presets and monitor selection; **F11** switches to native-resolution fullscreen. Display preferences are stored separately from the garden.

The interface responds to desktop and portrait windows down to 390 × 780. Escape closes an overlay. Buttons and specimen cells accept keyboard focus and Enter.

## Implemented

- Seven base species and eight behavioral types; carnivorous plants appear through radiation reversion or inherited lineage, never as starters.
- Eight redesigned ink-drawn botanical sprites, each a transparent 1024 × 1536 source frame, with layered foliage, veins, flower stamens, mushroom gills, pitcher rims, traps, and fine roots. Runtime gene pigments, six tissue patterns, form, shape, surface, size, graft colors, deformity, and rare glow preserve the fine line art and botanical anatomy. Alpha framing and real mipmaps keep cards sharp; wider soil cells give plants the full card height and inspection offers a larger close-up. The earlier 320 × 384 procedural renderer remains a missing-asset fallback. Artwork is documented in [assets/plants](assets/plants/README.md), with the new final prompt set in [landscape asset notes](assets/landscapes/prompts.json).
- A deterministic 160 × 128 tile overworld with eight habitats, 182 wild collection patches, nine camps, a route atlas and visited-camp travel. HD terrain is rendered as bounded, mipmapped 16 × 12-tile chunks rather than one enormous image. Includes an ink-drawn botanist, isometric field shelters, illustrated region panoramas, ponds, bridges, tree collision, camera following, tap-to-pathfind, keyboard and touch controls. Wild collection uses finite supplies, study bonuses, visible odds, persistent encounter attempts, and daily patch regrowth. All seven founding species can be collected in the field; deep-field carnivorous forms stay rare.
- English and Simplified Chinese presentation with reversible runtime translation, CJK glyphs bundled under OFL1.1, translated phenotypes/odds/results/tooltips, and canonical saved data.
- A bright paper-and-leaf garden interface with cheerful plant cards, pixel tool illustrations, and a responsive tool shed. Individual height and weight appear on plant cards and inspections. Six care tools provide real lifetime, size, maturation, and fruit-ripening effects with persistent doses and cooldowns; acquired growth stays separate from inherited genes.
- A responsive, bilingual market with pixel stall and item icons, separate coins, deterministic daily demand, bounded supply discounts, itemized review-before-sale quotes, stable seed identities, five useful supplies, newest-first receipts, and preserved sold-plant genealogy.
- Two original 64-second stereo music loops, a forest ambience bed, thirteen pooled event effects, scene crossfades, independent volume settings, and mute. Audio assets are synthesized in `tools/generate_audio.py`; no third-party music or samples are used.
- A complete pollination, fruit, seed extraction, sowing, maturation, and repeated-crossing loop. All distinct mature parent pairs are supported. Full diploid genomes and weighted ancestry survive seeds and later generations, including crosses between hybrids. Diploid expressed/carried alleles, independent inheritance, ±10% parental stat variance, skills, recessive traits, G3+ combined patterns, and reduced graft inheritance remain active. Generations grant no flat stat bonus.
- Cross-species grafting with permanent donor anatomy/genome records, two-graft limit, 90%/65% base graft compatibility with second-graft rejection, protected favorite donors and cooldowns. Mutation uses 70% change / 20% unchanged / 10% deformity; radiation has an 8% carnivorous chance within the change outcome.
- Six display slots, live diversity/harmony/rarity scoring, beauty thresholds, species pattern pages, complete pattern-family and atlas rewards.
- Atomic local saves, previous-save recovery, full pedigrees, growing fruit, harvested fruit inventory, complete-genome seeds, mixed ancestry, discoveries that survive mutation, saved bed positions, display selection, and tray order. Existing V1 gardens and older seed snapshots migrate without deleting plants or resetting progress. Map position, visited camps, discovered habitats, field kits, patch history, and active wild encounters are also preserved. Language, sound, and display preferences are stored independently from the garden archive. Saves live at Godot's `user://conservatory_v1.json`; on macOS this is normally `~/Library/Application Support/Godot/app_userdata/The Quiet Conservatory/`.

This is an offline gardening game. Visitors and market demand rotate deterministically each UTC day; permanent ribbons and family histories stay in the local save. The project is ready for Godot export; platform export templates are installed separately through Godot.

## Illustrated plants and wild landscapes

Eight original panoramic landscapes and eight redesigned transparent plant families follow the supplied fine-ink, flat-color art direction. The same plant portraits appear at home, in the field, in encounters, and in DNA/breeding previews. Inherited pigments, stripes, spots, flower petal counts, mixed anatomy, grafts, care-grown size, and age remain driven by the actual specimen. The previous source art is retained beside the new `assets/plants/illustrated/` set.

Each region contains three stable growing habitats (24 total): ferns favor cool gullies, flowers favor sunny terraces, mushrooms favor damp islands and cisterns, roots hold banks and fissures, and vines or pale companions follow walls and host trunks. New patches draw from a 75% resident / 25% companion pool. Field clues name the likely families; rare pitcher plants retain their discovery requirement. Started encounters and previously seen legacy patches keep their original individual. Collected plants save their habitat provenance.

Choose **Where this family grows →** from a plant or its traits page, then **Follow this trail →** to walk toward a suitable available patch. The field panorama, nearby growing-spot clue, illustrated atlas, and encounter backdrop all describe the same place. Existing camps, movement, route collisions, and daily regrowth remain active.

Generation prompts and asset notes are recorded in `assets/landscapes/prompts.json` and `assets/landscapes/ART_DIRECTION.md`.

## Verification

```sh
godot --headless --path . --script res://tests/model_test.gd
godot --headless --path . --script res://tests/integration_test.gd
godot --headless --path . --script res://tests/reproduction_integration_test.gd
godot --headless --path . --script res://tests/dna_test.gd
godot --headless --path . --script res://tests/genetics_guide_test.gd
godot --headless --path . --script res://tests/genetics_guide_integration_test.gd
godot --headless --path . --script res://tests/plant_care_test.gd
godot --headless --path . --script res://tests/plant_care_integration_test.gd
godot --headless --path . --script res://tests/garden_fair_test.gd
godot --headless --path . --script res://tests/garden_fair_integration_test.gd
godot --headless --path . --script res://tests/market_model_test.gd
godot --headless --path . --script res://tests/market_integration_test.gd
godot --headless --path . --script res://tests/planting_model_test.gd
godot --headless --path . --script res://tests/planting_integration_test.gd
godot --headless --path . --script res://tests/wild_test.gd
godot --headless --path . --script res://tests/wild_preview_test.gd
godot --headless --path . --script res://tests/wilderness_test.gd
godot --headless --path . --script res://tests/habitat_model_test.gd
godot --headless --path . --script res://tests/adventure_model_test.gd
godot --headless --path . --script res://tests/adventure_integration_test.gd
godot --headless --path . --script res://tests/habitat_integration_test.gd
godot --headless --path . --script res://tests/field_integration_test.gd
godot --headless --path . --script res://tests/display_test.gd
godot --headless --path . --script res://tests/audio_test.gd
godot --headless --path . --script res://tests/localization_test.gd
godot --headless --path . --script res://tests/settings_integration_test.gd
godot --path . --script res://tests/plant_art_test.gd
godot --path . --script res://tests/plant_care_art_test.gd
```

Model checks exercise inheritance, risks, rewards, complete lineage saves, corruption recovery, read-only previews, and permanent collection progress. Reproduction integration checks drive the actual controls from pollination through fruit harvest, seed extraction and sowing to G2, then repeat through G3 and G4, with reloads between stages and Chinese mobile bounds. Fair checks exercise exact rewards, daily requests, kept plants, permanent ribbons, and old-save migration. Other integration checks run collection, fair visits, and planting loops and enforce desktop/mobile overlay and garden bounds.

Readable genetics checks validate analytical predictions against actual births and drive the visible/hidden trait cards, mate selection, goal chances, free laboratory prefill, optional encoded records, and English/Chinese desktop/mobile layouts.

Market checks exercise exact price sums, daily demand, saturation floors, condition and size premiums, stable seed selection, stale offers, repeated clicks, protected favorites and fruit, sold-parent archives, every shop purchase, save migration, malformed-ledger rejection, and large seed banks. UI checks drive actual trade controls in English and Chinese on desktop and mobile. `tests/market_visual_preview.gd` captures real quotes, sales, purchases, receipts, and sold archives using a disposable silent garden.

Planting checks tap actual empty soil, choose and review full-genome seeds, cancel safely, and plant into the exact selected plot. They verify stable seed references after inventory shifts, saved seedlings and parentage, visible growth and care actions, atomic failures for occupied plots, missing seeds and low light, full-garden guidance, and English/Chinese desktop/mobile bounds.

Plant care checks drive the actual tool shed entry, specimen selector, and all six tools; verify exact costs, cooldowns, treatment caps, saved measurements, extended survival, unchanged DNA and stored fruit embryos; and check English/Chinese desktop/mobile bounds. Native care artwork checks verify that extra height and weight change the rendered silhouette and that aging follows the extended lifetime.

`tests/plant_care_visual_preview.gd` captures the bright garden and tool shed, treatment results, grown silhouettes, and Chinese mobile layouts with a temporary garden.

Field tests cover save migration, exact collection odds and costs, stable encounters, all species pools, daily regrowth, real keyboard movement, every patch being reachable, mobile HUD bounds, and collecting a wild plant → returning home → breeding its descendant.

Botanical art checks use the native GPU renderer to verify transparency, mipmaps, actual visible genetic variations and growth states, and a fixed shared-texture cache. Map artwork previews the same deterministic organism as its encounter without changing saves, IDs, resources, or random state. `tests/plant_art_preview.gd` renders all eight plant types; `tests/hybrid_art_preview.gd` reviews every cross-type pair, multi-generation anatomy, grafts, literal petal counts, and natural withering; `tests/breeding_visual_preview.gd` captures the complete Chinese breeding, DNA, fruit, and seed interfaces; `tests/botanical_game_preview.gd` captures the actual garden, close-ups, fair visitors, wild specimens, and Chinese mobile layouts using a temporary save.

`tests/new_features_preview.gd` checks the expanded atlas, distant habitats, English/Chinese settings and mobile Chinese layouts with a silent temporary save.

`tests/high_resolution_preview.gd` verifies actual large-window and native-fullscreen screenshot dimensions with a temporary save. `tests/field_visual_preview.gd` captures the pixel garden, exploration, and wild encounters. `tests/visual_preview.gd` renders desktop/mobile screenshots to `screenshots/` using the native renderer and a separate temporary save, leaving the player's garden untouched.

`tests/garden_fair_visual_preview.gd` uses disposable silent gardens to capture visitors, exact plant-show gifts, permanent ribbons, friendly talents, and English/Chinese desktop/mobile views. Legacy win and battle counters remain readable in old saves solely for archive compatibility.

`tests/landscape_visual_preview.gd` captures every illustrated region, encounter scenery, atlas, and Chinese mobile field views in a disposable garden. `tests/illustrated_plants_preview.gd` captures all eight redesigned plant families and real genetic, hybrid, graft and aging variants.

`tests/adventure_visual_preview.gd` captures a full Moonbell Crossing playthrough in disposable gardens: collecting parents, real cross fruit and siblings, both genetic routes, Moonbell and a glowing G3 courtyard, with English/Chinese desktop and phone views.
