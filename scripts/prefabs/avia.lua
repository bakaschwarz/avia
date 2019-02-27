
local MakePlayerCharacter = require "prefabs/player_common"

local assets = {
    Asset("SCRIPT", "scripts/prefabs/player_common.lua"),
	Asset( "ANIM", "anim/avia.zip" ),
	Asset( "ANIM", "anim/avia_winter.zip"),
}
local prefabs = {}

local start_inv = {
	"acorn",
	"acorn",
	"seeds",
	"seeds",
	"seeds",
}

local hunger_switch = false

local SPEED_UPPER_LIMIT = 1.6

local current_flying_modifier = 1.0

local last_x, last_y, last_z, x, y, z = 0, 0, 0, 0, 0, 0

local winter_skin = false

-- Revive
local function onbecamehuman(inst)
    inst.components.locomotor.walkspeed = TUNING.WILSON_WALK_SPEED - 0.5
    inst.components.locomotor.runspeed = TUNING.WILSON_RUN_SPEED - 0.5
	inst.components.locomotor:SetExternalSpeedMultiplier(inst, "avia_speed_mod", 1)
end

-- When dead
local function onbecameghost(inst)
   inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, "avia_speed_mod")
end

-- When spawning
local function onload(inst)
    inst:ListenForEvent("ms_respawnedfromghost", onbecamehuman)
    inst:ListenForEvent("ms_becameghost", onbecameghost)

    if inst:HasTag("playerghost") then
        onbecameghost(inst)
    else
        onbecamehuman(inst)
    end
end


-- Server and Client
local common_postinit = function(inst) 
	inst.MiniMapEntity:SetIcon( "avia.tex" )
	inst:AddTag("birdwhisperer")
end

local function HandleSpeedModifier(inst)
	if inst.components.sanity:GetPercent() >= 0.2 then
		local x, y, z = inst.Transform:GetWorldPosition()
		if x ~= last_x or z ~= last_z then
			local equipitem = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
			if current_flying_modifier < SPEED_UPPER_LIMIT and equipitem == nil then
				current_flying_modifier = current_flying_modifier + 0.025
				inst.components.locomotor:SetExternalSpeedMultiplier(inst, "avia_fly", current_flying_modifier)
			end
		else 
			inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, "avia_fly")
			current_flying_modifier = 1.0
		end
		last_x = x
		last_y = y
		last_z = z
	else
		inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, "avia_fly")
		current_flying_modifier = 1.0
	end
end

local function HandleSkinChange(inst)
	if TheWorld.state.iswinter and not winter_skin then
		winter_skin = true
		inst.AnimState:SetBuild("avia_winter")
	elseif not TheWorld.state.iswinter and winter_skin then
		winter_skin = false
        inst.AnimState:SetBuild("avia")
	end
end

local function ForceSkinChange(inst, skins)
	if TheWorld.state.iswinter then
		inst.AnimState:SetBuild("avia_winter")
	else
		inst.AnimState:SetBuild("avia")
	end	
end

local function FlingItem(inst, loot)
	local x, y, z = inst.Transform:GetWorldPosition()
	loot.Transform:SetPosition(x, y, z)

	local angle = math.random() * 2 * PI
	local speed = math.random() * 2
	loot.Physics:SetVel(speed * math.cos(angle), GetRandomWithVariance(8, 4), speed * math.sin(angle))
	local radius = (loot.Physics:GetRadius() or 1) + (inst.Physics:GetRadius() or 1)
	loot.Transform:SetPosition(
		x + math.cos(angle) * radius,
		y,
		z + math.sin(angle) * radius
	)
end

local function HandleHits(inst, attacker, damage)
	if damage >= 40 then
		local quantity = math.random(1, 3)
		local counter = 0
		repeat 
			if TheWorld.state.iswinter then
				local feather = SpawnPrefab("feather_robin_winter")
				FlingItem(inst, feather)
			else
				local feather = SpawnPrefab("feather_robin")
				FlingItem(inst, feather)
			end
			counter = counter + 1
		until counter == quantity
	end
end

local function OnEat(inst, food)
	if not food:HasTag("spoiled") then
		if food.prefab == "seeds" then
			inst.components.sanity:DoDelta(2)
		elseif food.prefab == "dragonfruit_seeds" then
			inst.components.sanity:DoDelta(-5)
			inst.components.temperature:DoDelta(20)
		elseif food.prefab == "carrot_seeds" then
			inst.components.sanity:DoDelta(6)
			inst.components.health:DoDelta(1)
		elseif food.prefab == "durian_seeds" then
			inst.components.sanity:DoDelta(-9999)
			inst.components.hunger:DoDelta(9999)
		elseif food.prefab == "eggplant_seeds" then
			inst.components.hunger:DoDelta(10)
		elseif food.prefab == "pomegranate_seeds" then
			inst.components.health:DoDelta(15)
		elseif food.prefab == "pumpkin_seeds" then
			inst.components.sanity:DoDelta(10)
		elseif food.prefab == "watermelon_seeds" then
			inst.components.sanity:DoDelta(-5)
			inst.components.temperature:DoDelta(-5)
		elseif food.prefab == "sweet_potato_seeds" then
			inst.components.sanity:DoDelta(5)
			inst.components.hunger:DoDelta(1)
		elseif food.prefab == "corn_seeds" then
			inst.components.sanity:DoDelta(1)
		end
	end
end

-- Server only
local master_postinit = function(inst)
	inst.soundsname = "avia"
	inst.components.health:SetMaxHealth(100)
	inst.components.hunger:SetMax(50)
	inst.components.sanity:SetMax(350)
	
	inst.components.eater:SetDiet({ FOODTYPE.SEEDS }, { FOODTYPE.SEEDS })

    inst.components.combat.damagemultiplier = 0.9
	inst.components.combat:SetOnHit(HandleHits)
	
	inst.components.hunger.hungerrate = 0.08
	
	inst.OnLoad = onload
    inst.OnNewSpawn = onload

	inst.Transform:SetScale(0.9, 0.9, 0.9)

	inst.components.eater:SetOnEatFn(OnEat)

	inst:ListenForEvent("ms_closewardrobe", ForceSkinChange)

	inst.components.combat.onhitotherfn = function (attacker, inst, damage, stimuli)
		if inst:HasTag("bird") then
			attacker.components.sanity:DoDelta(-10)
			local text_choice = math.random(0, 2)
			if text_choice == 0 then
				attacker.components.talker:Say("I'm so sorry little one...")
			elseif text_choice == 1 then
				attacker.components.talker:Say("Please forgive me...")
			elseif text_choice == 2 then
				attacker.components.talker:Say("This is unforgivable...")
			end
			attacker.SoundEmitter:PlaySound("dontstarve/characters/avia/talk_LP", "talk")
		end
	end

	inst:DoPeriodicTask(0.2, function()
		HandleSpeedModifier(inst)
		HandleSkinChange(inst)
		if inst.components.hunger:GetPercent() < 0.3 then
			hunger_switch = true
			inst.components.sanity.dapperness = TUNING.CRAZINESS_MED
		else
			hunger_switch = false
			inst.components.sanity.dapperness = TUNING.DAPPERNESS_MED
		end
	end)
end

return MakePlayerCharacter("avia", prefabs, assets, common_postinit, master_postinit, start_inv)
