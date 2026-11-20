# Botanical sprite artwork

Eight original pixel-art botanical specimens replace the prototype's simple
procedural silhouettes: Leaf, Bloom, Vine, Root, Spore, Toxin, Parasite, and
Carnivorous. The selected transparent atlas is `botanical-atlas-v1.png`.
The eight named PNGs are lossless 384 × 512 frames from its four-column,
two-row layout. `tools/import_plant_atlas.gd` repeats that extraction without
changing the painted pixels or alpha.

Created using the built-in image generation tool. The complete generation
prompt is saved in `generation-prompt.txt`. No third-party game sprites or
characters were used.

The game loads these source PNGs, trims transparent margins, fixes alpha edges,
and generates mipmaps. Gene coloring and markings are applied at runtime, so
the original light, leaf veins, flower details, and shading remain visible.
The old procedural anatomy remains available as a missing-asset fallback.
