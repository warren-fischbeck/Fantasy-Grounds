--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

function getAbilityEffectsBonus(rActor, sAbility, tData)
	if not rActor or not sAbility then
		return 0, 0;
	end

	local bNegativeOnly = (sAbility:sub(1,1) == "-");
	if bNegativeOnly then
		sAbility = sAbility:sub(2);
	end

	local sAbilityEffect = DataCommon and DataCommon.ability_ltos and DataCommon.ability_ltos[sAbility];
	if not sAbilityEffect then
		return 0, 0;
	end

	local nEffectBase, nBaseAbilityEffects = EffectManager.getMaxMod(rActor, "B" .. sAbilityEffect, tData);
	local nEffectMod, nAbilityEffects = EffectManager.getBonusMod(rActor, sAbilityEffect, tData);
	local nEffectCondMod, nCondEffects = ActorManagerD20.getAbilityCondEffectsBonus(rActor, sAbility);
	nEffectMod = nEffectMod + nEffectCondMod;
	nAbilityEffects = nAbilityEffects + nCondEffects;

	local nTotalEffects = nBaseAbilityEffects + nAbilityEffects;

	local nAbilityScore = GameManager.callFunction("onActorGetAbilityScore", rActor, sAbility) or 0;

	local nAbilityMod;
	if nAbilityScore > 0 then
		local nAbilityDamage = GameManager.callFunction("onActorGetAbilityDamage", rActor, sAbility) or 0;
		local nCurrentBonus = math.floor((nAbilityScore - nAbilityDamage - 10) / 2);

		nAbilityScore = nEffectBase or nAbilityScore;
		local nAffectedBonus = math.floor((nAbilityScore - nAbilityDamage + nEffectMod - 10) / 2);

		nAbilityMod = nAffectedBonus - nCurrentBonus;
	else
		if nEffectMod > 0 then
			nAbilityMod = math.floor(nEffectMod / 2);
		else
			nAbilityMod = math.ceil(nEffectMod / 2);
		end

		if nEffectBase then
			local nAbilityBonus = math.floor((nAbilityScore - 10) / 2);
			local nEffectBaseBonus = math.floor((nEffectBase - 10) / 2);
			nAbilityMod = nAbilityMod + (nEffectBaseBonus - nAbilityBonus);
		end
	end

	if bNegativeOnly and (nAbilityMod > 0) then
		nAbilityMod = 0;
	end

	return nAbilityMod, nTotalEffects;
end
function getAbilityCondEffectsBonus(rActor, sAbility)
	local nEffectMod = 0;
	local nEffects = 0;

	if GameManager.isOption("abilityeffectcond", "PF2") then
		if sAbility == "dexterity" or sAbility == "strength" then
			if EffectManager.hasCondition(rActor, "Exhausted") then
				nEffectMod = nEffectMod - 6;
				nEffects = nEffects + 1;
			end
		end
	elseif GameManager.isOption("abilityeffectcond", "PF") then
		if sAbility == "dexterity" then
			if EffectManager.hasCondition(rActor, "Entangled") then
				nEffectMod = nEffectMod - 4;
				nEffects = nEffects + 1;
			end
			if EffectManager.hasCondition(rActor, "Grappled") then
				nEffectMod = nEffectMod - 4;
				nEffects = nEffects + 1;
			end
		end
		if sAbility == "dexterity" or sAbility == "strength" then
			if EffectManager.hasCondition(rActor, "Exhausted") then
				nEffectMod = nEffectMod - 6;
				nEffects = nEffects + 1;
			elseif EffectManager.hasCondition(rActor, "Fatigued") then
				nEffectMod = nEffectMod - 2;
				nEffects = nEffects + 1;
			end
		end
	elseif GameManager.isOption("abilityeffectcond", "SF") then
		if sAbility == "dexterity" then
			if EffectManager.hasCondition(rActor, "Entangled") then
				nEffectMod = nEffectMod - 2;
				nEffects = nEffects + 1;
			end
		end
		if sAbility == "dexterity" or sAbility == "strength" then
			if EffectManager.hasCondition(rActor, "Exhausted") then
				nEffectMod = nEffectMod - 3;
				nEffects = nEffects + 1;
			elseif EffectManager.hasCondition(rActor, "Fatigued") then
				nEffectMod = nEffectMod - 1;
				nEffects = nEffects + 1;
			end
		end
	elseif GameManager.isOption("abilityeffectcond", "3.5E") then
		if sAbility == "dexterity" then
			if EffectManager.hasCondition(rActor, "Entangled") then
				nEffectMod = nEffectMod - 4;
				nEffects = nEffects + 1;
			end
		end
		if sAbility == "dexterity" or sAbility == "strength" then
			if EffectManager.hasCondition(rActor, "Exhausted") then
				nEffectMod = nEffectMod - 6;
				nEffects = nEffects + 1;
			elseif EffectManager.hasCondition(rActor, "Fatigued") then
				nEffectMod = nEffectMod - 2;
				nEffects = nEffects + 1;
			end
		end
	end
	return nEffectMod, nEffects;
end
