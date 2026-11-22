--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

--
--	GAME OPTIONS
--		NOTE: Used for limited common option scenarios to modify standard action handling
--		NOTE 2: Some option checks look for specific values; not just the key itself.
--
--	EXAMPLES TBD
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
--	GAME SPECIFIC FUNCTIONS (EVENTS / OVERRIDES)
--
--	EXAMPLES TBD
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

local _tMultiKeyFunction = {};
function getMultiKeyFunction(sKey, sSubKey)
	if ((sKey or "") == "") or ((sSubKey or "") == "") then
		return nil;
	end
	return _tMultiKeyFunction[sKey] and _tMultiKeyFunction[sKey][sSubKey];
end
function setMultiKeyFunction(sKey, sSubKey, fn)
	if ((sKey or "") == "") or ((sSubKey or "") == "") then
		return;
	end
	_tMultiKeyFunction[sKey] = _tMultiKeyFunction[sKey] or {};
	_tMultiKeyFunction[sKey][sSubKey] = fn;
end

--
--	GAME SPECIFIC FUNCTIONS (EVENTS / OVERRIDES)
--
--
--	ACTION
--
--	onActionPostTargeting(rSource, tTargetGroups, rRolls)
--
--	ATTACK
--
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
--	onEffectAdd(rActor, rEffect, nodeEffect)
--	onEffectExpire(rActor, nodeEffect)
--	onEffectRemove(rActor, nodeEffect)
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
