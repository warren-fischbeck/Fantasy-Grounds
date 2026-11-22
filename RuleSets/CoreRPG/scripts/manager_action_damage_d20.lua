--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

-- NOTE: D20 (3.5E/PF) - Effect damage dice are not multiplied on critical, though numerical modifiers are multiplied
-- https://rpg.stackexchange.com/questions/4465/is-smite-evil-damage-multiplied-by-a-critical-hit

OOB_MSGTYPE_APPLYDMG = "applydmg";

function registerStandardDamageHealHandlers()
	OOBManager.registerOOBMsgHandler(ActionDamageD20.OOB_MSGTYPE_APPLYDMG, ActionDamageD20.handleApplyDamage);

	ActionsManager.registerModHandler("damage", ActionDamageD20.modDamage);
	ActionsManager.registerPostRollHandler("damage", ActionDamageD20.onDamageRoll);
	ActionsManager.registerResultHandler("damage", ActionDamageD20.onRoll);

	ActionsManager.registerModHandler("heal", ActionHealD20.modHeal);
	ActionsManager.registerPostRollHandler("heal", ActionHealD20.onHealRoll);
	ActionsManager.registerResultHandler("heal", ActionDamageD20.onRoll);

	ActionDamageCore.registerStandardDamageStateHandlers();

	if GameManager.hasOption("dmgfortification") then
		ActionsManager.registerResultHandler("fortification", ActionDamageD20.onFortification);
	end
end

--
--	NETWORKING
--

function notifyApplyDamage(rSource, rTarget, rRoll)
	if not rTarget then
		return;
	end

	local msgOOB = UtilityManager.encodeRollToOOB(rRoll);
	msgOOB.type = ActionDamageD20.OOB_MSGTYPE_APPLYDMG;
	msgOOB.sSourceNode = ActorManager.getCreatureNodeName(rSource);
	msgOOB.sTargetNode = ActorManager.getCreatureNodeName(rTarget);
	msgOOB.nTargetOrder = rTarget.nOrder;
	Comm.deliverOOBMessage(msgOOB, "");
end
function handleApplyDamage(msgOOB)
	local rSource = ActorManager.resolveActor(msgOOB.sSourceNode);
	local rTarget = ActorManager.resolveActor(msgOOB.sTargetNode);
	if rTarget then
		rTarget.nOrder = msgOOB.nTargetOrder;
	end
	local rRoll = UtilityManager.decodeRollFromOOB(msgOOB);
	ActionHealthD20.apply(rSource, rTarget, rRoll);
end

--
--	ROLL BUILD
--

function performRoll(draginfo, rActor, rAction)
	local rRoll = ActionDamageD20.getRoll(rActor, rAction);
	ActionsManager.performAction(draginfo, rActor, rRoll);
end
function getRoll(rActor, rAction)
	if not rAction then
		return nil;
	end

	local rRoll = {
		sType = "damage",
		sDesc = ActionDamageCore.encodeActionText(rAction),
		sLabel = StringManager.capitalizeAll(rAction.label),
		nOrder = rAction.order,
		aDice = {},
		nMod = 0,
		clauses = rAction.clauses or {},
		bWeapon = rAction.bWeapon,
		bSpell = rAction.bSpell,
		bOngoing = rAction.bOngoing,
		sRange = rAction.range,
		bSelfTarget = ((rAction and rAction.sTargeting or "") == "self"),
		bSecret = rAction.bSecret,
		tActionTags = rAction.tActionTags,
	};

	-- Add the dice and modifiers
	if rAction.dice or rAction.modifier then
		table.insert(rRoll.clauses, { dice = rAction.dice or {}, modifier = rAction.modifier or 0, dmgtype = rAction.dmgtype or "", });
	end
	for _,tClause in ipairs(rRoll.clauses) do
		local tData = {
			dmgtype = tClause.dmgtype,
			nReroll = tClause.nReroll,
			bRerollNoLimit = tClause.bRerollNoLimit,
			bExplodeCompound = tClause.bExplodeCompound,
		};
		DiceRollManager.addDamageDice(rRoll.aDice, tClause.dice, tData);
		rRoll.nMod = rRoll.nMod + (tClause.modifier or 0);
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

function modDamage(rSource, rTarget, rRoll)
	ActionCore.applyModClauseAbilityEffects(rSource, rTarget, rRoll);

	ActionDamageD20.applyModConditions(rSource, rTarget, rRoll);
	ActionDamageD20.applyModNonlethal(rSource, rTarget, rRoll);
	ActionDamageD20.applyModPreEffectCritical(rSource, rTarget, rRoll);

	ActionDamageD20.applyModDmgBaseTypeEffects(rSource, rTarget, rRoll);
	ActionDamageD20.applyModDmgEffects(rSource, rTarget, rRoll);
	ActionDamageD20.applyModDmgTypeEffects(rSource, rTarget, rRoll);

	ActionDamageD20.applyModPostEffectCritical(rSource, rTarget, rRoll);

	ActionCore.applyModMaxEffects(rSource, rTarget, rRoll);
	ActionCore.applyModHalfEffects(rSource, rTarget, rRoll);
	ActionCore.applyModTabletopButtons(rSource, rTarget, rRoll);

	ActionDamageD20.applyModFixedDamageOption(rSource, rTarget, rRoll);
end
-- applyModConditions(rSource, rTarget, rRoll)
function applyModConditions(rSource, _, rRoll)
	if not rSource then
		return;
	end
	if GameManager.isOption("atktype", { "3.5E", "PF" }) then
		if not rRoll.bSpell then
			if EffectManager.hasCondition(rSource, "Sickened") then
				rRoll.nMod = rRoll.nMod - 2;
				rRoll.nEffectMod = rRoll.nEffectMod - 2;
				rRoll.bEffects = true;
			end
		end
	end
	if GameManager.isOption("incorporeal", { "3.5E", "PF" }) then
		if not rRoll.bSpell then
			if EffectManager.hasCondition(rSource, "Incorporeal") and (rRoll.sRange == "M")
					and not rRoll.sDesc:lower():match("incorporeal touch") then
				rRoll.bEffects = true;
				table.insert(rRoll.tNotifications, "[INCORPOREAL]");
			end
		end
	elseif GameManager.hasOption("incorporeal") then
		if EffectManager.hasCondition(rSource, "Incorporeal") then
			rRoll.bEffects = true;
			table.insert(rRoll.tNotifications, "[INCORPOREAL]");
		end
	end
end
-- applyModNonlethal(rSource, rTarget, rRoll)
function applyModNonlethal(_, _, rRoll)
	if not GameManager.hasOption("nonlethal") then
		return;
	end
	if not ModifierManager.getKey("DMG_NONLETHAL") then
		return;
	end

	for _,tClause in ipairs(rRoll.clauses) do
		local tClauseDamageTypes = StringManager.split(tClause.dmgtype, ",", true);
		if not StringManager.contains(tClauseDamageTypes, "nonlethal") then
			table.insert(tClauseDamageTypes, "nonlethal");
			tClause.dmgtype = table.concat(tClauseDamageTypes, ",");
		end
	end
end
function applyModPreEffectCritical(rSource, rTarget, rRoll)
	if GameManager.isOption("critical", { "3.5E", "PF" }) then
		ActionDamageD20.applyModCritical35E(rSource, rTarget, rRoll);
	end
end
-- applyModCritical35E(rSource, rTarget, rRoll)
function applyModCritical35E(_, _, rRoll)
	if not rRoll.bCritical then
		return;
	end

	local nDieIndex = 1;
	local tNewClauses = {};
	for _,tClause in ipairs(rRoll.clauses) do
		local nClauseDice = #(tClause.dice or {});
		nDieIndex = nDieIndex + nClauseDice;

		table.insert(tNewClauses, tClause);

		local nMult = tClause.mult or 2;
		if nMult > 1 then
			local rNewClause = UtilityManager.copyDeep(tClause);
			rNewClause.dice = {};
			rNewClause.modifier = 0;
			if rNewClause.dmgtype == "" then
				rNewClause.dmgtype = "critical";
			else
				rNewClause.dmgtype = rNewClause.dmgtype .. ",critical";
			end

			local nMod = tClause.modifier or 0;

			for _ = 2, nMult do
				for j = 1, nClauseDice do
					table.insert(rNewClause.dice, tClause.dice[j]);
				end
				rRoll.nMod = rRoll.nMod + nMod;
				rNewClause.modifier = rNewClause.modifier + nMod;
			end

			local tDiceData = {
				index = nDieIndex,
				dmgtype = rNewClause.dmgtype,
				iconcolor = "00FF00",
				nReroll = tClause.nReroll,
				bRerollNoLimit = tClause.bRerollNoLimit,
			};
			DiceRollManager.addDamageDice(rRoll.aDice, rNewClause.dice, tDiceData);

			table.insert(tNewClauses, rNewClause);
		end
	end
	rRoll.clauses = tNewClauses;
end
function applyModDmgBaseTypeEffects(rSource, rTarget, rRoll)
	if not rSource then
		return;
	end
	if not rRoll.clauses[1] then
		return;
	end

	local tDmgBaseTypes = EffectManagerD20.getDamageTypeDescriptors(rSource, "DMGBASETYPE", { rTarget = rTarget, tFilter = rRoll.tEffectFilter, });
	if #tDmgBaseTypes <= 0 then
		return;
	end

	local setDamageTypes = SetManager.new(tDmgBaseTypes);
	local tOldTypes = StringManager.split(rRoll.clauses[1].dmgtype or "", ",", true);
	for i = 2, #tOldTypes do
		SetManager.add(setDamageTypes, tOldTypes[i]);
	end
	rRoll.clauses[1].dmgtype = SetManager.concat(setDamageTypes, ",");
end
function applyModDmgEffects(rSource, rTarget, rRoll)
	if rRoll.bStatic and GameManager.hasOption("dmgstaticnoeffect") then
		return;
	end

	ActionDamageD20.applyModDmgEffectsTag(rSource, rTarget, rRoll, rRoll.sEffectBaseTag);

	for _,sEffectTag in ipairs(rRoll.tEffectTags or {}) do
		ActionDamageD20.applyModDmgEffectsTag(rSource, rTarget, rRoll, sEffectTag);
	end
end
function applyModDmgEffectsTag(rSource, rTarget, rRoll, sEffectTag)
	if (sEffectTag or "") == "" then
		return;
	end

	if rSource and not rRoll.bOngoing then
		local tData = {
			rTarget = rTarget,
			tFilter = rRoll.tEffectFilter,
			tActionTags = rRoll.tActionTags,
		};
		local tBonusData, nEffects = EffectManager.getBonusData(rSource, sEffectTag, tData);
		if nEffects > 0 then
			ActionDamageD20.applyModDmgEffectsBonus(rRoll, tBonusData);
		end
	end
	if rTarget then
		local tAtData = {
			rTarget = rSource,
			tFilter = rRoll.tEffectFilter,
			tActionTags = rRoll.tActionTags,
		};
		local tBonusData, nEffects = EffectManager.getBonusData(rTarget, "@" .. sEffectTag, tAtData);
		if nEffects > 0 then
			ActionDamageD20.applyModDmgEffectsBonus(rRoll, tBonusData);
		end
	end
end
function applyModDmgEffectsBonus(rRoll, tBonusData)
	if not rRoll or not tBonusData then
		return;
	end

	local sEffectBaseType = "";
	local nEffectCritMult = 1;
	if #(rRoll.clauses) > 0 then
		sEffectBaseType = rRoll.clauses[1].dmgtype or "";
		if GameManager.hasOption("critmult") then
			nEffectCritMult = rRoll.clauses[1].mult or 2;
		end
	end

	for k,v in pairs(tBonusData) do
		local bCritEffect = false;
		local bPrecisionEffect = false;
		local tEffectDmgType = {};
		local tEffectSpecialDmgType = {};
		for _,sType in ipairs(StringManager.split(k, ",", true)) do
			if ActionCore.isBasicDamageType(sType) then
				table.insert(tEffectDmgType, sType);
			elseif ActionCore.isCriticalDamageType(sType) then
				table.insert(tEffectSpecialDmgType, sType);
				bCritEffect = true;
			elseif ActionCore.isDamageType(sType) then
				table.insert(tEffectSpecialDmgType, sType);
				if sType == "precision" then
					bPrecisionEffect = true;
				end
			end
		end

		if not bCritEffect or rRoll.bCritical then
			rRoll.bEffects = true;
			rRoll.nEffectMod = rRoll.nEffectMod + v.mod;
			rRoll.nMod = rRoll.nMod + v.mod;

			if #tEffectDmgType == 0 and (sEffectBaseType ~= "") then
				for _,sType in ipairs(StringManager.split(sEffectBaseType, ",", true)) do
					table.insert(tEffectDmgType, sType);
				end
			end
			for _,vSpecialDmgType in ipairs(tEffectSpecialDmgType) do
				if not StringManager.contains(tEffectDmgType, vSpecialDmgType) then
					table.insert(tEffectDmgType, vSpecialDmgType);
				end
			end

			local tClause = {
				dice = {},
				modifier = v.mod,
				stat = "",
				dmgtype = table.concat(tEffectDmgType, ","),
			};
			for _,vDie in ipairs(v.dice) do
				table.insert(rRoll.tEffectDice, vDie);
				table.insert(tClause.dice, vDie);
			end
			table.insert(rRoll.clauses, tClause);

			local tDiceData = {
				dmgtype = tClause.dmgtype,
				iconcolor = "FF00FF",
			};
			DiceRollManager.addDamageDice(rRoll.aDice, tClause.dice, tDiceData);

			-- Add critical effect modifier
			if GameManager.isOption("critmult", "PF2") then
				if rRoll.bCritical and not bCritEffect and (nEffectCritMult > 1) then
					local nCurrentMod = (v.mod * (nEffectCritMult - 1));
					rRoll.nEffectMod = rRoll.nEffectMod + nCurrentMod;
					rRoll.nMod = rRoll.nMod + nCurrentMod;

					local tClauseCritical = {
						dice = {},
						modifier = nCurrentMod,
						dmgtype = StringManager.append(tClause.dmgtype, "critical");
					};
					for _ = 2, nEffectCritMult do
						for _,vDie in ipairs(v.dice) do
							table.insert(rRoll.tEffectDice, vDie);
							table.insert(tClauseCritical.dice, vDie);
						end
					end

					local tDiceData = {
						dmgtype = tClauseCritical.dmgtype,
						iconcolor = "FF00FF",
					};
					DiceRollManager.addDamageDice(rRoll.aDice, tClauseCritical.dice, tDiceData);

					table.insert(rRoll.clauses, tClauseCritical);
				end
			else
				if rRoll.bCritical and not bPrecisionEffect and not bCritEffect and (nEffectCritMult > 1) and (#(v.dice) == 0) then
					local nCurrentMod = (v.mod * (nEffectCritMult - 1));
					rRoll.nEffectMod = rRoll.nEffectMod + nCurrentMod;
					rRoll.nMod = rRoll.nMod + nCurrentMod;

					local tClauseCritical = {
						dice = {},
						modifier = nCurrentMod,
						dmgtype = StringManager.append(tClause.dmgtype, "critical");
					};
					table.insert(rRoll.clauses, tClauseCritical);
				end
			end
		end
	end
end
function applyModDmgTypeEffects(rSource, rTarget, rRoll)
	if not rSource then
		return;
	end

	local tAddTypes = EffectManagerD20.getDamageTypeDescriptors(rSource, "DMGTYPE", { rTarget = rTarget, tFilter = rRoll.tEffectFilter, });
	if #tAddTypes <= 0 then
		return;
	end

	for _,tClause in ipairs(rRoll.clauses or {}) do
		tClause.dmgtype = StringManager.appendUnique(tClause.dmgtype, tAddTypes);
	end

	table.insert(rRoll.tNotifications, EffectManager.buildEffectOutput(SetManager.concat(tAddTypes, ",")));
end
function applyModPostEffectCritical(rSource, rTarget, rRoll)
	if GameManager.isOption("critical", "5E") then
		ActionDamageD20.applyModCritical5E(rSource, rTarget, rRoll);
	end
	if GameManager.isOption("critical", "2E") then
		ActionDamageD20.applyModCritical2E(rSource, rTarget, rRoll);
	end

	if rRoll.bCritical and GameManager.hasOption("critical") then
		table.insert(rRoll.tNotifications, "[CRITICAL]");
	end
end
function applyModCritical5E(rSource, rTarget, rRoll)
	ActionDamageD20.applyModCriticalDoubleDice(rSource, rTarget, rRoll);
end
function applyModCritical2E(rSource, rTarget, rRoll)
	if not rRoll.bCritical then
		return;
	end

	local sOptCritType = OptionsManager.getOption("HouseRule_CRIT_TYPE");
	if sOptCritType == "none" then
		rRoll.bCritical = false;
	elseif sOptCritType == "max" then
		rRoll.bModMax = true;
	elseif sOptCritType == "timestwo" then
		rRoll.nMult = (rRoll.nMult or 1) * 2;
	else
		ActionDamageD20.applyModCriticalDoubleDice(rSource, rTarget, rRoll);
	end
end
-- applyModCriticalDoubleDice(rSource, rTarget, rRoll)
function applyModCriticalDoubleDice(_, _, rRoll)
	if not rRoll.bCritical then
		return;
	end

	-- Double all the dice, including effect dice
	local tNewClauses = {};
	for _,tClause in ipairs(rRoll.clauses) do
		local tClauseDmgType = StringManager.split(tClause.dmgtype, ",", true);
		if not SetManager.overlaps(tClauseDmgType, ActionCore.getCriticalDamageTypes()) then
			local nClauseDice = #(tClause.dice or {});
			if nClauseDice > 0 then
				table.insert(tClauseDmgType, "critical");
				local tNewClause = {
					dice = UtilityManager.copyDeep(tClause.dice),
					modifier = 0,
					dmgtype = table.concat(tClauseDmgType, ",");
					nReroll = tClause.nReroll,
					bRerollNoLimit = tClause.bRerollNoLimit,
					nMin = tClause.nMin,
					stat = "",
					bCritical = true,
				};
				table.insert(tNewClauses, tNewClause);

				if (tClause.nExtraCritDice or 0) > 0 then
					local nMaxSides = 0;
					for _,sDie in ipairs(tClause.dice) do
						if sDie:sub(1,1) ~= "-" then
							nMaxSides = math.max(nMaxSides, tonumber(sDie:sub(2)) or 0);
						end
					end
					if nMaxSides > 0 then
						for _ = 1, tClause.nExtraCritDice do
							table.insert(tNewClause.dice, "d" .. nMaxSides);
						end
					end
				end
			end
		end
	end
	for _,tClause in ipairs(tNewClauses) do
		table.insert(rRoll.clauses, tClause);

		local tDiceData = {
			dmgtype = tClause.dmgtype,
			iconcolor = "00FF00",
			nReroll = tClause.nReroll,
			bRerollNoLimit = tClause.bRerollNoLimit,
		};
		DiceRollManager.addDamageDice(rRoll.aDice, tClause.dice, tDiceData);
	end
end
-- applyModFixedDamageOption(rSource, rTarget, rRoll)
function applyModFixedDamageOption(rSource, _, rRoll)
	if not OptionsManager.isOption("NPCD", "fixed") or not ActorManager.isRecordType(rSource, "npc") then
		return;
	end

	local tNewClauses = {};
	local tNewDice = {};
	local nFixedMod = 0;
	local nFixedPositiveCount = 0;
	local nFixedNegativeCount = 0;
	for kClause,tClause in ipairs(rRoll.clauses) do
		if kClause <= rRoll.nOrigClauses then
			local nClauseFixedMod = 0;
			for _,vDie in ipairs(tClause.dice) do
				if vDie:sub(1,1) == "-" then
					nFixedNegativeCount = nFixedNegativeCount + 1;
					nClauseFixedMod = nClauseFixedMod - math.floor(math.ceil(tonumber(vDie:sub(3)) or 0) / 2);
					if nFixedNegativeCount % 2 == 0 then
						nClauseFixedMod = nClauseFixedMod - 1;
					end
				else
					nFixedPositiveCount = nFixedPositiveCount + 1;
					nClauseFixedMod = nClauseFixedMod + math.floor(math.ceil(tonumber(vDie:sub(2)) or 0) / 2);
					if nFixedPositiveCount % 2 == 0 then
						nClauseFixedMod = nClauseFixedMod + 1;
					end
				end
				tClause.modifier = tClause.modifier + nClauseFixedMod;
			end
			tClause.dice = {};
			nFixedMod = nFixedMod + nClauseFixedMod;
		else
			local tDiceData = {
				dmgtype = tClause.dmgtype,
				nReroll = tClause.nReroll,
				bRerollNoLimit = tClause.bRerollNoLimit,
			};
			if tClause.bCritical then
				tDiceData.iconcolor = "00FF00";
			end
			DiceRollManager.addDamageDice(tNewDice, tClause.dice, tDiceData);
		end

		table.insert(tNewClauses, tClause);
	end

	rRoll.clauses = tNewClauses;
	rRoll.aDice = tNewDice;
	rRoll.nMod = rRoll.nMod + nFixedMod;
end

--
--	ON ROLL (PRE-TARGET)
--

function onDamageRoll(rSource, rRoll)
	ActionCore.decodeRollClauses(rRoll);
	ActionCore.encodeDamageTypesDisplay(rRoll);

	ActionCore.applyRollGeneralModifiers(rSource, rRoll);
	ActionD20.applyRollMetaMagic(rSource, rRoll);
	ActionDamageD20.applyRollMinDamage(rSource, rRoll);
end
-- applyRollMinDamage(rSource, rRoll)
function applyRollMinDamage(_, rRoll)
	if #(rRoll.aDice or {}) <= 0 then
		return;
	end

	local nTotal = ActionsManager.total(rRoll);
	if GameManager.isOption("dmgmin", { "3.5E", "PF", "PF2", }) then
		if nTotal <= 0 then
			rRoll.sDesc = rRoll.sDesc .. "\r[MIN DAMAGE]";
			local nMinMod = 1 - nTotal;
			rRoll.nMod = rRoll.nMod + nMinMod;

			local setDamageTypes = SetManager.new();
			for _,tClause in pairs(rRoll.clauses) do
				SetManager.add(setDamageTypes, StringManager.split(tClause.dmgtype, ",", true));
			end
			if GameManager.isOption("nonlethal", "3.5E") then
				SetManager.add(setDamageTypes, "nonlethal");
			end
			rRoll.clauses = { { dmgtype = SetManager.concat(setDamageTypes, ","), dice = {}, modifier = 1, nTotal = 1 } };
		end
	else
		if nTotal < 0 then
			rRoll.sDesc = rRoll.sDesc .. "\r[MIN DAMAGE]";
			rRoll.nMod = rRoll.nMod - nTotal;

			local setDamageTypes = SetManager.new();
			for _,tClause in pairs(rRoll.clauses) do
				SetManager.add(setDamageTypes, StringManager.split(tClause.dmgtype, ",", true));
			end
			rRoll.clauses = { { dmgtype = SetManager.concat(setDamageTypes, ","), dice = {}, modifier = 0, nTotal = 0 } };
		end
	end
end

--
--	ON ROLL (POST-TARGET)
--

function onRoll(rSource, rTarget, rRoll)
	if rRoll.sType == "damage" then
		ActionDamageCore.decodeRollData(rRoll);
	elseif rRoll.sType == "heal" then
		ActionHealCore.decodeRollData(rRoll);
	end

	if not rTarget then
		ActionDamageD20.applyRollUntargetedMultEffects(rSource, rRoll);
	end

	local rMessage = ActionsManager.createActionMessage(rSource, rRoll);
	rMessage.text = rMessage.text:gsub(" %[MOD:[^]]*%]", "");
	rMessage.text = rMessage.text:gsub(" %[MULT:[^]]*%]", "");
	rRoll.sDesc = rMessage.text;

	-- Send the chat message
	if (not rTarget or ((rTarget.nOrder or 1) == 1)) then
		Comm.deliverChatMessage(rMessage);
	end

	if ActionDamageD20.checkFortification(rSource, rTarget, rRoll) then
		return;
	end

	-- Apply damage to the PC or CT entry referenced
	ActionDamageD20.notifyApplyDamage(rSource, rTarget, rRoll);
end
function applyRollUntargetedMultEffects(rSource, rTarget, rRoll)
	if rTarget then
		return;
	end

	if rRoll.sType == "damage" then
		ActionCore.applyRollEffectCompsMult(rRoll, EffectManager.getCompsDataByTag(rSource, "DMGMULT"), "damage");
	elseif rRoll.sType == "heal" then
		if (rRoll.healtype or "") == "" then
			ActionCore.applyRollEffectCompsMult(rRoll, EffectManager.getCompsDataByTag(rSource, "HEALMULT"), "heal");
		elseif (rRoll.healtype or "") == "temp" then
			ActionCore.applyRollEffectCompsMult(rRoll, EffectManager.getCompsDataByTag(rSource, "TEMPMULT"), "temp");
		end
	elseif rRoll.sType == "recovery" then
		ActionCore.applyRollEffectCompsMult(rRoll, EffectManager.getCompsDataByTag(rSource, "HDMULT", "recovery"));
	end
	if (rRoll.nMult or 1) == 1 then
		return;
	end

	if rRoll.sType == "damage" then
		if rRoll.nMult < 0 then
			rRoll.sType = "heal";
			rRoll.sDesc = string.format("%s %s", rRoll.sDesc:gsub("%[DAMAGE[^]]*%]", "[HEAL]"):gubs(" %[TYPE:[^]]*%]", ""), "[CONVERTED]");
			rRoll.nMult = rRoll.nMult * -1;
		else
			local nCarry = 0;
			for _,tClause in ipairs(rRoll.clauses) do
				if tClause.dmgtype and tClause.dmgtype ~= "" then
					local nAdjusted = tClause.nTotal * rRoll.nMult;
					nCarry = nCarry + (nAdjusted % 1);
					if nCarry >= 1 then
						nAdjusted = nAdjusted + 1;
						nCarry = nCarry - 1;
					end
					nAdjusted = math.floor(nAdjusted);
					if (nAdjusted - tClause.nTotal) > 0 then
						rRoll.sDesc = rRoll.sDesc .. string.format("\r[TYPE: %s (%s)]", tClause.dmgtype, (nAdjusted - tClause.nTotal));
					elseif (nAdjusted - tClause.nTotal < 0) then
						local sPattern = string.format("%%[TYPE: %s[^]]*%%]", tClause.dmgtype);
						local sReplace = string.format("[TYPE: %s (%d)]", tClause.dmgtype, math.floor(nAdjusted));
						rRoll.sDesc = string.gsub(rRoll.sDesc, sPattern, sReplace);
					end
				end
			end
		end
	elseif rRoll.sType == "heal" then
		if rRoll.nMult < 0 then
			rRoll.sType = "damage";
			rRoll.sDesc = string.format("%s %s", rRoll.sDesc:gsub("%[HEAL[^]]*%]", "[DAMAGE]"), "[CONVERTED]");
			rRoll.nMult = rRoll.nMult * -1;
		end
	end

	if rRoll.nMult % 1 == 0 then
		rRoll.sDesc = string.format("%s %s", rRoll.sDesc, string.format("[MULT: %d]", rRoll.nMult));
	else
		rRoll.sDesc = string.format("%s %s", rRoll.sDesc, string.format("[MULT: %.2f]", rRoll.nMult));
	end

	local nAdj = math.floor(rRoll.nTotal * rRoll.nMult) - rRoll.nTotal;
	rRoll.nTotal = rRoll.nTotal + nAdj;
	rRoll.nMod = rRoll.nMod + nAdj;
end
function checkFortification(rSource, rTarget, rRoll)
	if not GameManager.hasOption("dmgfortification") then
		return false;
	end
	if not rTarget or (rRoll.sType ~= "damage") then
		return false;
	end

	-- Determine if fortification needs to be checked (critical or precision damage)
	local bCheckFortification = false;
	for _,tClause in ipairs(rRoll.clauses) do
		if SetManager.overlaps(StringManager.split(tClause.dmgtype, ",", true), { "critical", "precision", }) then
			bCheckFortification = true;
			break;
		end
	end
	if not bCheckFortification then
		return false;
	end

	-- Calculate fortification percentage (max of bonuses - sum of penalties)
	local nFortBonusMax = 0;
	local nFortPenalty = 0;
	for _,tCompData in ipairs(EffectManager.getCompsDataByTag(rTarget, "FORTIFY", { rTarget = rSource, tActionTags = rRoll.tActionTags, })) do
		if tCompData.mod >= 0 then
			nFortBonusMax = math.max(nFortBonusMax, tCompData.mod);
		else
			nFortPenalty = nFortPenalty + tCompData.mod;
		end
	end
	for _,tCompData in ipairs(EffectManager.getCompsDataByTag(rSource, "@FORTIFY", { rTarget = rTarget, tActionTags = rRoll.tActionTags, })) do
		if tCompData.mod >= 0 then
			nFortBonusMax = math.max(nFortBonusMax, tCompData.mod);
		else
			nFortPenalty = nFortPenalty + tCompData.mod;
		end
	end
	rRoll.nFortification = math.max(math.min(nFortBonusMax + nFortPenalty, 100), 0);

	-- Handle fortification roll based on total fortification
	if rRoll.nFortification >= 100 then
		rRoll.bFortification = true;
	elseif rRoll.nFortification > 0 then
		ActionDamageD20.performFortificationRoll(rTarget, rSource, rRoll);
		return true;
	end
	return false;
end

--
--	FORTIFICATION
--

function performFortificationRoll(rSource, rTarget, rDamageRoll)
	local rRoll = ActionDamageD20.getFortificationRoll(rSource, rTarget, rDamageRoll);
	ActionsManager.actionDirect(rSource, rRoll.sType, { rRoll }, { { rTarget } });
end
-- getFortificationRoll(rSource, rTarget, rDamageRoll)
function getFortificationRoll(rSource, _, rDamageRoll)
	local rRoll = {
		sType = "fortification",
		sDesc = string.format("[FORTIFICATION] [%d%%]", rDamageRoll.nFortification);
		aDice = DiceRollManager.getActorDice({ "d100" }, rSource),
		nMod = 0,
		nTarget = rDamageRoll.nFortification,
		jsonDamage = Utility.encodeJSON(rDamageRoll or {}) or "",
	};
	return rRoll;
end
function onFortification(rSource, rTarget, rRoll)
	local rMessage = ActionsManager.createActionMessage(rSource, rRoll);
	Comm.deliverChatMessage(rMessage);

	local rDamageRoll = Utility.decodeJSON(rRoll.jsonDamage) or {};
	if rRoll.nTotal <= rRoll.nTarget then
		rDamageRoll.bFortification = true;
	end
	ActionDamageD20.notifyApplyDamage(rTarget, rSource, rDamageRoll);
end
