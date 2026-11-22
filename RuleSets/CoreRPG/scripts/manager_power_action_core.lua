--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

--
--	Registrations and Handlers
--

local _tAllTypeData = {};
function registerActionType(sType, tTypeData)
	_tAllTypeData[sType] = tTypeData;
	if tTypeData and (sType ~= "") and not tTypeData.nOrder then
		tTypeData.nOrder = #_tAllTypeData;
	end
end
function overrideActionType(sType, tTypeData)
	if _tAllTypeData[sType] then
		for k,v in pairs(tTypeData) do
			_tAllTypeData[sType][k] = v;
		end
	else
		_tAllTypeData[sType] = tTypeData;
	end
end

function isActionType(sType)
	return (_tAllTypeData[sType] ~= nil);
end
function getActionTypes()
	local tUnsortedTypes = {};
	for k,_ in pairs(_tAllTypeData) do
		if k ~= "" then
			table.insert(tUnsortedTypes, k);
		end
	end
	return tUnsortedTypes;
end
function getSortedActionTypes()
	local tSortedTypes = {};
	for k,_ in pairs(_tAllTypeData) do
		if k ~= "" then
			table.insert(tSortedTypes, k);
		end
	end
	table.sort(tSortedTypes, PowerActionManagerCore.sortfuncActionTypes);
	return tSortedTypes;
end
function sortfuncActionTypes(sType1, sType2)
	local nOrder1 = _tAllTypeData[sType1].nOrder or 1;
	local nOrder2 = _tAllTypeData[sType2].nOrder or 1;
	if nOrder1 ~= nOrder2 then
		return nOrder1 > nOrder2;
	end
	return sType1 > sType2;
end

function getActionType(nodeAction)
	return DB.getValue(nodeAction, "type", "");
end
function resolveActionTypeData(nodeAction, tData)
	if not tData then
		tData = {};
	end
	tData.sType = PowerActionManagerCore.getActionType(nodeAction);
	return tData;
end
function callActionTypeFunction(sFunction, nodeAction, tData)
	if not tData or (tData.sType or "") == "" then
		return nil;
	end

	local v = _tAllTypeData[tData.sType] and _tAllTypeData[tData.sType][sFunction];
	if not v then
		v = _tAllTypeData[""] and _tAllTypeData[""][sFunction];
	end
	if not v then
		return nil;
	end

	if type(v) == "function" then
		return v(nodeAction, tData);
	end
	return v;
end

function getActionButtonIcons(nodeAction, tData)
	if not nodeAction then
		return "", "";
	end
	local tData = PowerActionManagerCore.resolveActionTypeData(nodeAction, tData);
	local sButton1, sButton2 = PowerActionManagerCore.callActionTypeFunction("fnGetButtonIcons", nodeAction, tData);
	if sButton1 then
		return sButton1, sButton2 ;
	end
	return "", "";
end
function getActionText(nodeAction, tData)
	if not nodeAction then
		return "";
	end
	local tData = PowerActionManagerCore.resolveActionTypeData(nodeAction, tData);
	return PowerActionManagerCore.callActionTypeFunction("fnGetText", nodeAction, tData) or "";
end
function getActionTooltip(nodeAction, tData)
	if not nodeAction then
		return "";
	end
	local tData = PowerActionManagerCore.resolveActionTypeData(nodeAction, tData);
	return PowerActionManagerCore.callActionTypeFunction("fnGetTooltip", nodeAction, tData) or "";
end
function performAction(draginfo, nodeAction, tData)
	if not nodeAction then
		return nil;
	end
	local tData = PowerActionManagerCore.resolveActionTypeData(nodeAction, tData);
	tData.draginfo = draginfo;
	return PowerActionManagerCore.callActionTypeFunction("fnPerform", nodeAction, tData);
end

--
--	Common Functions
--

function getActionEffectTooltip(nodeAction, tData)
	if tData and tData.sSubRoll == "duration" then
		return string.format("%s: %s", Interface.getString("power_tooltip_duration"), PowerActionManagerCore.getActionEffectText(nodeAction, tData));
	end

	local tTooltip = {};
	local sAutoKey = StringManager.trim(DB.getValue(nodeAction, "autokey", ""));
	if sAutoKey ~= "" then
		table.insert(tTooltip, StringManager.capitalizeAll(sAutoKey));
	end
	table.insert(tTooltip, string.format("%s: %s", Interface.getString("power_tooltip_effect"), PowerActionManagerCore.getActionEffectText(nodeAction, tData)));
	return table.concat(tTooltip, "\r");
end

function getActionEffectText(nodeAction, tData)
	if tData and tData.sSubRoll == "duration" then
		local nDuration = DB.getValue(nodeAction, "durmod", 0);
		if nDuration == 0 then
			return "";
		end

		local tOutput = {};
		table.insert(tOutput, tostring(nDuration) or "");

		local sUnits = DB.getValue(nodeAction, "durunit", "");
		if sUnits ~= "" then
			if sUnits == "minute" then
				table.insert(tOutput, "min");
			elseif sUnits == "turn" then
				table.insert(tOutput, "trn");
			elseif sUnits == "hour" then
				table.insert(tOutput, "hr");
			elseif sUnits == "day" then
				table.insert(tOutput, "dy");
			elseif sUnits == "week" then
				table.insert(tOutput, "wk");
			elseif sUnits == "month" then
				table.insert(tOutput, "mo");
			elseif sUnits == "year" then
				table.insert(tOutput, "yr");
			else
				table.insert(tOutput, "rd");
			end
		end
		return table.concat(tOutput, " ");
	end

	local sLabel = EffectVarManager.getEffectVarFromNode(nodeAction, "sName", "");
	if sLabel == "" then
		return "";
	end

	local tOutput = {};
	table.insert(tOutput, sLabel);

	local sApply = EffectVarManager.getEffectVarApplySummary(nodeAction);
	if (sApply or "") ~= "" then
		table.insert(tOutput, sApply);
	end
	local sTargeting = EffectVarManager.getEffectVarTargetingSummary(nodeAction);
	if (sTargeting or "") ~= "" then
		table.insert(tOutput, sTargeting);
	end
	local sExpiration = EffectVarManager.getEffectVarExpirationSummary(nodeAction);
	if (sExpiration or "") ~= "" then
		table.insert(tOutput, sExpiration);
	end
	local sInitSource = EffectVarManager.getEffectVarInitSourceSummary(nodeAction);
	if (sInitSource or "") ~= "" then
		table.insert(tOutput, sInitSource);
	end

	return table.concat(tOutput, "; ");
end

--
--	Misc functions
--

function appendActionPowerTags(vPowerTags, vAction)
	if not vPowerTags then
		return;
	end

	if type(vAction) == "databasenode" then
		local sType = DB.getValue(vAction, "type", "");
		if sType == "damage" then
			for _,v in ipairs(UtilityManager.getNodeSortedChildren(vAction, "damagelist")) do
				PowerActionManagerCore.appendDamagePowerTags(vPowerTags, DB.getValue(v, "type", ""));
			end
		elseif sType == "effect" then
			PowerActionManagerCore.appendEffectPowerTags(vPowerTags, EffectVarManager.getEffectVarFromNode(vAction, "sName", ""));
		end
	elseif type(vAction) == "table" then
		if (vAction.type or "") == "damage" then
			for _,tClause in ipairs(vAction.clauses or {}) do
				PowerActionManagerCore.appendDamagePowerTags(vPowerTags, tClause.dmgtype or "");
			end
		elseif (vAction.type or "") == "effect" then
			PowerActionManagerCore.appendEffectPowerTags(vPowerTags, vAction.sName or "");
		end
	end
end
function appendDamagePowerTags(vPowerTags, sDmgType)
	if not vPowerTags then
		return;
	end

	if SetManager.isSet(vPowerTags) then
		for _,s in ipairs(StringManager.splitByPattern(sDmgType:lower(), ",", true)) do
			if ActionCore.isDamageType(s) then
				SetManager.add(vPowerTags, s);
			end
		end
	else
		for _,s in ipairs(StringManager.splitByPattern(sDmgType:lower(), ",", true)) do
			if ActionCore.isDamageType(s) and not StringManager.contains(vPowerTags, s) then
				table.insert(vPowerTags, s);
			end
		end
	end
end
function appendEffectPowerTags(vPowerTags, sEffect)
	if not vPowerTags then
		return;
	end

	if SetManager.isSet(vPowerTags) then
		for _,sComp in ipairs(EffectManager.parseEffect(sEffect)) do
			local sLower = sComp:lower();
			if ActionCore.isCondition(sLower) then
				SetManager.add(vPowerTags, sLower);
			end
		end
	else
		for _,sComp in ipairs(EffectManager.parseEffect(sEffect)) do
			local sLower = sComp:lower();
			if ActionCore.isCondition(sLower) and not StringManager.contains(vPowerTags, sLower) then
				table.insert(vPowerTags, sLower);
			end
		end
	end
end
