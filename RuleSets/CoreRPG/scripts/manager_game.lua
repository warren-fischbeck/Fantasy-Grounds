--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

--
--	GAME OPTIONS
--		NOTE: Used for limited common option scenarios to modify standard action handling
--		NOTE 2: Some option checks look for specific values; not just the key itself.
--
--	EXAMPLES
--		5E - critical, deathsave, dmgmishap, dmgthreshold, regeneration, systemshock
--		4E - dmghalfonweakened, dmgstaticnoeffect, healsurge, regeneration
--		3.5E - atktype, critical, critmult, dmgdr, dmgmin, incorporeal, metamagic, negativehp, nonlethal, regeneration, rest
--		2E - rest
--		PF - atktype, critical, critmult, dmgdr, dmgmin, incorporeal, metamagic, negativehp, nonlethal, regeneration, rest
--		SF - (PF), dmghardness, dmgsplit
--		PF2 - atktype, rest
--

local _tOption = {};
function setOption(sKey, v)
	if (sKey or "") == "" then
		return;
	end
	_tOption[sKey] = v;
end
function getOption(sKey)
	if (sKey or "") == "" then
		return nil;
	end
	return _tOption[sKey];
end
function hasOption(sKey)
	return (GameManager.getOption(sKey) ~= nil);
end
function isOption(sKey, v)
	if type(v) == "table" then
		for _,v2 in ipairs(v) do
			if GameManager.isOption(sKey, v2) then
				return true;
			end
		end
		return false;
	end
	return (GameManager.getOption(sKey) == v);
end

--
--	GAME ACTIONS
--

function isAction(sKey)
	if not GameSystem or not GameSystem.actions then
		return false;
	end
	return (GameSystem.actions[sKey or ""] ~= nil);
end
function addAction(sKey, tData)
	if (sKey or "") == "" then
		return;
	end
	if not GameSystem or not GameSystem.actions then
		return;
	end
	GameSystem.actions[sKey] = tData or { bUseModStack = true };
end
function getActionProperty(sKey, sProperty)
	if not GameSystem or not GameSystem.actions or not GameSystem.actions[sKey or ""] then
		return nil;
	end
	return GameSystem.actions[sKey or ""][sProperty or ""];
end
function setActionProperty(sKey, sProperty, v)
	if not GameSystem or not GameSystem.actions or not GameSystem.actions[sKey or ""] then
		return;
	end
	GameSystem.actions[sKey or ""][sProperty or ""] = v;
end

--
--	GAME RECORD FIELD MAPPING
--
--	NOTE: Only used for ActionHealthD20 field mapping currently
--		(hp, hptemp, wounds, nonlethal, deathsavesuccess, deathsavefail)
--

local _tRecordFieldMap = {
	[""] = {
		["enclevel"] = "encumbrance.level",
		["encload"] = "encumbrance.load",
		["encstate"] = "encumbrance.state",
	},
	["charsheet"] = {
		["type"] = "race",
		["hptotal"] = "hp.total",
		["hptemp"] = "hp.temporary",
		["wounds"] = "hp.wounds",
		["nonlethal"] = "hp.nonlethal",
		["deathsavesuccess"] = "hp.deathsavesuccess",
		["deathsavefail"] = "hp.deathsavefail",
	},
	["vehicle"] = {
		["nonlethal"] = "",
		["deathsavesuccess"] = "",
		["deathsavefail"] = "",
	},
};
function setRecordFieldMap(sRecordType, sKey, s)
	if (sKey or "") == "" then
		return;
	end
	_tRecordFieldMap[sRecordType or ""] = _tRecordFieldMap[sRecordType or ""] or {};
	_tRecordFieldMap[sRecordType or ""][sKey] = s;
end
function getRecordFieldMap(sRecordType, sKey)
	if (sKey or "") == "" then
		return nil;
	end
	if (sRecordType or "") ~= "" then
		if _tRecordFieldMap[sRecordType] and _tRecordFieldMap[sRecordType][sKey] then
			return _tRecordFieldMap[sRecordType][sKey];
		end
	end
	return _tRecordFieldMap[""][sKey];
end
function getRecordFieldValue(rActor, sKey, vDefault)
	if (sKey or "") == "" then
		return vDefault;
	end
	local nodeActor = ActorManager.getCreatureNode(rActor);
	if not nodeActor then
		return vDefault;
	end
	local sRecordType = ActorManager.getRecordType(rActor);
	if (sRecordType or "") == "" then
		return vDefault;
	end
	local sField = GameManager.getRecordFieldMap(sRecordType, sKey) or sKey;
	if sField == "" then
		return vDefault;
	end
	return DB.getValue(nodeActor, sField, vDefault);
end
function setRecordFieldValue(rActor, sKey, sDataType, v)
	if (sKey or "") == "" then
		return;
	end
	local nodeActor = ActorManager.getCreatureNode(rActor);
	if not nodeActor then
		return;
	end
	local sRecordType = ActorManager.getRecordType(rActor);
	if (sRecordType or "") == "" then
		return;
	end
	local sField = GameManager.getRecordFieldMap(sRecordType, sKey) or sKey;
	if sField == "" then
		return;
	end
	DB.setValue(nodeActor, sField, sDataType, v);
end
function getRecordFieldValueLinked(rActor, sKey, vDefault)
	if (sKey or "") == "" then
		return vDefault;
	end
	local nodeCT = ActorManager.getCTNode(rActor);
	if nodeCT then
		local sField = GameManager.getRecordFieldMap("", sKey) or sKey;
		if sField == "" then
			return vDefault;
		end
		return DB.getValue(nodeCT, sField, vDefault);
	end
	return GameManager.getRecordFieldValue(rActor, sKey, vDefault);
end

--
--	GAME SPECIFIC FUNCTIONS (OVERRIDES)
--
--	COMBAT
--
--	onActorStartTurn(rActor)
--	onActorEndTurn(rActor)
--
--	ACTIONS
--
--	[MK] onActionPostGetRoll(rActor, rAction, rRoll)
--	[MK] onActionPreModRoll(rSource, rTarget, rRoll)
--	[MK] onActionPostModRoll(rSource, rTarget, rRoll)
--	[MK] onActionPreOnRoll(rSource, rRoll)
--	[MK] onActionPostOnRoll(rSource, rRoll)
--	[MK] onActionPreResolve(rSource, rTarget, rRoll);
--	[MK] onActionPostResolve(rSource, rTarget, rRoll);
--
--	DAMAGE
--
--	onActorEffectConditionImmune(rActor, rSource) -> table of lowercase condition strings
--	onActorEffectDamageAdjust(sEffectTag, rActor, rSource, rRoll, tApplyData) -> table of tCompData effects (extra resist, immune, etc.)
-- 	onDamageApplyResults(rSource, rTarget, rRoll, tApplyData)
--	onDamageApplyResultsNormal(rSource, rTarget, rRoll, tApplyData)
--
--	HEALTH ADJUST
--
--	onHealthApply(rSource, rTarget, rRoll)
-- 	onHealthApplyGetHealth(rActor, rRoll, tApplyData)
--	[MK] onHealthApplyType(rSource, rTarget, rRoll, tApplyData)
-- 	onHealthApplySetHealth(rActor, rRoll, tApplyData)
--	onHealthApplyStatusChange(rSource, rTarget, rRoll, tApplyData)
--	onHealthPostApply(rSource, rTarget, rRoll, tApplyData)
--
--	EFFECTS
--
--	onEffectActorStartTurn(rActor, nodeEffect)
--	onEffectActorEndTurn(rActor, nodeEffect)
--
--	onEffectPreAdd(rActor, rEffect) -> bHandled (true to continue processing)
--	onEffectPostAdd(rActor, nodeEffect, rEffect)
--	onEffectExpire(rActor, nodeEffect) -> bHandled (true to continue processing)
--	onEffectRemove(rActor, nodeEffect)
--
--	onEffectDragDecode(draginfo, rEffect)
--	onEffectRollEncode(rRoll, rEffect)
--	onEffectRollDecode(rRoll, rEffect)
--	onEffectTextEncode(rEffect) -> string (extra string data to add to default string data)
--	onEffectTextDecode(sEffect, rEffect) -> string (sEffect with extra data removed)
--
--	onEffectCheckApply(tCheckData)
--	onEffectCheckCompFilter(tCompData, tCheckData)
--
--	onEffectDisplayFilter(w) -> bool
--
--	ACTOR
--
--	onActorGetAbilityScore(rActor, sAbility)
--	onActorGetAbilityDamage(rActor, sAbility)
--	onActorGetBonus(rActor, sKey, ...) -> nBonus
--	onActorGetEffectsBonus(rActor, sKey, ...) -> nBonus
--	onActorGetEffectsData(rActor) -> tEffectsData (see ActorEffectManager)
--	onActorGetHealthStatus(rActor) -> nPercentWounded, sStatus
--	onActorRest(rActor, sRestType)
--
--	INTERNAL
--
--	onEffectAddLegacy(rEffect)
--	onEffectAddIgnoreCheckLegacy(rActor, rEffect) -> sMessage (non-nil to stop processing)
--	onEffectPostAddLegacy(nodeEffect, rEffect)
--	onEffectExpireLegacy(nodeEffect, nExpireComp) -> sMessage (non-nil to stop processing)
--

local _tFunction = {};
function getFunction(sKey)
	if (sKey or "") == "" then
		return nil;
	end
	return _tFunction[sKey];
end
function setFunction(sKey, fn)
	if (sKey or "") == "" then
		return;
	end
	_tFunction[sKey] = fn;
end
function callFunction(sKey, ...)
	local fn = GameManager.getFunction(sKey);
	if not fn then
		return;
	end
	return fn(...);
end

local _tMultiKeyFunction = {};
function getMultiKeyFunction(sKey, sSubKey)
	if ((sKey or "") == "") then
		return nil;
	end
	return _tMultiKeyFunction[sKey] and _tMultiKeyFunction[sKey][sSubKey or ""];
end
function setMultiKeyFunction(sKey, sSubKey, fn)
	if ((sKey or "") == "") then
		return;
	end
	_tMultiKeyFunction[sKey] = _tMultiKeyFunction[sKey] or {};
	_tMultiKeyFunction[sKey][sSubKey or ""] = fn;
end
function callMultiKeyFunction(sKey, sSubKey, ...)
	local fn = GameManager.getMultiKeyFunction(sKey, sSubKey);
	if not fn then
		return;
	end
	return fn(...);
end
function callMultiKeyFunctionPreLayered(sKey, sSubKey, ...)
	GameManager.callMultiKeyFunction(sKey, "", ...);
	GameManager.callMultiKeyFunction(sKey, sSubKey, ...);
end
function callMultiKeyFunctionPostLayered(sKey, sSubKey, ...)
	GameManager.callMultiKeyFunction(sKey, sSubKey, ...);
	GameManager.callMultiKeyFunction(sKey, "", ...);
end

--
--	GAME SPECIFIC FUNCTIONS (EVENTS)
--
--
--	ACTION
--
--	onActionPostTargeting(rSource, tTargetGroups, rRolls)
--
--	ATTACK
--
--	onAttackPreResolve(rSource, rTarget, rRoll)
--	onAttackPostResolve(rSource, rTarget, rRoll)
--
--	DAMAGE
--
--	onDamagePostResolve(rSource, rTarget, rRoll)
--
--	SAVE
--
--	onSavePostResolve(rActor, rOrigin, rRoll)
--
--	EFFECT
--
--	onEffectAdd(rActor, rEffect, nodeEffect) (after effect added)
--	onEffectExpire(rActor, nodeEffect) (just before effect deleted)
--	onEffectRemove(rActor, nodeEffect) (just before effect deleted)
--

local _tEventFunctions = {};
function addEventFunction(sKey, fn)
	if ((sKey or "") == "") or not fn then
		return;
	end
	_tEventFunctions[sKey] = _tEventFunctions[sKey] or {};
	UtilityManager.registerCallback(_tEventFunctions[sKey], fn);
end
function removeEventFunction(sKey, fn)
	if ((sKey or "") == "") or not fn then
		return;
	end
	UtilityManager.unregisterCallback(_tEventFunctions[sKey], fn);
end
function callEventFunctions(sKey, ...)
	if ((sKey or "") == "") then
		return;
	end
	UtilityManager.performAllCallbacks(_tEventFunctions[sKey], ...);
end
