PrefabFiles = {
	"avia",
	"avia_none",
}

Assets = {
    Asset( "IMAGE", "images/saveslot_portraits/avia.tex" ),
    Asset( "ATLAS", "images/saveslot_portraits/avia.xml" ),

    Asset( "IMAGE", "images/selectscreen_portraits/avia.tex" ),
    Asset( "ATLAS", "images/selectscreen_portraits/avia.xml" ),
	
    Asset( "IMAGE", "images/selectscreen_portraits/avia_silho.tex" ),
    Asset( "ATLAS", "images/selectscreen_portraits/avia_silho.xml" ),

    Asset( "IMAGE", "bigportraits/avia.tex" ),
    Asset( "ATLAS", "bigportraits/avia.xml" ),
	
	Asset( "IMAGE", "images/map_icons/avia.tex" ),
	Asset( "ATLAS", "images/map_icons/avia.xml" ),
	
	Asset( "IMAGE", "images/avatars/avatar_avia.tex" ),
    Asset( "ATLAS", "images/avatars/avatar_avia.xml" ),
	
	Asset( "IMAGE", "images/avatars/avatar_ghost_avia.tex" ),
    Asset( "ATLAS", "images/avatars/avatar_ghost_avia.xml" ),
	
	Asset( "IMAGE", "images/avatars/self_inspect_avia.tex" ),
    Asset( "ATLAS", "images/avatars/self_inspect_avia.xml" ),
	
	Asset( "IMAGE", "images/names_avia.tex" ),
    Asset( "ATLAS", "images/names_avia.xml" ),
	
    Asset( "IMAGE", "bigportraits/avia_none.tex" ),
    Asset( "ATLAS", "bigportraits/avia_none.xml" ),

    Asset("SOUNDPACKAGE", "sound/avia.fev"),
    Asset("SOUND", "sound/avia.fsb"),
}

local require = GLOBAL.require
local STRINGS = GLOBAL.STRINGS
local FOODTYPE = GLOBAL.FOODTYPE
local FRAMES = GLOBAL.FRAMES
require "prefabutil"

RemapSoundEvent("dontstarve/characters/avia/talk_LP", "avia/avia/talk_LP")
RemapSoundEvent("dontstarve/characters/avia/yawn", "avia/avia/yawn")
RemapSoundEvent("dontstarve/characters/avia/pose", "avia/avia/pose")
RemapSoundEvent("dontstarve/characters/avia/ghost_LP", "avia/avia/ghost_LP")
RemapSoundEvent("dontstarve/characters/avia/emote", "avia/avia/emote")
RemapSoundEvent("dontstarve/characters/avia/death_voice", "avia/avia/death_voice")
RemapSoundEvent("dontstarve/characters/avia/hurt", "avia/avia/hurt")

-- From 492792310 ------------------------------
local function RecheckForThreat(inst)
    local busy = inst.sg:HasStateTag("sleeping") or inst.sg:HasStateTag("busy") or inst.sg:HasStateTag("flying")
    if not busy then
        local threat = GLOBAL.FindEntity(inst, 5, nil, nil, {'notarget', 'birdwhisperer'}, {'player', 'monster', 'scarytoprey'})
        return threat ~= nil or GLOBAL.TheWorld.state.isnight
    end
end

AddStategraphPostInit("bird", function(sg)
    local old = sg.events.flyaway.fn
    sg.events.flyaway.fn = function(inst)
        if RecheckForThreat(inst) then
            old(inst)
        end
    end
end)
------------------------------------------------

-- Make feathers a healing item for Avia -------
local function MakeHealingItem(inst)
    if not GLOBAL.TheWorld.ismastersim then
            return inst
    end
    local old_set_owner_fn = inst.components.inventoryitem.SetOwner
    function inst.components.inventoryitem.SetOwner(owner, ...)
        old_set_owner_fn(owner, ...)
        local owner_name = inst.components.inventoryitem.owner.prefab
        if owner_name == "avia" then
            inst:AddComponent("healer")
            if inst.prefab == "feather_crow" then
                inst.components.healer:SetHealthAmount(5)
            elseif inst.prefab == "feather_robin" then
                inst.components.healer:SetHealthAmount(10)
            elseif inst.prefab == "feather_robin_winter" then
                inst.components.healer:SetHealthAmount(10)
            elseif inst.prefab == "feather_canary" then
                inst.components.healer:SetHealthAmount(50)
            end
        else
            inst:RemoveComponent("healer")
        end
    end
    local old_clear_owner_fn = inst.components.inventoryitem.ClearOwner
    function inst.components.inventoryitem.ClearOwner(owner, ...)
        old_clear_owner_fn(owner, ...)
        inst:RemoveComponent("healer")
    end
end
AddPrefabPostInit("feather_crow", MakeHealingItem)
AddPrefabPostInit("feather_robin", MakeHealingItem)
AddPrefabPostInit("feather_robin_winter", MakeHealingItem)
AddPrefabPostInit("feather_canary", MakeHealingItem)
------------------------------------------------

-- Birds trade seeds with avia -----------------

local function TradeWithAvia(inst)
    if not GLOBAL.TheWorld.ismastersim then
            return inst
    end
    inst:AddComponent("trader")
    inst.components.trader:SetAcceptTest(function(inst, item, giver)
        if giver.prefab == "avia" then
            local invalid_foods =
            {
                "bird_egg",
                "rottenegg",
                "monstermeat",
                -- "cookedmonstermeat",
                -- "monstermeat_dried",
            }
            local seed_name = string.lower(item.prefab .. "_seeds")
            local can_accept = item.components.edible
                and (Prefabs[seed_name] 
                or item.prefab == "seeds"
                or item.components.edible.foodtype == FOODTYPE.MEAT)
            if table.contains(invalid_foods, item.prefab) then
                can_accept = false
            end
            
            return can_accept
        else
            return false
        end
    end)
    inst.components.trader.onaccept = function(inst, giver, item)
        --If you're sleeping, wake up.
        if inst.components.sleeper and inst.components.sleeper:IsAsleep() then
            inst.components.sleeper:WakeUp()
        end

        if item.components.edible ~= nil and
            (   item.components.edible.foodtype == FOODTYPE.MEAT
                or item.prefab == "seeds"
                or Prefabs[string.lower(item.prefab .. "_seeds")] ~= nil
            ) then
            local function DigestFood(inst, food)
                if food.components.edible.foodtype == FOODTYPE.MEAT then
                    --If the food is meat:
                        --Spawn an egg.
                    inst.components.lootdropper:SpawnLootPrefab("bird_egg")
                else
                    local seed_name = string.lower(food.prefab .. "_seeds")
                    if Prefabs[seed_name] ~= nil then
                        --If the food has a relavent seed type:
                            --Spawn 1 or 2 of those seeds.
                        local num_seeds = math.random(2)
                        for k = 1, num_seeds do
                            inst.components.lootdropper:SpawnLootPrefab(seed_name)
                        end
                            --Spawn regular seeds on a 50% chance.
                        if math.random() < 0.5 then
                            inst.components.lootdropper:SpawnLootPrefab("seeds")
                        end
                    else
                        --Otherwise...
                            --Spawn a poop 1/3 times.
                        if math.random() < 0.33 then
                            local loot = inst.components.lootdropper:SpawnLootPrefab("guano")
                            loot.Transform:SetScale(.33, .33, .33)
                        end
                    end
                end

                inst.components.perishable:SetPercent(1)
            end
            --Digest Food in 60 frames.
            inst:DoTaskInTime(60 * FRAMES, DigestFood, item)
        end
    end
    inst.components.trader.onrefuse = function(inst, item)
        inst.AnimState:PlayAnimation("flap")
        inst.AnimState:PlayAnimation("idle")
    end
end

----AddPrefabPostInit("crow", TradeWithAvia)
--AddPrefabPostInit("robin", TradeWithAvia)
--AddPrefabPostInit("robin_winter", TradeWithAvia)
--AddPrefabPostInit("canary", TradeWithAvia)
------------------------------------------------


STRINGS.CHARACTER_TITLES.avia = "Child Of The Bird Tribe"
STRINGS.CHARACTER_NAMES.avia = "Avia"
STRINGS.CHARACTER_DESCRIPTIONS.avia = "* Is a bird\n* Gets nervous when hungry\n* Only eats seeds"
STRINGS.CHARACTER_QUOTES.avia = "\"Where is everyone?\""

STRINGS.CHARACTERS.AVIA = require "speech_avia"

STRINGS.NAMES.AVIA = "Avia"

AddMinimapAtlas("images/map_icons/avia.xml")

AddModCharacter("avia", "FEMALE")