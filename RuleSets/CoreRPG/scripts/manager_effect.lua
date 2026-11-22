--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

--luacheck: globals checkForOncePerTurn

OOB_MSGTYPE_ADDEFFECT = "addeffect"
OOB_MSGTYPE_EXPIREEFFECT = "expireeffect"
OOB_MSGTYPE_REMOVEEFFECT = "removeeffect";
OOB_MSGTYPE_EFFECT_SET_ACTIVE = "effect_set_active";
OOB_MSGTYPE_EFFECT_ADD_USE = "effect_add_use";

function onInit()
	CombatManager.setCustomInitChange(EffectManager.processEffects);

	GameManager.setFunction("onEffectPreAdd", EffectManager.onEffectPreAddDefault);
	GameManager.setFunction("onEffectPostAdd", EffectManager.onEffectPostAddDefault);
	GameManager.setFunction("onEffectDisplayFilter", EffectManager.onEffectDisplayFilterDefault);

	if Session.IsHost then
		OOBManager.registerOOBMsgHandler(EffectManager.OOB_MSGTYPE_ADDEFFECT, EffectManager.handleAddEffect);
		OOBManager.registerOOBMsgHandler(EffectManager.OOB_MSGTYPE_EXPIREEFFECT, EffectManager.handleExpireEffect);
		OOBManager.registerOOBMsgHandler(EffectManager.OOB_MSGTYPE_REMOVEEFFECT, EffectManager.handleRemoveEffect);
		OOBManager.registerOOBMsgHandler(EffectManager.OOB_MSGTYPE_EFFECT_SET_ACTIVE, EffectManager.handleSetActiveEffect);
		OOBManager.registerOOBMsgHandler(EffectManager.OOB_MSGTYPE_EFFECT_ADD_USE, EffectManager.handleAddUseEffect);
	end
end

--
--	CONFIGURATION
--

local _nInitDirection = -1;
function getInitDirection()
	return _nInitDirection;
end
function setInitAscending(bValue)
	if bValue then
		_nInitDirection = 1;
	else
		_nInitDirection = -1;
	end
end

--	EXAMPLES OF COMP TAG OPTIONS (CoreRPG)
--		EffectManager.setTagOptions("LIGHT", { bIgnoreExpire = true, bIgnoreTarget = true });

function setTagOptions(sTag, tOptions)
	EffectQueryManager.setTagOptions(sTag, tOptions);
end

--	EXAMPLES OF DESCRIPTOR GROUPS (5E)
--	EffectManager.addDescriptorGroup({ sKey = "range", bFilter = true, tTags = ActionCore.getRangeTypes(), });
--	EffectManager.addDescriptorGroup({ sKey = "damage", bBonus = true, tTags = SetManager.union(SetManager.union(ActionCore.getDamageTypes(), "all"), ActionCore.getConditions()):toarray(), })

--	EXAMPLES OF DESCRIPTOR GROUPS (3.5E)
--	EffectManager.addDescriptorGroup({ sKey = "range", bFilter = true, tTags = ActionCore.getRangeTypes(), });
-- 	EffectManager.addDescriptorGroup({ sKey = "damage", bBonus = true, tTags = SetManager.union(SetManager.union(ActionCore.getDamageTypes(), "all"), ActionCore.getConditions()):toarray(), })
-- 	EffectManager.addDescriptorGroup({ sKey = "modstack", bBonus = true, bNoDice = true, tTags = DataCommon and DataCommon.stackablebonustypes or {}, })
--	EffectManager.addDescriptorGroup({ sKey = "mod", bBonus = true, bNoDice = true, bNoStack = true,
--			tTags = SetManager.difference(DataCommon and DataCommon.bonustypes or {}, DataCommon and DataCommon.stackablebonustypes or {}):toarray(), })

function registerStandardDescriptorGroups()
	local tAtk = ActionCore.getAttackTypes();
	if #tAtk > 0 then
		EffectManager.addDescriptorGroup({ sKey = "atktype", bFilter = true, tTags = tAtk, });
	end

	local tRange = ActionCore.getRangeTypes();
	if #tRange > 0 then
		EffectManager.addDescriptorGroup({ sKey = "range", bFilter = true, tTags = tRange, });
	end

	local tDmgCond = SetManager.union(SetManager.union(ActionCore.getDamageTypes(), "all"), ActionCore.getConditions()):toarray();
	EffectManager.addDescriptorGroup({ sKey = "damage", bBonus = true, bMulti = true, tTags = tDmgCond, });

	local tBonus = DataCommon and DataCommon.bonustypes or {};
	if #tBonus > 0 then
		local tStackBonus = DataCommon and DataCommon.stackablebonustypes or {};
		if #tStackBonus > 0 then
			EffectManager.addDescriptorGroup({ sKey = "modstack", bBonus = true, bNoDice = true, tTags = tStackBonus, });
			EffectManager.addDescriptorGroup({ sKey = "mod", bBonus = true, bNoDice = true, bNoStack = true, tTags = SetManager.difference(tBonus, tStackBonus):toarray(), })
		else
			EffectManager.addDescriptorGroup({ sKey = "mod", bBonus = true, bNoDice = true, bNoStack = true, tTags = tBonus, })
		end
	end
end
function addDescriptorGroup(tData)
	EffectQueryManager.addDescriptorGroup(tData);
end

-- EXAMPLES OF CONDITIONALS - See EffectManager.registerBasicConditionals()

function registerBasicConditionals()
	EffectManager.setConditionalCheck("CONDITION", EffectQueryManager.onConditionCheck, ActionCore.getConditions());
	local tFactionDescriptors = { "friend", "neutral", "foe", "ally", "enemy", "notself", "self", };
	EffectManager.setConditionalCheck("FACTION", EffectQueryManager.onFactionCheck, tFactionDescriptors);
	EffectManager.setConditionalCheck("NAME", EffectQueryManager.onNameCheck);
	EffectManager.setConditionalCheck("RANGE", EffectQueryManager.onRangeCheck);
	local tStatusDescriptors = {
		DataCommon and DataCommon.healthstatusfull or "healthy",
		DataCommon and DataCommon.healthstatushalf or "bloodied",
		DataCommon and DataCommon.healthstatuswounded or "wounded",
		"light", "moderate", "heavy", "critical", "dying",
	};
	EffectManager.setConditionalCheck("STATUS", EffectQueryManager.onStatusCheck, tStatusDescriptors);
	EffectManager.setConditionalCheck("TAG", EffectQueryManager.onActionTagCheck);

	EffectManager.setConditionalCheck("CUSTOM", EffectQueryManager.onCustomCheck);
end
function setConditionalCheck(s, fn, tTags)
	EffectQueryManager.setConditionalCheck(s, fn, tTags);
end

--
--	EFFECT TURN CHANGE HANDLING
--

function processEffects(nodeCurrentActor, nodeNewActor)
	local tData = {
		nodeCurrentActor = nodeCurrentActor,
		nodeNewActor = nodeNewActor,
	};

	-- Set up current and new initiative values for effect processing
	if tData.nodeCurrentActor then
		tData.nCurrentInit = DB.getValue(tData.nodeCurrentActor, "initresult", 0);
	elseif EffectManager.getInitDirection() > 0 then
		tData.nCurrentInit = -10000;
	else
		tData.nCurrentInit = 10000;
	end
	if tData.nodeNewActor then
		tData.nNewInit = DB.getValue(tData.nodeNewActor, "initresult", 0);
	elseif EffectManager.getInitDirection() > 0 then
		tData.nNewInit = 10000;
	else
		tData.nNewInit = -10000;
	end

	EffectManager.resetPerTurnUses();
	EffectManager.processGlobalEffects(tData);

	-- Get sorted combatant list
	local tEntries = CombatManager.getSortedCombatantList();
	if #tEntries == 0 then
		return;
	end

	-- For each actor, advance durations, and process start of turn special effects
	tData.bProcessSpecialStart = (tData.nodeCurrentActor == nil);
	tData.bProcessSpecialEnd = (tData.nodeCurrentActor == nil);
	for i = 1,#tEntries do
		tData.nodeActor = tEntries[i];

		if tData.nodeActor == tData.nodeCurrentActor then
			tData.bProcessSpecialEnd = true;
		elseif tData.nodeActor == tData.nodeNewActor then
			tData.bProcessSpecialEnd = false;
		end

		EffectManager.processActorEffects(tData);

		if tData.nodeActor == tData.nodeCurrentActor then
			tData.bProcessSpecialStart = true;
		elseif tData.nodeActor == tData.nodeNewActor then
			tData.bProcessSpecialStart = false;
		end
	end
end
-- NOTE: Allow each ruleset a chance to process effects before expiration
function processActorEffects(tData)
	EffectManager.startDelayedUpdates();

	EffectManager.processActorStartTurn(tData);
	EffectManager.processActorEffectsExpire(tData, false);

	EffectManager.processActorEndTurn(tData);
	EffectManager.processActorEffectsExpire(tData, true);

	EffectManager.endDelayedUpdates();
end
function processActorStartTurn(tData)
	if not tData.bProcessSpecialStart then
		return;
	end

	local rActor = ActorManager.resolveActor(tData.nodeActor);

	EffectManager.resetActorPerRoundUses(tData);
	EffectManager.applyTurnChangeEffect(rActor, "TABLEO", TableManager.applyOngoingTable);

	GameManager.callFunction("onActorStartTurn", rActor);

	for _,tEffectData in ipairs(ActorEffectManager.getEffectsData(rActor)) do
		GameManager.callFunction("onEffectActorStartTurn", rActor, tEffectData.node);
	end
end
function processActorEndTurn(tData)
	if not tData.bProcessSpecialEnd then
		return;
	end

	local rActor = ActorManager.resolveActor(tData.nodeActor);

	EffectManager.applyTurnChangeEffect(rActor, "TABLEOE", TableManager.applyOngoingTable);

	GameManager.callFunction("onActorEndTurn", rActor);

	for _,tEffectData in ipairs(ActorEffectManager.getEffectsData(rActor)) do
		GameManager.callFunction("onEffectActorEndTurn", rActor, tEffectData.node);
	end
end
function processActorEffectsExpire(tData, bEnd)
	if not EffectVarManager.hasEffectVar("nInit") or
			not EffectVarManager.hasEffectVar("nDuration") or
			not EffectVarManager.hasEffectVar("sExpiration") then
		return;
	end

	for _,tEffectData in ipairs(ActorEffectManager.getEffectsData(tData.nodeActor)) do
		tData.nodeEffect = tEffectData.node;
		EffectManager.processEffectExpire(tData, bEnd);
	end
end
function processGlobalEffects(tData)
	if tData.nCurrentInit == tData.nNewInit then
		return;
	end

	EffectManager.resetGlobalPerRoundUses(tData);

	EffectManager.startDelayedUpdates();

	EffectManager.processGlobalEffectsExpire(tData, false);
	EffectManager.processGlobalEffectsExpire(tData, true);

	EffectManager.endDelayedUpdates();
end
function processGlobalEffectsExpire(tData, bEnd)
	if not EffectVarManager.hasEffectVar("nInit") or
			not EffectVarManager.hasEffectVar("nDuration") or
			not EffectVarManager.hasEffectVar("sExpiration") then
		return;
	end

	for _,tEffectData in ipairs(CombatManager.getGlobalEffectsData()) do
		tData.nodeEffect = tEffectData.node;
		EffectManager.processEffectExpire(tData, bEnd);
	end
end
function processEffectExpire(tData, bEnd)
	if DB.getValue(tData.nodeEffect, "isactive", 0) == 0 then
		return;
	end
	if not EffectManager.hasDuration(tData.nodeEffect) then
		return;
	end

	local sExpiration = EffectVarManager.getEffectVarFromNode(tData.nodeEffect, "sExpiration", "");
	if bEnd then
		if sExpiration ~= "end" then
			return;
		end
	else
		if sExpiration ~= "" then
			return;
		end
	end

	local nEffInit = EffectVarManager.getEffectVarFromNode(tData.nodeEffect, "nInit", 0);
	local bApply;
	if bEnd then
		bApply = ((EffectManager.getInitDirection() > 0) and (nEffInit >= tData.nCurrentInit and nEffInit < tData.nNewInit)) or (nEffInit <= tData.nCurrentInit and nEffInit > tData.nNewInit);
	else
		bApply = ((EffectManager.getInitDirection() > 0) and (nEffInit > tData.nCurrentInit and nEffInit <= tData.nNewInit)) or (nEffInit < tData.nCurrentInit and nEffInit >= tData.nNewInit);
	end
	if not bApply then
		return;
	end

	EffectManager.processEffectDecrementDuration(tData);
end
function processEffectDecrementDuration(tData)
	if not EffectVarManager.hasEffectVar("nDuration") then
		return false;
	end

	local nDuration = EffectVarManager.getEffectVarFromNode(tData.nodeEffect, "nDuration", 0);
	nDuration = nDuration - 1;
	if nDuration <= 0 then
		EffectManager.expireEffectByNode(tData.nodeActor, tData.nodeEffect);
		return true;
	end

	EffectVarManager.setEffectVarToNode(tData.nodeEffect, "nDuration", nDuration);
	return false;
end

function resetPerTurnUses()
	function checkForOncePerTurn(nodeEffect)
		local sApply = EffectVarManager.getEffectVarFromNode(nodeEffect, "sApply", "");
		if sApply == "onceperturn" then
			DB.setValue(nodeEffect, "isactive", "number", 1);
			DB.setValue(nodeEffect, "remaininguses", "number", 1);
		end
	end
	CombatManager.callForEachGlobalEffect(checkForOncePerTurn);
	CombatManager.callForEachCombatantEffect(checkForOncePerTurn);
end
function resetActorPerRoundUses(tData)
	for _,tEffectData in ipairs(ActorEffectManager.getEffectsData(tData.nodeActor)) do
		EffectManager.helperResetPerRoundUses(tEffectData.node);
	end
end
function resetGlobalPerRoundUses(tData)
	for _,tEffectData in ipairs(CombatManager.getGlobalEffectsData()) do
		local nEffInit = EffectVarManager.getEffectVarFromNode(tEffectData.node, "nInit", 0);
		local bReset = ((EffectManager.getInitDirection() > 0) and (nEffInit > tData.nCurrentInit and nEffInit <= tData.nNewInit)) or (nEffInit < tData.nCurrentInit and nEffInit >= tData.nNewInit);
		if bReset then
			EffectManager.helperResetPerRoundUses(tEffectData.node);
		end
	end
end
function helperResetPerRoundUses(nodeEffect)
	if type(nodeEffect) ~= "databasenode" then
		return;
	end
	local sApply = EffectVarManager.getEffectVarFromNode(nodeEffect, "sApply", "");
	if (sApply == "onceperround") or (sApply == "twiceperround") then
		DB.setValue(nodeEffect, "isactive", "number", 1);
		if sApply == "onceperround" then
			DB.setValue(nodeEffect, "remaininguses", "number", 1);
		elseif sApply == "twiceperround" then
			DB.setValue(nodeEffect, "remaininguses", "number", 2);
		end
	end
end

--
--	EFFECT ACTION HANDLING (CLIENT OR HOST)
--

function hasTag(rActor, sEffectTag, tData)
	return EffectQueryManager.hasTag(rActor, sEffectTag, tData);
end
function hasText(rActor, sEffectTag, tData)
	return EffectQueryManager.hasText(rActor, sEffectTag, tData);
end
function hasTextOrTag(rActor, sEffectTag, tData)
	return EffectQueryManager.hasTextOrTag(rActor, sEffectTag, tData);
end

function hasCondition(rActor, sEffect, tData)
	local tGroup = EffectManager.getConditionGroup(sEffect);
	if tGroup and ((#tGroup.tTags or {}) > 0) then
		for _,sTag in ipairs(tGroup.tTags) do
			if EffectQueryManager.hasText(rActor, sTag, tData) then
				return true;
			end
		end
		return false;
	end
	return EffectQueryManager.hasText(rActor, sEffect, tData);
end
function addCondition(rActor, sEffect)
	if (sEffect or "") == "" then
		return;
	end
	if EffectManager.hasCondition(rActor, sEffect) then
		return;
	end

	local rEffect = { sName = sEffect, nDuration = 0, bSkipAnnounce = true, };
	EffectManager.addEffectByTable(rActor, rEffect);
end
function removeCondition(rActor, sEffect)
	if EffectManager.hasCondition(rActor, sEffect) then
		EffectManager.removeEffectByText(rActor, sEffect);
	end
end

function getBonusDiceMod(rActor, sEffectTag, tData)
	return EffectQueryManager.getBonusDiceMod(rActor, sEffectTag, tData);
end
function getBonusMod(rActor, sEffectTag, tData)
	return EffectQueryManager.getBonusMod(rActor, sEffectTag, tData);
end
function getMinMod(rActor, sEffectTag, tData)
	return EffectQueryManager.getMinMod(rActor, sEffectTag, tData);
end
function getMaxMod(rActor, sEffectTag, tData)
	return EffectQueryManager.getMaxMod(rActor, sEffectTag, tData);
end
function getBonusData(rActor, vEffectTags, tData)
	return EffectQueryManager.getBonusData(rActor, vEffectTags, tData);
end

function getCompsDataByTag(rActor, sEffectTag, tData)
	return EffectQueryManager.getCompsDataByTag(rActor, sEffectTag, tData);
end
function getCompsDataByText(rActor, sEffectTag, tData)
	return EffectQueryManager.getCompsDataByText(rActor, sEffectTag, tData);
end

function getCompsCountByTag(rActor, sEffectTag, tData)
	return #EffectQueryManager.getCompsDataByTag(rActor, sEffectTag, tData);
end
function getCompsCountByText(rActor, sEffectTag, tData)
	return #EffectQueryManager.getCompsDataByText(rActor, sEffectTag, tData);
end
function getCompsCountByTextOrTag(rActor, sEffectTag, tData)
	return #EffectQueryManager.getCompsDataByText(rActor, sEffectTag, tData) + #EffectQueryManager.getCompsDataByTag(rActor, sEffectTag, tData);
end

function getDescriptorsByTag(rActor, sEffectTag, tData)
	local tResults = {};
	for _, tCompData in ipairs(EffectManager.getCompsDataByTag(rActor, sEffectTag, tData)) do
		for _, s in ipairs(tCompData.remainder) do
			table.insert(tResults, s);
		end
	end
	return tResults;
end

local _tConditionGroups = {};
function getConditionGroups()
	return _tConditionGroups;
end
function getConditionGroup(sKey)
	if (sKey or "") == "" then
		return;
	end
	for _,v in ipairs(EffectManager.getConditionGroups()) do
		if (v.sKey or "") == sKey then
			return v;
		end
	end
	return nil;
end
function addConditionGroup(tData)
	if not tData or ((tData.sKey or "") == "") then
		return;
	end
	local tGroups = EffectManager.getConditionGroups();
	if (tData.sKey or "") ~= "" then
		for k,v in ipairs(tGroups) do
			if (v.sKey or "") == tData.sKey then
				table.remove(tGroups, k);
				break;
			end
		end
	end
	if #(tData.tTags or {}) == 0 then
		return;
	end
	table.insert(tGroups, tData);
end
function removeConditionGroup(sKey)
	if (sKey or "") == "" then
		return;
	end
	local tGroups = EffectManager.getConditionGroups();
	for k,v in ipairs(tGroups) do
		if (v.sKey or "") == sKey then
			table.remove(tGroups, k);
			break;
		end
	end
end

--
--	EFFECT ACTION HANDLING (HOST ONLY)
--

function addEffectByText(vActor, s)
	return EffectManager.addEffectByTable(vActor, { sName = s, });
end
function addEffectByTable(vActor, rEffect)
	local rActor = ActorManager.resolveActor(vActor);
	if not rActor or not rEffect or ((rEffect.sName or "") == "") then
		return nil;
	end

	if not Session.IsHost then
		EffectManager.notifyAddEffect(rActor, rEffect);
		return nil;
	end

	if EffectManager.isDelayedUpdate() then
		EffectManager.addAfterDelay({ rActor = rActor, tEffect = rEffect });
		return nil;
	end

	EffectManager.onEffectEval(rActor, rEffect);
	EffectVarManager.onEffectAddSetup(rActor, rEffect);

	-- Pre-add scripting
	local fnPreAdd = GameManager.getFunction("onEffectPreAdd");
	if fnPreAdd then
		if not fnPreAdd(rActor, rEffect) then
			return nil;
		end
	end

	-- Write effect record
	local nodeEffect = EffectManager.onEffectAddMain(rActor, rEffect);
	if not nodeEffect then
		return nil;
	end

	-- Post-add scripting
	GameManager.callFunction("onEffectPostAdd", rActor, nodeEffect, rEffect);
	GameManager.callEventFunctions("onEffectAdd", rActor, nodeEffect, rEffect);

	return nodeEffect;
end
-- NOTE:
--		Effect apply variables = [<variablename>]
--		Effect math expression = {_<expr>_} (evaluated on effect application only if dice string)
-- POSSIBLE FUTURE:
--		Effect dynamic variables = $<variablename>$  (do not process math if contains $; and eval later?)
function onEffectEval(rActor, rEffect)
	EffectManager.onEffectEvalVariables(rActor, rEffect);
	EffectManager.onEffectEvalMath(rEffect);
	EffectManager.onEffectEvalTagBonusCombine(rEffect);
end
function onEffectEvalVariables(rActor, rEffect)
	if not rEffect then
		return;
	end

	local rOrigin = EffectManager.getSourceActor(rEffect) or rActor;
	ActorEffectManager.evalEffectTags(rOrigin, rEffect);
end
function onEffectEvalMath(rEffect)
	if not rEffect or ((rEffect.sName or "") == "") then
		return;
	end

	local tEffectComps = {};
	for _,sComp in ipairs(EffectManager.parseEffect(rEffect.sName)) do
		local tReplace = {};
		for sExpr in sComp:gmatch("{_([^_]+)_}") do
			local nResult = 0;
			if DiceManager.isDiceMathString(sExpr) then
				nResult = DiceManager.evalDiceMathExpression(sExpr);
			end
			table.insert(tReplace, { source = StringManager.encodeAsPattern(string.format("{_%s_}", sExpr)), target = string.format("%d", nResult), });
		end
		for _,v in ipairs(tReplace) do
			sComp = sComp:gsub(v.source, v.target, 1);
		end
		table.insert(tEffectComps, sComp);
	end
	rEffect.sName = EffectManager.rebuildParsedEffect(tEffectComps);
end
function onEffectEvalTagBonusCombine(rEffect)
	if not rEffect or ((rEffect.sName or "") == "") then
		return;
	end

	local tEffectComps = {};
	for _,sComp in ipairs(EffectManager.parseEffect(rEffect.sName)) do
		local tCompData = EffectManager.parseEffectCompSimple(sComp);
		if tCompData.type ~= "" and tCompData.remainder[1] then
			local sReplace = tCompData.remainder[1];
			local sCheck, sRemainder = sReplace:match("^%s*([^%s]+)(.*)$");
			while StringManager.isDiceString(sCheck) do
				local aDice, nMod = DiceManager.convertStringToDice(sCheck);
				for _,v in ipairs(aDice) do
					table.insert(tCompData.dice, v);
				end
				tCompData.mod = tCompData.mod + nMod;
				sReplace = StringManager.trim(sRemainder);
				sCheck, sRemainder = sReplace:match("^%s*([^%s]+)(.*)$");
			end
			if sReplace == "" then
				table.remove(tCompData.remainder, 1);
			else
				tCompData.remainder[1] = sReplace;
			end
		end
		table.insert(tEffectComps, EffectManager.rebuildParsedEffectCompSimple(tCompData));
	end
	rEffect.sName = EffectManager.rebuildParsedEffect(tEffectComps);
end
function onEffectPreAddDefault(rActor, rEffect)
	GameManager.callFunction("onEffectAddLegacy", rEffect);

	-- Check whether to ignore new effects (such as duplicates)
	local fnAddIgnoreLegacy = GameManager.getFunction("onEffectAddIgnoreCheckLegacy");
	if fnAddIgnoreLegacy then
		local sDuplicateMsg = fnAddIgnoreLegacy(rActor, rEffect);
		if sDuplicateMsg then
			EffectManager.message(sDuplicateMsg, rActor, ((rEffect.nGMOnly or 0) == 1), rEffect.sUser);
			return false;
		end
	else
		if EffectManager.checkEffectAddIgnore(rActor, rEffect) then
			return false;
		end
	end
	return true;
end
function onEffectPostAddDefault(rActor, nodeEffect, rEffect)
	GameManager.callFunction("onEffectPostAddLegacy", nodeEffect, rEffect);
	EffectManager.onEffectAddNotify(rActor, nodeEffect, rEffect);
end
function checkEffectAddIgnore(rActor, rEffect)
	if EffectManager.onCheckEffectAddIgnoreDuplicate(rActor, rEffect) then
		return true;
	end

	if EffectManager.onCheckEffectAddIgnoreImmune(rActor, rEffect) then
		return true;
	end

	return false;
end
function onCheckEffectAddIgnoreDuplicate(rActor, rEffect)
	local bStack = false;
	local tEffectPhrases = EffectManager.parseEffect(rEffect.sName);
	for i = #tEffectPhrases, 1, -1 do
		local tCompData = EffectManager.parseEffectCompSimple(tEffectPhrases[i]);
		if tCompData.original == "STACK" then
			bStack = true;
			table.remove(tEffectPhrases, i);
			rEffect.sName = EffectManager.rebuildParsedEffect(tEffectPhrases);
		elseif (tCompData.type ~= "" and StringManager.contains(DataCommon and DataCommon.stackable_conditions, tCompData.type:lower())) or
				(StringManager.contains(DataCommon and DataCommon.stackable_conditions, tCompData.original:lower())) then
			bStack = true;
		end
	end
	if bStack then
		return false;
	end

	-- Check for exact duplication (label/init/duration/targets) in combat effects only
	for _, nodeEffect in ipairs(ActorEffectManager.getCombatantEffectNodes(rActor)) do
		if EffectVarManager.getEffectVarFromNode(nodeEffect, "sName", "") == (rEffect.sName or "") then
			if EffectVarManager.getEffectVarFromNode(nodeEffect, "sSource", "") == (rEffect.sSource or "") then
				local tTargetPaths = {};
				for _, nodeTarget in pairs(DB.getChildList(nodeEffect, "targets")) do
					table.insert(tTargetPaths, DB.getValue(nodeTarget, "noderef", ""));
				end
				local bIsDuplicate = SetManager.equals(StringManager.splitByPattern(rEffect.sTargets or "", "|", true), tTargetPaths);
				if bIsDuplicate then
					if EffectManager.onCheckEffectAddIgnoreIsNewEffectLonger(rEffect, nodeEffect) then
						EffectVarManager.setEffectVarToNode(nodeEffect, "sExpiration", rEffect.sExpiration);
						EffectVarManager.setEffectVarToNode(nodeEffect, "nDuration", rEffect.nDuration);
						EffectVarManager.setEffectVarToNode(nodeEffect, "nInit", rEffect.nInit);

						if not rEffect.bSkipAnnounce then
							local sMsg = string.format("%s ['%s'] -> [%s]", Interface.getString("effect_label"), rEffect.sName, Interface.getString("effect_status_replaceshorter"));
							EffectManager.message(sMsg, rActor, ((rEffect.nGMOnly or 0) == 1));
						end
						return true;
					end

					if not rEffect.bSkipAnnounce then
						local sMsg = string.format("%s ['%s'] -> [%s]", Interface.getString("effect_label"), rEffect.sName, Interface.getString("effect_status_exists"));
						EffectManager.message(sMsg, rActor, ((rEffect.nGMOnly or 0) == 1));
					end
					return true;
				end
			end
		end
	end
	return false;
end
function onCheckEffectAddIgnoreIsNewEffectLonger(rEffect, nodeEffect)
	if not EffectVarManager.hasEffectVar("sExpiration") or
			not EffectVarManager.hasEffectVar("nDuration") or
			not EffectVarManager.hasEffectVar("nInit") then
		return false;
	end

	local sCurrExpiration = EffectVarManager.getEffectVarFromNode(nodeEffect, "sExpiration", "");
	local nCurrDuration = EffectVarManager.getEffectVarFromNode(nodeEffect, "nDuration", 0);
	local nCurrInit = EffectVarManager.getEffectVarFromNode(nodeEffect, "nInit", 0);

	-- Until long rest
	if sCurrExpiration == "restlong" then
		local bNewInfinite = ((rEffect.nDuration or 0) == 0) and StringManager.contains({ "end", "", }, rEffect.sExpiration);
		return bNewInfinite;
	end

	-- Until short rest
	if sCurrExpiration == "restshort" then
		if rEffect.sExpiration == "restlong" then
			return true;
		end
		local bNewInfinite = ((rEffect.nDuration or 0) == 0) and StringManager.contains({ "end", "", }, rEffect.sExpiration);
		return bNewInfinite;
	end

	-- Infinite
	if nCurrDuration <= 0 then
		return false;
	end

	-- End of turn
	if sCurrExpiration == "end" then
		if StringManager.contains({ "restlong", "restshort", }, rEffect.sExpiration) then
			return true;
		end
		if (rEffect.nDuration or 0) == 0 then
			return (nCurrDuration > 0);
		end
		if sCurrExpiration == "end" then
			return ((rEffect.nDuration or 0) > nCurrDuration) or ((rEffect.nInit or 0) < nCurrInit);
		end
		return ((rEffect.nDuration or 0) >= nCurrDuration) or ((rEffect.nInit or 0) <= nCurrInit);
	end

	-- Start of turn
	if StringManager.contains({ "restlong", "restshort", }, rEffect.sExpiration) then
		return true;
	end
	if (rEffect.nDuration or 0) == 0 then
		return (nCurrDuration > 0);
	end
	if rEffect.sExpiration == "end" then
		return ((rEffect.nDuration or 0) >= nCurrDuration) or ((rEffect.nInit or 0) <= nCurrInit);
	end
	return ((rEffect.nDuration or 0) > nCurrDuration) or ((rEffect.nInit or 0) < nCurrInit);
end
function onCheckEffectAddIgnoreImmune(rActor, rEffect)
	local sOriginal = rEffect.sName;
	local tCancelled = EffectManager.onEffectAddIgnoreCheckImmunities(rActor, rEffect);
	if #tCancelled > 0 then
		-- Announce the changes to the effect based on immunities
		if rEffect.sName == "" then
			if not rEffect.bSkipAnnounce then
				local sMsg = string.format("%s ['%s'] -> [%s]", Interface.getString("effect_label"), sOriginal, Interface.getString("effect_status_targetimmune"));
				EffectManager.message(sMsg, rActor, ((rEffect.nGMOnly or 0) == 1));
			end
			return true;
		else
			if not rEffect.bSkipAnnounce then
				local sMessage = string.format("%s ['%s'] -> [%s] [%s]", Interface.getString("effect_label"), sOriginal, Interface.getString("effect_status_targetpartialimmune"), table.concat(tCancelled, ","));
				EffectManager.message(sMessage, rActor, false);
			end
		end
	end
	return false;
end
function onEffectAddIgnoreCheckImmunities(rActor, rEffect)
	local tEffectConditions = {};
	for _,sComp in ipairs(EffectManager.parseEffect(rEffect.sName)) do
		local sLower = sComp:lower();
		if ActionCore.isCondition(sLower) then
			table.insert(tEffectConditions, sLower);
		end
	end
	local rSource = EffectManager.getSourceActor(rEffect);

	local tImmuneConditions = ActorCommonManager.getEffectsConditionImmunities(rActor, rSource, tEffectConditions);
	if #tImmuneConditions == 0 then
		return {};
	end

	local tNewEffectComps = {};
	local tCancelled = {};
	for _,sComp in ipairs(EffectManager.parseEffect(rEffect.sName)) do
		local tCompData = EffectManager.parseEffectCompSimple(sComp);
		if StringManager.contains(tImmuneConditions, tCompData.type:lower()) or
				StringManager.contains(tImmuneConditions, StringManager.trim(sComp:lower())) then
			table.insert(tCancelled, StringManager.trim(sComp));
		else
			table.insert(tNewEffectComps, sComp);
		end
	end
	if #tCancelled == 0 then
		return {};
	end

	-- Rebuild parsed effect without conditions that actor was immune to
	rEffect.sName = EffectManager.rebuildParsedEffect(tNewEffectComps);
	if StringManager.trim(rEffect.sName) == "(C)" then
		rEffect.sName = "";
	end

	-- Return list of cancelled conditions
	return tCancelled;
end
function onEffectAddMain(rActor, rEffect)
	local nodeCT = ActorManager.getCTNode(rActor);
	if not nodeCT then
		return nil;
	end
	local nodeEffectsList = DB.createChild(nodeCT, "effects");
	if not nodeEffectsList then
		return nil;
	end
	local nodeEffect = DB.createChild(nodeEffectsList);

	EffectVarManager.setNodeFromEffectData(nodeEffect, rEffect);
	DB.setValue(nodeEffect, "isactive", "number", 1);
	if (rEffect.sTargets or "") ~= "" then
		for _,sTarget in ipairs(StringManager.split(rEffect.sTargets, "|", true)) do
			EffectManager.addEffectTarget(nodeEffect, sTarget);
		end
		rEffect.sTargets = "";
	end
	EffectVarManager.onEffectAddCleanup(rActor, nodeEffect);

	-- Handle effect ownership
	if ((rEffect.nGMOnly or 0) ~= 1) and ((rEffect.sUser or "") ~= "") then
		DB.setOwner(nodeEffect, rEffect.sUser);
	end

	return nodeEffect;
end
-- onEffectAddNotify(rActor, nodeEffect, rEffect)
function onEffectAddNotify(rActor, _, rEffect)
	if rEffect.bSkipAnnounce then
		return;
	end

	-- Build output message
	local msg = { font = "msgfont", icon = "action_effect", };
	msg.text = string.format("%s ['%s']\r-> [to %s]", Interface.getString("effect_label"), rEffect.sName, ActorManager.getDisplayName(rActor));
	if (rEffect.sSource or "") ~= "" then
		msg.text = msg.text .. string.format("\r[by %s]", ActorManager.getDisplayName(DB.findNode(rEffect.sSource)));
	end

	-- Output message
	if (rEffect.nGMOnly or 0) == 1 then
		msg.secret = true;
		Comm.addChatMessage(msg);
	elseif CombatManager.isCTHidden(ActorManager.getCTNode(rActor)) then
		if (rEffect.sUser or "") == "" then
			msg.secret = true;
			Comm.addChatMessage(msg);
		else
			Comm.addChatMessage(msg);
			Comm.deliverChatMessage(msg, rEffect.sUser);
		end
	else
		Comm.deliverChatMessage(msg);
	end
end

function removeEffect(vActor, v)
	if type(v) == "databasenode" then
		EffectManager.removeEffectByNode(vActor, v);
	elseif type(v) == "string" then
		EffectManager.removeEffectByPattern(vActor, v);
	end
end
function removeEffectByNode(vActor, nodeEffect)
	if type(nodeEffect) ~= "databasenode" then
		return;
	end

	local rActor = ActorManager.resolveActor(vActor);

	if not Session.IsHost then
		EffectManager.notifyRemoveEffect(rActor, nodeEffect);
		return;
	end

	if EffectManager.isDelayedUpdate() then
		EffectManager.removeAfterDelay({ rActor = rActor, nodeEffect = nodeEffect });
		return;
	end

	GameManager.callEventFunctions("onEffectRemove", rActor, nodeEffect);
	DB.deleteNode(nodeEffect);
end
function removeEffectByPattern(vActor, sPattern)
	if (sPattern or "") == "" then
		return;
	end

	for _,nodeEffect in ipairs(ActorEffectManager.getCombatantEffectNodes(vActor)) do
		local sName = EffectVarManager.getEffectVarFromNode(nodeEffect, "sName", "");
		if sName:match(sPattern) then
			EffectManager.removeEffectByNode(vActor, nodeEffect);
			return;
		end
	end
end
function removeEffectByText(vActor, s)
	if (s or "") == "" then
		return;
	end

	local sLower = s:lower();
	for _,nodeEffect in ipairs(ActorEffectManager.getCombatantEffectNodes(vActor)) do
		local sName = StringManager.trim(EffectVarManager.getEffectVarFromNode(nodeEffect, "sName", ""));
		if sName:lower() == sLower then
			EffectManager.removeEffectByNode(vActor, nodeEffect);
			return;
		end
	end
end
-- NOTE: Must be called on host only
function removeEffectsByTag(rActor, sEffectTag, tData)
	if not Session.IsHost then
		return;
	end
	if (sEffectTag or "") == "" then
		return;
	end

	local tEffectNodesToDelete = {};
	for _, tEffectData in ipairs(EffectQueryManager.getEffectsDataByTag(rActor, sEffectTag, tData)) do
		if #(tEffectData.tComps or {}) > 0 then
			for i = #(tEffectData.tComps), 1, -1 do
				if tEffectData.tComps[i].type == sEffectTag then
					table.remove(tEffectData.tComps, i);
				end
			end
			if #tEffectData.tComps == 0 then
				table.insert(tEffectNodesToDelete, tEffectData.node);
			else
				local tEffectComps = {};
				for _,tCompData in ipairs(tEffectData.tComps) do
					table.insert(tEffectComps, EffectManager.rebuildParsedEffectCompSimple(tCompData));
				end
				EffectVarManager.setEffectVarToNode(tEffectData.node, "sName", EffectManager.rebuildParsedEffect(tEffectComps));
			end
		end
	end
	for _,nodeEffect in ipairs(tEffectNodesToDelete) do
		EffectManager.removeEffectByNode(rActor, nodeEffect);
	end
end
function removeEffectsByText(rActor, s)
	if (s or "") == "" then
		return;
	end

	local sLower = s:lower();
	local tEffectNodesToDelete = {};
	for _,nodeEffect in ipairs(ActorEffectManager.getCombatantEffectNodes(rActor)) do
		local sName = StringManager.trim(EffectVarManager.getEffectVarFromNode(nodeEffect, "sName", ""));
		if sName:lower() == sLower then
			table.insert(tEffectNodesToDelete, nodeEffect);
		end
	end
	for _,nodeEffect in ipairs(tEffectNodesToDelete) do
		EffectManager.removeEffectByNode(rActor, nodeEffect);
	end
end

function expireEffectByNode(vActor, nodeEffect, tData)
	if type(nodeEffect) ~= "databasenode" then
		return false;
	end

	vActor = vActor or DB.getChild(nodeEffect, "...");
	local rActor = ActorManager.resolveActor(vActor);

	if not Session.IsHost then
		EffectManager.notifyExpireEffect(rActor, nodeEffect, tData);
		return;
	end

	if not (tData and tData.bImmediate) and EffectManager.isDelayedUpdate() then
		EffectManager.expireAfterDelay({ rActor = rActor, nodeEffect = nodeEffect, tData = tData, });
		return true;
	end

	local sEffect = EffectVarManager.getEffectVarFromNode(nodeEffect, "sName", "");

	-- Check for partial expiration
	if ((tData and tData.nExpireComp) or 0) > 0 then
		local tEffectComps = EffectManager.parseEffect(sEffect);
		if #tEffectComps >= tData.nExpireComp then
			table.remove(tEffectComps, tData.nExpireComp);
			if #tEffectComps ~= 0 then
				EffectVarManager.setEffectVarToNode(nodeEffect, "sName", EffectManager.rebuildParsedEffect(tEffectComps));
				if not tData.bSkipAnnounce then
					local sMessage = string.format("%s ['%s'] -> [%s]", Interface.getString("effect_label"), sEffect, Interface.getString("effect_status_singleused"));
					EffectManager.message(sMessage, rActor, EffectManager.isGMEffect(rActor, nodeEffect));
				end
				return true;
			end
		end
	end

	-- Check for follow-on effect
	if EffectManager.handleEffectAfter(rActor, nodeEffect, tData) then
		return true;
	end

	local fnExpire = GameManager.getFunction("onEffectExpire");
	if fnExpire then
		if not fnExpire(rActor, nodeEffect, tData) then
			return true;
		end
	else
		local sExpirationMsg = GameManager.callFunction("onEffectExpireLegacy", nodeEffect);
		if sExpirationMsg then
			EffectManager.message(sExpirationMsg, rActor, EffectManager.isGMEffect(rActor, nodeEffect));
			return true;
		end
	end

	EffectManager.onEffectExpireNotify(rActor, nodeEffect, tData);
	GameManager.callEventFunctions("onEffectExpire", rActor, nodeEffect, tData);
	DB.deleteNode(nodeEffect);
	return true;
end
function onEffectExpireNotify(rActor, nodeEffect, tData)
	if tData and tData.bSkipAnnounce then
		return;
	end

	local nodeActor = ActorManager.getCreatureNode(rActor);
	local bGMOnly = EffectManager.isGMEffect(nodeActor, nodeEffect);
	local sEffect = EffectVarManager.getEffectVarFromNode(nodeEffect, "sName", "");
	local sMessage = string.format("%s ['%s'] -> [%s]", Interface.getString("effect_label"), sEffect, Interface.getString("effect_status_expired"));
	EffectManager.message(sMessage, nodeActor, bGMOnly);
end
function disableEffect(vActor, nodeEffect)
	local rActor = ActorManager.resolveActor(vActor);
	if not nodeEffect then
		return false;
	end

	local sEffect = EffectVarManager.getEffectVarFromNode(nodeEffect, "sName", "");
	local bGMOnly = EffectManager.isGMEffect(rActor, nodeEffect);

	DB.setValue(nodeEffect, "isactive", "number", 2);
	local sMessage = string.format("%s ['%s'] -> [%s]", Interface.getString("effect_label"), sEffect, Interface.getString("effect_status_disabled"));
	EffectManager.message(sMessage, rActor, bGMOnly);
end
function deactivateEffect(vActor, nodeEffect)
	local rActor = ActorManager.resolveActor(vActor);
	if not nodeEffect then
		return false;
	end

	local sEffect = EffectVarManager.getEffectVarFromNode(nodeEffect, "sName", "");
	local bGMOnly = EffectManager.isGMEffect(rActor, nodeEffect);

	DB.setValue(nodeEffect, "isactive", "number", 0);
	local sMessage = string.format("%s ['%s'] -> [%s]", Interface.getString("effect_label"), sEffect, Interface.getString("effect_status_deactivated"));
	EffectManager.message(sMessage, rActor, bGMOnly);
end

function handleEffectAfter(rActor, nodeEffect, tData)
	return EffectManager.expireToFollowOnTag(rActor, nodeEffect, "AFTER", tData);
end
function handleEffectSaveFail(rActor, nodeEffect, tData)
	return EffectManager.expireToFollowOnTag(rActor, nodeEffect, "FAIL", tData);
end
function expireToFollowOnTag(rActor, nodeEffect, sTag, tData)
	local tEffectComps = EffectIndexManager.getEffectCompsData(nodeEffect);

	-- If no matching tag, then return false
	local nIndex = 0;
	for kComp, tCompData in ipairs(tEffectComps) do
		if tCompData.type == sTag or tCompData.original == sTag then
			nIndex = kComp;
			break;
		end
	end
	if (nIndex <= 0) or (nIndex >= #(tEffectComps)) then
		return false;
	end

	-- If we have after condition, then strip out expired part of effect
	local tNewEffectComps = {};
	for j = nIndex + 1, #tEffectComps do
		table.insert(tNewEffectComps, tEffectComps[j].original);
	end
	local sNewEffect = EffectManager.rebuildParsedEffect(tNewEffectComps)

	-- Update effect
	EffectVarManager.setEffectVarToNode(nodeEffect, "sName", sNewEffect);
	for j = 1, nIndex - 1 do
		if StringManager.contains({ "SAVEOE", "SAVEO", }, tEffectComps[j].type) then
			tEffectComps[nIndex].sSaveTag = tEffectComps[j].type;
			break;
		elseif StringManager.contains({ "SAVEOE", "SAVEO", }, tEffectComps[j].original) then
			tEffectComps[nIndex].sSaveTag = tEffectComps[j].original;
			break;
		end
	end
	EffectManager.applyFollowOnExpiration(rActor, nodeEffect, tEffectComps[nIndex]);

	-- Send output message, and cancel deletion
	if not (tData and tData.bSkipAnnounce) then
		local sEffect = EffectVarManager.getEffectVarFromNode(nodeEffect, "sName", "");
		local sMsg = string.format("%s [%s] -> [%s]", Interface.getString("effect_label"), sEffect, sNewEffect);
		EffectManager.message(sMsg, rActor, EffectManager.isGMEffect(rActor, nodeEffect));
	end

	return true;
end
function applyFollowOnExpiration(rActor, nodeEffect, tCompData)
	if not nodeEffect or not tCompData then
		return;
	end

	EffectVarManager.setEffectVarToNode(nodeEffect, "sApply", "");

	local tWords = StringManager.parseWords(tCompData.sRemainder);
	local sExpire = tWords[1] or "";
	local nMod = tCompData.mod or 0;

	if sExpire ~= "inherit" then
		local nodeCT = ActorManager.getCTNode(rActor);
		if nodeCT then
			local nInit = DB.getValue(nodeCT, "initresult", 0);
			EffectVarManager.setEffectVarToNode(nodeEffect, "nInit", nInit);
		end
	end

	if sExpire == "start" then
		EffectVarManager.setEffectVarToNode(nodeEffect, "sExpiration", "");
		EffectVarManager.setEffectVarToNode(nodeEffect, "nDuration", math.max(nMod, 1));
	elseif sExpire == "end" then
		EffectVarManager.setEffectVarToNode(nodeEffect, "sExpiration", "end");
		EffectVarManager.setEffectVarToNode(nodeEffect, "nDuration", math.max(nMod, 1));
	elseif sExpire == "endnext" then
		EffectVarManager.setEffectVarToNode(nodeEffect, "sExpiration", "end");
		if rActor and CombatManager.isActive(ActorManager.getCTNode(rActor)) then
			EffectVarManager.setEffectVarToNode(nodeEffect, "nDuration", 2);
		else
			EffectVarManager.setEffectVarToNode(nodeEffect, "nDuration", 1);
		end
	elseif sExpire == "encounter" or sExpire == "restshort" then
		EffectVarManager.setEffectVarToNode(nodeEffect, "sExpiration", "restshort");
		EffectVarManager.setEffectVarToNode(nodeEffect, "nDuration", 0);
	elseif sExpire == "save" then
		EffectVarManager.setEffectVarToNode(nodeEffect, "sExpiration", "");
		EffectVarManager.setEffectVarToNode(nodeEffect, "nDuration", 0);

		local tSaveComp = {};
		if (nMod or 0) ~= 0 then
			table.insert(tSaveComp, tostring(nMod));
		end
		for i = 2, #tWords do
			table.insert(tSaveComp, tWords[i]);
		end
		local sSaveTag = tCompData.sSaveTag or "SAVEOE";
		local sSavePhrase = (#tSaveComp == 0) and sSaveTag or string.format("%s: %s", sSaveTag, table.concat(tSaveComp, " "));

		local sEffect = EffectVarManager.getEffectVarFromNode(nodeEffect, "sName", "");
		local tEffectPhrases = EffectManager.parseEffect(sEffect);
		local kInsert = nil;
		for k,sComp in ipairs(tEffectPhrases) do
			local tCompData = EffectManager.parseEffectCompSimple(sComp);
			if EffectQueryManager.isFollowOnCompData(tCompData) then
				kInsert = k;
				break;
			end
		end
		if kInsert then
			table.insert(tEffectPhrases, kInsert, sSavePhrase);
		else
			table.insert(tEffectPhrases, sSavePhrase);
		end
		EffectVarManager.setEffectVarToNode(nodeEffect, "sName", EffectManager.rebuildParsedEffect(tEffectPhrases));
	elseif sExpire ~= "inherit" then
		EffectVarManager.setEffectVarToNode(nodeEffect, "sExpiration", "");
		EffectVarManager.setEffectVarToNode(nodeEffect, "nDuration", math.max(nMod, 0));
	end
end

function applyEffectExpiration(nodeEffect, nMatch)
	if type(nodeEffect) ~= "databasenode" then
		return;
	end

	local nActive = DB.getValue(nodeEffect, "isactive", 0);

	-- Handle re-activating skipped effects
	if (nActive == 2) then
		local sApply = EffectVarManager.getEffectVarFromNode(nodeEffect, "sApply", "");
		if not StringManager.contains({ "onceperturn", "onceperround", "twiceperround", }, sApply) then
			EffectManager.notifySetActive(nodeEffect);
		end

	-- Handle expiration of effects based on roll application setting
	elseif nActive == 1 then
		local sApply = EffectVarManager.getEffectVarFromNode(nodeEffect, "sApply", "");
		if sApply == "action" then
			EffectManager.expireEffectByNode(nil, nodeEffect);
		elseif sApply == "roll" then
			EffectManager.expireEffectByNode(nil, nodeEffect, { bImmediate = true, });
		elseif sApply == "single" then
			EffectManager.expireEffectByNode(nil, nodeEffect, { nExpireComp = nMatch, bImmediate = true, });
		elseif StringManager.contains({ "onceperturn", "onceperround", "twiceperround", }, sApply) then
			EffectManager.notifyAddUse(nodeEffect);
		end
	end
end

--
--	EFFECT ACTION HANDLING (INTERNAL)
--

function notifyAddEffect(rActor, rEffect)
	if not rEffect then
		return;
	end

	rEffect.sUser = Session.IsHost and "" or Session.UserName;

	-- Build OOB message to pass to host
	local msgOOB = {
		type = EffectManager.OOB_MSGTYPE_ADDEFFECT,
		sActorPath = ActorManager.getCTNodeName(rActor);
		jsonEffect = Utility.encodeJSON(rEffect) or "";
	};
	Comm.deliverOOBMessage(msgOOB, "");
end
function handleAddEffect(msgOOB)
	local rActor = ActorManager.resolveActor(msgOOB.sActorPath);
	if not rActor then
		ChatManager.SystemMessage(Interface.getString("ct_error_effectapplyfail") .. " (" .. msgOOB.sTargetNode .. ")");
		return;
	end
	local rEffect = Utility.decodeJSON(msgOOB.jsonEffect) or {};

	EffectManager.addEffectByTable(rActor, rEffect);
end

function notifyExpireEffect(rActor, nodeEffect, tData)
	if not nodeEffect then
		return;
	end

	-- Build OOB message to pass to host
	local msgOOB = {
		type = EffectManager.OOB_MSGTYPE_EXPIREEFFECT,
		sActorPath = ActorManager.getCTNodeName(rActor);
		sPath = DB.getPath(nodeEffect),
		nExpireComp = tData and tData.nExpireComp,
		nSkipAnnounce = (tData and tData.bSkipAnnounce) and 1 or 0,
	};
	Comm.deliverOOBMessage(msgOOB, "");
end
function handleExpireEffect(msgOOB)
	if (msgOOB.sPath or "") == "" then
		return;
	end
	local rActor = ActorManager.resolveActor(msgOOB.sActorPath);
	local nodeEffect = DB.findNode(msgOOB.sPath);
    local nExpireComp = tonumber(msgOOB.nExpireComp) or 0;
	local bSkipAnnounce = ((tonumber(msgOOB.nSkipAnnounce) or 0) == 1);
	EffectManager.expireEffectByNode(rActor, nodeEffect, { nExpireComp = nExpireComp, bSkipAnnounce = bSkipAnnounce, });
end

function notifyRemoveEffect(rActor, nodeEffect)
	if not nodeEffect then
		return;
	end

	-- Build OOB message to pass to host
	local msgOOB = {
		type = EffectManager.OOB_MSGTYPE_REMOVEEFFECT,
		sActorPath = ActorManager.getCTNodeName(rActor);
		sPath = DB.getPath(nodeEffect),
	};
	Comm.deliverOOBMessage(msgOOB, "");
end
function handleRemoveEffect(msgOOB)
	local rActor = ActorManager.resolveActor(msgOOB.sActorPath);
	if not rActor then
		ChatManager.SystemMessage(Interface.getString("ct_error_effectremovefail") .. " (" .. msgOOB.sTargetNode .. ")");
		return;
	end

	if (msgOOB.sPath or "") ~= "" then
		EffectManager.removeEffectByNode(rActor, DB.findNode(msgOOB.sPath));
	end
end

function notifySetActive(varEffect)
	if type(varEffect) == "databasenode" then
		varEffect = DB.getPath(varEffect);
	elseif type(varEffect) ~= "string" then
		return;
	end

	local msgOOB = {};
	msgOOB.type = EffectManager.OOB_MSGTYPE_EFFECT_SET_ACTIVE;
	msgOOB.sEffectNode = varEffect;

	Comm.deliverOOBMessage(msgOOB, "");
end
function handleSetActiveEffect(msgOOB)
	local nodeEffect = DB.findNode(msgOOB.sEffectNode);
	if not nodeEffect then
		return;
	end

	DB.setValue(nodeEffect, "isactive", "number", 1);
end

function notifyAddUse(varEffect)
	if type(varEffect) == "databasenode" then
		varEffect = DB.getPath(varEffect);
	elseif type(varEffect) ~= "string" then
		return;
	end

	local msgOOB = {};
	msgOOB.type = EffectManager.OOB_MSGTYPE_EFFECT_ADD_USE;
	msgOOB.sEffectNode = varEffect;

	Comm.deliverOOBMessage(msgOOB, "");
end
function handleAddUseEffect(msgOOB)
	local nodeEffect = DB.findNode(msgOOB.sEffectNode);
	if not nodeEffect then
		return;
	end

	local nUses = DB.getValue(nodeEffect, "remaininguses", 0);
	if nUses > 1 then
		nUses = nUses - 1;
		DB.setValue(nodeEffect, "remaininguses", "number", nUses);
	else
		-- Set remaining uses per round to 0 and set effect to skip
		DB.setValue(nodeEffect, "remaininguses", "number", 0);
		DB.setValue(nodeEffect, "isactive", "number", 2);
	end
end

--
--	EFFECT ACTION QUEUEING
--

local _nDelayedUpdates = 0;
local _tAddAfterDelay = {};
local _tExpireAfterDelay = {};
local _tRemoveAfterDelay = {};

function isDelayedUpdate()
	return (_nDelayedUpdates > 0);
end
function startDelayedUpdates()
	_nDelayedUpdates = _nDelayedUpdates + 1;
end
function endDelayedUpdates()
	_nDelayedUpdates = math.max(_nDelayedUpdates - 1, 0);

	if _nDelayedUpdates == 0 then
		local tAdd = {};
		local tExpire = {};
		local tRemove = {};
		for _,v in ipairs(_tAddAfterDelay) do
			table.insert(tAdd, v);
		end
		for _,v in ipairs(_tExpireAfterDelay) do
			table.insert(tExpire, v);
		end
		for _,v in ipairs(_tRemoveAfterDelay) do
			table.insert(tRemove, v);
		end
		_tAddAfterDelay = {};
		_tExpireAfterDelay = {};
		_tRemoveAfterDelay = {};

		for _,v in ipairs(tAdd) do
			EffectManager.addEffectByTable(v.rActor, v.tEffect);
		end
		for _,v in ipairs(tExpire) do
			EffectManager.expireEffectByNode(v.rActor, v.nodeEffect, v.tData);
		end
		for _,v in ipairs(tRemove) do
			EffectManager.removeEffect(v.rActor, v.nodeEffect);
		end
	end

	GameManager.callEventFunctions("onEffectDelayedUpdateComplete");
end
function addAfterDelay(tAddData)
	if not tAddData then
		return;
	end
	table.insert(_tAddAfterDelay, tAddData);
end
function expireAfterDelay(tExpireData)
	if not tExpireData or not tExpireData.nodeEffect then
		return;
	end
	table.insert(_tExpireAfterDelay, tExpireData);
end
function removeAfterDelay(tRemoveData)
	if not tRemoveData or not tRemoveData.nodeEffect then
		return;
	end
	table.insert(_tRemoveAfterDelay, tRemoveData);
end

--
--	EFFECT DATA HANDLING
--

function parseEffect(sEffect)
	if not sEffect then
		return {};
	end
	local tEffectPhrases = {};
	for s in sEffect:gmatch("([^;]*);?") do
		local sTrim = StringManager.trim(s);
		if sTrim ~= "" then
			table.insert(tEffectPhrases, sTrim);
		end
	end
	return tEffectPhrases;
end
function rebuildParsedEffect(tEffectPhrases)
	return table.concat(tEffectPhrases, "; ");
end

function parseEffectComps(tEffectData)
	if not tEffectData then
		return {};
	end
	if not tEffectData.tComps then
		tEffectData.tComps = {};
		for kComp,sComp in ipairs(EffectManager.parseEffect(tEffectData.sLabel)) do
			local tCompData = EffectManager.parseEffectCompSimple(sComp);
			tCompData.kComp = kComp;
			tCompData.node = tEffectData.node;
			table.insert(tEffectData.tComps, tCompData);
		end
	end
	return tEffectData.tComps;
end
function parseEffectCompSimple(s)
	-- NOTE: Optional secondary dice expression supported for all tags (i.e. "TAG: <dice>/<dice2> ...")
	--		Ex: "LIGHT: 10/15 light" => mod = 10, mod2 = 15, remainder = { "light" }
	--		Ex: "TAG: 1d6+2/2d4 fire" => dice = { "d6" }, mod = 2, dice2 = { "d4", "d4" }, mod2 = 0
	--		dice2 and mod2 are nil when no secondary expression is specified.
	local tCompData = {
		type = "",
		mod = 0,
		dice = {},
		remainder = {},
		sRemainder = "",
		original = StringManager.trim(s) or "",
	};
	if not s then
		return tCompData;
	end

	local sType = tCompData.original:match("^(@?%w+):");
	if sType then
		tCompData.type = sType;
		tCompData.sRemainder = StringManager.trim(tCompData.original:sub(#sType + 2));

		local sDice = tCompData.sRemainder:match("^([%.%w%d%+%-]+)");
		if DiceManager.isDiceString(sDice) then
			tCompData.dice, tCompData.mod = DiceManager.convertStringToDice(sDice);
			tCompData.sRemainder = StringManager.trim(tCompData.sRemainder:sub(#sDice + 1));

			-- Optional secondary dice expression (i.e. "TAG: <dice>/<dice2> ...")
			local sDice2Full, sDice2 = tCompData.sRemainder:match("^(/%s*([%.%w%d%+%-]+))");
			if DiceManager.isDiceString(sDice2) then
				tCompData.dice2, tCompData.mod2 = DiceManager.convertStringToDice(sDice2);
				tCompData.sRemainder = StringManager.trim(tCompData.sRemainder:sub(#sDice2Full + 1));
			end
		end
	else
		tCompData.sRemainder = StringManager.trim(s);
	end

	local nStartPhrase = 1;
	local i = 1;
	while i < #tCompData.sRemainder do
		local sCheck = tCompData.sRemainder:sub(i, i);
		if sCheck == "," then
			local sPhrase = StringManager.trim(tCompData.sRemainder:sub(nStartPhrase, i - 1)) or "";
			if sPhrase ~= "" then
				table.insert(tCompData.remainder, sPhrase);
			end
			nStartPhrase = i + 1;
		elseif sCheck == "(" then
			while i < #tCompData.sRemainder do
				if tCompData.sRemainder:sub(i, i) == ")" then
					break;
				end
				i = i + 1;
			end
		elseif sCheck == "[" then
			while i < #tCompData.sRemainder do
				if tCompData.sRemainder:sub(i, i) == "]" then
					break;
				end
				i = i + 1;
			end
		end
		i = i + 1;
	end
	local sPhrase = StringManager.trim(tCompData.sRemainder:sub(nStartPhrase, #tCompData.sRemainder)) or "";
	if sPhrase ~= "" then
		table.insert(tCompData.remainder, sPhrase);
	end

	return tCompData;
end
function rebuildParsedEffectCompSimple(tCompData)
	if not tCompData then
		return "";
	end

	local tOutput = {};
	if tCompData.type ~= "" then
		table.insert(tOutput, tCompData.type .. ":");
	end
	local sDiceString = StringManager.convertDiceToString(tCompData.dice, tCompData.mod);
	if tCompData.dice2 or tCompData.mod2 then
		local sDice2String = StringManager.convertDiceToString(tCompData.dice2, tCompData.mod2);
		if sDiceString == "" then
			sDiceString = "0";
		end
		if sDice2String == "" then
			sDice2String = "0";
		end
		sDiceString = string.format("%s/%s", sDiceString, sDice2String);
	end
	if sDiceString ~= "" then
		table.insert(tOutput, sDiceString);
	end
	if #(tCompData.remainder) > 0 then
		table.insert(tOutput, table.concat(tCompData.remainder, ","));
	end
	return table.concat(tOutput, " ");
end

--
--	ENCODING AND DECODING
--

function getEffect(nodeEffect)
	return EffectVarManager.getEffectDataFromNode(nodeEffect);
end
function setEffect(nodeEffect, rEffect)
	EffectVarManager.setNodeFromEffectData(nodeEffect, rEffect, true);
end

function getEffectsString(vActor, bPublicOnly, sSeparator)
	local tOutputEffects = {};
	for _,nodeEffect in ipairs(UtilityManager.getSortedNodeList(ActorEffectManager.getCombatantEffectNodes(vActor))) do
		local sEffect = EffectManager.getEffectString(nodeEffect, bPublicOnly);
		if sEffect ~= "" then
			table.insert(tOutputEffects, sEffect);
		end
	end
	return table.concat(tOutputEffects, sSeparator or " | ");
end
function getEffectString(nodeEffect, bPublicOnly)
	if not nodeEffect then
		return "";
	end
	if DB.getValue(nodeEffect, "isactive", 0) ~= 1 then
		return "";
	end

	local bGMOnly = false;
	if EffectVarManager.getEffectVarFromNode(nodeEffect, "nGMOnly", 0) == 1 then
		if Session.IsHost and not bPublicOnly then
			bGMOnly = true;
		else
			return "";
		end
	end

	local sOutput;
	if OptionsManager.isOption("EFFSHORT", "on") then
		sOutput = EffectVarManager.getEffectDisplayShort(nodeEffect);
	else
		sOutput = EffectVarManager.getEffectDisplayLong(nodeEffect);
	end

	if bGMOnly and (sOutput ~= "") then
		return string.format("(%s)", sOutput);
	end
	return sOutput;
end
function getEffectsStringConditions(vActor, bPublicOnly, sSeparator)
	local tOutputEffects = {};
	for _,nodeEffect in ipairs(UtilityManager.getSortedNodeList(ActorEffectManager.getCombatantEffectNodes(vActor))) do
		local sEffect = EffectManager.getEffectStringConditions(nodeEffect, bPublicOnly, sSeparator);
		if sEffect ~= "" then
			table.insert(tOutputEffects, sEffect);
		end
	end
	return table.concat(tOutputEffects, sSeparator or " | ");
end
function getEffectStringConditions(nodeEffect, bPublicOnly, sSeparator)
	if not nodeEffect then
		return "";
	end
	if DB.getValue(nodeEffect, "isactive", 0) ~= 1 then
		return "";
	end

	local bGMOnly = false;
	if EffectVarManager.getEffectVarFromNode(nodeEffect, "nGMOnly", 0) == 1 then
		if Session.IsHost and not bPublicOnly then
			bGMOnly = true;
		else
			return "";
		end
	end

	local tConditions = {};
	for _,sComp in ipairs(EffectManager.parseEffect(EffectVarManager.getEffectVarFromNode(nodeEffect, "sName", ""))) do
		local sLower = sComp:lower();
		if ActionCore.isCondition(sLower) then
			table.insert(tConditions, StringManager.capitalizeAll(sLower));
		end
	end
	if #tConditions <= 0 then
		return "";
	end

	local sOutput = table.concat(tConditions, sSeparator or " | ");
	if bGMOnly and (sOutput ~= "") then
		return string.format("(%s)", sOutput);
	end
	return sOutput;
end

function encodeEffect(rAction)
	local rRoll = {
		sType = "effect",
		sDesc = EffectManager.encodeEffectAsText(rAction),
		sInitSource = rAction and rAction.sInitSource,
		bSecret = ((rAction and rAction.nGMOnly or 0) ~= 0),
	};

	if EffectVarManager.hasEffectVar("nDuration") then
		rRoll.aDice = rAction and rAction.aDice or {};
		rRoll.nMod = rAction and rAction.nDuration or 0;
	end
	if StringManager.contains({ "self", "totargets" }, (rAction and rAction.sTargeting or "")) then
		rRoll.bSelfTarget = true;
	end

	GameManager.callFunction("onEffectRollEncode", rRoll, rAction);

	return rRoll;
end
function decodeEffect(rRoll)
	local rEffect = EffectManager.decodeEffectFromText(rRoll.sDesc, rRoll.bSecret);
	if not rEffect then
		return nil;
	end

	if EffectVarManager.hasEffectVar("nDuration") then
		rEffect.aDice = rRoll.aDice;
		rEffect.nMod = rRoll.nMod;
		rEffect.nDuration = ActionsManager.total(rRoll);
	end

	rEffect.sInitSource = rRoll.sInitSource;

	GameManager.callFunction("onEffectRollDecode", rRoll, rEffect);

	return rEffect;
end

function encodeEffectAsText(rEffect)
	if not rEffect then
		return "";
	end

	local tOutput = {};

	EffectVarManager.onEffectVarNameTextEncode(rEffect, tOutput);
	EffectVarManager.onEffectVarInitTextEncode(rEffect, tOutput);
	EffectVarManager.onEffectVarExpirationTextEncode(rEffect, tOutput);
	EffectVarManager.onEffectVarInitSourceTextEncode(rEffect, tOutput);
	EffectVarManager.onEffectVarTargetingTextEncode(rEffect, tOutput);
	EffectVarManager.onEffectVarSourceTextEncode(rEffect, tOutput);
	EffectVarManager.onEffectVarApplyTextEncode(rEffect, tOutput);
	EffectVarManager.onEffectVarUnitsTextEncode(rEffect, tOutput);

	local sEncode = GameManager.callFunction("onEffectTextEncode", rEffect);
	if (sEncode or "") ~= "" then
		table.insert(tOutput, sEncode);
	end

	return table.concat(tOutput, " ");
end
function decodeEffectFromText(sEffect, bSecret)
	local rEffect = {};

	local s = sEffect;

	s = GameManager.callFunction("onEffectTextDecode", s, rEffect) or s;

	local tInput = { sEffect = s, };

	EffectVarManager.onEffectVarUnitsTextDecode(tInput, rEffect);
	EffectVarManager.onEffectVarApplyTextDecode(tInput, rEffect);
	EffectVarManager.onEffectVarSourceTextDecode(tInput, rEffect);
	EffectVarManager.onEffectVarTargetingTextDecode(tInput, rEffect);
	EffectVarManager.onEffectVarInitSourceTextDecode(tInput, rEffect);
	EffectVarManager.onEffectVarExpirationTextDecode(tInput, rEffect);
	EffectVarManager.onEffectVarInitTextDecode(tInput, rEffect);
	EffectVarManager.onEffectVarNameTextDecode(tInput, rEffect);

	if (rEffect.sName or "") == "" then
		return nil;
	end

	rEffect.nGMOnly = bSecret and 1 or 0;

	return rEffect;
end

function decodeEffectFromDrag(draginfo, rActor)
	local rEffect = nil;

	local sDragType = draginfo.getType();
	local sDragDesc = "";

	local bEffectDrag = false;
	if sDragType == "effect" then
		bEffectDrag = true;
		sDragDesc = draginfo.getStringData();
	elseif sDragType == "number" then
		if sDragDesc:match("%[" .. Interface.getString("action_effect_tag")) then
			bEffectDrag = true;
			sDragDesc = draginfo.getDescription();
		end
	end

	if bEffectDrag then
		rEffect = EffectManager.decodeEffectFromText(sDragDesc, draginfo.getSecret());
		if rEffect then
			if EffectVarManager.hasEffectVar("nDuration") then
				rEffect.nDuration = draginfo.getNumberData();
			end
			GameManager.callFunction("onEffectDragDecode", draginfo, rEffect);
			if not rActor then
				EffectManager.onUntargetedDrop(rEffect);
			end
		end
	end

	return rEffect;
end

--
--	EFFECT TARGETING
--

function setEffectSource(nodeEffect, nodeCT)
	if not nodeCT then
		return;
	end
	local nodeEffectActor = DB.getChild(nodeEffect, "...");
	if not nodeEffectActor then
		return;
	end

	local sSourcePath = DB.getPath(nodeCT);
	if DB.getPath(nodeEffectActor) == sSourcePath then
		EffectVarManager.setEffectVarToNode(nodeEffect, "sSource", "");
	else
		EffectVarManager.setEffectVarToNode(nodeEffect, "sSource", sSourcePath);
	end
end

function isTargetedEffect(nodeEffect)
	return (DB.getChildCount(nodeEffect, "targets") > 0);
end
function isEffectTarget(nodeEffect, rActor)
	if not rActor then
		return false;
	end
	local sTargetCT = ActorManager.getCTNodeName(rActor);
	if sTargetCT == "" then
		return false;
	end

	local bMatch = false;
	for _,v in ipairs(DB.getChildList(nodeEffect, "targets")) do
		if DB.getValue(v, "noderef", "") == sTargetCT then
			bMatch = true;
			break;
		end
	end
	return bMatch;
end
function getEffectTargets(nodeEffect, bUseName)
	local tTargets = {};
	for _,nodeTarget in ipairs(DB.getChildList(nodeEffect, "targets")) do
		local sNode = DB.getValue(nodeTarget, "noderef", "");
		if bUseName then
			table.insert(tTargets, ActorManager.getDisplayName(sNode));
		else
			table.insert(tTargets, sNode);
		end
	end
	return tTargets;
end
function addEffectTarget(vEffect, sTargetNode)
	if sTargetNode == "" then
		return;
	end

	local nodeTargetList = nil;
	if type(vEffect) == "string" then
		nodeTargetList = DB.createChild(DB.findNode(vEffect), "targets");
	elseif type(vEffect) == "databasenode" then
		nodeTargetList = DB.createChild(vEffect, "targets");
	end
	if not nodeTargetList then
		return;
	end

	for _,nodeTarget in ipairs(DB.getChildList(nodeTargetList)) do
		if (DB.getValue(nodeTarget, "noderef", "") == sTargetNode) then
			return;
		end
	end

	local nodeNewTarget = DB.createChild(nodeTargetList);
	if nodeNewTarget then
		DB.setValue(nodeNewTarget, "noderef", "string", sTargetNode);
	end
end
function setEffectFactionTargets(nodeEffect, sFaction, bNegated)
	if not nodeEffect then
		return;
	end

	EffectManager.clearEffectTargets(nodeEffect);

	local sTrackerKey = CombatManager.getTrackerKeyFromCT(nodeEffect);

	for _,nodeCT in pairs(CombatManager.getCombatantNodes(sTrackerKey)) do
		if bNegated then
			if CombatManager.getFactionFromCT(nodeCT) ~= sFaction then
				EffectManager.addEffectTarget(nodeEffect, DB.getPath(nodeCT));
			end
		else
			if CombatManager.getFactionFromCT(nodeCT) == sFaction then
				EffectManager.addEffectTarget(nodeEffect, DB.getPath(nodeCT));
			end
		end
	end
end
function clearEffectTargets(nodeEffect)
	DB.deleteChildren(nodeEffect, "targets");
end

--
--	MISC
--

function message(sMsg, vActor, bGMOnly, sUser)
	if OptionsManager.isOption("EFFSHORT", "on") then
		local sLabel = Interface.getString("effect_label");
		local sMatchPattern = "^%s*" .. sLabel .. "%s*%[([^%]]*)%]";
		local sEffect = sMsg:match(sMatchPattern);
		if sEffect then
			local tEffectPhrases = EffectManager.parseEffect(sEffect);
			if #tEffectPhrases > 1 then
				local sReplacePattern = "^%s*" .. sLabel .. "%s*%[[^%]]*%]";
				sMsg = sMsg:gsub(sReplacePattern, string.format("%s [%s*]", sLabel, tEffectPhrases[1]))
			end
		end
	end

	local msg = {
		font = "msgfont",
		icon = "action_effect",
		text = sMsg,
	};
	if vActor then
		msg.text = string.format("%s [on %s]", msg.text, ActorManager.getDisplayName(vActor));
	end

	if bGMOnly then
		msg.secret = true;
		if Session.IsHost then
			Comm.addChatMessage(msg);
		else
			Comm.deliverChatMessage(msg, Session.UserName);
		end
	elseif sUser then
		if sUser == "" then
			msg.secret = true;
			Comm.addChatMessage(msg);
		else
			Comm.deliverChatMessage(msg, sUser);
		end
	else
		Comm.deliverChatMessage(msg);
	end
end

function isGMEffect(vActor, nodeEffect)
	if EffectVarManager.getEffectVarFromNode(nodeEffect, "nGMOnly", 0) == 1 then
		return true;
	end
	if vActor then
		local rActor = ActorManager.resolveActor(vActor);
		if rActor then
			if CombatManager.isCTHidden(ActorManager.getCTNode(rActor)) then
				return true;
			end
		end
	end
	return false;
end
function hasDuration(nodeEffect)
	return (EffectVarManager.getEffectVarFromNode(nodeEffect, "nDuration", 0) > 0);
end
function getSourceActor(vEffect)
	if type(vEffect) == "table" then
		return ActorManager.resolveActor(vEffect.sSource);
	end
	local nodeEffect = ((type(vEffect) == "string") and DB.findNode(vEffect)) or vEffect;
	return ActorManager.resolveActor(EffectVarManager.getEffectVarFromNode(nodeEffect, "sSource", ""));
end

function onEffectFilter(w)
	return GameManager.callFunction("onEffectDisplayFilter", w);
end
function onEffectDisplayFilterDefault(w)
	local node = w.getDatabaseNode();
	if EffectVarManager.getEffectVarFromNode(node, "nGMOnly", 0) == 1 then
		return false;
	end
	if not DB.isOwner(node) then
		if DB.getValue(node, "isactive", 1) == 0 then
			return false;
		end
	end
	return true;
end

function buildEffectOutput(v)
	if type(v) == "number" then
		if v ~= 0 then
			return string.format("[%s %+d]", Interface.getString("effects_tag"), v);
		end
	elseif type(v) == "string" then
		if v ~= "" then
			return string.format("[%s %s]", Interface.getString("effects_tag"), v);
		end
	end
	return string.format("[%s]", Interface.getString("effects_tag"));
end
function buildEffectDiceModOutput(tDice, nMod)
	return EffectManager.buildEffectOutput(StringManager.convertDiceToString(tDice, nMod, true));
end
function buildDefEffectOutput(v)
	if type(v) == "number" then
		if v ~= 0 then
			return string.format("[%s %+d]", Interface.getString("effects_def_tag"), v);
		end
	elseif type(v) == "string" then
		if v ~= "" then
			return string.format("[%s %s]", Interface.getString("effects_def_tag"), v);
		end
	end
	return string.format("[%s]", Interface.getString("effects_def_tag"));
end

function onUntargetedDrop(rEffect)
	if not rEffect then
		return;
	end

	EffectManager.onEffectEval(nil, rEffect);

	for k,_ in pairs(rEffect) do
		local tVar = EffectVarManager.getEffectVar(k);
		if tVar and tVar.bClearOnUntargetedDrop then
			rEffect[k] = nil;
		end
	end
end

function applyTurnChangeEffect(rActor, sEffectTag, fnAction)
	for _, tCompData in ipairs(EffectManager.getCompsDataByTag(rActor, sEffectTag)) do
		if fnAction then
			fnAction(rActor, tCompData);
		end
	end
end
function applyTurnChangeEffectText(rActor, sEffectTag, fnAction)
	for _, tCompData in ipairs(EffectManager.getCompsDataByText(rActor, sEffectTag)) do
		if fnAction then
			fnAction(rActor, tCompData);
		end
	end
end

--
--	LEGACY
--

function getEffectVarMap()
	return EffectVarManager.getEffectVarMap();
end
function getEffectVar(sVar)
	return EffectVarManager.getEffectVar(sVar);
end
function registerEffectVar(sVar, tData)
	EffectVarManager.setEffectVar(sVar, tData);
end
function registerEffectCompType(sTag, tOptions)
	EffectManager.setTagOptions(sTag, tOptions);
end

function hasEffect(rActor, sEffect, rTarget, bTargetedOnly)
	local tData = {
		rTarget = rTarget,
		bTargetedOnly = bTargetedOnly,
	};
	return EffectManager.hasText(rActor, sEffect, tData);
end
function getEffectsByType(rActor, sEffectTag, rTarget, bTargetedOnly)
	local tData = {
		rTarget = rTarget,
		bTargetedOnly = bTargetedOnly,
	};
	return EffectManager.getCompsDataByTag(rActor, sEffectTag, tData);
end

function addEffect(sUser, _, vActor, rEffect, bShowMsg)
	if not rEffect then
		return nil;
	end

	rEffect.sUser = sUser;
	rEffect.bSkipAnnounce = not bShowMsg;
	return EffectManager.addEffectByTable(vActor, rEffect);
end
function notifyApply(rEffect, vTargets)
	if type(vTargets) == "table" then
		for _, v in pairs(vTargets) do
			EffectManager.addEffectByTable(v, rEffect);
		end
	else
		EffectManager.addEffectByTable(vTargets, rEffect);
	end
end
function expireEffect(vActor, nodeEffect, nExpireComp, bSkipAnnounce)
	EffectManager.expireEffectByNode(vActor, nodeEffect, { nExpireComp = nExpireComp, bSkipAnnounce = bSkipAnnounce, });
end
function notifyExpire(varEffect, nMatch, bImmediate, bSkipAnnounce)
	local nodeEffect;
	if type(varEffect) == "string" then
		nodeEffect = DB.findNode(varEffect);
	elseif type(varEffect) == "databasenode" then
		nodeEffect = varEffect;
	else
		return;
	end
	EffectManager.expireEffectByNode(nil, nodeEffect, { nExpireComp = nMatch, bImmediate = bImmediate, bSkipAnnounce = bSkipAnnounce, });
end

function isLocked()
	return false;
end
function lock()
	-- Do nothing
end
function unlock()
	-- Do nothing
end
function expireOnUnlock()
	-- Do nothing
end

function setCustomOnEffectAddStart(fn)
	GameManager.setFunction("onEffectAddLegacy", fn);
end
function setCustomOnEffectAddIgnoreCheck(fn)
	GameManager.setFunction("onEffectAddIgnoreCheckLegacy", fn);
end
function setCustomOnEffectAddEnd(fn)
	GameManager.setFunction("onEffectPostAddLegacy", fn);
end
function setCustomOnEffectExpire(fn)
	GameManager.setFunction("onEffectExpireLegacy", fn);
end
function setCustomOnEffectDragDecode(fn)
	GameManager.setFunction("onEffectDragDecode", fn);
end
function setCustomOnEffectRollEncode(fn)
	GameManager.setFunction("onEffectRollEncode", fn);
end
function setCustomOnEffectRollDecode(fn)
	GameManager.setFunction("onEffectRollDecode", fn);
end
function setCustomOnEffectTextEncode(fn)
	GameManager.setFunction("onEffectTextEncode", fn);
end
function setCustomOnEffectTextDecode(fn)
	GameManager.setFunction("onEffectTextDecode", fn);
end
function setCustomOnActorStartTurn(fn)
	GameManager.setFunction("onActorStartTurn", fn);
end
function setCustomOnActorEndTurn(fn)
	GameManager.setFunction("onActorEndTurn", fn);
end
local _fnOnEffectActorStartTurnLegacy;
local _fnOnEffectActorEndTurnLegacy;
function setCustomOnEffectActorStartTurn(fn)
	_fnOnEffectActorStartTurnLegacy = fn;
	GameManager.setFunction("onEffectActorStartTurn", EffectManager.onEffectActorStartTurnLegacy);
end
function onEffectActorStartTurnLegacy(rActor, nodeEffect)
	_fnOnEffectActorStartTurnLegacy(ActorManager.getCTNode(rActor), nodeEffect);
end
function setCustomOnEffectActorEndTurn(fn)
	_fnOnEffectActorEndTurnLegacy = fn;
	GameManager.setFunction("onEffectActorEndTurn", EffectManager.onEffectActorEndTurnLegacy);
end
function onEffectActorEndTurnLegacy(rActor, nodeEffect)
	_fnOnEffectActorEndTurnLegacy(ActorManager.getCTNode(rActor), nodeEffect);
end
function setCustomOnEffectStartTurn(fn)
	EffectManager.setCustomOnEffectActorStartTurn(fn);
end
function setCustomOnEffectEndTurn(fn)
	EffectManager.setCustomOnEffectActorEndTurn(fn);
end