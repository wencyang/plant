extends RefCounted
## A field guide shared by encounter generation, landscape art and plant pages.
## Microhabitats belong to places, not random rolls: returning tomorrow changes
## the individual genome while keeping the same resident-family preference.

const SPECIES: Array[String] = ["Veilfern","Lantern Bloom","Threadvine","Anchoroot","Ghostcap","Gall Orchid","Pale Strangler"]
const TYPES: Array[String] = ["Leaf","Bloom","Vine","Root","Spore","Toxin","Parasite"]
const REGIONS := {
	"Mosswood": {"landscape":"Pine terraces & fern gullies","clue":"Follow the cool gullies for ferns, sunny clearings for lantern flowers, and old walls for vines.","art_key":"forest"},
	"Amber Hollow": {"landscape":"Amber terraces & warm stone","clue":"Lantern flowers love the bright terraces. Look among ochre stones for roots and fragrant orchids.","art_key":"amber"},
	"Sporefen": {"landscape":"Spore islands & reed marshes","clue":"Pearl mushrooms gather on damp islands, roots grip the reed banks, and pale tendrils climb old trunks.","art_key":"sporefen"},
	"Sunken Glade": {"landscape":"Sunken courtyards & hanging gardens","clue":"Look for vines on broken trellises, mushrooms in the cisterns, and pale tendrils on old host trees.","art_key":"glasshouse"},
	"Glassfall Coast": {"landscape":"Sea cliffs & turquoise tide pools","clue":"Fern pockets hide from sea winds. Tidal roots grip the pools while vines lace the cliff gardens.","art_key":"coast"},
	"Moonfen": {"landscape":"Moonlit pools & silver reeds","clue":"Silver spore beds, moon orchids, and pale host trees each shelter a different plant family.","art_key":"moonfen"},
	"Ember Ridge": {"landscape":"Red canyons & golden scrub","clue":"Fragrant orchids grow on warm ledges, lantern flowers face the sun, and roots shelter in rock fissures.","art_key":"canyon"},
	"Ancient Grove": {"landscape":"Giant roots & ancient archways","clue":"Follow great roots for Anchoroot, hanging lianas for Threadvine, and old host trunks for pale companions.","art_key":"ancient"}
}

## Each four-entry pool is an honest field-guide promise: three entries for the
## named resident and one for its companion. Every founding family remains wild.
const PATCHES := {
	"Mosswood": [
		{"id":"fern_gully","name":"Fern gully","terrain":"fern_gully","pool":[0,0,0,2],"clue":"Cool shade and wet stone make this a favorite home for Veilfern. Threadvine sometimes shares the gully."},
		{"id":"lantern_clearing","name":"Lantern clearing","terrain":"flower_terrace","pool":[1,1,1,0],"clue":"A pocket of sunshine for Lantern Bloom, with a few ferns at its shaded edge."},
		{"id":"vine_terrace","name":"Vine terrace","terrain":"vine_trellis","pool":[2,2,2,0],"clue":"Threadvine climbs the old terrace walls; Veilfern shelters below."}
	],
	"Amber Hollow": [
		{"id":"golden_terrace","name":"Golden flower terrace","terrain":"flower_terrace","pool":[1,1,1,5],"clue":"Warm terraces favor Lantern Bloom. Fragrant Gall Orchids sometimes take root beside it."},
		{"id":"ochre_roots","name":"Ochre root bank","terrain":"root_bank","pool":[3,3,3,1],"clue":"Anchoroot knots hold these ochre banks together, with lantern flowers above."},
		{"id":"orchid_ledge","name":"Fragrant stone ledge","terrain":"cliff_ledge","pool":[5,5,5,1],"clue":"Gall Orchid loves this warm, fragrant ledge. Lantern Bloom is its sunny companion."}
	],
	"Sporefen": [
		{"id":"pearl_island","name":"Pearl spore island","terrain":"spore_marsh","pool":[4,4,4,3],"clue":"Ghostcap gathers on damp peat islands. Anchoroot grips the edges of the pool."},
		{"id":"reed_roots","name":"Reed root bank","terrain":"root_bank","pool":[3,3,3,4],"clue":"Look between the reeds for Anchoroot, and beneath their roots for Ghostcap."},
		{"id":"marsh_hosts","name":"Old marsh hosts","terrain":"host_trunks","pool":[6,6,6,4],"clue":"Pale Strangler follows these old host trunks. Ghostcap grows in the damp shade below."}
	],
	"Sunken Glade": [
		{"id":"hanging_court","name":"Hanging garden court","terrain":"vine_trellis","pool":[2,2,2,6],"clue":"Threadvine drapes the broken trellises, sometimes joined by Pale Strangler."},
		{"id":"sunken_hosts","name":"Sunken host garden","terrain":"host_trunks","pool":[6,6,6,4],"clue":"Pale Strangler clings to the old host trees; Ghostcap prefers their damp foundations."},
		{"id":"spore_cistern","name":"Spore cistern","terrain":"stone_cistern","pool":[4,4,4,2],"clue":"Cool cistern stone shelters Ghostcap. Threadvine hangs over its rim."}
	],
	"Glassfall Coast": [
		{"id":"sheltered_fern","name":"Sheltered sea ferns","terrain":"salt_scrub","pool":[0,0,0,1],"clue":"Veilfern hides in sheltered cliff pockets, with Lantern Bloom where sunlight reaches the rock."},
		{"id":"tidal_roots","name":"Tidal root pool","terrain":"tide_pool","pool":[3,3,3,0],"clue":"Anchoroot grips the turquoise pools. Veilfern grows just above the tide line."},
		{"id":"sea_lattice","name":"Sea garden lattice","terrain":"vine_trellis","pool":[2,2,2,1],"clue":"Threadvine laces the seaside garden walls. Lantern Bloom follows the warm stone."}
	],
	"Moonfen": [
		{"id":"silver_spores","name":"Silver spore bed","terrain":"spore_marsh","pool":[4,4,4,6],"clue":"Ghostcap clusters beside the silver pools. Pale Strangler winds through the reeds."},
		{"id":"moon_orchids","name":"Moon orchid island","terrain":"moon_orchids","pool":[5,5,5,4],"clue":"Gall Orchid favors these quiet islands. A few Ghostcaps share the moist banks."},
		{"id":"moon_hosts","name":"Pale moon hosts","terrain":"host_trunks","pool":[6,6,6,5],"clue":"Pale Strangler follows the moonlit host trees. Gall Orchid grows in their shelter."}
	],
	"Ember Ridge": [
		{"id":"canyon_orchids","name":"Canyon orchid ledge","terrain":"cliff_ledge","pool":[5,5,5,3],"clue":"Gall Orchid brightens the warm canyon ledges. Anchoroot shelters in their cracks."},
		{"id":"sun_lanterns","name":"Sun-facing lantern shelf","terrain":"flower_terrace","pool":[1,1,1,3],"clue":"Lantern Bloom faces the sun on these high shelves, while Anchoroot holds the soil."},
		{"id":"ember_fissure","name":"Ember root fissure","terrain":"root_fissure","pool":[3,3,3,5],"clue":"Anchoroot shelters inside cool fissures. Gall Orchid grows along the warm rim."}
	],
	"Ancient Grove": [
		{"id":"great_roots","name":"Great root hollow","terrain":"giant_roots","pool":[3,3,3,2],"clue":"Anchoroot gathers beneath the giant roots. Threadvine climbs toward the canopy."},
		{"id":"liana_arch","name":"Ancient liana arch","terrain":"vine_trellis","pool":[2,2,2,6],"clue":"Threadvine hangs from the living archways. Pale Strangler winds around old branches."},
		{"id":"elder_hosts","name":"Elder host grove","terrain":"host_trunks","pool":[6,6,6,4],"clue":"Pale Strangler follows the oldest host trunks; Ghostcap grows in their shade."}
	]
}

static func region(biome: String) -> Dictionary:
	if not REGIONS.has(biome): return {}
	var result: Dictionary = REGIONS[biome].duplicate(true)
	result["biome"] = biome
	var names: Array[String] = []
	for definition: Dictionary in PATCHES[biome]:
		for species_index: int in definition.pool:
			if not names.has(SPECIES[species_index]): names.append(SPECIES[species_index])
	result["signature_species"] = names
	result["rare_species"] = ["Hollow Pitcher"] if biome in ["Sunken Glade","Ancient Grove","Moonfen"] else []
	return result

static func patch(biome: String,site_id: String) -> Dictionary:
	if not PATCHES.has(biome): return {}
	var choices: Array = PATCHES[biome]
	var index: int = posmod((biome+"/"+site_id).hash(),choices.size())
	# Preserve the easy first fern encounter and a matching landscape clue.
	if site_id=="moss_01": index=0
	var result: Dictionary = choices[index].duplicate(true)
	result["biome"] = biome
	result["landscape"] = str(REGIONS[biome].landscape)
	result["art_key"] = str(REGIONS[biome].art_key)
	result["species_pool"] = result.pool.duplicate()
	result["primary_species"] = SPECIES[int(result.pool[0])]
	var names: Array[String] = []
	for species_index: int in result.pool:
		if not names.has(SPECIES[species_index]): names.append(SPECIES[species_index])
	result["species"] = names
	result.erase("pool")
	return result

static func site_info(biome: String,site_id: String) -> Dictionary:
	return patch(biome,site_id)

static func species_pool(biome: String,site_id: String) -> Array:
	return patch(biome,site_id).get("species_pool",[])

static func preferred_habitats(species_or_type: String) -> Array[Dictionary]:
	var species_index: int = SPECIES.find(species_or_type)
	if species_index<0: species_index=TYPES.find(species_or_type)
	var preferred: Array[Dictionary] = []
	var companions: Array[Dictionary] = []
	if species_or_type in ["Hollow Pitcher","Carnivorous"]:
		for biome: String in ["Sunken Glade","Moonfen","Ancient Grove"]:
			preferred.append({"biome":biome,"habitat":str(REGIONS[biome].landscape),"landscape":str(REGIONS[biome].landscape),"clue":"Rare pitcher plants may appear here after ten successful wild collections.","primary":false,"rare":true})
		return preferred
	if species_index<0: return preferred
	for biome: String in PATCHES:
		for definition: Dictionary in PATCHES[biome]:
			if not definition.pool.has(species_index): continue
			var primary: bool = int(definition.pool[0])==species_index
			var entry: Dictionary = {"biome":biome,"habitat":str(definition.name),"habitat_key":str(definition.id),"landscape":str(REGIONS[biome].landscape),"clue":str(definition.clue),"primary":primary,"rare":false}
			if primary: preferred.append(entry)
			else: companions.append(entry)
	preferred.append_array(companions)
	return preferred
