--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

function onInit()
	GameManager.setFunction("onActorGetEffectsData", ActorEffectManager.getEffectsDataDefault);

	if Session.IsHost then
		CombatManager.addAllCombatantFieldChangeHandler("initresult", "onUpdate", ActorEffectManager.onInitResultUpdate);
	end
end

--
--	ACTOR EFFECTS (COMBAT, GLOBAL, ACTIVE)
--

function getEffects(vActor)
	local rActor = ActorManager.resolveActor(vActor);
	if not rActor then
		return {};
	end

	local tCTEffects = ActorEffectManager.getCombatantEffectNodes(rActor);
	local tActiveEffectNodes = ActorEffectManager.getActiveEffectNodes(rActor);
	if #tActiveEffectNodes == 0 then
		return tCTEffects;
	end

	local tAllEffects = {};
	for _,nodeEffect in ipairs(tCTEffects) do
		table.insert(tAllEffects, nodeEffect);
	end
	for _,nodeActive in ipairs(tActiveEffectNodes) do
		for _,nodeEffect in ipairs(DB.getChildList(DB.getPath(nodeActive, "effects"))) do
			table.insert(tAllEffects, nodeEffect);
		end
	end
	return tAllEffects;
end
function getCombatantEffectNodes(rActor)
	local nodeCT = ActorManager.getCTNode(rActor);
	if not nodeCT then
		return {};
	end
	return DB.getChildList(nodeCT, "effects");
end
function getActiveEffectNodes(rActor)
	if type(rActor) ~= "table" then
		return {};
	end
	return rActor.tActiveEffectNodes or {};
end

function getEffectsData(rActor, tData)
	return GameManager.callFunction("onActorGetEffectsData", rActor, tData);
end
function getEffectsDataDefault(rActor, tData)
	local tCombatantEffectsData = ActorEffectManager.getCombatantEffectsData(rActor, tData);
	local tActiveEffectsData = ActorEffectManager.getActiveEffectsData(rActor, tData);
	local tGlobalEffectsData = (tData and tData.bIncludeGlobal and CombatManager.getGlobalEffectsData(tData)) or {};
	if (#tActiveEffectsData == 0) and (#tGlobalEffectsData == 0) then
		return tCombatantEffectsData;
	end

	local tResults = {};
	for _,tEffectData in ipairs(tGlobalEffectsData) do
		table.insert(tResults, tEffectData);
	end
	for _,tEffectData in ipairs(tCombatantEffectsData) do
		table.insert(tResults, tEffectData);
	end
	for _,tEffectData in ipairs(tActiveEffectsData) do
		table.insert(tResults, tEffectData);
	end
	return tResults;
end
function getCombatantEffectsData(rActor, tData)
	local nodeCT = ActorManager.getCTNode(rActor);
	if not nodeCT then
		return {};
	end
	local tResults = {};
	for _,nodeEffect in ipairs(DB.getChildList(nodeCT, "effects")) do
		local tEffectData = EffectIndexManager.getEffectData(nodeEffect);
		if tEffectData and ((tData and tData.bIgnoreDisabled) or (tEffectData.nActive ~= 0)) then
			table.insert(tResults, tEffectData);
		end
	end
	return tResults;
end
function getActiveEffectsData(rActor, tData)
	local tResults = {};
	for _,nodeActive in ipairs(ActorEffectManager.getActiveEffectNodes(rActor)) do
		for _,nodeEffect in ipairs(DB.getChildList(DB.getPath(nodeActive, "effects"))) do
			local tEffectData = EffectIndexManager.buildEffectData(nodeEffect);
			if tEffectData and ((tData and tData.bIgnoreDisabled) or (tEffectData.nActive ~= 0)) then
				table.insert(tResults, tEffectData);
			end
		end
	end
	return tResults;
end

-- NOTE: Requires actor to be previously resolved before being able to store active effect nodes
function addActiveEffectNode(rActor, vNode)
	if type(rActor) ~= "table" then
		return;
	end
	if not vNode then
		return;
	end
	if (type(vNode) == "string") and (vNode == "") then
		return;
	end

	if not rActor.tActiveEffectNodes then
		rActor.tActiveEffectNodes = {};
	end
	table.insert(rActor.tActiveEffectNodes, vNode);
end

--
--	EVAL EFFECTS
--

function evalEffectTags(rActor, rEffect, ...)
	if not rActor or not rEffect or ((rEffect.sName or "") == "") then
		return;
	end

	local tEffectComps = {};
	for _,sComp in ipairs(EffectManager.parseEffect(rEffect.sName)) do
		local tReplace = {};
		for sTag in sComp:gmatch("(%[[^]]+%])") do
			local nBonus = ActorEffectManager.evalEffectTagsBonus(rActor, sTag, rEffect, ...);
			if nBonus then
				table.insert(tReplace, { source = StringManager.encodeAsPattern(sTag), target = string.format("%d", nBonus), });
			end
		end
		for _,v in ipairs(tReplace) do
			sComp = sComp:gsub(v.source, v.target, 1);
		end
		table.insert(tEffectComps, sComp);
	end
	rEffect.sName = EffectManager.rebuildParsedEffect(tEffectComps);
end
-- LEGACY - (2026-10) - REMOVE "H" PREFIX
function evalEffectTagsBonus(rActor, sTag, rEffect, ...)
	local sSign, sRoundUp, sOperator, sModifier, sKey, sMax = sTag:match("^%[([%+%-]?)(^?)([/*]?)([H%d]?)([A-Z]+)(%d*)%]$");
	if not sKey then
		sSign, sKey, sMax, sRoundUp, sOperator, sModifier = sTag:match("^%[([%+%-]?)([A-Z]+)(%d*)(^?)([/*]+)(%d+)%]$");
		if not sKey then
			local sContents = sTag:match("^%[(.*)%]$");
			if DiceManager.isDiceString(sContents) then
				return DiceManager.evalDiceString(sContents);
			end
			return nil;
		end
	end

	local nBonus = ActorCommonManager.getBonus(rActor, sKey, rEffect, ...) + ActorCommonManager.getEffectsBonus(rActor, sKey, rEffect, ...);
	if nBonus == 0 then
		return 0;
	end

	if (sMax or "") ~= "" then
		local nMax = tonumber(sMax);
		if nMax then
			nBonus = math.min(nBonus, nMax);
		end
	end
	local bFloor = ((nBonus >= 0) and (sRoundUp == "")) or ((nBonus < 0) and (sRoundUp == "^"));
	if (sModifier or "") ~= "" then
		if sModifier == "H" then
			if bFloor then
				nBonus = math.floor(nBonus / 2);
			else
				nBonus = math.ceil(nBonus / 2);
			end
		elseif sOperator == "/" then
			local nDivisor = (tonumber(sModifier) or 1);
			if nDivisor == 0 then
				nBonus = 0;
			elseif bFloor then
				nBonus = math.floor(nBonus / nDivisor);
			else
				nBonus = math.ceil(nBonus / nDivisor);
			end
		else
			nBonus = nBonus * (tonumber(sModifier) or 1);
		end
	end
	if sSign == "-" then
		nBonus = 0 - nBonus;
	end
	return nBonus;
end

--
--	INIT RESULT HANDLING
--

function onInitResultUpdate(nodeField)
	-- NOTE: nodeCT is nil for global effects
	local function checkForSourceInitChange(nodeEffect, rActor, nInit, nodeCT)
		if EffectVarManager.getEffectVarFromNode(nodeEffect, "nDuration", 0) <= 0 then
			return;
		end

		local sInitSource = EffectVarManager.getEffectVarFromNode(nodeEffect, "sInitSource", "");
		if sInitSource == "" then
			local rSourceActor = EffectManager.getSourceActor(nodeEffect) or ActorManager.resolveActor(nodeCT);
			if not ActorManager.isEqual(rActor, rSourceActor) then
				return;
			end
		elseif sInitSource == "target" then
			local rEffectActor = ActorManager.resolveActor(nodeCT);
			if not ActorManager.isEqual(rActor, rEffectActor) then
				return;
			end
		else
			return;
		end

		EffectVarManager.setEffectVarToNode(nodeEffect, "nInit", nInit);
	end
	local function checkForSourceInitChangeGlobalEffect(nodeEffect, rActor, nInit)
		return checkForSourceInitChange(nodeEffect, rActor, nInit);
	end
	local function checkForSourceInitChangeActorEffect(nodeEffect, nodeCT, rActor, nInit)
		return checkForSourceInitChange(nodeEffect, rActor, nInit, nodeCT);
	end

	local rActor = ActorManager.resolveActor(DB.getParent(nodeField));
	local nInit = DB.getValue(nodeField, ".", 0);
	CombatManager.callForEachGlobalEffect(checkForSourceInitChangeGlobalEffect, rActor, nInit);
	CombatManager.callForEachCombatantEffect(checkForSourceInitChangeActorEffect, rActor, nInit);
end
