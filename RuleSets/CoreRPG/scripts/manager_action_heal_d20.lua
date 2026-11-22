--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

--
--	ROLL BUILD
--

function performRoll(draginfo, rActor, rAction)
	local rRoll = ActionHealD20.getRoll(rActor, rAction);
	ActionsManager.performAction(draginfo, rActor, rRoll);
end
function getRoll(rActor, rAction)
	if not rAction then
		return nil;
	end

	local rRoll = {
		sType = "heal",
		sDesc = ActionHealCore.encodeActionText(rAction),
		sLabel = StringManager.capitalizeAll(rAction.label),
		nOrder = rAction.order,
		aDice = {},
		nMod = 0,
		clauses = rAction.clauses or {},
		bOngoing = rAction.bOngoing,
		bNonlethal = rAction.bNonlethal,
		sRange = rAction.range,
		bSelfTarget = ((rAction and rAction.sTargeting or "") == "self"),
		bSecret = rAction.bSecret,
		tActionTags = rAction.tActionTags,
	};

	-- Handle various heal types
	if (rAction.subtype or "") == "temp" then
		rRoll.healtype = "temp";
		rRoll.sDesc = rRoll.sDesc .. " [TEMP]";
	elseif (rAction.subtype or "") == "sp" then
		rRoll.healtype = "stamina";
		rRoll.sDesc = rRoll.sDesc .. " [STAMINA]";
	elseif (rAction.subtype or "") == "fheal" then
		rRoll.sDesc = string.format("[FHEAL] %s", rAction.label);
	elseif (rAction.subtype or "") == "regen" then
		rRoll.sDesc = string.format("[REGEN] %s", rAction.label);
	else
		rRoll.healtype = rAction.subtype or "";
	end

	-- Add the dice and modifiers
	if rAction.dice or rAction.modifier then
		table.insert(rRoll.clauses, { dice = rAction.dice or {}, modifier = rAction.modifier or 0, });
	end
	rRoll.nHealCost = 0;
	rRoll.nHSMult = 0;
	for _,tClause in pairs(rRoll.clauses) do
		DiceRollManager.addHealDice(rRoll.aDice, tClause.dice, { healtype = rRoll.healtype });
		rRoll.nMod = rRoll.nMod + (tClause.modifier or 0);
		local sAbility = DataCommon.ability_ltos[tClause.stat];
		if sAbility then
			rRoll.sDesc = rRoll.sDesc .. string.format(" [MOD: %s (%s)]", sAbility, tClause.statmult or 1);
		end
		if GameManager.hasOption("healsurge") then
			rRoll.nHealCost = rRoll.nHealCost + (tClause.cost or 0);
			rRoll.nHSMult = rRoll.nHSMult + (tClause.basemult or 0);
		end
	end
	if rRoll.nHealCost ~= 0 then
		rRoll.sDesc = string.format("%s\r[COST %d]", rRoll.sDesc, rRoll.nHealCost);
	end
	if rRoll.nHSMult ~= 0 then
		rRoll.sDesc = string.format("%s\r[HSV %d]", rRoll.sDesc, rRoll.nHSMult);
	end

	-- Encode metamagic
	if GameManager.hasOption("metamagic") then
		if rAction.meta then
			if rAction.meta == "empower" then
				rRoll.sDesc = StringManager.appendLine(rRoll.sDesc, "[EMPOWER]");
			elseif rAction.meta == "maximize" then
				rRoll.sDesc = StringManager.appendLine(rRoll.sDesc, "[MAXIMIZE]");
			elseif rAction.meta == "empowermaximize" then
				rRoll.sDesc = StringManager.appendLine(rRoll.sDesc, "[EMPOWER]");
				rRoll.sDesc = StringManager.appendLine(rRoll.sDesc, "[MAXIMIZE]");
			elseif rAction.meta == "epicintensify" then
				rRoll.sDesc = StringManager.appendLine(rRoll.sDesc, "[EPIC INTENSIFY]");
			end
		end
	end

	-- Extra display text
	if #(rAction.tAddText or {}) > 0 then
		rRoll.sDesc = rRoll.sDesc .. "\r" .. table.concat(rAction.tAddText, "\r");
	end

	GameManager.callMultiKeyFunctionPostLayered("onActionPostGetRoll", rRoll.sType, rActor, rAction, rRoll);

	-- Encode the damage types
	ActionCore.encodeRollClauses(rRoll);

	return rRoll;
end

--
--	ROLL MOD
--

function modHeal(rSource, rTarget, rRoll)
	ActionCore.applyModClauseAbilityEffects(rSource, rTarget, rRoll);

	ActionHealD20.applyModHealEffects(rSource, rTarget, rRoll);

	ActionCore.applyModMaxEffects(rSource, rTarget, rRoll);
	ActionCore.applyModHalfEffects(rSource, rTarget, rRoll);
	ActionCore.applyModTabletopButtons(rSource, rTarget, rRoll);
end
function applyModHealEffects(rSource, rTarget, rRoll)
	ActionHealD20.applyModHealEffectsTag(rSource, rTarget, rRoll, rRoll.sEffectBaseTag);

	for _,sEffectTag in ipairs(rRoll.tEffectTags or {}) do
		ActionHealD20.applyModHealEffectsTag(rSource, rTarget, rRoll, sEffectTag);
	end
end
function applyModHealEffectsTag(rSource, rTarget, rRoll, sEffectTag)
	if (sEffectTag or "") == "" then
		return;
	end

	if rSource and not rRoll.bOngoing then
		local tData = {
			rTarget = rTarget,
			tActionTags = rRoll.tActionTags,
		};
		local tBonusData, nEffects = EffectManager.getBonusData(rSource, sEffectTag, tData);
		if nEffects > 0 then
			ActionHealD20.applyModHealEffectsBonus(rRoll, tBonusData);
		end
	end
	if rTarget then
		local tAtData = {
			rTarget = rSource,
			tActionTags = rRoll.tActionTags,
		};
		local tBonusData, nEffects = EffectManager.getBonusData(rTarget, "@" .. sEffectTag, tAtData);
		if nEffects > 0 then
			ActionHealD20.applyModHealEffectsBonus(rRoll, tBonusData);
		end
	end
end
function applyModHealEffectsBonus(rRoll, tBonusData)
	if not rRoll or not tBonusData then
		return;
	end

	for _,v in pairs(tBonusData) do
		rRoll.bEffects = true;
		rRoll.nEffectMod = rRoll.nEffectMod + v.mod;
		for _,vDie in ipairs(v.dice) do
			table.insert(rRoll.tEffectDice, vDie);
		end
		rRoll.nMod = rRoll.nMod + v.mod;

		DiceRollManager.addHealDice(rRoll.aDice, v.dice, { dmgtype = rRoll.healtype, iconcolor = "FF00FF", });
	end
end

--
--	ON ROLL (PRE-TARGET)
--

function onHealRoll(rSource, rRoll)
	ActionCore.decodeRollClauses(rRoll);

	ActionCore.applyRollGeneralModifiers(rSource, rRoll);
	ActionD20.applyRollMetaMagic(rSource, rRoll);
end
