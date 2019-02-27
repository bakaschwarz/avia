local assets =
{
	Asset( "ANIM", "anim/avia.zip" ),
	Asset( "ANIM", "anim/ghost_avia_build.zip" ),
}

local skins =
{
	normal_skin = "avia",
	ghost_skin = "ghost_avia_build",
}

local base_prefab = "avia"

local tags = {"AVIA", "CHARACTER"}

return CreatePrefabSkin("avia_none",
{
	base_prefab = base_prefab, 
	skins = skins, 
	assets = assets,
	tags = tags,
	
	skip_item_gen = true,
	skip_giftable_gen = true,
})