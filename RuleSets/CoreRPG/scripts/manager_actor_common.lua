--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

function onInit()
	ActorCommonManager.setSpaceReachFromActorSizeCallback("D20", ActorCommonManager.getSpaceReachFromActorSizeD20);
	ActorCommonManager.setSpaceReachFromActorSizeCallback("4E", ActorCommonManager.getSpaceReachFromActorSize4E);
	ActorCommonManager.setSpaceReachFromActorSizeCallback("5E", ActorCommonManager.getSpaceReachFromActorSize5E);

	GameManager.setFunction("onActorEffectDamageAdjust", ActorCommonManager.getEffectsDamageAdjustDefault);
	GameManager.setFunction("onActorEffectConditionImmune", ActorCommonManager.getEffectsConditionImmunitiesDefault);
end

--
--	SIZE HANDLING
--

local _bDefaultSizeHandling = false;
function useDefaultSizeHandling()
	return _bDefaultSizeHandling;
end
function setDefaultSizeHandling(bState)
	_bDefaultSizeHandling = bState;
end
function addDefaultSizeHandling()
	ActorCommonManager.setDefaultSizeHandling(true);

	EffectManager.setTagOptions("SIZE", { bIgnoreExpire = true, bIgnoreTarget = true });
	EffectManager.setTagOptions("SPACE", { bIgnoreExpire = true, bIgnoreTarget = true });
	EffectManager.setTagOptions("ADDSPACE", { bIgnoreExpire = true, bIgnoreTarget = true });
	EffectManager.setTagOptions("REACH", { bIgnoreExpire = true, bIgnoreTarget = true });
	EffectManager.setTagOptions("ADDREACH", { bIgnoreExpire = true, bIgnoreTarget = true });

	if Session.IsHost then
		CombatManager.setCustomDeleteCombatantEffectHandler(ActorCommonManager.onActorEffectDelete);
		CombatManager.addAllCombatantEffectFieldChangeHandler("isactive", "onUpdate", ActorCommonManager.onActorEffectFieldUpdate);
		CombatManager.addAllCombatantEffectFieldChangeHandler("label", "onUpdate", ActorCommonManager.onActorEffectFieldUpdate);
	end
end
function onActorEffectDelete(nodeCT)
	ActorCommonManager.onSizeChanged(nodeCT);
end
function onActorEffectFieldUpdate(nodeField)
	local nodeEffect = DB.getParent(nodeField);
	EffectIndexManager.clearEffectData(nodeEffect);
	ActorCommonManager.onSizeChanged(DB.getChild(nodeEffect, "..."));
end

--
--	BONUSES
--

function getAbilityScore(rActor, sKey, ...)
	return GameManager.callFunction("onActorGetAbilityScore", rActor, sKey, ...) or 0;
end
function getBonus(rActor, sKey, ...)
	return GameManager.callFunction("onActorGetBonus", rActor, sKey, ...) or 0;
end
-- Assumes return of nEffectsBonus, nEffectsCount
function getEffectsBonus(rActor, sKey, ...)
	local fn = GameManager.getFunction("onActorGetEffectsBonus");
	if fn then
		return fn(rActor, sKey, ...);
	end
	return 0, 0;
end

--
--	EFFECTS
--

function getEffectsDamageAdjust(sEffectTag, rActor, rSource, rRoll, tApplyData)
	return GameManager.callFunction("onActorEffectDamageAdjust", sEffectTag, rActor, rSource, rRoll, tApplyData);
end
function getEffectsDamageAdjustDefault(sEffectTag, rActor, rSource, rRoll, tApplyData)
	return EffectManager.getCompsDataByTag(rActor, sEffectTag, { rTarget = rSource, tActionTags = rRoll.tActionTags, bFilterAllDesc = true, tFilter = tApplyData.tDamageTypeList, });
end
function getEffectsConditionImmunities(rActor, rSource, tEffectConditions)
	return GameManager.callFunction("onActorEffectConditionImmune", rActor, rSource, tEffectConditions);
end
function getEffectsConditionImmunitiesDefault(rActor, rSource, tEffectConditions)
	local setCondImmune = SetManager.new();
	for _,tCompData in ipairs(EffectManager.getCompsDataByTag(rActor, "IMMUNE", { rTarget = rSource, tFilter = tEffectConditions, bFilterAllDesc = true, })) do
		for _,s in ipairs(tCompData.remainder) do
			local sLower = s:lower();
			if ActionCore.isCondition(sLower) then
				SetManager.add(setCondImmune, sLower);
			end
		end
	end
	return SetManager.toarray(setCondImmune);
end

--
--	REST
--

function rest(vActor, sRestType)
	local rActor = ActorManager.resolveActor(vActor);
	GameManager.callFunction("onActorRest", rActor, sRestType);
end
function restDefault(rActor, sRestType)
	if not ActorManager.checkRest(rActor, sRestType) then
		return false;
	end

	ActorCommonManager.resetHealth(rActor, sRestType);
	EffectManagerD20.clearRestExpiringEffectsByActor(rActor, sRestType);
	return true;
end
function resetHealth(rActor, sRestType)
	if sRestType ~= "long" then
		return;
	end

	local nodeActor = ActorManager.getCreatureNode(rActor);
	if not nodeActor then
		return;
	end

	GameManager.setRecordFieldValue(rActor, "hptemp", "number", 0)

	if not ActorManager.canHeal(rActor, "rest") then
		ChatManager.Message(Interface.getString("message_healblocked"), false, rActor);
		return;
	end

	if ActorManager.isPC(rActor) then
		if GameManager.isOption("rest", "2E") then
			-- No health automatically healed in 2E
		elseif GameManager.isOption("rest", { "3.5E", "PF" }) then
			-- NOTE: Lethal damage in D20 heals at level per overnight rest
			local nWounds = GameManager.getRecordFieldValue(rActor, "wounds", 0);
			nWounds = math.max(nWounds - math.max(DB.getValue(nodeActor, "level", 0), 1), 0);
			GameManager.setRecordFieldValue(rActor, "wounds", "number", nWounds);
		elseif GameManager.isOption("rest", "PF2") then
			-- NOTE: Damage in PF2 heals at level * CON per overnight rest
			local nLevel = DB.getValue(nodeActor, "level", 0);
			local nConBonus = math.max(DB.getValue(nodeActor, "abilities.constitution.bonus", 1), 1);
			local nWounds = GameManager.getRecordFieldValue(rActor, "wounds", 0);
			nWounds = math.max(nWounds - (nLevel * nConBonus), 0);
			GameManager.setRecordFieldValue(rActor, "wounds", "number", nWounds);
		else
			GameManager.setRecordFieldValue(rActor, "wounds", "number", 0);
		end

		if GameManager.hasOption("nonlethal") then
			-- NOTE: Nonlethal damage in D20 heals at level per hour (assume 8 hours for long rest)
			local nNonlethal = GameManager.getRecordFieldValue(rActor, "nonlethal", 0);
			nNonlethal = math.max(nNonlethal - (DB.getValue(nodeActor, "level", 0) * 8), 0);
			GameManager.setRecordFieldValue(rActor, "nonlethal", "number", nNonlethal);
		end
		if GameManager.hasOption("deathsave") then
			GameManager.setRecordFieldValue(rActor, "deathsavesuccess", "number", 0);
			GameManager.setRecordFieldValue(rActor, "deathsavefail", "number", 0);
		end
		if GameManager.hasOption("healsurge") then
			DB.setValue(nodeActor, "hp.surgesused", "number", 0);
		end

		if GameManager.isOption("rest", { "3.5E", "PF", "PF2" }) then
			-- Heal ability damage
			for _,sAbility in pairs(DataCommon.abilities) do
				local sSubPath = "abilities." .. sAbility .. ".damage";
				local nAbilityDamage = DB.getValue(nodeActor, sSubPath, 0);
				if nAbilityDamage > 0 then
					DB.setValue(nodeActor, sSubPath, "number", nAbilityDamage - 1);
				end
			end
		end
	else
		if GameManager.isOption("rest", "2E") then
			-- No health automatically healed in 2E
		elseif GameManager.isOption("rest", { "3.5E", "PF" }) then
			-- Undefined
		elseif GameManager.isOption("rest", "PF2") then
			-- Undefined
		else
			GameManager.setRecordFieldValue(rActor, "wounds", "number", 0);
		end
		if GameManager.hasOption("nonlethal") then
			GameManager.setRecordFieldValue(rActor, "nonlethal", "number", 0);
		end
		if GameManager.hasOption("deathsave") then
			GameManager.setRecordFieldValue(rActor, "deathsavesuccess", "number", 0);
			GameManager.setRecordFieldValue(rActor, "deathsavefail", "number", 0);
		end
		if GameManager.hasOption("healsurge") then
			local nLevel = tonumber(DB.getValue(nodeActor, "levelrole", ""):lower():match("level (%d*)")) or 0;
			local nHealSurges = ((nLevel > 20) and 3) or ((nLevel > 10) and 2) or 1;
			DB.setValue(nodeActor, "healsurgeremaining", "number", nHealSurges);
		end
	end

	if not ActorHealthManager.isDyingOrDead(rActor) then
		EffectManager.removeCondition(rActor, "Prone");
		EffectManager.removeCondition(rActor, "Stable");
		EffectManager.removeCondition(rActor, "Unconscious");
	end
end

--
--	SPACE AND REACH
--

function getSpaceReach(v)
	local rActor = ActorManager.resolveActor(v);
	if not rActor then
		local nDU = GameSystem.getDistanceUnitsPerGrid();
		return nDU, nDU;
	end

	local sRecordType = ActorManager.getRecordType(rActor);
	if ActorCommonManager.hasRecordTypeSpaceReachCallback(sRecordType) then
		local nSpace, nReach = ActorCommonManager.onRecordTypeSpaceReachEvent(sRecordType, rActor);
		if nSpace then
			return nSpace, nReach;
		end
	end

	-- Default (1x1 grid)
	local nDU = GameSystem.getDistanceUnitsPerGrid();
	return nDU, nDU;
end

local _tSpaceReachCallbacks = {};
function setRecordTypeSpaceReachCallback(sRecordType, fn)
	UtilityManager.setKeySingleCallback(_tSpaceReachCallbacks, sRecordType, fn);
end
function getRecordTypeSpaceReachCallback(sRecordType)
	return UtilityManager.getKeySingleCallback(_tSpaceReachCallbacks, sRecordType);
end
function hasRecordTypeSpaceReachCallback(sRecordType)
	return UtilityManager.hasKeySingleCallback(_tSpaceReachCallbacks, sRecordType);
end
function onRecordTypeSpaceReachEvent(sRecordType, rActor)
	return UtilityManager.performKeySingleCallback(_tSpaceReachCallbacks, sRecordType, rActor);
end

local _sDefaultSpaceReachFromActorSizeKey = nil;
local _tSpaceReachToActorSizeCallbacks = {};
function setDefaultSpaceReachFromActorSizeKey(sKey)
	_sDefaultSpaceReachFromActorSizeKey = sKey;
end
function setSpaceReachFromActorSizeCallback(sKey, fn)
	UtilityManager.setKeySingleCallback(_tSpaceReachToActorSizeCallbacks, sKey, fn);
end
function getSpaceReachFromActorSizeCallback(sKey)
	return UtilityManager.getKeySingleCallback(_tSpaceReachToActorSizeCallbacks, sKey);
end
function getSpaceReachFromActorSize(nActorSize, sFallbackKey)
	return UtilityManager.performKeySingleCallback(_tSpaceReachToActorSizeCallbacks, _sDefaultSpaceReachFromActorSizeKey or sFallbackKey, nActorSize);
end

-- NOTE: CoreRPG-based sizes with explicit space and reach fields
function getSpaceReachCore(rActor)
	local nSpace = GameSystem.getDistanceUnitsPerGrid();
	local nReach = nSpace;

	local nodeActor = ActorManager.getCreatureNode(rActor);
	if nodeActor then
		nSpace = tonumber(DB.getValue(nodeActor, "space")) or nSpace;
		nReach = tonumber(DB.getValue(nodeActor, "reach")) or nReach;
	end

	return nSpace, nReach;
end
-- Uses 5E as default key (if none defined) for backward compatibility
function getSpaceReachFromSizeFieldCore(rActor)
	local nBaseSize = ActorCommonManager.getCreatureSizeFromSizeFieldCore(rActor);
	local nActorSize = ActorCommonManager.getCreatureSizeWithEffects(rActor, nBaseSize);
	return ActorCommonManager.getSpaceReachFromActorSize(nActorSize, "5E");
end
-- Uses 4E as default key (if none defined) for backward compatibility
function getSpaceReachFromTypeFieldCore(rActor)
	local nBaseSize = ActorCommonManager.getCreatureSizeFromTypeFieldCore(rActor);
	local nActorSize = ActorCommonManager.getCreatureSizeWithEffects(rActor, nBaseSize);
	return ActorCommonManager.getSpaceReachFromActorSize(nActorSize, "4E");
end
-- NOTE: Legacy Pathfinder and D&D 3.5E-based sizes with explicit space and reach combined field
function getSpaceReachDnD3Legacy(rActor)
	local nBaseSize = ActorCommonManager.getCreatureSizeFromTypeFieldCore(rActor);
	local nActorSize = ActorCommonManager.getCreatureSizeWithEffects(rActor, nBaseSize);

	local nSpace, nReach;
	if ActorCommonManager.isCreatureTypeDnD(rActor, "swarm") then
		local nDU = GameSystem.getDistanceUnitsPerGrid();
		nSpace = nDU * 2;
		nReach = 0;
	else
		nSpace, nReach = ActorCommonManager.getSpaceReachFromActorSize(nActorSize, "D20");
	end

	if nActorSize > 0 then
		local bTall = true;
		local nFieldSpace, nFieldReach = ActorCommonManager.getSpaceReachFromField(rActor);
		if nFieldSpace then
			bTall = (nFieldSpace <= nFieldReach);
		end
		if not bTall then
			local nDU = GameSystem.getDistanceUnitsPerGrid();
			if nActorSize == 4 then
				nReach = nReach - (2 * nDU);
			elseif nActorSize > 4 then
				nReach = nReach - (3 * nDU);
			else
				nReach = nReach - nDU;
			end
		end
	end

	return nSpace, nReach;
end

-- From 5E SRD: Tiny (-2), Small (-1), Medium (0), Large (1), Huge (2), Gargantuan (3)
-- Plus custom Colossal (4)
function getSpaceReachFromActorSize5E(nActorSize)
	local nSpace = GameSystem.getDistanceUnitsPerGrid();
	local nReach = nSpace;
	-- Medium (0) and Small (-1) just return 1 unit each

	if nActorSize == 1 then
		nSpace = nSpace * 2;
	elseif nActorSize == 2 then
		nSpace = nSpace * 3;
	elseif nActorSize == 3 then
		nSpace = nSpace * 4;
	elseif nActorSize > 3 then
		nSpace = nSpace * 6;
	elseif nActorSize == -1 then
		nSpace = nSpace * 0.75;
	elseif nActorSize < -1 then
		nSpace = nSpace * 0.5;
	end

	return nSpace, nReach;
end
-- From 4E Rules: Tiny (-2), Small (-1), Medium (0), Large (1), Huge (2), Gargantuan (3)
-- Plus custom Colossal (4)
function getSpaceReachFromActorSize4E(nActorSize)
	local nSpace = GameSystem.getDistanceUnitsPerGrid();
	local nReach = nSpace;
	-- Medium (0) and Small (-1) just return 1 unit each

	if nActorSize == 1 then
		nSpace = nSpace * 2;
		--nReach = 1 unit;
	elseif nActorSize == 2 then
		nSpace = nSpace * 3;
		nReach = nReach * 2;
	elseif nActorSize == 3 then
		nSpace = nSpace * 4;
		nReach = nReach * 3;
	elseif nActorSize > 3 then
		nSpace = nSpace * 6;
		nReach = nReach * 4;
	elseif nActorSize == -1 then
		nSpace = nSpace * 0.75;
	elseif nActorSize < -1 then
		nSpace = nSpace * 0.5;
		nReach = 0;
	end

	return nSpace, nReach;
end
-- From d20 SRD: Fine (-4), Diminutive (-3), Tiny (-2), Small (-1), Medium (0), Large (1), Huge (2), Gargantuan (3), Colossal (4)
-- Plus custom Epic (5)
function getSpaceReachFromActorSizeD20(nActorSize)
	local nSpace = GameSystem.getDistanceUnitsPerGrid();
	local nReach = nSpace;
	-- Medium (0) and Small (-1) just return 1 unit each

	if nActorSize == 1 then
		nSpace = nSpace * 2;
		nReach = nReach * 2;
	elseif nActorSize == 2 then
		nSpace = nSpace * 3;
		nReach = nReach * 3;
	elseif nActorSize == 3 then
		nSpace = nSpace * 4;
		nReach = nReach * 4;
	elseif nActorSize == 4 then
		nSpace = nSpace * 6;
		nReach = nReach * 6;
	elseif nActorSize > 4 then
		nSpace = nSpace * 8;
		nReach = nReach * 8;
	elseif nActorSize == -1 then
		nSpace = nSpace * 0.75;
	elseif nActorSize < -1 then
		nSpace = nSpace * 0.5;
		nReach = 0;
	end

	return nSpace, nReach;
end
function getSpaceReachFromField(rActor)
	local nodeActor = ActorManager.getCreatureNode(rActor);
	if not nodeActor then
		return nil, nil;
	end

	local sSpaceReach = StringManager.trim(DB.getValue(nodeActor, "spacereach", ""));
	if sSpaceReach == "" then
		return nil, nil;
	end

	local sSpace, sReach = sSpaceReach:match("(%d+)[^/]*/%s*(%d+)");
	if not sSpace then
		return nil, nil;
	end

	return tonumber(sSpace) or GameSystem.getDistanceUnitsPerGrid(), tonumber(sReach) or GameSystem.getDistanceUnitsPerGrid();
end

--
--	SIZE MANAGEMENT
--

function getSize(rActor, tData)
	local nBaseSize = ActorCommonManager.getBaseSize(rActor);
	return ActorCommonManager.getCreatureSizeWithEffects(rActor, nBaseSize, tData), nBaseSize;
end
function getBaseSize(rActor)
	local s = GameManager.getRecordFieldValue(rActor, "size", "");
	return (ActorCommonManager.getSizeFromField(s)) or 0;
end
function onSizeChanged(vActor)
	local rActor = ActorManager.resolveActor(vActor);

	local nodeCT = ActorManager.getCTNode(rActor);
	if nodeCT then
		local nSpace, nReach = ActorCommonManager.getSpaceReach(rActor);

		if ActorCommonManager.useDefaultSizeHandling() then
			nSpace = EffectManager.getMaxMod(rActor, "SPACE") or nSpace;
			nSpace = nSpace + EffectManager.getBonusMod(rActor, "ADDSPACE");
			nReach = EffectManager.getMaxMod(rActor, "REACH") or nReach;
			nReach = nReach + EffectManager.getBonusMod(rActor, "ADDREACH");
		end

		DB.setValue(nodeCT, "space", "number", nSpace);
		DB.setValue(nodeCT, "reach", "number", nReach);
	end

	GameManager.callEventFunctions("onActorSizeChanged", rActor);
end

function getSizeFromField(s)
	if (s or "") == "" then
		return nil, nil;
	end
	local tLines = StringManager.splitLines(s);
	for _,sLine in ipairs(tLines) do
		local tWords = StringManager.splitWords(sLine);
		for _,sWord in ipairs(tWords) do
			local nSize = ActorCommonManager.convertSizeStringToNumber(sWord);
			if nSize then
				return nSize, sWord;
			end
		end
	end
	return nil, nil;
end
function convertSizeStringToNumber(s)
	return ActionCore.getCreatureSizes()[(s or ""):lower()];
end
function convertSizeNumberToString(n)
	for k,v in pairs(ActionCore.getCreatureSizes()) do
		if (#k > 1) and (v == n) then
			return StringManager.capitalize(k);
		end
	end
	return nil;
end

function getCreatureSizeFromSizeFieldCore(rActor)
	return ActorCommonManager.getBaseSizeFromField(rActor, "size");
end
function getCreatureSizeFromTypeFieldCore(rActor)
	return ActorCommonManager.getBaseSizeFromField(rActor, "type");
end
function getBaseSizeFromField(rActor, sField)
	if (sField or "") == "" then
		return 0;
	end
	local nodeActor = ActorManager.getCreatureNode(rActor);
	if not nodeActor then
		return 0;
	end
	return ActorCommonManager.getSizeFromField(DB.getValue(nodeActor, sField, "")) or 0;
end
function getCreatureSizeWithEffects(rActor, nBaseSize, tData)
	if not ActorCommonManager.useDefaultSizeHandling() then
		return nBaseSize;
	end

	local nSize = nBaseSize;
	for _, tCompData in ipairs(EffectManager.getCompsDataByTag(rActor, "SIZE", tData)) do
		local nCompSize = ActorCommonManager.convertSizeStringToNumber(tCompData.sRemainder:lower());
		if nCompSize then
			return nCompSize;
		end
		nSize = nSize + tCompData.mod;
	end
	if nSize == nBaseSize then
		return nSize;
	end

	if ActorCommonManager.convertSizeNumberToString(nSize) then
		return nSize;
	end

	local tSizes = ActionCore.getCreatureSizes();
	local nMin = 0;
	local nMax = 0;
	for _,n in pairs(tSizes) do
		nMin = math.min(nMin, n);
		nMax = math.max(nMax, n);
	end
	return ((nSize <= 0) and nMin) or nMax;
end

function incrementSizeField(s, n)
	local nSize, sSize = ActorCommonManager.getSizeFromField(s);
	if not sSize then
		return nil;
	end
	local sSizeNew = ActorCommonManager.convertSizeNumberToString(nSize + n);
	if not sSizeNew then
		return nil;
	end
	return s:gsub(sSize, sSizeNew, 1);
end

--
--	SIZE TYPE CHECKS
--

function isCreatureSizeDnD(rActor, sParam, tCheckData, tEffectData)
	local tParamSize = ActorCommonManager.internalIsCreatureSizeDnDParam(sParam);
	if not tParamSize then
		return false;
	end

	local tData = {
		tEffectsIgnore = UtilityManager.copyDeep(tCheckData and tCheckData.tEffectsIgnore) or {};
		bIgnoreExpire = true,
		tParent = tCheckData,
	};
	table.insert(tData.tEffectsIgnore, tEffectData and tEffectData.node);

	local nActorSize = ActorCommonManager.getSize(rActor, tData);
	return ActorCommonManager.internalIsCreatureSizeDnDCompare(tParamSize, nActorSize);
end
function internalIsCreatureSizeDnDParam(sParam)
	if not sParam then
		return nil;
	end

	local tSizes = ActionCore.getCreatureSizes();
	local tParamSize = {};
	for _,sParamComp in ipairs(StringManager.splitByPattern(sParam:lower(), ",", true)) do
		local sParamCompLower = StringManager.trim(sParamComp):lower();
		local sParamOp = sParamCompLower:match("^[<>]?=?");
		if sParamOp then
			sParamCompLower = StringManager.trim(sParamCompLower:sub(#sParamOp + 1));
		end
		local nParamSize = tSizes[sParamCompLower];
		if nParamSize then
			table.insert(tParamSize, { nParamSize = nParamSize, sParamOp = sParamOp });
		end
	end
	if #tParamSize == 0 then
		return nil;
	end
	return tParamSize;
end
function internalIsCreatureSizeDnDCompare(tParamSize, nActorSize)
	for _,t in ipairs(tParamSize) do
		local bReturn;
		if t.sParamOp then
			if t.sParamOp == "<" then
				bReturn = (nActorSize < t.nParamSize);
			elseif t.sParamOp == ">" then
				bReturn = (nActorSize > t.nParamSize);
			elseif t.sParamOp == "<=" then
				bReturn = (nActorSize <= t.nParamSize);
			elseif t.sParamOp == ">=" then
				bReturn = (nActorSize >= t.nParamSize);
			else
				bReturn = (nActorSize == t.nParamSize);
			end
		else
			bReturn = (nActorSize == t.nParamSize);
		end
		if bReturn then
			return true;
		end
	end
	return false;
end

--
--	CREATURE TYPE CHECKS
--

function getCreatureTypes()
	return DataCommon and DataCommon.creaturetype or { "humanoid" };
end
function getCreatureTypeDefault()
	return DataCommon and DataCommon.creaturedefaulttype or "humanoid";
end
function getCreatureSubtypes()
	return DataCommon and DataCommon.creaturesubtype or {};
end
function getCreatureOrigins()
	return DataCommon and DataCommon.creatureorigin or { };
end
function getCreatureOriginDefault()
	return DataCommon and DataCommon.creaturedefaultorigin or "";
end

function getCreatureTypeDnD(rActor)
	local tTypes = ActorCommonManager.getCreatureTypesDnD(rActor);
	if tTypes and tTypes.type and tTypes.type[1] then
		return tTypes.type[1];
	end
	return ActorCommonManager.getCreatureTypeDefault();
end
function getCreatureTypesDnD(rActor)
	local sActorType = GameManager.getRecordFieldValue(rActor, "type", "");
	return ActorCommonManager.internalGetCreatureTypesFromStringDnD(sActorType, true);
end
function isCreatureTypeDnD(rActor, sParam)
	local tCheckTypes = ActorCommonManager.internalGetCreatureTypeDnDParam(sParam);
	if not tCheckTypes then
		return false;
	end

	local tActorTypes = ActorCommonManager.getCreatureTypesDnD(rActor);
	if not tActorTypes then
		return false;
	end

	for s,t in pairs(tCheckTypes) do
		for _,sCheck in ipairs(t) do
			if StringManager.contains(tActorTypes[s], sCheck) then
				return true;
			end
		end
	end
	return false;
end

function internalGetCreatureTypeDnDParam(sParam)
	if not sParam then
		return nil;
	end
	local tParams = StringManager.splitByPattern(sParam:lower(), ",", true);

	local tCheckTypes = {};
	for _,sParamComp in ipairs(tParams) do
		local tParamCompTypes = ActorCommonManager.internalGetCreatureTypesFromStringDnD(sParamComp, false);
		for sParamCompTypeKey, tParamCompType in pairs(tParamCompTypes) do
			if not tCheckTypes[sParamCompTypeKey] then
				tCheckTypes[sParamCompTypeKey] = {};
			end
			for _,s in ipairs(tParamCompType) do
				table.insert(tCheckTypes[sParamCompTypeKey], s);
			end
		end
	end

	for _,t in pairs(tCheckTypes) do
		if #t > 0 then
			return tCheckTypes;
		end
	end
	return nil;
end
-- Known usage notes:
--		5E/PFRPG/3.5E/SFRPG/d20Modern/DCC - type/subtype
--		4E - origin/type/subtype
--		13A/MCC - type
function internalGetCreatureTypesFromStringDnD(sType, bUseDefaultType)
	-- Build parameter tracking
	local tSource = { nIndex = 1 };
	tSource.tWords = StringManager.split(sType:lower(), ", %(%)", true);

	-- Handle half races
	ActorCommonManager.internalHandleCreatureTypeDnDHalfType(tSource);

	-- Check each type set (order matters)
	local tResult = {};
	tResult["origin"] = ActorCommonManager.internalIsCreatureTypeDnDMatch(tSource, ActorCommonManager.getCreatureOrigins(), true, bUseDefaultType, ActorCommonManager.getCreatureOriginDefault());
	tResult["type"] = ActorCommonManager.internalIsCreatureTypeDnDMatch(tSource, ActorCommonManager.getCreatureTypes(), true, bUseDefaultType, ActorCommonManager.getCreatureTypeDefault());
	tResult["subtype"] = ActorCommonManager.internalIsCreatureTypeDnDMatch(tSource, ActorCommonManager.getCreatureSubtypes());

	return tResult;
end
function internalHandleCreatureTypeDnDHalfType(tSource)
	if DataCommon and DataCommon.creaturehalftype then
		local sDefaultHalfTypeSubrace = DataCommon.creaturehalftypesubrace or "human";
		local nHalfRace = 0;
		for n = 1, #(tSource.tWords) do
			if StringManager.startsWith(DataCommon.creaturehalftype, tSource.tWords[n]) then
				tSource.tWords[n] = tSource.tWords[n]:sub(#DataCommon.creaturehalftype + 1);
				nHalfRace = nHalfRace + 1;
			end
		end
		if nHalfRace == 1 then
			if not StringManager.contains(tSource.tWords, sDefaultHalfTypeSubrace) then
				table.insert(tSource.tWords, sDefaultHalfTypeSubrace);
			end
		end
	end
end
function internalIsCreatureTypeDnDMatch(tSource, tCheck, bSingle, bUseDefault, sDefault)
	if not tCheck then
		return nil;
	end

	local tResult = {};

	while tSource.nIndex <= #(tSource.tWords) do
		for _,sCheck in ipairs(tCheck) do
			local tCheckWords = StringManager.split(sCheck, " ", true);
			if #tCheckWords > 0 then
				local bMatch = true;
				for i = 1, #tCheckWords do
					if tCheckWords[i] ~= tSource.tWords[tSource.nIndex - 1 + i] then
						bMatch = false;
						break;
					end
				end
				if bMatch then
					table.insert(tResult, sCheck);
					tSource.nIndex = tSource.nIndex + (#tCheckWords - 1);
					break;
				end
			end
		end
		tSource.nIndex = tSource.nIndex + 1;
		if bSingle and (#tResult > 0) then
			break;
		end
	end
	if #tResult == 0 then
		if bUseDefault and ((sDefault or "") ~= "") then
			table.insert(tResult, sDefault);
		end
		tSource.nIndex = 1;
	end

	return tResult;
end

--
--	CREATURE ALIGNMENT CHECKS
--

-- Known usage notes:
--		5E/4E/3.5E/SFRPG/DCC/MCC - alignment
--		PFRPG - alignment(PC) or type(NPC)
function isCreatureAlignmentDnD(rActor, sParam)
	local tParamAlign = ActorCommonManager.internalGetCreatureAlignmentDnDParam(sParam);
	if #(tParamAlign or {}) == 0 then
		return false;
	end

	local tActorAlign = ActorCommonManager.internalGetCreatureAlignmentDnDActor(rActor);
	if not tActorAlign then
		return false;
	end

	for _,t in ipairs(tParamAlign) do
		local bMatch = true;
		if t.nLawChaos and (t.nLawChaos ~= tActorAlign.nLawChaos) then
			bMatch = false;
		end
		if t.nGoodEvil and (t.nGoodEvil ~= tActorAlign.nGoodEvil) then
			bMatch = false;
		end
		if bMatch then
			return true;
		end
	end
	return false;
end
-- NOTE: Assume standard values of:
--		nCheckLawChaosAxis = Lawful = 1, Neutral = 2, Chaos = 3
--		nCheckGoodEvilAxis = Good = 1, Neutral = 2, Evil = 3
function getCreatureAlignmentDnD(s, bUseDefault)
	if not DataCommon or not DataCommon.alignment_lawchaos or not DataCommon.alignment_goodevil then
		return nil;
	end

	-- Build parameter tracking
	local tWords = StringManager.splitWords(s:lower());

	local nCheckLawChaosAxis, nCheckGoodEvilAxis;
	for _,sWord in ipairs(tWords) do
		if not nCheckLawChaosAxis and DataCommon.alignment_lawchaos[sWord] then
			nCheckLawChaosAxis = DataCommon.alignment_lawchaos[sWord];
		end
		if not nCheckGoodEvilAxis and DataCommon.alignment_goodevil[sWord] then
			nCheckGoodEvilAxis = DataCommon.alignment_goodevil[sWord];
		end
	end
	if bUseDefault then
		if not nCheckLawChaosAxis then
			nCheckLawChaosAxis = 2;
		end
		if not nCheckGoodEvilAxis then
			nCheckGoodEvilAxis = 2;
		end
	else
		if not nCheckLawChaosAxis and not nCheckGoodEvilAxis then
			return nil;
		end
	end

	return { nLawChaos = nCheckLawChaosAxis, nGoodEvil = nCheckGoodEvilAxis };
end

function internalGetCreatureAlignmentDnDParam(sParam)
	if not sParam then
		return nil;
	end

	local tResults = {};
	for _,s in ipairs(StringManager.splitByPattern(sParam:lower(), ",", true)) do
		local tAlign = ActorCommonManager.getCreatureAlignmentDnD(s, false);
		if tAlign then
			table.insert(tResults, tAlign);
		end
	end
	return tResults;
end
function internalGetCreatureAlignmentDnDActor(rActor)
	local sActorAlign = GameManager.getRecordFieldValue(rActor, "alignment", "");
	return ActorCommonManager.getCreatureAlignmentDnD(sActorAlign, true);
end
