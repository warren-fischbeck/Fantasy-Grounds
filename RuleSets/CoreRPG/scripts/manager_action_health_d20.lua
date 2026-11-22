--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

function onInit()
	GameManager.setFunction("onHealthApply", ActionHealthD20.applyDefault);

	GameManager.setFunction("onHealthApplyGetHealth", ActionHealthD20.applyGetHealthDefault);
	GameManager.setFunction("onHealthApplySetHealth", ActionHealthD20.applySetHealthDefault);
	GameManager.setFunction("onHealthApplyStatusChange", ActionHealthD20.applyStatusChangeDefault);
	GameManager.setFunction("onHealthPostApply", ActionHealthD20.onPostApplyDefault);

	GameManager.setFunction("onDamageApplyResults", ActionHealthD20.applyDamageResultsDefault);
	GameManager.setFunction("onDamageApplyResultsNormal", ActionHealthD20.applyDamageResultsNormalDefault);

	GameManager.setMultiKeyFunction("onHealthApplyType", "damage", ActionHealthD20.applyDamage);
	GameManager.setMultiKeyFunction("onHealthApplyType", "heal", ActionHealthD20.applyHeal);
	GameManager.setMultiKeyFunction("onHealthApplyType", "recovery", ActionHealthD20.applyHeal);
	GameManager.setMultiKeyFunction("onHealthApplyType", "regen", ActionHealthD20.applyRegen);
	GameManager.setMultiKeyFunction("onHealthApplyType", "fheal", ActionHealthD20.applyHeal);
	GameManager.setMultiKeyFunction("onHealthApplyType", "temphp", ActionHealthD20.applyTemp);
end

--
--	APPLY HEALTH ADJUSTMENT
--

-- Standard Absorption / Immmunity / Resistance / Vulnerability
local _tDamageModEffectTags = { "ABSORB", "IMMUNE", "RESIST", "", "VULN", };
function setDamageModEffectTags(t)
	_tDamageModEffectTags = t;
end
function getDamageModEffectTags()
	return _tDamageModEffectTags;
end
function getDamageModEffectKey(s1, s2)
	if s2 == "" then
		return "IGNORE" .. s1;
	elseif s1 == "" then
		return "MAKE" .. s2;
	end
	return s1 .. "TO" .. s2;
end

function apply(rSource, rTarget, rRoll)
	GameManager.callFunction("onHealthApply", rSource, rTarget, rRoll);
end

function applyDefault(rSource, rTarget, rRoll)
	local tApplyData = {
		tNotifications = {},
		tResolver = {},
		bIgnoreEffects = (rRoll and rRoll.bIgnoreEffects),
	};

	ActionHealthD20.applyGetType(rRoll, tApplyData);
	if (tApplyData.sType or "") == "" then
		return;
	end

	ActionHealthD20.applyGetHealth(rTarget, rRoll, tApplyData);
	if not tApplyData.tHealth then
		return;
	end

	ActionHealthD20.applyDecode(rRoll, tApplyData);
	ActionHealthD20.applyGetEffects(rSource, rTarget, rRoll, tApplyData);
	ActionHealthD20.applyDisplay(rRoll, tApplyData);

	ActionHealthD20.applyMain(rSource, rTarget, rRoll, tApplyData);

	ActionHealthD20.applySetHealth(rTarget, rRoll, tApplyData);
	ActionHealthD20.applyStatusChange(rSource, rTarget, rRoll, tApplyData);
	ActionCore.applyMessage(rSource, rTarget, rRoll, tApplyData);

	ActionHealthD20.onPostApplyResolve(rSource, rTarget, rRoll, tApplyData);
end

function applyGetType(rRoll, tApplyData)
	if not rRoll then
		return;
	end
	if (rRoll.sDesc or ""):match("%[HEAL") then
		if rRoll.sDesc:match("%[TEMP%]") then
			tApplyData.sType = "temphp";
		else
			tApplyData.sType = "heal";
		end
	elseif (rRoll.sDesc or ""):match("%[FHEAL") then
		tApplyData.sType = "fheal";
	elseif (rRoll.sDesc or ""):match("%[REGEN") then
		tApplyData.sType = "regen";
	elseif (rRoll.sDesc or ""):match("%[RECOVERY") then
		tApplyData.sType = "recovery";
	elseif (rRoll.nTotal or 0) < 0 then
		rRoll.nTotal = 0 - rRoll.nTotal;
		tApplyData.sType = "heal";
	else
		tApplyData.sType = "damage";
	end

	tApplyData.bWeapon = rRoll.bWeapon;
	tApplyData.bSpell = rRoll.bSpell;
end
function applyGetHealth(rActor, rRoll, tApplyData)
	GameManager.callFunction("onHealthApplyGetHealth", rActor, rRoll, tApplyData);
end
function applyGetHealthDefault(rActor, rRoll, tApplyData)
	local nodeActor = ActorManager.getCreatureNode(rActor);
	if not nodeActor then
		return;
	end

	local tHealth = { ["hp"] = {}, };
	if GameManager.hasOption("deathsave") then
		tHealth["deathsave"] = {};
	end
	if GameManager.hasOption("healsurge") then
		tHealth["healsurge"] = {};
	end

	if rRoll and ((rRoll.sSubtargetPath or "") ~= "") then
		tHealth["hp"].nTotal = DB.getValue(DB.getPath(rRoll.sSubtargetPath, "hp"), 0);
		tHealth["hp"].nWounds = DB.getValue(DB.getPath(rRoll.sSubtargetPath, "wounds"), 0);
		tHealth["hp"].nTemp = 0;
		if GameManager.hasOption("nonlethal") then
			tHealth["hp"].nNonlethal = 0;
		end
		if GameManager.hasOption("deathsave") then
			tHealth["deathsave"].nSuccess = 0;
			tHealth["deathsave"].nFail = 0;
		end
	else
		tHealth["hp"].nTotal = GameManager.getRecordFieldValue(rActor, "hptotal", 0);
		tHealth["hp"].nTemp = GameManager.getRecordFieldValue(rActor, "hptemp", 0);
		tHealth["hp"].nWounds = GameManager.getRecordFieldValue(rActor, "wounds", 0);
		if GameManager.hasOption("nonlethal") then
			tHealth["hp"].nNonlethal = GameManager.getRecordFieldValue(rActor, "nonlethal", 0);
		end
		if GameManager.hasOption("deathsave") then
			tHealth["deathsave"].nSuccess = GameManager.getRecordFieldValue(rActor, "deathsavesuccess", 0);
			tHealth["deathsave"].nFail = GameManager.getRecordFieldValue(rActor, "deathsavefail", 0);
		end
	end

	if ActorManager.isPC(rActor) then
		if GameManager.hasOption("healsurge") then
			tHealth["healsurge"].nMax = DB.getValue(nodeActor, "hp.surgesmax", 0);
			tHealth["healsurge"].nUsed = DB.getValue(nodeActor, "hp.surgesused", 0);
			tHealth["healsurge"].nHeal = DB.getValue(nodeActor, "hp.surge", 0);
		end
	elseif ActorManager.isRecordType(rActor, "npc") then
		if GameManager.hasOption("healsurge") then
			tHealth["healsurge"].nMax = DB.getValue(nodeActor, "healsurgeremaining", 0);
			tHealth["healsurge"].nUsed = 0;
			tHealth["healsurge"].nHeal = math.floor(tHealth["hp"].nTotal / 4);
		end
	elseif ActorManager.isRecordType(rActor, "vehicle") then
		if GameManager.hasOption("healsurge") then
			tHealth["healsurge"].nMax = 0;
			tHealth["healsurge"].nUsed = 0;
			tHealth["healsurge"].nHeal = 0;
		end
	else
		return;
	end

	tHealth.sOriginalStatus = ActorHealthManager.getHealthStatus(rActor);
	tApplyData.tHealth = tHealth;
end
function applyDecode(rRoll, tApplyData)
	tApplyData.nValue = rRoll.nTotal;
	tApplyData.nAdjustedDamage = rRoll.nTotal;

	if (tApplyData.sType or "") == "damage" then
		ActionHealthD20.applyDecodeDamage(rRoll, tApplyData);
	end
end
function applyDecodeDamage(rRoll, tApplyData)
	tApplyData.bCritical = rRoll.sDesc:match("%[CRITICAL%]");

	tApplyData.tDamageTypes = {};
	for sDamageType,_,sDamageSubTotal in rRoll.sDesc:gmatch("%[TYPE: ([^(]*) %(([%w%p]+)%=(%d+)%)%]") do
		tApplyData.tDamageTypes[sDamageType] = (tonumber(sDamageSubTotal) or 0) + (tApplyData.tDamageTypes[sDamageType] or 0);
		if not tApplyData.sFirstDamageType then
			tApplyData.sFirstDamageType = sDamageType;
		end
	end

	local nDamageRemaining = tApplyData.nValue;
	for _,n in pairs(tApplyData.tDamageTypes) do
		nDamageRemaining = nDamageRemaining - n;
	end
	if nDamageRemaining > 0 then
		tApplyData.tDamageTypes[""] = (tApplyData.tDamageTypes[""] or 0) + nDamageRemaining;
	elseif nDamageRemaining < 0 then
		ChatManager.SystemMessage("Total mismatch in damage type totals");
	end
end
function applyGetEffects(rSource, rTarget, rRoll, tApplyData)
	tApplyData.tCompsData = {};
	ActionHealthD20.applyGetEffectsPrep(rSource, rTarget, rRoll, tApplyData);
	ActionHealthD20.applyGetEffectsMult(rSource, rTarget, rRoll, tApplyData);
	ActionHealthD20.applyDieAdjust(rSource, rTarget, rRoll, tApplyData);
	ActionHealthD20.applyMult(rSource, rTarget, rRoll, tApplyData);
end
-- applyGetEffectsPrep(rSource, rTarget, rRoll, tApplyData)
-- No effects for modifying regeneration or temporary hit point assignment
function applyGetEffectsPrep(_, _, rRoll, tApplyData)
	if ActionHealthD20.isHealActionType(tApplyData) then
		tApplyData.sRange = ActionHealCore.decodeRangeText(rRoll.sDesc);
		if tApplyData.sType == "recovery" then
			tApplyData.sEffectBaseTag = "HD";
		elseif (rRoll.healtype or "") ~= "nonlethal" then
			tApplyData.sEffectBaseTag = "HEAL";
		end
	elseif ActionHealthD20.isDamageActionType(tApplyData) then
		tApplyData.sEffectBaseTag = "DMG";
		tApplyData.sRange = ActionDamageCore.decodeRangeText(rRoll.sDesc);
		tApplyData.tEffectFilter = ActionCore.buildEffectFilter(tApplyData);
	elseif tApplyData.sType == "temphp" then
		tApplyData.sEffectBaseTag = "TEMP";
	end
end
function applyGetEffectsMult(rSource, rTarget, rRoll, tApplyData)
	if (tApplyData.sEffectBaseTag or "") == "" then
		return;
	end

	local sBaseTag = tApplyData.sEffectBaseTag .. "MULT";

	if rSource then
		local tData = {
			rTarget = rTarget,
			tFilter = tApplyData.tEffectFilter,
			tActionTags = rRoll.tActionTags,
		};
		tApplyData.tCompsData["MULT"] = EffectManager.getCompsDataByTag(rSource, sBaseTag, tData);
	end
	if rTarget then
		local tAtData = {
			rTarget = rSource,
			tFilter = tApplyData.tEffectFilter,
			tActionTags = rRoll.tActionTags,
		};
		tApplyData.tCompsData["@MULT"] = EffectManager.getCompsDataByTag(rTarget, "@" .. sBaseTag, tAtData);
	end
end
function applyDieAdjust(rSource, rTarget, rRoll, tApplyData)
	if (tApplyData.sEffectBaseTag or "") == "" then
		return;
	end

	local sBaseTag = tApplyData.sEffectBaseTag .. "DIE";
	local sBaseAtTag = "@" .. sBaseTag;

	if tApplyData.sType == "damage" then
		local tSrcCompsData = EffectManager.getCompsDataByTag(rSource, sBaseTag, { rTarget = rTarget, tActionTags = rRoll.tActionTags, });
		local tTrgtCompsData = EffectManager.getCompsDataByTag(rTarget, sBaseAtTag, { rTarget = rSource, tActionTags = rRoll.tActionTags, });
		if (#tSrcCompsData == 0) and (#tTrgtCompsData == 0) then
			return;
		end

		local tAdjustByType = {};
		for _,tCompData in ipairs(tSrcCompsData) do
			if tCompData.mod ~= 0 then
				local tCompDamageTypes = {};
				for _,s in ipairs(tCompData.remainder) do
					local sLower = s:lower();
					if ActionCore.isDamageType(sLower) then
						table.insert(tCompDamageTypes, sLower);
					end
				end
				if #tCompDamageTypes == 0 then
					tAdjustByType["all"] = (tAdjustByType["all"] or 0) + tCompData.mod;
				else
					for _,s in ipairs(tCompDamageTypes) do
						tAdjustByType[s] = (tAdjustByType[s] or 0) + tCompData.mod;
					end
				end
			end
		end
		for _,tCompData in ipairs(tTrgtCompsData) do
			if tCompData.mod ~= 0 then
				local tCompDamageTypes = {};
				for _,s in ipairs(tCompData.remainder) do
					local sLower = s:lower();
					if ActionCore.isDamageType(sLower) then
						table.insert(tCompDamageTypes, sLower);
					end
				end
				if #tCompDamageTypes == 0 then
					tAdjustByType["all"] = (tAdjustByType["all"] or 0) + tCompData.mod;
				else
					for _,s in ipairs(tCompDamageTypes) do
						tAdjustByType[s] = (tAdjustByType[s] or 0) + tCompData.mod;
					end
				end
			end
		end

		local bNotify = false;
		local nTotalAdjust = 0;
		local nMainDieIndex = 0;
		for _,tClause in ipairs(rRoll.clauses or {}) do
			if (#(tClause.dice or {}) > 0) then
				local nClauseAdjust = 0;
				if tAdjustByType["all"] then
					bNotify = true;
					nClauseAdjust = nClauseAdjust + tAdjustByType["all"];
				end
				for _,s in ipairs(StringManager.split(tClause.dmgtype, ",", true)) do
					if tAdjustByType[s] then
						bNotify = true;
						nClauseAdjust = nClauseAdjust + tAdjustByType[s];
					end
				end
				local nActualClauseAdjust = 0;
				for _,_ in ipairs(tClause.dice or {}) do
					nMainDieIndex = nMainDieIndex + 1;
					if nClauseAdjust ~= 0 then
						local tDie = rRoll.aDice[nMainDieIndex];
						if tDie then
							local nDieAdjust = 0;
							if nClauseAdjust > 0 then
								nDieAdjust = nClauseAdjust;
							elseif nClauseAdjust < 0 then
								local nDieValue = (tDie.value or tDie.result or 0);
								nDieAdjust = math.max(nDieValue + nClauseAdjust, 1) - nDieValue;
							end
							nActualClauseAdjust = nActualClauseAdjust + nDieAdjust;
						end
					end
				end
				tApplyData.tDamageTypes[tClause.dmgtype or ""] = (tApplyData.tDamageTypes[tClause.dmgtype or ""] or 0) + nActualClauseAdjust;
				tApplyData.nAdjustedDamage = tApplyData.nAdjustedDamage + nActualClauseAdjust;
				nTotalAdjust = nTotalAdjust + nActualClauseAdjust;
			end
		end
		if bNotify then
			table.insert(tApplyData.tNotifications, string.format("[%s: %+d]", sBaseTag, nTotalAdjust));
		end

	elseif tApplyData.sType == "heal" then
		local nSourceMod, nSourceEffects = EffectManager.getBonusMod(rSource, sBaseTag, { rTarget = rTarget, tActionTags = rRoll.tActionTags, });
		local nTargetMod, nTargetEffects = EffectManager.getBonusMod(rTarget, sBaseAtTag, { rTarget = rSource, tActionTags = rRoll.tActionTags, });
		if (nSourceEffects == 0) and (nTargetEffects == 0) then
			return;
		end

		local nTotalAdjust = 0;
		local nEffectMod = nSourceMod + nTargetMod;

		if nEffectMod ~= 0 then
			local nMainDieIndex = 0;
			for _,tClause in ipairs(rRoll.clauses or {}) do
				if (#(tClause.dice or {}) > 0) then
					local nClauseAdjust = 0;
					for _,_ in ipairs(tClause.dice or {}) do
						nMainDieIndex = nMainDieIndex + 1;
						local tDie = rRoll.aDice[nMainDieIndex];
						if tDie then
							local nDieAdjust = 0;
							if nEffectMod > 0 then
								nDieAdjust = nEffectMod;
							elseif nEffectMod < 0 then
								local nDieValue = (tDie.value or tDie.result or 0);
								nDieAdjust = math.max(nDieValue + nEffectMod, 1) - nDieValue;
							end
							nClauseAdjust = nClauseAdjust + nDieAdjust;
						end
					end
					tApplyData.tDamageTypes = tApplyData.tDamageTypes or {};
					tApplyData.tDamageTypes[tClause.dmgtype or ""] = (tApplyData.tDamageTypes[tClause.dmgtype or ""] or 0) + nClauseAdjust;
					tApplyData.nAdjustedDamage = tApplyData.nAdjustedDamage + nClauseAdjust;
					nTotalAdjust = nTotalAdjust + nClauseAdjust;
				end
			end
		end
		table.insert(tApplyData.tNotifications, string.format("[%s: %+d]", sBaseTag, nTotalAdjust));
	else
		local nSourceMod, nSourceEffects = EffectManager.getBonusMod(rSource, sBaseTag, { rTarget = rTarget, tActionTags = rRoll.tActionTags, });
		local nTargetMod, nTargetEffects = EffectManager.getBonusMod(rTarget, sBaseAtTag, { rTarget = rSource, tActionTags = rRoll.tActionTags, });
		if (nSourceEffects == 0) and (nTargetEffects == 0) then
			return;
		end

		local nTotalAdjust = 0;
		local nEffectMod = nSourceMod + nTargetMod;

		if nEffectMod ~= 0 then
			for _,tDie in ipairs(rRoll.aDice or {}) do
				local nDieAdjust = 0;
				if nEffectMod > 0 then
					nDieAdjust = nEffectMod;
				elseif nEffectMod < 0 then
					local nDieValue = (tDie.value or tDie.result or 0);
					nDieAdjust = math.max(nDieValue + nEffectMod, 1) - nDieValue;
				end
				tApplyData.nAdjustedDamage = tApplyData.nAdjustedDamage + nDieAdjust;
				nTotalAdjust = nTotalAdjust + nDieAdjust;
			end
		end
		table.insert(tApplyData.tNotifications, string.format("[%s: %+d]", sBaseTag, nTotalAdjust));
	end
end
-- applyMult(rSource, rTarget, rRoll, tApplyData)
function applyMult(_, _, rRoll, tApplyData)
	ActionCore.applyRollEffectCompsMult(rRoll, tApplyData.tCompsData["MULT"] or {}, tApplyData.sType);
	ActionCore.applyRollEffectCompsMult(rRoll, tApplyData.tCompsData["@MULT"] or {}, tApplyData.sType);

	if ActionHealthD20.isHealActionType(tApplyData) then
		if (rRoll.nMult or 1) < 0 then
			rRoll.sType = "damage";
			rRoll.sDesc = string.format("%s %s", string.gsub(rRoll.sDesc, "%[HEAL[^]]*%]", "[DAMAGE]"), "[CONVERTED]");
			tApplyData.sType = "damage";
			rRoll.nMult = rRoll.nMult * -1;
		end
	elseif ActionHealthD20.isDamageActionType(tApplyData) then
		if (rRoll.nMult or 1) < 0 then
			rRoll.sType = "heal";
			rRoll.sDesc = string.format("%s %s", string.gsub(string.gsub(rRoll.sDesc, "%[DAMAGE[^]]*%]", "[HEAL]"), " %[TYPE:[^]]*%]", ""), "[CONVERTED]");
			tApplyData.sType = "heal";
			rRoll.nMult = rRoll.nMult * -1;
		end
	end
end

-- applyDisplay(rRoll, tApplyData)
function applyDisplay(_, tApplyData)
	if tApplyData.sType == "heal" then
		tApplyData.sResultText = "Heal";
		tApplyData.sResultIcon = "action_heal";
	elseif tApplyData.sType == "temphp" then
		tApplyData.sResultText = "Temporary hit points";
		tApplyData.sResultIcon = "action_heal";
	elseif tApplyData.sType == "fheal" then
		tApplyData.sResultText = "Fast healing";
		tApplyData.sResultIcon = "action_heal";
	elseif tApplyData.sType == "regen" then
		tApplyData.sResultText = "Regeneration";
		tApplyData.sResultIcon = "action_heal";
	elseif tApplyData.sType == "recovery" then
		tApplyData.sResultText = "Recovery";
		tApplyData.sResultIcon = "action_heal";
	else
		tApplyData.sResultText = "Damage";
		tApplyData.sResultIcon = "action_damage";
	end
end

function applyMain(rSource, rTarget, rRoll, tApplyData)
	GameManager.callMultiKeyFunction("onHealthApplyType", tApplyData.sType, rSource, rTarget, rRoll, tApplyData);
end

function applyHeal(rSource, rTarget, rRoll, tApplyData)
	if not ActionHealthD20.applyHealPreCheck(rSource, rTarget, rRoll, tApplyData) then
		return false;
	end
	if not ActionHealthD20.applyHealCheckCost(rSource, rTarget, rRoll, tApplyData) then
		return false;
	end
	ActionHealthD20.applyHealTargetedEffects(rSource, rTarget, rRoll, tApplyData);
	ActionHealthD20.applyHealSurgeValue(rSource, rTarget, rRoll, tApplyData);
	ActionHealthD20.applyHealMult(rSource, rTarget, rRoll, tApplyData);
	ActionHealthD20.applyHealResults(rSource, rTarget, rRoll, tApplyData);
	ActionHealthD20.applyHealCost(rSource, rTarget, rRoll, tApplyData);
	ActionHealthD20.applyHealEnd(rSource, rTarget, rRoll, tApplyData);
	return true;
end
-- applyHealPreCheck(rSource, rTarget, rRoll, tApplyData)
function applyHealPreCheck(_, rTarget, rRoll, tApplyData)
	if rRoll.sDesc:match("%[CONVERTED%]") then
		table.insert(tApplyData.tNotifications, string.format("[%s]", Interface.getString("action_tag_damagetoheal")));
	end

	-- Check if wounded
	if tApplyData.tHealth["hp"].nWounds <= 0 and (not GameManager.hasOption("nonlethal") or (tApplyData.tHealth["hp"].nNonlethal <= 0)) then
		rRoll.tResults = { [""] = { nTotal = 0, nBase = tApplyData.nAdjustedDamage, nOver = tApplyData.nAdjustedDamage, }, };
		table.insert(tApplyData.tNotifications, "[NOT WOUNDED]");
		return false;
	end

	-- Check if target can heal
	local sSubType = StringManager.contains({ "heal", "fheal", }, tApplyData.sType) and "heal" or "hitdice";
	if not ActorManager.canHeal(rTarget, sSubType) then
		rRoll.tResults = { [""] = { nTotal = 0, nBase = tApplyData.nAdjustedDamage, nOver = tApplyData.nAdjustedDamage, }, };
		table.insert(tApplyData.tNotifications, "[NOHEAL]");
		return false;
	end

	return true;
end
-- applyHealCheckCost(rSource, rTarget, rRoll, tApplyData)
function applyHealCheckCost(_, _, rRoll, tApplyData)
	if not GameManager.hasOption("healsurge") then
		return true;
	end
	if (rRoll.nHealCost or 0) < 0 then
		if tApplyData.tHealth["healsurge"].nUsed == 0 then
			local nNewSurges = rRoll.nHealCost + tApplyData.tHealth["healsurge"].nUsed;
			table.insert(tApplyData.tNotifications, "[ALREADY AT MAX HEAL SURGES (+" .. (0 - nNewSurges) .. ")]");
			return false;
		end
	elseif (rRoll.nHealCost or 0) > 0 then
		local nSurgesAvailable = math.max(tApplyData.tHealth["healsurge"].nMax - tApplyData.tHealth["healsurge"].nUsed, 0);
		if rRoll.nHealCost > nSurgesAvailable then
			table.insert(tApplyData.tNotifications, "[INSUFFICIENT HEAL SURGES (-" .. (rRoll.nHealCost - nSurgesAvailable) .. ")]");
			return false;
		end
	end
	return true;
end
function applyHealTargetedEffects(rSource, rTarget, rRoll, tApplyData)
	if rSource and rTarget and rTarget.nOrder then
		ActionHealthD20.applyHealTargetedEffectsMain(rSource, rTarget, rRoll, tApplyData);
	end
end
function applyHealTargetedEffectsMain(rSource, rTarget, rRoll, tApplyData)
	if (tApplyData.sEffectBaseTag or "") == "" then
		return;
	end

	tApplyData.nTargetedEffectCount = 0;
	tApplyData.nTargetedEffectTotal = 0;

	ActionHealthD20.applyHealTargetedEffectsTag(rSource, rTarget, rRoll, tApplyData, tApplyData.sEffectBaseTag);
	for _,sEffectTag in ipairs(rRoll.tEffectTags or {}) do
		ActionHealthD20.applyHealTargetedEffectsTag(rSource, rTarget, rRoll, tApplyData, sEffectTag);
	end

	if tApplyData.nTargetedEffectCount > 0 then
		table.insert(tApplyData.tNotifications, EffectManager.buildEffectOutput(tApplyData.nTargetedEffectTotal));
	end
	tApplyData.nAdjustedDamage = tApplyData.nAdjustedDamage + tApplyData.nTargetedEffectTotal;

	tApplyData.nTargetedEffectCount = nil;
	tApplyData.nTargetedEffectTotal = nil;
end
function applyHealTargetedEffectsTag(rSource, rTarget, rRoll, tApplyData, sEffectTag)
	if (sEffectTag or "") == "" then
		return;
	end

	-- NOTE: Dice determined randomly, instead of rolled
	local tData = { rTarget = rTarget, bTargetedOnly = true, tFilter = tApplyData.tEffectFilter, tActionTags = rRoll.tActionTags, };
	local tDice, nMod, nEffects = EffectManager.getBonusDiceMod(rSource, sEffectTag, tData);
	tApplyData.nTargetedEffectCount = tApplyData.nTargetedEffectCount + nEffects;
	tApplyData.nTargetedEffectTotal = tApplyData.nTargetedEffectTotal + StringManager.evalDice(tDice, nMod);

	local tAtData = { rTarget = rSource, tFilter = tApplyData.tEffectFilter, tActionTags = rRoll.tActionTags, };
	tDice, nMod, nEffects = EffectManager.getBonusDiceMod(rTarget, "@" .. sEffectTag, tAtData);
	tApplyData.nTargetedEffectCount = tApplyData.nTargetedEffectCount + nEffects;
	tApplyData.nTargetedEffectTotal = tApplyData.nTargetedEffectTotal + StringManager.evalDice(tDice, nMod);
end
-- applyHealSurgeValue(rSource, rTarget, rRoll, tApplyData)
function applyHealSurgeValue(_, _, rRoll, tApplyData)
	if not GameManager.hasOption("healsurge") then
		return true;
	end
	if (rRoll.nHSMult or 0) ~= 0 then
		local nHSAdj = math.floor(tApplyData.tHealth["healsurge"].nHeal * rRoll.nHSMult * (rRoll.nMult or 1));
		rRoll.nTotal = rRoll.nTotal + nHSAdj;
		tApplyData.nAdjustedDamage = tApplyData.nAdjustedDamage + nHSAdj;
	end
end
-- applyHealMult(rSource, rTarget, rRoll, tApplyData)
function applyHealMult(_, _, rRoll, tApplyData)
	if rRoll.bModDouble or rRoll.sDesc:match("%[DOUBLE%]") then
		rRoll.nMult = (rRoll.nMult or 1) * 2;
	end
	if rRoll.bModHalf or rRoll.sDesc:match("%[HALF%]") then
		rRoll.nMult = (rRoll.nMult or 1) * 0.5;
	end

	if ((rRoll.nMult or 1) == 1) or (rRoll.nMult < 0) then
		return;
	end

	if rRoll.nMult % 1 == 0 then
		table.insert(tApplyData.tNotifications, string.format("[MULT: %d]", rRoll.nMult));
	else
		table.insert(tApplyData.tNotifications, string.format("[MULT: %.2f]", rRoll.nMult));
	end

	rRoll.nTotal = math.floor(rRoll.nTotal * rRoll.nMult);
	tApplyData.nAdjustedDamage = math.floor(tApplyData.nAdjustedDamage * rRoll.nMult);
end
function applyHealResults(_, rTarget, rRoll, tApplyData)
	local nHealAmount = tApplyData.nAdjustedDamage;

	if GameManager.hasOption("nonlethal") then
		local nNonlethalHealAmount = math.min(nHealAmount, tApplyData.tHealth["hp"].nNonlethal);
		tApplyData.tHealth["hp"].nNonlethal = tApplyData.tHealth["hp"].nNonlethal - nNonlethalHealAmount;
		if GameManager.isOption("nonlethal", "3.5E") and (tApplyData.sType == "fheal") then
			nHealAmount = nHealAmount - nNonlethalHealAmount;
		end
		rRoll.tResults = { ["nonlethal"] = { nTotal = nNonlethalHealAmount, nBase = nNonlethalHealAmount, }, };
	end

	-- If healing from zero (or negative), then remove Stable effect and reset wounds to match HP
	if not GameManager.hasOption("negativehp") and (nHealAmount > 0) and (tApplyData.tHealth["hp"].nWounds >= tApplyData.tHealth["hp"].nTotal) then
		EffectManager.removeCondition(rTarget, "Stable");
		tApplyData.tHealth["hp"].nWounds = tApplyData.tHealth["hp"].nTotal;
	end

	local nWoundHealAmount = math.min(nHealAmount, tApplyData.tHealth["hp"].nWounds);
	tApplyData.tHealth["hp"].nWounds = tApplyData.tHealth["hp"].nWounds - nWoundHealAmount;

	tApplyData.nAdjustedDamage = nWoundHealAmount;
	rRoll.nOverflow = nHealAmount - nWoundHealAmount;
	rRoll.tResults = { [""] = { nTotal = nWoundHealAmount, nBase = nHealAmount, nOver = rRoll.nOverflow, }, };
end
-- applyHealCost(rSource, rTarget, rRoll, tApplyData)
function applyHealCost(_, _, rRoll, tApplyData)
	if not GameManager.hasOption("healsurge") then
		return;
	end
	tApplyData.tHealth["healsurge"].nUsed = math.max(math.min(tApplyData.tHealth["healsurge"].nUsed + (rRoll.nHealCost or 0), tApplyData.tHealth["healsurge"].nMax), 0);
end
function applyHealEnd(_, _, rRoll, tApplyData)
	if (rRoll.nOverflow or 0) > 0 then
		table.insert(tApplyData.tNotifications, "[HEAL EXCEEDS WOUNDS BY " .. rRoll.nOverflow.. "]");
	end
	tApplyData.nValue = (tApplyData.nAdjustedDamage or 0);
end

function applyRegen(rSource, rTarget, rRoll, tApplyData)
	if GameManager.isOption("regeneration", "3.5E") then
		if tApplyData.tHealth["hp"].nNonlethal <= 0 then
			table.insert(tApplyData.tNotifications, "[NO NONLETHAL DAMAGE]");
			return false;
		end

		local nNonlethalHealAmount = math.min(tApplyData.nAdjustedDamage, tApplyData.tHealth["hp"].nNonlethal);
		tApplyData.tHealth["hp"].nNonlethal = tApplyData.tHealth["hp"].nNonlethal - nNonlethalHealAmount;
		rRoll.tResults = { ["nonlethal"] = { nTotal = nNonlethalHealAmount, nBase = nNonlethalHealAmount, }, };
		return true;
	end

	ActionHealthD20.applyHeal(rSource, rTarget, rRoll, tApplyData);
end

function applyTemp(rSource, rTarget, rRoll, tApplyData)
	if not ActionHealthD20.applyHealCheckCost(rSource, rTarget, rRoll, tApplyData) then
		return false;
	end
	ActionHealthD20.applyHealSurgeValue(rSource, rTarget, rRoll, tApplyData);
	ActionHealthD20.applyHealMult(rSource, rTarget, rRoll, tApplyData);
	ActionHealthD20.applyTempResults(rSource, rTarget, rRoll, tApplyData);
	ActionHealthD20.applyHealCost(rSource, rTarget, rRoll, tApplyData);
	ActionHealthD20.applyTempEnd(rSource, rTarget, rRoll, tApplyData);
	return true;
end
-- applyTempResults(rSource, rTarget, rRoll, tApplyData)
function applyTempResults(_, _, rRoll, tApplyData)
	local nTempHPAdjust = math.max(0, tApplyData.nAdjustedDamage - tApplyData.tHealth["hp"].nTemp);
	tApplyData.tHealth["hp"].nTemp = tApplyData.tHealth["hp"].nTemp + nTempHPAdjust;
	tApplyData.nAdjustedDamage = nTempHPAdjust;
	rRoll.tResults = { [""] = { nTotal = nTempHPAdjust, nBase = tApplyData.nAdjustedDamage, nOver = 0, }, };
end
-- applyTempEnd(rSource, rTarget, rRoll, tApplyData)
function applyTempEnd(_, _, _, tApplyData)
	tApplyData.nValue = (tApplyData.nAdjustedDamage or 0);
end

function applyDamage(rSource, rTarget, rRoll, tApplyData)
	-- Apply any targeted damage effects
	ActionHealthD20.applyDamageTargetedEffects(rSource, rTarget, rRoll, tApplyData);

	-- Prepare damage adjustment
	ActionHealthD20.applyDamageStart(rSource, rTarget, rRoll, tApplyData);

	-- Handle avoidance/evasion and half damage
	ActionHealthD20.applyDamageEvasion(rSource, rTarget, rRoll, tApplyData);

	-- Handle damage multiplication
	ActionHealthD20.applyDamageMult(rSource, rTarget, rRoll, tApplyData);

	-- Apply damage type adjustments
	ActionHealthD20.applyDamageAdjust(rSource, rTarget, rRoll, tApplyData);

	-- Apply damage results
	ActionHealthD20.applyDamageResults(rSource, rTarget, rRoll, tApplyData);

	ActionHealthD20.applyDamageEnd(rSource, rTarget, rRoll, tApplyData);

	return true;
end
-- applyDamageStart(rSource, rTarget, rRoll, tApplyData)
function applyDamageStart(_, _, rRoll, tApplyData)
	if rRoll.sDesc:match("%[CONVERTED%]") then
		table.insert(tApplyData.tNotifications, string.format("[%s]", Interface.getString("action_tag_healtodamage")));
	end
end
function applyDamageTargetedEffects(rSource, rTarget, rRoll, tApplyData)
	if rSource and rTarget and rTarget.nOrder then
		ActionHealthD20.applyDamageTargetedEffectsMain(rSource, rTarget, rRoll, tApplyData);
		ActionHealthD20.applyDamageTargetedEffectsType(rSource, rTarget, rRoll, tApplyData);
	end
end
function applyDamageTargetedEffectsMain(rSource, rTarget, rRoll, tApplyData)
	if (tApplyData.sEffectBaseTag or "") == "" then
		return;
	end

	tApplyData.nTargetedEffectCount = 0;
	tApplyData.nTargetedEffectTotal = 0;

	ActionHealthD20.applyDamageTargetedEffectsTag(rSource, rTarget, rRoll, tApplyData, tApplyData.sEffectBaseTag);
	for _,sEffectTag in ipairs(rRoll.tEffectTags or {}) do
		ActionHealthD20.applyDamageTargetedEffectsTag(rSource, rTarget, rRoll, tApplyData, sEffectTag);
	end

	if tApplyData.nTargetedEffectCount > 0 then
		table.insert(tApplyData.tNotifications, EffectManager.buildEffectOutput(tApplyData.nTargetedEffectTotal));
	end
	tApplyData.nAdjustedDamage = tApplyData.nAdjustedDamage + tApplyData.nTargetedEffectTotal;
	tApplyData.nTargetedEffectCount = nil;
	tApplyData.nTargetedEffectTotal = nil;
end
function applyDamageTargetedEffectsTag(rSource, rTarget, rRoll, tApplyData, sEffectTag)
	if (sEffectTag or "") == "" then
		return;
	end

	-- NOTE: Dice determined randomly, instead of rolled
	local tData = { rTarget = rTarget, bTargetedOnly = true, tFilter = tApplyData.tEffectFilter, tActionTags = rRoll.tActionTags, };
	local tBonusData = EffectManager.getBonusData(rSource, sEffectTag, tData);
	ActionHealthD20.applyDamageTargetedEffectsMainHelper(rRoll, tApplyData, tBonusData)

	local tAtData = { rTarget = rSource, tFilter = tApplyData.tEffectFilter, tActionTags = rRoll.tActionTags, };
	local tBonusDataAt = EffectManager.getBonusData(rTarget, "@" .. sEffectTag, tAtData);
	ActionHealthD20.applyDamageTargetedEffectsMainHelper(rRoll, tApplyData, tBonusDataAt)
end
function applyDamageTargetedEffectsMainHelper(rRoll, tApplyData, tBonusData)
	for k, v in pairs(tBonusData) do
		local bValid = (tApplyData.bCritical or
				not SetManager.overlaps(StringManager.split(k, ",", true), ActionCore.getCriticalDamageTypes()));

		if bValid then
			local nMult = 1;
			if tApplyData.bCritical and GameManager.hasOption("critmult") then
				nMult = rRoll.clauses[1] and rRoll.clauses[1].mult or 2;
			end
			local nSubTotal = StringManager.evalDice(v.dice, (nMult * v.mod));

			local tNewKey = SetManager.new(tApplyData.sFirstDamageType);
			SetManager.add(tNewKey, k);
			local sDamageType = SetManager.concat(tNewKey, ",");
			tApplyData.tDamageTypes = tApplyData.tDamageTypes or {};
			tApplyData.tDamageTypes[sDamageType] = (tApplyData.tDamageTypes[sDamageType] or 0) + nSubTotal;

			tApplyData.nTargetedEffectTotal = tApplyData.nTargetedEffectTotal + nSubTotal;
			tApplyData.nTargetedEffectCount = tApplyData.nTargetedEffectCount + 1;
		end
	end
end
function applyDamageTargetedEffectsType(rSource, rTarget, rRoll, tApplyData)
	local tData = { rTarget = rTarget, bTargetedOnly = true, tFilter = tApplyData.tEffectFilter, tActionTags = rRoll.tActionTags, };
	local tAddTypes = EffectManagerD20.getDamageTypeDescriptors(rSource, "DMGTYPE", tData);
	if #tAddTypes <= 0 then
		return;
	end

	local tNewDmgTypes = {};
	for k,v in pairs(tApplyData.tDamageTypes or {}) do
		tNewDmgTypes[StringManager.appendUnique(k, tAddTypes)] = v;
	end
	tApplyData.tDamageTypes = tNewDmgTypes;

	tApplyData.sFirstDamageType = StringManager.appendUnique(tApplyData.sFirstDamageType, tAddTypes);

	table.insert(tApplyData.tNotifications, EffectManager.buildEffectOutput(SetManager.concat(tAddTypes)));
end
function applyDamageEvasion(rSource, rTarget, rRoll, tApplyData)
	local sAttack = ActionDamageCore.decodeLabelText(rRoll.sDesc);
	if (sAttack or "") == "" then
		return;
	end

	local sDamageState = ActionDamageCore.getDamageState(rSource, rTarget, StringManager.trim(sAttack));
	if sDamageState == "none" then
		tApplyData.bEvasionFull = true;
		tApplyData.bRemoveTarget = rRoll.bRemoveOnMiss;
		table.insert(tApplyData.tNotifications, "[EVADED]");
	elseif sDamageState == "half_success" then
		tApplyData.bEvasionHalf = true;
		tApplyData.bRemoveTarget = rRoll.bRemoveOnMiss;
		table.insert(tApplyData.tNotifications, "[HALF ON SAVE]");
	elseif sDamageState == "half_failure" then
		tApplyData.bEvasionHalf = true;
		table.insert(tApplyData.tNotifications, "[HALF ON FAIL]");
	elseif sDamageState == "half_miss" then
		tApplyData.bMissHalf = true;
		table.insert(tApplyData.tNotifications, "[HALF ON MISS]");
	end

	if tApplyData.bEvasionFull then
		for kType,_ in pairs(tApplyData.tDamageTypes or {}) do
			tApplyData.tDamageTypes[kType] = 0;
		end
		tApplyData.nAdjustedDamage = 0;
	end
end
-- applyDamageMult(rSource, rTarget, rRoll, tApplyData)
function applyDamageMult(rSource, _, rRoll, tApplyData)
	if rRoll.bModDouble or rRoll.sDesc:match("%[DOUBLE%]") then
		rRoll.nMult = (rRoll.nMult or 1) * 2;
	end
	if rRoll.bModHalf or rRoll.sDesc:match("%[HALF%]") then
		rRoll.nMult = (rRoll.nMult or 1) * 0.5;
	end
	if GameManager.hasOption("dmghalfonweakened") and EffectManager.hasCondition(rSource, "Weakened") then
		rRoll.bEffects = true;
		rRoll.nMult = (rRoll.nMult or 1) * 0.5;
		table.insert(tApplyData.tNotifications, "[WEAKENED]");
	end
	if tApplyData.bEvasionHalf or tApplyData.bMissHalf then
		rRoll.nMult = (rRoll.nMult or 1) * 0.5;
	end

	if ((rRoll.nMult or 1) == 1) or (rRoll.nMult < 0) then
		return;
	end

	if rRoll.nMult % 1 == 0 then
		table.insert(tApplyData.tNotifications, string.format("[MULT: %d]", rRoll.nMult));
	else
		table.insert(tApplyData.tNotifications, string.format("[MULT: %.2f]", rRoll.nMult));
	end
	rRoll.nTotal = math.max(math.floor(rRoll.nTotal * rRoll.nMult), 1);
	tApplyData.nAdjustedDamage = math.max(math.floor(tApplyData.nAdjustedDamage * rRoll.nMult), 1);

	local nCarry = 0;
	for kType, nType in pairs(tApplyData.tDamageTypes or {}) do
		local nAdjusted = nType * rRoll.nMult;
		nCarry = nCarry + nAdjusted % 1;
		if nCarry >= 1 then
			nAdjusted = nAdjusted + 1;
			nCarry = nCarry - 1;
		end
		tApplyData.tDamageTypes[kType] = math.floor(nAdjusted);
	end
end
function applyDamageAdjust(rSource, rTarget, rRoll, tApplyData)
	ActionHealthD20.applyDamageAdjustPrep(rSource, rTarget, rRoll, tApplyData);

	ActionHealthD20.applyDamageAdjustResolveEffects(tApplyData);
	ActionHealthD20.applyDamageAdjustResolveEffectMods(tApplyData);

	ActionHealthD20.applyDamageAdjustBuildResults(rRoll, tApplyData);

	ActionHealthD20.applyDamageAdjustRegen(rSource, rTarget, rRoll, tApplyData);
	ActionHealthD20.applyDamageAdjustReductionEffects(rSource, rTarget, rRoll, tApplyData);

	if not ActionHealthD20.applyDamageAdjustCheckDT(rSource, rTarget, rRoll, tApplyData) then
		return;
	end

	ActionHealthD20.applyDamageAdjustMain(rSource, rTarget, rRoll, tApplyData);

	ActionHealthD20.applyDamageAdjustHardnessReduction(rSource, rTarget, rRoll, tApplyData);
	ActionHealthD20.applyDamageAdjustWardReduction(rSource, rTarget, rRoll, tApplyData);

	ActionHealthD20.applyDamageAdjustCheckMT(rSource, rTarget, rRoll, tApplyData);
end
function applyDamageAdjustPrep(rSource, rTarget, rRoll, tApplyData)
	ActionHealthD20.applyDamageAdjustPrepBuildFilters(rSource, rTarget, rRoll, tApplyData);
	ActionHealthD20.applyDamageAdjustPrepGetEffects(rSource, rTarget, rRoll, tApplyData);

	ActionHealthD20.applyDamageAdjustPrepIncorporeal(rSource, rTarget, rRoll, tApplyData);
	ActionHealthD20.applyDamageAdjustPrepFortification(rSource, rTarget, rRoll, tApplyData);
end
-- applyDamageAdjustPrepBuildFilters(rSource, rTarget, rRoll, tApplyData)
function applyDamageAdjustPrepBuildFilters(_, _, _, tApplyData)
	-- Calculate damage types in damage roll
	local setDamageTypes = SetManager.new({ "all", });
	for k,v in pairs(tApplyData.tDamageTypes or {}) do
		if v > 0 then
			SetManager.add(setDamageTypes, StringManager.split(k, ",", true));
		end
	end
	tApplyData.tDamageTypeList = setDamageTypes:toarray();
end
function applyDamageAdjustPrepGetEffects(rSource, rTarget, rRoll, tApplyData)
	if tApplyData.bIgnoreEffects then
		return;
	end

	if GameManager.hasOption("dmgdr") then
		tApplyData.tCompsData["DR"] = EffectManager.getCompsDataByTag(rTarget, "DR", { rTarget = rSource, tActionTags = rRoll.tActionTags, });
	end

	local tEffData = { rTarget = rTarget, bFilterAllDesc = true, tFilter = tApplyData.tDamageTypeList, };
	for k, sEffectTag in ipairs(ActionHealthD20.getDamageModEffectTags()) do
		if sEffectTag ~= "" then
			-- Standard Absorption / Immmunity / Resistance / Vulnerability
			tApplyData.tCompsData[sEffectTag] = ActorCommonManager.getEffectsDamageAdjust(sEffectTag, rTarget, rSource, rRoll, tApplyData);
		end

		-- Downgrades
		for k2, s2 in ipairs(ActionHealthD20.getDamageModEffectTags()) do
			if k < k2 then
				local sKey = ActionHealthD20.getDamageModEffectKey(sEffectTag, s2);
				tApplyData.tCompsData[sKey] = EffectManager.getCompsDataByTag(rSource, sKey, tEffData);
			end
		end

		-- Upgrades
		for k2, s2 in ipairs(ActionHealthD20.getDamageModEffectTags()) do
			if k > k2 then
				local sKey = ActionHealthD20.getDamageModEffectKey(sEffectTag, s2);
				tApplyData.tCompsData[sKey] = EffectManager.getCompsDataByTag(rSource, sKey, tEffData);
			end
		end
	end
end
-- applyDamageAdjustPrepIncorporeal(rSource, rTarget, rRoll, tApplyData)
function applyDamageAdjustPrepIncorporeal(_, rTarget, rRoll, tApplyData)
	if tApplyData.bIgnoreEffects then
		return;
	end

	if GameManager.isOption("incorporeal", "PF") then
		tApplyData.bApplyIncorporeal = EffectManager.hasCondition(rTarget, "Incorporeal") and not rRoll.sDesc:match("%[INCORPOREAL%]");
		if tApplyData.bApplyIncorporeal and StringManager.contains(tApplyData.tDamageTypeList, "ghost touch") then
			tApplyData.bApplyIncorporeal = false;
		end
		if tApplyData.bApplyIncorporeal then
			table.insert(tApplyData.tCompsData["IMMUNE"], { type = "IMMUNE", dice = {}, mod = 0, remainder = { "critical", }, original = "IMMUNE: critical", });
		end
	elseif GameManager.isOption("incorporeal", { "3.5E", "2E", }) then
		tApplyData.bApplyIncorporeal = EffectManager.hasCondition(rTarget, "Incorporeal") and not rRoll.sDesc:match("%[INCORPOREAL%]");
		if tApplyData.bApplyIncorporeal and SetManager.contains(tApplyData.tDamageTypeList, "ghost touch") then
			tApplyData.bApplyIncorporeal = false;
		end
	end
end
-- applyDamageAdjustPrepFortification(rSource, rTarget, rRoll, tApplyData)
function applyDamageAdjustPrepFortification(_, _, rRoll, tApplyData)
	if tApplyData.bIgnoreEffects then
		return;
	end

	if GameManager.hasOption("dmgfortification") then
		if rRoll.bFortification then
			table.insert(tApplyData.tCompsData["IMMUNE"], { type = "IMMUNE", dice = {}, mod = 0, remainder = { "critical", }, original = "IMMUNE: critical", });
			table.insert(tApplyData.tCompsData["IMMUNE"], { type = "IMMUNE", dice = {}, mod = 0, remainder = { "precision", }, original = "IMMUNE: precision", });
			table.insert(tApplyData.tNotifications, "[FORTIFICATION IMMUNITY]");
		end
	end
end
function applyDamageAdjustResolveEffects(tApplyData)
	if tApplyData.bIgnoreEffects then
		return;
	end

	tApplyData.tResolver = {};
	for _, sEffectTag in ipairs(ActionHealthD20.getDamageModEffectTags()) do
		if sEffectTag ~= "" then
			tApplyData.tResolver[sEffectTag] = {};
			for _,tCompData in pairs(tApplyData.tCompsData[sEffectTag] or {}) do
				ActionHealthD20.applyDamageAdjustResolveEffect(tApplyData.tResolver[sEffectTag], tCompData);
			end
		end
	end
end
function applyDamageAdjustResolveEffect(tResolver, tCompData)
	if not tResolver or not tCompData then
		return;
	end

	local tData = {
		nMod = DiceManager.evalDice(tCompData.dice, tCompData.mod),
		tNegatives = {},
	};
	for _,s in ipairs(tCompData.remainder) do
		if StringManager.startsWith(s, "!") then
			local sLower = s:sub(2):lower();
			if ActionCore.isDamageType(sLower) then
				table.insert(tData.tNegatives, sLower);
			end
		end
	end

	for _,s in ipairs(tCompData.remainder) do
		if (s ~= "") and not StringManager.startsWith(s, "!") then
			local sLower = s:lower();
			if ActionCore.isDamageType(sLower) or (sLower == "all") then
				tResolver[sLower] = tResolver[sLower] or {};
				if (tData.nMod or 0) == 0 then
					tResolver[sLower].tBasic = tResolver[sLower].tBasic or {};
					table.insert(tResolver[sLower].tBasic, tData);
				else
					tResolver[sLower].tNumeric = tResolver[sLower].tNumeric or {};
					table.insert(tResolver[sLower].tNumeric, tData);
				end
			end
		end
	end
end
function applyDamageAdjustResolveEffectMods(tApplyData)
	if tApplyData.bIgnoreEffects then
		return;
	end

	for k, sEffectTag in ipairs(ActionHealthD20.getDamageModEffectTags()) do
		-- Downgrades
		for k2, s2 in ipairs(ActionHealthD20.getDamageModEffectTags()) do
			if k < k2 then
				local sKey = ActionHealthD20.getDamageModEffectKey(sEffectTag, s2);
				for _, tCompData in ipairs(tApplyData.tCompsData[sKey] or {}) do
					ActionHealthD20.applyDamageAdjustResolveEffectMod(tApplyData, tCompData, sEffectTag, s2);
				end
			end
		end

		-- Upgrades
		for k2, s2 in ipairs(ActionHealthD20.getDamageModEffectTags()) do
			if k > k2 then
				local sKey = ActionHealthD20.getDamageModEffectKey(sEffectTag, s2);
				for _, tCompData in ipairs(tApplyData.tCompsData[sKey] or {}) do
					ActionHealthD20.applyDamageAdjustResolveEffectMod(tApplyData, tCompData, sEffectTag, s2);
				end
			end
		end
	end
end
function applyDamageAdjustResolveEffectMod(tApplyData, tCompData, sEffectTagSource, sEffectTagTarget)
	if StringManager.contains(tCompData.remainder, "all") then
		ActionHealthD20.applyDamageAdjustResolveEffectModToResolver(tApplyData, "all", sEffectTagSource, sEffectTagTarget);
		for _, s in ipairs(ActionCore.getDamageTypes()) do
			ActionHealthD20.applyDamageAdjustResolveEffectModToResolver(tApplyData, s, sEffectTagSource, sEffectTagTarget);
		end
	else
		for _,s in ipairs(tCompData.remainder) do
			local sLower = s:lower();
			if ActionCore.isDamageType(sLower) then
				ActionHealthD20.applyDamageAdjustResolveEffectModToResolver(tApplyData, sLower, sEffectTagSource, sEffectTagTarget);
			end
		end
	end
end
function applyDamageAdjustResolveEffectModToResolver(tApplyData, sDamage, sEffectTagSource, sEffectTagTarget)
	if sEffectTagSource ~= "" then
		local tSource = tApplyData.tResolver[sEffectTagSource] and tApplyData.tResolver[sEffectTagSource][sDamage];
		if tSource then
			local tTarget = tApplyData.tResolver[sEffectTagTarget] and tApplyData.tResolver[sEffectTagTarget][sDamage];
			if tTarget then
				for _,v in ipairs(tSource.tBasic) do
					table.insert(tTarget.tBasic, v);
				end
				for _,v in ipairs(tSource.tNumeric) do
					table.insert(tTarget.tNumeric, v);
				end
			else
				tApplyData.tResolver[sEffectTagTarget] = tApplyData.tResolver[sEffectTagTarget] or {};
				tApplyData.tResolver[sEffectTagTarget][sDamage] = tSource;
			end
			tApplyData.tResolver[sEffectTagSource][sDamage] = nil;
		end
	elseif sEffectTagTarget ~= "" then
		local tTarget = tApplyData.tResolver[sEffectTagTarget] and tApplyData.tResolver[sEffectTagTarget][sDamage];
		if tTarget then
			table.insert(tTarget.tBasic, { nMod = 0, tNegatives = {}, });
		else
			tApplyData.tResolver[sEffectTagTarget] = tApplyData.tResolver[sEffectTagTarget] or {};
			tApplyData.tResolver[sEffectTagTarget][sDamage] = {};
			tApplyData.tResolver[sEffectTagTarget][sDamage].tBasic = { { nMod = 0, tNegatives = {}, }, };
		end
	end
end
function applyDamageAdjustBuildResults(rRoll, tApplyData)
	rRoll.tResults = {};
	for kType,nType in pairs(tApplyData.tDamageTypes or {}) do
		rRoll.tResults[kType] = { nTotal = nType, nBase = nType, };
	end
end
-- applyDamageAdjustRegen(rSource, rTarget, rRoll, tApplyData)
function applyDamageAdjustRegen(_, rTarget, rRoll, tApplyData)
	if tApplyData.bIgnoreEffects then
		return;
	end
	if not GameManager.isOption("regeneration", "3.5E") then
		return;
	end

	local tRegenData = { bIgnoreExpire = true, };
	if not EffectManager.hasTag(rTarget, "REGEN", tRegenData) and not EffectManager.hasTag(rTarget, "REGENE", tRegenData) then
		return;
	end

	local tRemap = {};
	for k,_ in pairs(tApplyData.tDamageTypes or {}) do
		local tClauseDamageTypes = StringManager.split(k, ",", true);
		if not StringManager.contains(tClauseDamageTypes, "nonlethal") then
			for _, tCompData in ipairs(EffectManager.getCompsDataByTag(rTarget, "REGEN", tRegenData)) do
				if not ActionCore.matchAndOrClauses(tCompData.sRemainder, tClauseDamageTypes) then
					table.insert(tClauseDamageTypes, "nonlethal");
					tRemap[k] = table.concat(tClauseDamageTypes, ",");
				end
			end
			for _, tCompData in ipairs(EffectManager.getCompsDataByTag(rTarget, "REGENE", tRegenData)) do
				if not ActionCore.matchAndOrClauses(tCompData.sRemainder, tClauseDamageTypes) then
					table.insert(tClauseDamageTypes, "nonlethal");
					tRemap[k] = table.concat(tClauseDamageTypes, ",");
				end
			end
		end
	end
	for k,v in pairs(tRemap) do
		tApplyData.tDamageTypes[v] = tApplyData.tDamageTypes[k];
		tApplyData.tDamageTypes[k] = nil;
		rRoll.tResults[v] = rRoll.tResults[k];
		rRoll.tResults[k] = nil;
	end
end
function applyDamageAdjustReductionEffects(rSource, rTarget, rRoll, tApplyData)
	if tApplyData.bIgnoreEffects then
		return;
	end

	local nReduction = 0;
	local tCombinedFilter = SetManager.union(tApplyData.tEffectFilter, tApplyData.tDamageTypeList):toarray();
	for _,tCompData in ipairs(EffectManager.getCompsDataByTag(rTarget, "DMGR", { rTarget = rSource, tActionTags = rRoll.tActionTags, bFilterAllDesc = true, tFilter = tCombinedFilter, })) do
		nReduction = nReduction + ActionHealthD20.applyDamageAdjustReductionHelper(rRoll, tApplyData, tCompData);
	end
	if nReduction > 0 then
		table.insert(tApplyData.tNotifications, string.format("[REDUCED: %d]", nReduction));
	end
end
-- applyDamageAdjustCheckDT(rSource, rTarget, rRoll, tApplyData)
function applyDamageAdjustCheckDT(_, rTarget, rRoll, tApplyData)
	if not GameManager.hasOption("dmgthreshold") then
		return true;
	end

	local nDT = ActionHealthD20.applyDamageAdjustGetDT(rTarget, rRoll, tApplyData);
	if (nDT <= 0) or (nDT <= rRoll.nTotal) then
		return true;
	end

	for k, v in pairs(tApplyData.tDamageTypes or {}) do
		rRoll.tResults[k] = { nTotal = 0, nBase = v, nVulnerable = 0, nResist = v, };
	end
	tApplyData.nAdjustedDamage = 0;
	table.insert(tApplyData.tNotifications, "[RESISTED]");
	return false;
end
-- applyDamageAdjustGetDT(rActor, rRoll, tApplyData)
function applyDamageAdjustGetDT(rActor, rRoll, _)
	if (rRoll.sSubtargetPath or "") ~= "" then
		return DB.getValue(DB.getPath(rRoll.sSubtargetPath, "damagethreshold"), 0);
	end

	local nResult = GameManager.getRecordFieldValue(rActor, "damagethreshold", 0);
	nResult = nResult + (EffectManager.getMaxMod(rActor, "DT") or 0);
	return nResult;
end
-- applyDamageAdjustMain(rSource, rTarget, rRoll, tApplyData)
function applyDamageAdjustMain(_, _, rRoll, tApplyData)
	local nDamageAdjust = 0;
	local nNLDamage = 0;
	local bVulnerable = false;
	local bResist = false;
	local setAbsorbedTypes = SetManager.new();
	local tAdjResults = {};

	-- Iterate through damage type entries for vulnerability, resistance and immunity
	local bResistCarry = false;
	for k, tResult in pairs(rRoll.tResults or {}) do
		local v = tResult.nTotal;
		tAdjResults[k] = tResult;

		local tSplitDamageTypes = {};
		if GameManager.hasOption("dmgsplit") then
			local tNormal = {};
			local tSpecial = {};
			for _,s in ipairs(StringManager.split(k, ",", true)) do
				if ActionCore.isBasicDamageType(s) then
					table.insert(tNormal, s);
				else
					tSpecial[s] = true;
				end
			end
			local sSpecial = table.concat(tSpecial, ",");

			local nSplit = math.floor(v / #tNormal);
			local nRemainder = v - (nSplit * #tNormal);
			for _,s in ipairs(tNormal) do
				local tBuild = { s };
				if sSpecial ~= "" then
					table.insert(tBuild, sSpecial);
				end
				local n = nSplit;
				if nRemainder > 0 then
					n = n + 1;
					nRemainder = nRemainder - 1;
				end
				table.insert(tSplitDamageTypes, { sKey = table.concat(tBuild, ","), nValue = n, })
			end
		else
			table.insert(tSplitDamageTypes, { sKey = k, nValue = v, });
		end

		local nClauseDmgAdj = 0;
		for _,tDmgValue in ipairs(tSplitDamageTypes) do
			-- Get individual damage types for each damage clause
			local tDamageTypes = ActionDamageCore.getDamageTypeArray(tDmgValue.sKey);

			-- Handle standard immunity, vulnerability and resistance
			local bLocalVulnerable = ActionHealthD20.applyDamageCheckBasicReductionType(tApplyData.tResolver["VULN"], tDamageTypes);
			local bLocalResist = ActionHealthD20.applyDamageCheckBasicReductionType(tApplyData.tResolver["RESIST"], tDamageTypes);
			local bLocalImmune = ActionHealthD20.applyDamageCheckBasicReductionType(tApplyData.tResolver["IMMUNE"], tDamageTypes);
			local nAbsorbMult = ActionHealthD20.applyDamageGetAbsorbMult(tApplyData.tResolver["ABSORB"], tDamageTypes);

			-- HANDLE INCORPOREAL
			if tApplyData.bApplyIncorporeal then
				if GameManager.isOption("incorporeal", "2E") then
					bLocalResist = true;
				elseif not StringManager.contains(tDamageTypes, "force") then
					if not StringManager.contains(tDamageTypes, "spell") and not StringManager.contains(tDamageTypes, "magic") then
						bLocalImmune = true;
					elseif GameManager.isOption("incorporeal", "PF") then
						bLocalResist = true;
					end
				end
			end

			-- Calculate adjustment
			-- Vulnerability = double
			-- Resistance = half
			-- Immunity = none
			if nAbsorbMult > 0 then
				nClauseDmgAdj = nClauseDmgAdj - tDmgValue.nValue;
				bResist = true;
				tResult.nResist = (tResult.nResist or 0) + tDmgValue.nValue;
				tResult.nAbsorbMult = nAbsorbMult;
				for _,sType in ipairs(tDamageTypes) do
					SetManager.add(setAbsorbedTypes, sType);
				end
			elseif bLocalImmune then
				nClauseDmgAdj = nClauseDmgAdj - tDmgValue.nValue;
				bResist = true;
				tResult.nResist = (tResult.nResist or 0) + tDmgValue.nValue;
			else
				-- Handle numerical resistance
				local nResist = ActionHealthD20.applyDamageCheckNumericReductionType(tApplyData.tResolver["RESIST"], tDamageTypes, tDmgValue.nValue);
				if nResist ~= 0 then
					tResult.nResist = (tResult.nResist or 0) + nResist;
					nClauseDmgAdj = nClauseDmgAdj - nResist;
					bResist = true;
				end
				-- Handle numerical vulnerability
				local nVuln = ActionHealthD20.applyDamageCheckNumericReductionType(tApplyData.tResolver["VULN"], tDamageTypes);
				if nVuln ~= 0 then
					tResult.nVulnerable = (tResult.nVulnerable or 0) + nVuln;
					nClauseDmgAdj = nClauseDmgAdj + nVuln;
					bVulnerable = true;
				end
				-- Handle standard resistance
				if bLocalResist then
					local nResistOddCheck = (nClauseDmgAdj + v) % 2;
					local nAdj = math.ceil((nClauseDmgAdj + v) / 2);
					tResult.nResist = (tResult.nResist or 0) + nAdj;
					nClauseDmgAdj = nClauseDmgAdj - nAdj;
					if nResistOddCheck == 1 then
						if bResistCarry then
							tResult.nResist = math.max(0, (tResult.nResist or 0) - 1);
							nClauseDmgAdj = nClauseDmgAdj + 1;
							bResistCarry = false;
						else
							bResistCarry = true;
						end
					end
					bResist = true;
				end
				-- Handle standard vulnerability
				if bLocalVulnerable then
					local nAdj;
					if GameManager.isOption("dmgvuln", { "3.5E", "PF", "SF", }) then
						-- 50% increased damage
						nAdj = math.floor((nClauseDmgAdj + v) / 2);
					else
						-- 100% increased damage
						nAdj = (nClauseDmgAdj + v)
					end
					tResult.nVulnerable = (tResult.nVulnerable or 0) + nAdj;
					nClauseDmgAdj = nClauseDmgAdj + nAdj;
					bVulnerable = true;
				end

				-- HANDLE DR  (FORM: <type> and <type> or <type> and <type>)
				if GameManager.hasOption("dmgdr") then
					local bHasEnergyType = false;
					for _,s in ipairs(tDamageTypes) do
						if not bHasEnergyType and (ActionCore.isEnergyDamageType(s) or (s == "spell")) then
							bHasEnergyType = true;
							break;
						end
					end
					if not bHasEnergyType and (v + nClauseDmgAdj) > 0 then
						-- DR from multiple sources does not stack; only the best applicable DR applies
						local nBestDR = 0;
						for _,tCompData in pairs(tApplyData.tCompsData["DR"] or {}) do
							local bApplyDR;
							if StringManager.contains({ "", "-", "all" }, tCompData.sRemainder) then
								bApplyDR = true;
							else
								bApplyDR = not ActionCore.matchAndOrClauses(tCompData.sRemainder, tDamageTypes);
							end
							if bApplyDR then
								nBestDR = math.max(nBestDR, tCompData.mod or 0);
							end
						end
						local nDRApplied = tApplyData.nDRApplied or 0;
						if nBestDR > nDRApplied then
							local nChange = math.min(nBestDR - nDRApplied, v + nClauseDmgAdj);
							tApplyData.nDRApplied = nDRApplied + nChange;
							nClauseDmgAdj = nClauseDmgAdj - nChange;
							tResult.nResist = (tResult.nResist or 0) + nChange;
							bResist = true;
						end
					end
				end
			end
		end

		-- Apply adjustment to this damage type clause
		if GameManager.hasOption("nonlethal") and (v + nClauseDmgAdj > 0) and StringManager.contains(StringManager.split(k:lower(), ",", true), "nonlethal") then
			nNLDamage = nNLDamage + (v + nClauseDmgAdj);
			nDamageAdjust = nDamageAdjust - (v + nClauseDmgAdj);
		end
		nDamageAdjust = nDamageAdjust + nClauseDmgAdj;
	end

	tApplyData.nAdjustedDamage = math.max(tApplyData.nAdjustedDamage + nDamageAdjust, 0);
	if GameManager.hasOption("nonlethal") then
		tApplyData.nNonlethalDamage = nNLDamage;
	end
	tApplyData.bResist = bResist;
	tApplyData.bVulnerable = bVulnerable;
	if bResist then
		if tApplyData.nAdjustedDamage <= 0 then
			table.insert(tApplyData.tNotifications, "[RESISTED]");
		else
			table.insert(tApplyData.tNotifications, "[PARTIALLY RESISTED]");
		end
	end
	if bVulnerable then
		table.insert(tApplyData.tNotifications, "[VULNERABLE]");
	end
	if SetManager.count(setAbsorbedTypes) > 0 then
		table.insert(tApplyData.tNotifications, string.format("[ABSORBED: %s]", SetManager.concat(setAbsorbedTypes, ",")));

		tApplyData.nAbsorbedDamage = 0;
		local nCarry = 0;
		for _,tAdj in pairs(tAdjResults) do
			if (tAdj.nAbsorbMult or 0) > 0 then
				local nAdj = tAdj.nResist * tAdj.nAbsorbMult;
				nCarry = nCarry + (nAdj % 1);
				if nCarry >= 1 then
					nAdj = nAdj + 1;
					nCarry = nCarry - 1;
				end
				tApplyData.nAbsorbedDamage = tApplyData.nAbsorbedDamage + math.floor(nAdj);
			end
		end
	end

	for kType,_ in pairs(tApplyData.tDamageTypes or {}) do
		local tAdj = tAdjResults[kType];
		if tAdj then
			rRoll.tResults[kType] = {
				nTotal = (tAdj.nBase or 0) + (tAdj.nVulnerable or 0) - (tAdj.nResist or 0),
				nBase = tAdj.nBase or 0,
				nVulnerable = tAdj.nVulnerable or 0,
				nResist = tAdj.nResist or 0,
			};
		end
	end
end
-- NOTE: Absorption, immunity, resistance, and vulnerability are all or nothing for combined damage types.
--			(i.e. all basic damage types must match or does not apply)
function applyDamageGetAbsorbMult(tData, tDamageTypes)
	if not tData then
		return 0;
	end

	local nAllAbsorb = ActionHealthD20.applyDamageGetAbsorbMultDetail(tData["all"], tDamageTypes);

	local bBasicDamage = false;
	local bBasicMatch = true;
	local nBasicAbsorb = 0;
	local nSpecialAbsorb = 0;
	for _,sType in pairs(tDamageTypes) do
		local nTypeAbsorb = ActionHealthD20.applyDamageGetAbsorbMultDetail(tData[sType], tDamageTypes);
		if ActionCore.isBasicDamageType(sType) then
			bBasicDamage = true;
			if nTypeAbsorb > 0 then
				if nBasicAbsorb == 0 then
					nBasicAbsorb = nTypeAbsorb;
				else
					nBasicAbsorb = math.min(nBasicAbsorb, nTypeAbsorb);
				end
			else
				bBasicMatch = false;
			end
		else
			if nTypeAbsorb > 0 then
				nSpecialAbsorb = math.max(nSpecialAbsorb, nTypeAbsorb);
			end
		end
	end
	if not bBasicDamage or not bBasicMatch then
		nBasicAbsorb = 0;
	end

	if nAllAbsorb > 0 then
		if ((nBasicAbsorb <= 0) or (nAllAbsorb < nBasicAbsorb)) and ((nSpecialAbsorb <= 0) or (nAllAbsorb < nSpecialAbsorb)) then
			return nAllAbsorb;
		end
	end
	if nSpecialAbsorb > 0 then
		if ((nBasicAbsorb <= 0) or (nSpecialAbsorb < nBasicAbsorb)) then
			return nSpecialAbsorb;
		end
	end
	if nBasicAbsorb > 0 then
		return nBasicAbsorb;
	end

	return 0;
end
function applyDamageGetAbsorbMultDetail(tData, tDamageTypes)
	if not tData then
		return 0;
	end

	local nAbsorb = 0;
	for _,tBasicData in ipairs(tData.tBasic or {}) do
		if not SetManager.overlaps(tDamageTypes, tBasicData.tNegatives) then
			nAbsorb = 1;
			break;
		end
	end
	for _,tNumericData in ipairs(tData.tNumeric or {}) do
		if not SetManager.overlaps(tDamageTypes, tNumericData.tNegatives) then
			nAbsorb = math.max(nAbsorb, tNumericData.nMod);
		end
	end
	return nAbsorb;
end
function applyDamageCheckBasicReductionType(tData, tDamageTypes)
	if not tData then
		return false;
	end

	if ActionHealthD20.applyDamageCheckBasicReductionTypeDetail(tData["all"], tDamageTypes) then
		return true;
	end
	local bBasicDamage = false;
	local bBasicApply = true;
	local bSpecialApply = false;
	for _,sType in pairs(tDamageTypes) do
		local bTypeApply = ActionHealthD20.applyDamageCheckBasicReductionTypeDetail(tData[sType], tDamageTypes);
		if ActionCore.isBasicDamageType(sType) then
			bBasicDamage = true;
			if not bTypeApply then
				bBasicApply = false;
			end
		else
			if bTypeApply then
				bSpecialApply = true;
			end
		end
	end
	return (bBasicDamage and bBasicApply) or bSpecialApply;
end
function applyDamageCheckBasicReductionTypeDetail(tData, tDamageTypes)
	if not tData then
		return false;
	end
	for _,tBasicData in ipairs(tData.tBasic or {}) do
		if not SetManager.overlaps(tDamageTypes, tBasicData.tNegatives) then
			return true;
		end
	end
	return false;
end
function applyDamageCheckNumericReductionType(tData, tDamageTypes, nLimit)
	if not tData then
		return 0;
	end

	-- Highest applicable value wins; nothing is marked used until the winner is chosen
	local nBest = ActionHealthD20.applyDamageCheckNumericReductionTypeDetail(tData["all"], tDamageTypes);
	local tBestUsed = { tData["all"] };

	local bBasicDamage = false;
	local bBasicMatch = true;
	local nBasic = 0;
	local tBasicUsed = {};
	for _,sDmgType in ipairs(tDamageTypes) do
		local tTypeData = tData[sDmgType];
		local nType = ActionHealthD20.applyDamageCheckNumericReductionTypeDetail(tTypeData, tDamageTypes);
		if ActionCore.isBasicDamageType(sDmgType) then
			-- Basic: must cover every basic type in the clause, so the weakest limits it
			bBasicDamage = true;
			if nType > 0 then
				nBasic = (nBasic == 0) and nType or math.min(nBasic, nType);
				table.insert(tBasicUsed, tTypeData);
			else
				bBasicMatch = false;
			end
		elseif nType > nBest then
			-- Special: any one matching resistance applies
			nBest = nType;
			tBestUsed = { tTypeData };
		end
	end
	if bBasicDamage and bBasicMatch and (nBasic > nBest) then
		nBest = nBasic;
		tBestUsed = tBasicUsed;
	end

	if nLimit then
		nBest = math.min(nBest, math.max(nLimit, 0));
	end
	if nBest <= 0 then
		return 0;
	end
	for _,tUsed in ipairs(tBestUsed) do
		tUsed.nApplied = (tUsed.nApplied or 0) + nBest;
	end
	return nBest;
end
function applyDamageCheckNumericReductionTypeDetail(tData, tDamageTypes)
	if not tData then
		return 0;
	end
	local nMax = 0;
	for _,tNumericData in ipairs(tData.tNumeric or {}) do
		if not SetManager.overlaps(tDamageTypes, tNumericData.tNegatives) then
			nMax = math.max(nMax, tNumericData.nMod);
		end
	end
	return math.max(nMax - (tData.nApplied or 0), 0);
end
-- applyDamageAdjustHardnessReduction(rSource, rTarget, rRoll, tApplyData)
function applyDamageAdjustHardnessReduction(_, rTarget, rRoll, tApplyData)
	if not GameManager.hasOption("dmghardness") then
		return;
	end

	local nHardness = GameManager.getRecordFieldValue(rTarget, "hardness", 0);
	if (nHardness <= 0) then
		return;
	end

	table.insert(tApplyData.tNotifications, string.format("[REDUCED BY HARDNESS: %d]", nHardness));
	tApplyData.nAdjustedDamage = math.max(tApplyData.nAdjustedDamage - nHardness, 0);
	for _,tResult in pairs(rRoll.tResults) do
		if nHardness <= 0 then
			break;
		end
		local nReduce = math.min(tResult.nTotal, nHardness);
		tResult.nTotal = tResult.nTotal - nReduce;
		tResult.nResist = tResult.nResist + nReduce;
		nHardness = nHardness - nReduce;
	end
end
function applyDamageAdjustWardReduction(rSource, rTarget, rRoll, tApplyData)
	if tApplyData.bIgnoreEffects then
		return;
	end

	local tCombinedFilter = SetManager.union(tApplyData.tEffectFilter, tApplyData.tDamageTypeList):toarray();
	local tCompsData = EffectManager.getCompsDataByTag(rTarget, "DMGWARD", { rTarget = rSource, tActionTags = rRoll.tActionTags, bFilterAllDesc = true, tFilter = tCombinedFilter, });
	if #tCompsData == 0 then
		return;
	end

	local setNodesToRemove = SetManager.new();
	for _,tCompData in ipairs(tCompsData) do
		if ActionHealthD20.applyDamageAdjustWardReductionHelper(rRoll, tApplyData, tCompData) then
			if tCompData.mod <= 0 then
				SetManager.add(setNodesToRemove, tCompData.node);
			else
				local tEffectComps = EffectManager.parseEffect(EffectVarManager.getEffectVarFromNode(tCompData.node, "sName", ""));
				if tEffectComps[tCompData.kComp] then
					tEffectComps[tCompData.kComp] = EffectManager.rebuildParsedEffectCompSimple(tCompData);
					EffectVarManager.setEffectVarToNode(tCompData.node, "sName", EffectManager.rebuildParsedEffect(tEffectComps));
				end
			end
		end
	end

	for _,nodeEffect in ipairs(SetManager.toarray(setNodesToRemove)) do
		EffectManager.removeEffect(rTarget, nodeEffect);
	end
end
function applyDamageAdjustWardReductionHelper(rRoll, tApplyData, tCompData)
	if not tCompData or (tCompData.mod <= 0) or (tApplyData.nAdjustedDamage <= 0) then
		return false;
	end

	-- Special Type: "none": Tracks damage and expires effect when empty, but doesn't actually absorb it
	if StringManager.contains(tCompData.remainder, "none") then
		tCompData.mod = tCompData.mod - tApplyData.nAdjustedDamage;
		return true;
	end

	local nReduction = ActionHealthD20.applyDamageAdjustReductionHelper(rRoll, tApplyData, tCompData);
	if nReduction <= 0 then
		return false;
	end
	tCompData.mod = tCompData.mod - nReduction;
	table.insert(tApplyData.tNotifications, string.format("[REDUCED BY WARD: %d]", nReduction));
	return true;
end
function applyDamageAdjustReductionHelper(rRoll, tApplyData, tCompData)
	if not tCompData or (tApplyData.nAdjustedDamage <= 0) then
		return 0;
	end

	local nCompMod;
	if tCompData.type == "DMGR" then
		nCompMod = DiceManager.evalDice(tCompData.dice, tCompData.mod);
	elseif tCompData.type == "DMGWARD" then
		-- Optional maximum damage blocked per damage action (i.e. "DMGWARD: <ward>/<max> ...")
		nCompMod = tCompData.mod;
		if (tCompData.mod2 or 0) > 0 then
			nCompMod = math.min(nCompMod, tCompData.mod2);
		end
	end
	if (nCompMod or 0) <= 0 then
		return 0;
	end

	local nReduction = 0;
	local tCompDamageTypes = {};
	local tNegativeDamageTypes = {};
	for _,s in ipairs(tCompData.remainder) do
		local sLower = s:lower();
		if StringManager.startsWith(sLower, "!") then
			sLower = sLower:sub(2);
			if ActionCore.isDamageType(sLower) then
				table.insert(tNegativeDamageTypes, sLower);
			end
		else
			if ActionCore.isDamageType(sLower) then
				table.insert(tCompDamageTypes, sLower);
			end
		end
	end

	if StringManager.contains(tCompData.remainder, "all") or (#tCompDamageTypes == 0) then
		for k,tResult in pairs(rRoll.tResults) do
			local tRollDmgTypes = StringManager.splitByPattern(k, ",", true);
			if not SetManager.overlaps(tRollDmgTypes, tNegativeDamageTypes) then
				local nReduce = math.max(0, math.min(tResult.nTotal or 0, nCompMod));
				tApplyData.nAdjustedDamage = tApplyData.nAdjustedDamage - nReduce;
				nCompMod = nCompMod - nReduce;
				tResult.nTotal = (tResult.nTotal or 0) - nReduce;
				tResult.nResist = (tResult.nResist or 0) + nReduce;
				nReduction = nReduction + nReduce;
				if nCompMod <= 0 then
					break;
				end
			end
		end
	else
		for k, tResult in pairs(rRoll.tResults) do
			local tRollDmgTypes = StringManager.splitByPattern(k, ",", true);
			if SetManager.overlaps(tRollDmgTypes, tCompDamageTypes) and not SetManager.overlaps(tRollDmgTypes, tNegativeDamageTypes) then
				local nReduce = math.max(0, math.min(tResult.nTotal or 0, nCompMod));
				tApplyData.nAdjustedDamage = tApplyData.nAdjustedDamage - nReduce;
				nCompMod = nCompMod - nReduce;
				tResult.nTotal = (tResult.nTotal or 0) - nReduce;
				tResult.nResist = (tResult.nResist or 0) + nReduce;
				nReduction = nReduction + nReduce;
				if nCompMod <= 0 then
					break;
				end
			end
		end
	end

	return math.max(nReduction, 0);
end
-- applyDamageAdjustCheckMT(rSource, rTarget, rRoll, tApplyData)
function applyDamageAdjustCheckMT(_, rTarget, rRoll, tApplyData)
	if not GameManager.hasOption("dmgmishap") then
		return;
	end
	local nMT = ActionHealthD20.applyDamageAdjustGetMT(rTarget, rRoll, tApplyData);
	if (nMT > 0) and (nMT <= tApplyData.nAdjustedDamage) then
		table.insert(tApplyData.tNotifications, "[DAMAGE EXCEEDS MISHAP THRESHOLD]");
	end
end
-- applyDamageAdjustGetMT(rActor, rRoll, tApplyData)
function applyDamageAdjustGetMT(rActor, rRoll, _)
	if (rRoll.sSubtargetPath or "") ~= "" then
		return 0;
	end
	return GameManager.getRecordFieldValue(rActor, "mishapthreshold", 0);
end
function applyDamageResults(rSource, rTarget, rRoll, tApplyData)
	GameManager.callFunction("onDamageApplyResults", rSource, rTarget, rRoll, tApplyData);
end
function applyDamageResultsDefault(rSource, rTarget, rRoll, tApplyData)
	tApplyData.nConcentrationDamage = tApplyData.nAdjustedDamage;

	ActionHealthD20.applyDamageResultsTemp(rSource, rTarget, rRoll, tApplyData);
	ActionHealthD20.applyDamageResultsNonlethal(rSource, rTarget, rRoll, tApplyData);

	if (tApplyData.nAdjustedDamage or 0) <= 0 then
		return;
	end

	ActionHealthD20.applyDamageResultsNormal(rSource, rTarget, rRoll, tApplyData);

	ActionHealthD20.applyDamageResultsDeathSave(rSource, rTarget, rRoll, tApplyData);
	ActionHealthD20.applyDamageResultsSystemShock(rSource, rTarget, rRoll, tApplyData);
end
-- applyDamageResultsTemp(rSource, rTarget, rRoll, tApplyData)
function applyDamageResultsTemp(_, _, _, tApplyData)
	-- Reduce damage by temporary hit points
	if ((tApplyData.tHealth["hp"].nTemp or 0) > 0) and ((tApplyData.nAdjustedDamage or 0) > 0) then
		if tApplyData.nAdjustedDamage > tApplyData.tHealth["hp"].nTemp then
			table.insert(tApplyData.tNotifications, string.format("[TEMP ABSORBED: %d]", tApplyData.tHealth["hp"].nTemp));
			tApplyData.nAdjustedDamage = tApplyData.nAdjustedDamage - tApplyData.tHealth["hp"].nTemp;
			tApplyData.tHealth["hp"].nTemp = 0;
		else
			table.insert(tApplyData.tNotifications, string.format("[TEMP ABSORBED: %d]", tApplyData.nAdjustedDamage));
			tApplyData.tHealth["hp"].nTemp = tApplyData.tHealth["hp"].nTemp - tApplyData.nAdjustedDamage;
			tApplyData.nAdjustedDamage = 0;
		end
	end
end
-- applyDamageResultsNonlethal(rSource, rTarget, rRoll, tApplyData)
function applyDamageResultsNonlethal(_, rTarget, _, tApplyData)
	if not GameManager.hasOption("nonlethal") then
		return;
	end
	if (tApplyData.nNonlethalDamage or 0) <= 0 then
		return;
	end

	if GameManager.isOption("nonlethal", "PF") then
		if (tApplyData.tHealth["hp"].nNonlethal + tApplyData.nNonlethalDamage > tApplyData.tHealth["hp"].nTotal) then
			local tRegenData = { bIgnoreExpire = true, };
			if not EffectManager.hasTag(rTarget, "REGEN", tRegenData) and not EffectManager.hasTag(rTarget, "REGENE", tRegenData) then
				local nOver = tApplyData.tHealth["hp"].nNonlethal + tApplyData.nNonlethalDamage - tApplyData.tHealth["hp"].nTotal;
				if nOver > tApplyData.nNonlethalDamage then
					nOver = tApplyData.nNonlethalDamage;
				end
				tApplyData.nAdjustedDamage = tApplyData.nAdjustedDamage + nOver;
				tApplyData.nNonlethalDamage = tApplyData.nNonlethalDamage - nOver;
			end
		end
	end
	tApplyData.tHealth["hp"].nNonlethal = math.max(tApplyData.tHealth["hp"].nNonlethal + tApplyData.nNonlethalDamage, 0);
end
function applyDamageResultsNormal(rSource, rTarget, rRoll, tApplyData)
	GameManager.callFunction("onDamageApplyResultsNormal", rSource, rTarget, rRoll, tApplyData);
end
-- applyDamageResultsNormalDefault(rSource, rTarget, rRoll, tApplyData)
function applyDamageResultsNormalDefault(_, _, rRoll, tApplyData)
	-- Apply remaining damage
	tApplyData.tHealth["hp"].nPrevWounds = tApplyData.tHealth["hp"].nWounds;
	tApplyData.tHealth["hp"].nWounds = math.max(tApplyData.tHealth["hp"].nWounds + tApplyData.nAdjustedDamage, 0);

	-- Calculate wounds above HP
	local nRemainder = 0;
	if not GameManager.hasOption("negativehp") and tApplyData.tHealth["hp"].nWounds > tApplyData.tHealth["hp"].nTotal then
		nRemainder = tApplyData.tHealth["hp"].nWounds - tApplyData.tHealth["hp"].nTotal;
		tApplyData.tHealth["hp"].nWounds = tApplyData.tHealth["hp"].nTotal;
	end
	rRoll.nOverflow = nRemainder;
end
-- applyDamageResultsDeathSave(rSource, rTarget, rRoll, tApplyData)
function applyDamageResultsDeathSave(_, _, rRoll, tApplyData)
	if not GameManager.hasOption("deathsave") then
		return;
	end
	if rRoll.nOverflow >= tApplyData.tHealth["hp"].nTotal then
		table.insert(tApplyData.tNotifications, "[INSTANT DEATH]");
		tApplyData.tHealth["deathsave"].nFail = 3;
	elseif rRoll.nOverflow > 0 then
		if (tApplyData.tHealth["hp"].nPrevWounds or 0) >= tApplyData.tHealth["hp"].nTotal then
			if tApplyData.bCritical then
				tApplyData.tHealth["deathsave"].nFail = tApplyData.tHealth["deathsave"].nFail + 2;
			else
				tApplyData.tHealth["deathsave"].nFail = tApplyData.tHealth["deathsave"].nFail + 1;
			end
		end
	end
end
-- applyDamageResultsSystemShock(rSource, rTarget, rRoll, tApplyData)
function applyDamageResultsSystemShock(_, rTarget, rRoll, tApplyData)
	if not GameManager.hasOption("systemshock") then
		return;
	end
	if rRoll.nOverflow <= 0 then
		if OptionsManager.isOption("HRMD", "on") and (tApplyData.nAdjustedDamage >= (tApplyData.tHealth["hp"].nTotal / 2)) then
			ActionSave.performSystemShockRoll(nil, rTarget);
		end
	end
end
-- applyDamageEnd(rSource, rTarget, rRoll, tApplyData)
function applyDamageEnd(_, _, rRoll, tApplyData)
	if (rRoll.nOverflow or 0) > 0 then
		table.insert(tApplyData.tNotifications, "[DAMAGE EXCEEDS HIT POINTS BY " .. rRoll.nOverflow.. "]");
	end
	tApplyData.nValue = (tApplyData.nAdjustedDamage or 0);
end

function applySetHealth(rActor, rRoll, tApplyData)
	GameManager.callFunction("onHealthApplySetHealth", rActor, rRoll, tApplyData);
end
function applySetHealthDefault(rActor, rRoll, tApplyData)
	local nodeActor = ActorManager.getCreatureNode(rActor);
	if not nodeActor then
		return;
	end

	if GameManager.hasOption("deathsave") then
		if tApplyData.tHealth["hp"].nWounds < tApplyData.tHealth["hp"].nTotal then
			tApplyData.tHealth["deathsave"].nSuccess = 0;
			tApplyData.tHealth["deathsave"].nFail = 0;
		else
			tApplyData.tHealth["deathsave"].nSuccess = math.min(tApplyData.tHealth["deathsave"].nSuccess, 3);
			tApplyData.tHealth["deathsave"].nFail = math.min(tApplyData.tHealth["deathsave"].nFail, 3);
		end
	end

	if rRoll and (rRoll.sSubtargetPath or "") ~= "" then
		DB.setValue(DB.getPath(rRoll.sSubtargetPath, "wounds"), "number", tApplyData.tHealth["hp"].nWounds);
	else
		GameManager.setRecordFieldValue(rActor, "hptemp", "number", tApplyData.tHealth["hp"].nTemp);
		GameManager.setRecordFieldValue(rActor, "wounds", "number", tApplyData.tHealth["hp"].nWounds);
		if GameManager.hasOption("nonlethal") then
			GameManager.setRecordFieldValue(rActor, "nonlethal", "number", tApplyData.tHealth["hp"].nNonlethal);
		end
		if GameManager.hasOption("deathsave") then
			GameManager.setRecordFieldValue(rActor, "deathsavesuccess", "number", tApplyData.tHealth["deathsave"].nSuccess);
			GameManager.setRecordFieldValue(rActor, "deathsavefail", "number", tApplyData.tHealth["deathsave"].nFail);
		end
	end

	if GameManager.hasOption("healsurge") then
		if ActorManager.isPC(rActor) then
			DB.setValue(nodeActor, "hp.surgesused", "number", tApplyData.tHealth["healsurge"].nUsed);
		elseif ActorManager.isRecordType(rActor, "npc") then
			DB.setValue(nodeActor, "healsurgeremaining", "number", tApplyData.tHealth["healsurge"].nMax - tApplyData.tHealth["healsurge"].nUsed);
		end
	end
end
function applyStatusChange(rSource, rTarget, rRoll, tApplyData)
	GameManager.callFunction("onHealthApplyStatusChange", rSource, rTarget, rRoll, tApplyData);
end
-- applyStatusChangeDefault(rSource, rTarget, rRoll, tApplyData)
function applyStatusChangeDefault(_, rTarget, _, tApplyData)
	-- Remove Stable condition effect on damage
	if tApplyData.sType == "damage" then
		EffectManager.removeCondition(rTarget, "Stable");
	end

	tApplyData.tHealth.sNewStatus = ActorHealthManager.getHealthStatus(rTarget);
	if tApplyData.tHealth.sOriginalStatus ~= tApplyData.tHealth.sNewStatus then
		-- Check for automatic effects
		if ActorHealthManager.isDyingOrDeadStatus(tApplyData.tHealth.sOriginalStatus) and
				not ActorHealthManager.isDyingOrDeadStatus(tApplyData.tHealth.sNewStatus) then
			if ActorManager.isRecordType(rTarget, "vehicle") then
				EffectManager.removeCondition(rTarget, "Incapacitated");
			else
				EffectManager.removeCondition(rTarget, "Unconscious");
			end
		elseif not ActorHealthManager.isDyingOrDeadStatus(tApplyData.tHealth.sOriginalStatus) and
				ActorHealthManager.isDyingOrDeadStatus(tApplyData.tHealth.sNewStatus) then
			if ActorManager.isRecordType(rTarget, "vehicle") then
				EffectManager.addCondition(rTarget, "Incapacitated");
			else
				EffectManager.addCondition(rTarget, "Unconscious");
				EffectManager.addCondition(rTarget, "Prone");
			end
			tApplyData.bRemoveTarget = true;
		end

		-- Check for status announcement
		local bShowStatus;
		if ActorManager.isFaction(rTarget, "friend") then
			bShowStatus = not OptionsManager.isOption("SHPC", "off");
		else
			bShowStatus = not OptionsManager.isOption("SHNPC", "off");
		end
		if bShowStatus then
			table.insert(tApplyData.tNotifications, string.format("[%s: %s]", Interface.getString("combat_tag_status"), tApplyData.tHealth.sNewStatus));
		end
	end
end

function onPostApplyResolve(rSource, rTarget, rRoll, tApplyData)
	ActionHealthD20.onPostApplyRegen(rSource, rTarget, rRoll, tApplyData);
	ActionHealthD20.onPostApplyAbsorb(rSource, rTarget, rRoll, tApplyData);
	ActionHealthD20.onPostApplyTargeting(rSource, rTarget, rRoll, tApplyData);

	GameManager.callFunction("onHealthPostApply", rSource, rTarget, rRoll, tApplyData);
end
-- onPostApplyRegen(rSource, rTarget, rRoll, tApplyData)
function onPostApplyRegen(_, rTarget, _, tApplyData)
	if tApplyData.bIgnoreEffects then
		return;
	end
	if (tApplyData.nAdjustedDamage or 0) <= 0 then
		return;
	end
	local nodeTargetCT = ActorManager.getCTNode(rTarget);
	if not nodeTargetCT then
		return;
	end

	-- Calculate which damage types actually did damage
	local setActualDamageTypes = SetManager.new();
	for k,v in pairs(tApplyData.tDamageTypes or {}) do
		if v > 0 then
			SetManager.add(setActualDamageTypes, StringManager.split(k, ",", true));
		end
	end
	if SetManager.count(setActualDamageTypes) <= 0 then
		return;
	end

	-- Manage Regeneration effect state when hit with disabling damage
	if GameManager.isOption("regeneration", { "5E", "4E", "2E", "DCC", }) then
		local tRegenData = { bIgnoreExpire = true, };
		for _, tCompData in ipairs(EffectManager.getCompsDataByTag(rTarget, "REGEN", tRegenData)) do
			if SetManager.overlaps(setActualDamageTypes, tCompData.remainder) then
				EffectManager.disableEffect(nodeTargetCT, tCompData.node);
			end
		end
		for _, tCompData in ipairs(EffectManager.getCompsDataByTag(rTarget, "REGENE", tRegenData)) do
			if SetManager.overlaps(setActualDamageTypes, tCompData.remainder) then
				EffectManager.disableEffect(nodeTargetCT, tCompData.node);
			end
		end
	end
	if GameManager.isOption("regeneration", "PF") then
		local tActualDamageTypes = SetManager.toarray(setActualDamageTypes);
		local tRegenData = { bIgnoreExpire = true, };
		for _, tCompData in ipairs(EffectManager.getCompsDataByTag(rTarget, "REGEN", tRegenData)) do
			if ActionCore.matchAndOrClauses(tCompData.sRemainder, tActualDamageTypes) then
				if ActorHealthManager.getHealthStatus(rTarget) == ActorHealthManager.STATUS_DEAD then
					EffectManager.deactivateEffect(nodeTargetCT, tCompData.node);
				else
					EffectManager.disableEffect(nodeTargetCT, tCompData.node);
				end
			end
		end
		for _, tCompData in ipairs(EffectManager.getCompsDataByTag(rTarget, "REGENE", tRegenData)) do
			if ActionCore.matchAndOrClauses(tCompData.sRemainder, tActualDamageTypes) then
				if ActorHealthManager.getHealthStatus(rTarget) == ActorHealthManager.STATUS_DEAD then
					EffectManager.deactivateEffect(nodeTargetCT, tCompData.node);
				else
					EffectManager.disableEffect(nodeTargetCT, tCompData.node);
				end
			end
		end
	end
end
-- onPostApplyAbsorb(rSource, rTarget, rRoll, tApplyData)
function onPostApplyAbsorb(_, rTarget, rRoll, tApplyData)
	-- Apply absorbed damage as healing
	if (tApplyData.nAbsorbedDamage or 0) > 0 then
		local rAbsorbedHealRoll = {
			sType = "heal",
			bSecret = rRoll.bSecret,
			sDesc = string.format("[%s] [CONVERTED]", Interface.getString("action_heal_tag")),
			nTotal = tApplyData.nAbsorbedDamage,
		};
		ActionHealthD20.apply(nil, rTarget, rAbsorbedHealRoll);
	end
end
-- onPostApplyTargeting(rSource, rTarget, rRoll, tApplyData)
function onPostApplyTargeting(rSource, rTarget, _, tApplyData)
	-- Remove target after applying damage
	if tApplyData.bRemoveTarget and rSource and rTarget then
		TargetingManager.removeTarget(ActorManager.getCTNodeName(rSource), ActorManager.getCTNodeName(rTarget));
	end
end
function onPostApplyDefault(rSource, rTarget, rRoll, tApplyData)
	if tApplyData.sType == "damage" then
		GameManager.callEventFunctions("onDamagePostResolve", rSource, rTarget, rRoll);
	end
end

--
--	ONGOING EFFECT HANDLING
--

function applyOngoingHealthAdjustment(vActor, tCompData)
	if not tCompData or ((tCompData.type or "") == "") then
		return;
	end

	local rActor = ActorManager.resolveActor(vActor);

	local rRoll;
	if tCompData.type == "DMGO" or tCompData.type == "DMGOE" then
		rRoll = ActionHealthD20.getOngoingDamageRoll(rActor, tCompData);
	elseif tCompData.type == "TEMPO" or tCompData.type == "TEMPOE" then
		rRoll = ActionHealthD20.getOngoingTempRoll(rActor, tCompData);
	elseif tCompData.type == "REGEN" or tCompData.type == "REGENE" then
		rRoll = ActionHealthD20.getOngoingRegenRoll(rActor, tCompData);
	elseif tCompData.type == "FHEAL" then
		rRoll = ActionHealthD20.getOngoingFastHealRoll(rActor, tCompData);
	end

	if rRoll then
		local rSource = EffectManager.getSourceActor(tCompData.node);
		ActionsManager.actionDirect(rSource, rRoll.sType, { rRoll }, { { rActor } });
	end
end
function getOngoingDamageRoll(rActor, tCompData)
	if not tCompData or ((#(tCompData.dice or {}) == 0) and ((tCompData.mod or 0) == 0)) then
		return nil;
	end

	local tClauses = {};
	local bSpell = false;
	local bWeapon = false;
	for k,s in ipairs(StringManager.splitByPattern(tCompData.sRemainder, "%s+%+%s+", true)) do
		local tClause;
		if k == 1 then
			tClause = { dice = tCompData.dice, modifier = tCompData.mod, dmgtype = s:lower(), };
		else
			local sDice = s:match("^([%.%w%d%+%-]+)");
			if DiceManager.isDiceString(sDice) then
				tClause = {};
				tClause.dice, tClause.modifier = DiceManager.convertStringToDice(sDice);
				tClause.dmgtype = StringManager.trim(s:sub(#sDice + 1));
			end
		end
		if tClause then
			table.insert(tClauses, tClause);

			local tDamageTypes = StringManager.splitByPattern(tClause.dmgtype, ",", true);
			if StringManager.contains(tDamageTypes, "spell") then
				bSpell = true;
			end
			if StringManager.contains(tDamageTypes, "weapon") then
				bWeapon = true;
			end
		end
	end
	if #tClauses == 0 then
		table.insert(tClauses, { dice = tCompData.dice, modifier = tCompData.mod, dmgtype = "", });
	end

	local rAction = {
		label = Interface.getString("effect_special_DMGO"),
		clauses = tClauses,
		bSpell = bSpell,
		bWeapon = bWeapon,
		bOngoing = true,
		bSecret = EffectManager.isGMEffect(rActor, tCompData.node),
	};
	return ActionDamageD20.getRoll(nil, rAction);
end
function getOngoingTempRoll(rActor, tCompData)
	if not tCompData or ((#(tCompData.dice or {}) == 0) and ((tCompData.mod or 0) == 0)) then
		return nil;
	end

	-- Temporary hit points don't work once creature falls below 1 HP
	local nPercentWounded = ActorHealthManager.getWoundPercent(rActor);
	if nPercentWounded >= 1 then
		return nil;
	end

	local rAction = {
		label = Interface.getString("effect_special_TEMPO"),
		subtype = "temp",
		clauses = {
			{
				dice = tCompData.dice,
				modifier = tCompData.mod,
			},
		},
		bSecret = EffectManager.isGMEffect(rActor, tCompData.node),
		bSpell = StringManager.contains(tCompData.remainder, "spell");
		bWeapon = StringManager.contains(tCompData.remainder, "weapon");
		bOngoing = true,
	};
	return ActionHealD20.getRoll(nil, rAction);
end
function getOngoingRegenRoll(rActor, tCompData)
	if not tCompData or ((#(tCompData.dice or {}) == 0) and ((tCompData.mod or 0) == 0)) then
		return nil;
	end

	if GameManager.isOption("regeneration", "PF") then
		local nPercentWounded = ActorHealthManager.getWoundPercent(rActor);
		if nPercentWounded <= 0 then
			return nil;
		end
	elseif GameManager.isOption("regeneration", "3.5E") then
		if GameManager.getRecordFieldValue(rActor, "nonlethal", 0) <= 0 then
			return nil;
		end
	elseif GameManager.isOption("regeneration", { "4E", "2E", }) then
		-- If not wounded, then return
		-- Regeneration does not work once creature falls below 1 hit point
		local nPercentWounded = ActorHealthManager.getWoundPercent(rActor);
		if (nPercentWounded <= 0) or (nPercentWounded >= 1) then
			return nil;
		end
	else
		-- If not wounded, then skip
		-- If less than 1 HP, regeneration does not work (but only if no specific damage type needed to disable regeneration)
		local nPercentWounded = ActorHealthManager.getWoundPercent(rActor);
		if nPercentWounded <= 0 then
			return nil;
		end
		if nPercentWounded >= 1 and (#(tCompData.remainder) > 0) then
			return nil;
		end
	end

	local rAction = {
		label = Interface.getString("effect_special_REGEN"),
		subtype = "regen",
		clauses = {
			{
				dice = tCompData.dice,
				modifier = tCompData.mod,
			},
		},
		bSecret = EffectManager.isGMEffect(rActor, tCompData.node),
		bSpell = StringManager.contains(tCompData.remainder, "spell");
		bWeapon = StringManager.contains(tCompData.remainder, "weapon");
		bOngoing = true,
	};
	return ActionHealD20.getRoll(nil, rAction);
end
function getOngoingFastHealRoll(rActor, tCompData)
	if not tCompData or ((#(tCompData.dice or {}) == 0) and ((tCompData.mod or 0) == 0)) then
		return nil;
	end

	local sStatus = ActorHealthManager.getHealthStatus(rActor);
	if sStatus == ActorHealthManager.STATUS_DEAD then
		return nil;
	end
	local nPercentWounded = ActorHealthManager.getWoundPercent(rActor);
	if nPercentWounded <= 0 then
		return nil;
	end

	local rAction = {
		label = Interface.getString("effect_special_FHEAL"),
		subtype = "fheal",
		clauses = {
			{
				dice = tCompData.dice,
				modifier = tCompData.mod,
			},
		},
		bSecret = EffectManager.isGMEffect(rActor, tCompData.node),
		bSpell = StringManager.contains(tCompData.remainder, "spell");
		bWeapon = StringManager.contains(tCompData.remainder, "weapon");
		bOngoing = true,
	};
	return ActionHealD20.getRoll(nil, rAction);
end

--
--	MISC
--

function isHealActionType(tApplyData)
	return StringManager.contains({ "heal", "fheal", "regen", "recovery", }, tApplyData.sType or "");
end
function isDamageActionType(tApplyData)
	return StringManager.contains({ "damage", }, tApplyData.sType or "");
end
