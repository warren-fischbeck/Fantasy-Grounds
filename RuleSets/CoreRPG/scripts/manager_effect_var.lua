--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

function onInit()
	EffectVarManager.initStandardVars();
end

-- NOTE: isactive is a DB field that is part of all CT effects, but not tracked in the effect record
function initStandardVars()
	EffectVarManager.setEffectVar("sName", { sDBType = "string", sDBField = "label" });
	EffectVarManager.setEffectVar("nGMOnly", { sDBType = "number", sDBField = "isgmonly" });
	EffectVarManager.setEffectVar("sSource", { sDBType = "string", sDBField = "source_name", bClearOnUntargetedDrop = true });
	EffectVarManager.setEffectVar("sTargeting", { sDBType = "string", bClearOnUntargetedDrop = true });
	EffectVarManager.setEffectVar("sTargets", { sDBType = "string", bClearOnUntargetedDrop = true });
	EffectVarManager.setEffectVar("nDuration", { sDBType = "number", sDBField = "duration", vDBDefault = 0, sDisplay = "[D: %d]" });
	EffectVarManager.setEffectVar("sUnits", { sDBType = "string", sDBField = "unit", bSkipAdd = true });
	EffectVarManager.setEffectVar("nInit", { sDBType = "number", sDBField = "init", bClearOnUntargetedDrop = true });
	EffectVarManager.setEffectVar("sInitSource", { sDBType = "string", sDBField = "initsource", bClearOnUntargetedDrop = true });
	EffectVarManager.setEffectVar("sExpiration", { sDBType = "string", sDBField = "expiration", fDisplay = EffectVarManager.getEffectVarExpirationSummary });
	EffectVarManager.setEffectVar("sApply", { sDBType = "string", sDBField = "apply", fDisplay = EffectVarManager.getEffectVarApplySummary });

	if Session.IsHost then
		CombatManager.addEffectFieldChangeHandler("apply", "onUpdate", EffectVarManager.onStandardEffectApplyUpdate);
		CombatManager.addCombatantEffectFieldChangeHandler("apply", "onUpdate", EffectVarManager.onStandardEffectApplyUpdate);
	end
end

--
--	EFFECT VARIABLE HANDLING
--

local _tEffectVarMap = {};
function getEffectVarMap()
	return _tEffectVarMap;
end
function hasEffectVar(sVar)
	return (EffectVarManager.getEffectVar(sVar) ~= nil);
end
function getEffectVar(sVar)
	return _tEffectVarMap[sVar or ""];
end
function setEffectVar(sVar, tData)
	if not tData then
		ChatManager.SystemMessage("Invalid effect variable data registered. (" .. sVar .. ")");
		return;
	end
	if ((tData.sDBType or "") ~= "string") and ((tData.sDBType or "") ~= "number") then
		ChatManager.SystemMessage("Invalid effect variable type registered. (" .. sVar .. ")");
		return;
	end
	_tEffectVarMap[sVar] = tData;
end

function getEffectVarFromNode(nodeEffect, sVar, vDefault)
	if type(nodeEffect) ~= "databasenode" then
		return vDefault;
	end
	local tVarData = EffectVarManager.getEffectVar(sVar);
	if not tVarData or ((tVarData.sDBField or "") == "") then
		return vDefault;
	end
	if (tVarData.sDBType or "") == "string" then
		return DB.getValue(nodeEffect, tVarData.sDBField, tVarData.vDBDefault or vDefault);
	elseif (tVarData.sDBType or "") == "number" then
		return DB.getValue(nodeEffect, tVarData.sDBField, tVarData.vDBDefault or vDefault);
	end
	return tVarData.vDBDefault or vDefault;
end
function setEffectVarToNode(nodeEffect, sVar, v)
	if type(nodeEffect) ~= "databasenode" then
		return;
	end
	local tVarData = EffectVarManager.getEffectVar(sVar);
	if not tVarData or ((tVarData.sDBField or "") == "") then
		return;
	end
	if (tVarData.sDBType or "") == "string" then
		DB.setValue(nodeEffect, tVarData.sDBField, tVarData.sDBType, v);
	elseif (tVarData.sDBType or "") == "number" then
		DB.setValue(nodeEffect, tVarData.sDBField, tVarData.sDBType, v);
	end
end
function getEffectDataFromNode(nodeEffect)
	if type(nodeEffect) ~= "databasenode" then
		return nil;
	end
	local rEffect = {};
	for k, v in pairs(EffectVarManager.getEffectVarMap()) do
		if v.sDBField then
			if v.sDBType == "number" then
				rEffect[k] = DB.getValue(nodeEffect, v.sDBField, v.vDBDefault or 0);
			else
				rEffect[k] = DB.getValue(nodeEffect, v.sDBField, v.vDBDefault or "");
			end
		end
	end
	return rEffect;
end
function setNodeFromEffectData(nodeEffect, rEffect, bNoSkip)
	if (type(nodeEffect) ~= "databasenode") or not rEffect then
		return;
	end
	for k, v in pairs(EffectVarManager.getEffectVarMap()) do
		if v.sDBField then
			if not rEffect[k] then
				-- Do nothing
			elseif ((v.sDBType == "string") and (rEffect[k] == "")) or ((v.sDBType == "number") and (rEffect[k] == 0)) then
				-- Do nothing
			elseif bNoSkip or not v.bSkipAdd then
				DB.setValue(nodeEffect, v.sDBField, v.sDBType, rEffect[k]);
			end
		end
	end
end

function getEffectDisplayShort(nodeEffect)
	if type(nodeEffect) ~= "databasenode" then
		return "";
	end

	local tOutput = {};

	local sLabel = EffectVarManager.getEffectVarFromNode(nodeEffect, "sName", "");
	local tEffectPhrases = EffectManager.parseEffect(sLabel);
	local nPhrases = #tEffectPhrases;

	if nPhrases == 1 then
		table.insert(tOutput, tEffectPhrases[1]);
	elseif nPhrases > 1 then
		table.insert(tOutput, tEffectPhrases[1] .. "*");
	end

	if nPhrases > 0 then
		local nDuration = EffectVarManager.getEffectVarFromNode(nodeEffect, "nDuration", 0);
		if nDuration > 0 then
			table.insert(tOutput, string.format("[%d]", nDuration));
		end
		if EffectManager.isTargetedEffect(nodeEffect) then
			table.insert(tOutput, "[T]");
		end
	end

	return table.concat(tOutput, " ");
end
function getEffectDisplayLong(nodeEffect)
	if type(nodeEffect) ~= "databasenode" then
		return "";
	end

	local sLabel = EffectVarManager.getEffectVarFromNode(nodeEffect, "sName", "");
	local tEffectPhrases = EffectManager.parseEffect(sLabel);
	if #tEffectPhrases <= 0 then
		return "";
	end

	if EffectManager.isTargetedEffect(nodeEffect) then
		local sTargets = table.concat(EffectManager.getEffectTargets(nodeEffect, true), ",");
		table.insert(tEffectPhrases, 1, "[TRGT: " .. sTargets .. "]");
	end

	for _,v in pairs(EffectVarManager.getEffectVarMap()) do
		if v.fDisplay then
			local s = v.fDisplay(nodeEffect);
			if (s or "") ~= "" then
				table.insert(tEffectPhrases, s);
			end
		elseif v.sDisplay and v.sDBField then
			if v.sDBType == "number" then
				local n = DB.getValue(nodeEffect, v.sDBField, v.vDBDefault or 0);
				if (n or 0) ~= 0 then
					table.insert(tEffectPhrases, string.format(v.sDisplay, tostring(n):upper()));
				end
			else
				local s = DB.getValue(nodeEffect, v.sDBField, v.vDBDefault or "");
				if (s or "") ~= "" then
					table.insert(tEffectPhrases, string.format(v.sDisplay, s:upper()));
				end
			end
		end
	end

	return EffectManager.rebuildParsedEffect(tEffectPhrases);
end

--
--	CORE VARIABLE SUPPORT
--

local _tUnitMult = { [""] = 1, ["minute"] = 10, ["hour"] = 600, ["day"] = 14400, };
function getUnitDurationMult(sUnit)
	return _tUnitMult[sUnit or ""] or 0;
end
function setUnitDurationMult(sUnit, n)
	if (sUnit or "") == "" then
		return;
	end
	_tUnitMult[sUnit] = n;
end

function onEffectAddSetup(rActor, rEffect)
	EffectVarManager.onEffectAddSetupInit(rActor, rEffect);
	EffectVarManager.onEffectAddSetupDuration(rActor, rEffect);
	EffectVarManager.onEffectAddSetupSource(rActor, rEffect);
end
function onEffectAddSetupInit(rActor, rEffect)
	if not rEffect then
		return;
	end

	if (rEffect.sInitSource or "") == "target" then
		local nodeCT = ActorManager.getCTNode(rActor);
		if nodeCT then
			rEffect.nInit = DB.getValue(nodeCT, "initresult", 0);
		end
	elseif (rEffect.sInitSource or "") == "turn" then
		local nodeCT = CombatManager.getActiveCT();
		if nodeCT then
			rEffect.nInit = DB.getValue(nodeCT, "initresult", 0);
		end
	elseif (rEffect.sSource or "") ~= "" then
		local nodeCT = DB.findNode(rEffect.sSource);
		if nodeCT then
			rEffect.nInit = DB.getValue(nodeCT, "initresult", 0);
		end
	end

	if rEffect.sExpiration == "endnext" then
		rEffect.sExpiration = "end";

		local bIncrDuration;
		if rEffect.sInitSource == "target" then
			bIncrDuration = (rActor and CombatManager.isActive(ActorManager.getCTNode(rActor)));
		elseif rEffect.sInitSource == "turn" then
			bIncrDuration = true;
		else
			local rSourceActor = EffectManager.getSourceActor(rEffect) or rActor;
			bIncrDuration = (rSourceActor and CombatManager.isActive(ActorManager.getCTNode(rSourceActor)));
		end
		if bIncrDuration then
			rEffect.nDuration = 2;
		else
			rEffect.nDuration = 1;
		end
	end
end
-- onEffectAddSetupDuration(rActor, rEffect)
function onEffectAddSetupDuration(_, rEffect)
	if not rEffect then
		return;
	end

	rEffect.nDuration = rEffect.nDuration or 0;
	local nMult = EffectVarManager.getUnitDurationMult(rEffect.sUnits);
	rEffect.nDuration = rEffect.nDuration * nMult;
	rEffect.sUnits = "";
end
function onEffectAddSetupSource(rActor, rEffect)
	if not rEffect then
		return;
	end

	if rEffect.sSource == ActorManager.getCTNodeName(rActor) then
		rEffect.sSource = "";
	end
end
-- onEffectAddCleanup(rActor, nodeEffect)
function onEffectAddCleanup(_, nodeEffect)
	EffectVarManager.onStandardEffectResetUses(nodeEffect);
end

function onEffectVarNameTextEncode(rEffect, tOutput)
	if not rEffect or not tOutput then
		return;
	end
	table.insert(tOutput, string.format("[%s] %s", Interface.getString("effect_tag"), rEffect.sName or ""));
end
function onEffectVarNameTextDecode(tInput, rEffect)
	if not rEffect or not tInput then
		return;
	end
	rEffect.sName = StringManager.trim(tInput.sEffect:gsub("^%[" .. Interface.getString("effect_tag") .. "%] ", ""));
	tInput.sEffect = "";
end

function onEffectVarSourceTextEncode(rEffect, tOutput)
	if not rEffect or not tOutput then
		return;
	end
	if (rEffect.sSource or "") ~= "" then
		table.insert(tOutput, "[by " .. rEffect.sSource .. "]");
	end
end
function onEffectVarSourceTextDecode(tInput, rEffect)
	if not rEffect or not tInput then
		return;
	end
	rEffect.sSource = tInput.sEffect:match("%[by ([^]]+)%]") or "";
	tInput.sEffect = tInput.sEffect:gsub("%[by ([^]]+)%]", "");
end

function onEffectVarInitTextEncode(rEffect, tOutput)
	if not rEffect or not tOutput then
		return;
	end
	if not EffectVarManager.hasEffectVar("nInit") then
		return;
	end
	if (rEffect.nInit or 0) ~= 0 then
		table.insert(tOutput, "[INIT " .. rEffect.nInit .. "]");
	end
end
function onEffectVarInitTextDecode(tInput, rEffect)
	if not rEffect or not tInput then
		return;
	end
	if not EffectVarManager.hasEffectVar("nInit") then
		return;
	end
	local sEffectInit = tInput.sEffect:match("%[INIT ([%d.]+)%]");
	if not sEffectInit then
		return;
	end
	tInput.sEffect = tInput.sEffect:gsub("%[INIT ([%d.]+)%]", "");
	rEffect.nInit = tonumber(sEffectInit) or 0;
end

function onEffectVarExpirationTextEncode(rEffect, tOutput)
	if not rEffect or not tOutput then
		return;
	end
	local s = EffectVarManager.getEffectVarExpirationTag(rEffect.sExpiration);
	if (s or "") ~= "" then
		table.insert(tOutput, s);
	end
end
function onEffectVarExpirationTextDecode(tInput, rEffect)
	if not rEffect or not tInput then
		return;
	end
	if (tInput.sEffect or "") == "" then
		return;
	end
	if tInput.sEffect:match("%[ENDTURN%]") then
		tInput.sEffect = tInput.sEffect:gsub("%[ENDTURN%]", "");
		rEffect.sExpiration = "end";
	elseif tInput.sEffect:match("%[ENDNEXT%]") then
		tInput.sEffect = tInput.sEffect:gsub("%[ENDNEXT%]", "");
		rEffect.sExpiration = "endnext";
	elseif tInput.sEffect:match("%[REST%]") then
		tInput.sEffect = tInput.sEffect:gsub("%[REST%]", "");
		rEffect.sExpiration = "restshort";
	elseif tInput.sEffect:match("%[REST LONG%]") then
		tInput.sEffect = tInput.sEffect:gsub("%[REST LONG%]", "");
		rEffect.sExpiration = "restlong";
	end
end
function getEffectVarExpirationSummary(nodeEffect)
	local sExpire = EffectVarManager.getEffectVarFromNode(nodeEffect, "sExpiration", "");
	return EffectVarManager.getEffectVarExpirationTag(sExpire);
end
function getEffectVarExpirationTag(s)
	if (s or "") == "" then
		return "";
	end
	if s == "end" then
		return "[ENDTURN]";
	elseif s == "endnext" then
		return "[ENDNEXT]";
	elseif s == "restshort" then
		return "[REST]";
	elseif s == "restlong" then
		return "[REST LONG]";
	end
	return "";
end

function onEffectVarInitSourceTextEncode(rEffect, tOutput)
	if not rEffect or not tOutput then
		return;
	end
	local s = EffectVarManager.getEffectVarInitSourceTag(rEffect.sInitSource);
	if (s or "") ~= "" then
		table.insert(tOutput, s);
	end
end
function onEffectVarInitSourceTextDecode(tInput, rEffect)
	if not rEffect or not tInput then
		return;
	end
	if (tInput.sEffect or "") == "" then
		return;
	end
	if tInput.sEffect:match("%[INITTARGET%]") then
		tInput.sEffect = tInput.sEffect:gsub("%[INITTARGET%]", "");
		rEffect.sInitSource = "target";
	elseif tInput.sEffect:match("%[INITTURN%]") then
		tInput.sEffect = tInput.sEffect:gsub("%[INITTURN%]", "");
		rEffect.sInitSource = "turn";
	end
end
function getEffectVarInitSourceSummary(nodeEffect)
	local sInitSource = EffectVarManager.getEffectVarFromNode(nodeEffect, "sInitSource", "");
	return EffectVarManager.getEffectVarExpirationTag(sInitSource);
end
function getEffectVarInitSourceTag(s)
	if (s or "") == "" then
		return "";
	end
	if s == "target" then
		return "[INITTARGET]";
	elseif s == "turn" then
		return "[INITTURN]";
	end
	return "";
end

function onEffectVarTargetingTextEncode(rEffect, tOutput)
	if not rEffect or not tOutput then
		return;
	end
	local s = EffectVarManager.getEffectVarTargetingTag(rEffect.sTargeting);
	if (s or "") ~= "" then
		table.insert(tOutput, s);
	end
end
function onEffectVarTargetingTextDecode(tInput, rEffect)
	if not rEffect or not tInput then
		return;
	end
	if (tInput.sEffect or "") == "" then
		return;
	end
	if tInput.sEffect:match("%[SELF%]") then
		tInput.sEffect = tInput.sEffect:gsub("%[SELF%]", "");
		rEffect.sTargeting = "self";
	elseif tInput.sEffect:match("%[TARGETS TO SELF%]") then
		tInput.sEffect = tInput.sEffect:gsub("%[TARGETS TO SELF%]", "");
		rEffect.sTargeting = "toself";
	elseif tInput.sEffect:match("%[SELF TO TARGETS%]") then
		tInput.sEffect = tInput.sEffect:gsub("%[SELF TO TARGETS%]", "");
		rEffect.sTargeting = "totargets";
	end
end
function getEffectVarTargetingSummary(nodeEffect)
	return EffectVarManager.getEffectVarTargetingTag(DB.getValue(nodeEffect, "targeting", ""));
end
function getEffectVarTargetingTag(s)
	if (s or "") == "" then
		return "";
	end
	if s == "self" then
		return "[SELF]";
	elseif s == "toself" then
		return "[TARGETS TO SELF]";
	elseif s == "totargets" then
		return "[SELF TO TARGETS]";
	end
	return "";
end

function onEffectVarApplyTextEncode(rEffect, tOutput)
	if not rEffect or not tOutput then
		return;
	end
	local s = EffectVarManager.getEffectVarApplyTag(rEffect.sApply);
	if (s or "") ~= "" then
		table.insert(tOutput, s);
	end
end
function onEffectVarApplyTextDecode(tInput, rEffect)
	if not rEffect or not tInput then
		return;
	end
	if (tInput.sEffect or "") == "" then
		return;
	end
	if tInput.sEffect:match("%[1/TN%]") then
		tInput.sEffect = tInput.sEffect:gsub("%[1/TN%]", "");
		rEffect.sApply = "onceperturn";
	elseif tInput.sEffect:match("%[1/RD%]") then
		tInput.sEffect = tInput.sEffect:gsub("%[1/RD%]", "");
		rEffect.sApply = "onceperround";
	elseif tInput.sEffect:match("%[2/RD%]") then
		tInput.sEffect = tInput.sEffect:gsub("%[2/RD%]", "");
		rEffect.sApply = "twiceperround";
	elseif tInput.sEffect:match("%[ACTION%]") then
		tInput.sEffect = tInput.sEffect:gsub("%[ACTION%]", "");
		rEffect.sApply = "action";
	elseif tInput.sEffect:match("%[ROLL%]") then
		tInput.sEffect = tInput.sEffect:gsub("%[ROLL%]", "");
		rEffect.sApply = "roll";
	elseif tInput.sEffect:match("%[SINGLE%]") then
		tInput.sEffect = tInput.sEffect:gsub("%[SINGLE%]", "");
		rEffect.sApply = "single";
	end
end
function getEffectVarApplySummary(nodeEffect)
	local sApply = EffectVarManager.getEffectVarFromNode(nodeEffect, "sApply", "");
	return EffectVarManager.getEffectVarApplyTag(sApply);
end
function getEffectVarApplyTag(s)
	if (s or "") == "" then
		return "";
	end
	if s == "onceperturn" then
		return "[1/TN]";
	elseif s == "onceperround" then
		return "[1/RD]";
	elseif s == "twiceperround" then
		return "[2/RD]";
	elseif s == "action" then
		return "[ACTION]";
	elseif s == "roll" then
		return "[ROLL]";
	elseif s == "single" then
		return "[SINGLE]";
	end
	return "";
end

function onStandardEffectApplyUpdate(nodeApply)
	EffectVarManager.onStandardEffectResetUses(DB.getParent(nodeApply));
end
function onStandardEffectResetUses(nodeEffect)
	local sApply = EffectVarManager.getEffectVarFromNode(nodeEffect, "sApply", "");
	if sApply == "onceperround" or sApply == "onceperturn" then
		DB.setValue(nodeEffect, "remaininguses", "number", 1);
	elseif sApply == "twiceperround" then
		DB.setValue(nodeEffect, "remaininguses", "number", 2);
	end
end

function onEffectVarUnitsTextEncode(rEffect, tOutput)
	if not rEffect or not tOutput then
		return;
	end
	local s = EffectVarManager.getEffectVarUnitsTag(rEffect.sUnits);
	if (s or "") ~= "" then
		table.insert(tOutput, s);
	end
end
function onEffectVarUnitsTextDecode(tInput, rEffect)
	if not rEffect or not tInput then
		return;
	end
	if (tInput.sEffect or "") == "" then
		return;
	end
	if tInput.sEffect:match("%[UNITS MIN%]") then
		tInput.sEffect = tInput.sEffect:gsub("%[UNITS MIN%]", "");
		rEffect.sUnits = "minute";
	elseif tInput.sEffect:match("%[UNITS HR%]") then
		tInput.sEffect = tInput.sEffect:gsub("%[UNITS HR%]", "");
		rEffect.sUnits = "hour";
	elseif tInput.sEffect:match("%[UNITS DAY%]") then
		tInput.sEffect = tInput.sEffect:gsub("%[UNITS DAY%]", "");
		rEffect.sUnits = "day";
	elseif tInput.sEffect:match("%[UNITS TURN%]") then
		tInput.sEffect = tInput.sEffect:gsub("%[UNITS TURN%]", "");
		rEffect.sUnits = "turn";
	elseif tInput.sEffect:match("%[UNITS WEEK%]") then
		rEffect.sUnits = "week";
	elseif tInput.sEffect:match("%[UNITS MONTH%]") then
		rEffect.sUnits = "month";
	elseif tInput.sEffect:match("%[UNITS YEAR%]") then
		rEffect.sUnits = "year";
	end
end
function getEffectVarUnitsSummary(nodeEffect)
	local sUnits = EffectVarManager.getEffectVarFromNode(nodeEffect, "sUnits", "");
	return EffectVarManager.getEffectVarUnitsTag(sUnits);
end
function getEffectVarUnitsTag(s)
	if (s or "") == "" then
		return "";
	end
	if s == "minute" then
		return "[UNITS MIN]";
	elseif s == "hour" then
		return "[UNITS HR]";
	elseif s == "day" then
		return "[UNITS DAY]";
	elseif s == "turn" then
		return "[UNITS TURN]";
	elseif s == "week" then
		return "[UNITS WEEK]";
	elseif s == "month" then
		return "[UNITS MONTH]";
	elseif s == "year" then
		return "[UNITS YEAR]";
	end
	return "";
end
