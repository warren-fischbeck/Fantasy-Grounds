--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

--
--	GAME DATA
--

function getAttackTypes()
	return DataCommon and DataCommon.atktypes or {};
end

local _setRangeTypes;
function getRangeTypes()
	return DataCommon and DataCommon.rangetypes or {};
end
function isRangeType(s)
	if not _setRangeTypes then
		_setRangeTypes = SetManager.new(ActionCore.getRangeTypes());
	end
	return SetManager.contains(_setRangeTypes, s);
end

local _setDamageTypes;
local _setDamageTypesShort;
function getDamageTypes()
	return DataCommon and DataCommon.dmgtypes or {};
end
function isDamageType(s)
	if not _setDamageTypes then
		_setDamageTypes = SetManager.new(ActionCore.getDamageTypes());
	end
	if not _setDamageTypesShort then
		_setDamageTypesShort = SetManager.new();
		for k,_ in pairs(DataCommon and DataCommon.dmgtypes_stol or {}) do
			SetManager.add(_setDamageTypesShort, k);
		end
	end
	return SetManager.contains(_setDamageTypes, s) or SetManager.contains(_setDamageTypesShort, s);
end
function setDamageTypes(tDamageTypes)
	if not DataCommon then
		return;
	end
	DataCommon.dmgtypes = tDamageTypes;
	_setDamageTypes = nil;

	if EffectQueryManager.hasDescriptorGroup("damage") then
		local tDmgCond = SetManager.union(SetManager.union(ActionCore.getDamageTypes(), "all"), ActionCore.getConditions()):toarray();
		EffectManager.addDescriptorGroup({ sKey = "damage", bBonus = true, bMulti = true, tTags = tDmgCond, });
	end
end
function addDamageType(vParam)
	if not DataCommon then
		return;
	end
	DataCommon.dmgtypes = ActionCore.getDamageTypes();
	if type(vParam) == "table" then
		for _,v in pairs(vParam) do
			table.insert(DataCommon.dmgtypes, v);
		end
	elseif type(vParam) == "string" then
		table.insert(DataCommon.dmgtypes, vParam);
	else
		return;
	end
	_setDamageTypes = nil;

	EffectQueryManager.addDescriptorGroupTag("damage", vParam);
end

local _setBasicDamageTypes;
function getBasicDamageTypes()
	return DataCommon and DataCommon.basicdmgtypes or {};
end
function isBasicDamageType(s)
	if not _setBasicDamageTypes then
		local tBasic = ActionCore.getBasicDamageTypes();
		if #tBasic > 0 then
			_setBasicDamageTypes = SetManager.new(tBasic);
		else
			_setBasicDamageTypes = SetManager.new(ActionCore.getDamageTypes());
			SetManager.remove(_setBasicDamageTypes, ActionCore.getSpecialDamageTypes());
		end
	end
	return SetManager.contains(_setBasicDamageTypes, s);
end
function addBasicDamageType(vParam)
	if not DataCommon then
		return;
	end
	local tBasic = ActionCore.getBasicDamageTypes();
	if #tBasic == 0 then
		local _setBasic = SetManager.new(ActionCore.getDamageTypes());
		SetManager.remove(_setBasic, ActionCore.getSpecialDamageTypes());
		DataCommon.basicdmgtypes = _setBasic:toarray();
	end

	DataCommon.basicdmgtypes = ActionCore.getBasicDamageTypes();
	if type(vParam) == "table" then
		for _,v in pairs(vParam) do
			table.insert(DataCommon.basicdmgtypes, v);
		end
	elseif type(vParam) == "string" then
		table.insert(DataCommon.basicdmgtypes, vParam);
	else
		return;
	end
	_setBasicDamageTypes = nil;

	ActionCore.addDamageType(vParam);
end

local _setEnergyDamageTypes;
function getEnergyDamageTypes()
	return DataCommon and DataCommon.energytypes or {};
end
function isEnergyDamageType(s)
	if not _setEnergyDamageTypes then
		_setEnergyDamageTypes = SetManager.new(ActionCore.getEnergyDamageTypes());
	end
	return SetManager.contains(_setEnergyDamageTypes, s);
end
function addEnergyDamageType(vParam)
	if not DataCommon then
		return;
	end
	DataCommon.energytypes = ActionCore.getEnergyDamageTypes();
	if type(vParam) == "table" then
		for _,v in pairs(vParam) do
			table.insert(DataCommon.energytypes, v);
		end
	elseif type(vParam) == "string" then
		table.insert(DataCommon.energytypes, vParam);
	else
		return;
	end
	_setEnergyDamageTypes = nil;

	ActionCore.addBasicDamageType(vParam);
end

local _setSpecialDamageTypes;
function getSpecialDamageTypes()
	return DataCommon and DataCommon.specialdmgtypes or {};
end
function isSpecialDamageType(s)
	if not _setSpecialDamageTypes then
		_setSpecialDamageTypes = SetManager.new(ActionCore.getSpecialDamageTypes());
	end
	return SetManager.contains(_setSpecialDamageTypes, s);
end
function addSpecialDamageType(vParam)
	if not DataCommon then
		return;
	end
	DataCommon.specialdmgtypes = ActionCore.getSpecialDamageTypes();
	if type(vParam) == "table" then
		for _,v in pairs(vParam) do
			table.insert(DataCommon.specialdmgtypes, v);
		end
	elseif type(vParam) == "string" then
		table.insert(DataCommon.specialdmgtypes, vParam);
	else
		return;
	end
	_setSpecialDamageTypes = nil;

	ActionCore.addDamageType(vParam);
end

local _setCriticalDamageTypes;
function getCriticalDamageTypes()
	return DataCommon and DataCommon.criticaldmgtypes or { "critical" };
end
function isCriticalDamageType(s)
	if not _setCriticalDamageTypes then
		_setCriticalDamageTypes = SetManager.new(ActionCore.getCriticalDamageTypes());
	end
	return SetManager.contains(_setCriticalDamageTypes, s);
end
function addCriticalDamageType(vParam)
	if not DataCommon then
		return;
	end
	DataCommon.criticaldmgtypes = ActionCore.getCriticalDamageTypes();
	if type(vParam) == "table" then
		for _,v in pairs(vParam) do
			table.insert(DataCommon.criticaldmgtypes, v);
		end
	elseif type(vParam) == "string" then
		table.insert(DataCommon.criticaldmgtypes, vParam);
	else
		return;
	end
	_setCriticalDamageTypes = nil;

	ActionCore.addSpecialDamageType(vParam);
end

local _setImmuneTypes;
function getImmuneTypes()
	return DataCommon and DataCommon.immunetypes or {};
end
function isImmuneType(s)
	if not _setImmuneTypes then
		_setImmuneTypes = SetManager.new(ActionCore.getImmuneTypes());
	end
	return SetManager.contains(_setImmuneTypes, s);
end
function addImmuneType(vParam)
	if not DataCommon then
		return;
	end
	DataCommon.immunetypes = DataCommon.immunetypes or {};
	if type(vParam) == "table" then
		for _,v in pairs(vParam) do
			table.insert(DataCommon.immunetypes, v);
		end
	elseif type(vParam) == "string" then
		table.insert(DataCommon.immunetypes, vParam);
	else
		return;
	end
	_setImmuneTypes = nil;
end

local _setConditions;
function getConditions()
	return DataCommon and DataCommon.conditions or {};
end
function isCondition(s)
	if not _setConditions then
		_setConditions = SetManager.new(ActionCore.getConditions());
	end
	return SetManager.contains(_setConditions, s);
end
function setConditions(tConditions)
	if not DataCommon then
		return;
	end
	DataCommon.conditions = tConditions;
	_setConditions = nil;

	if EffectQueryManager.hasDescriptorGroup("damage") then
		local tDmgCond = SetManager.union(SetManager.union(ActionCore.getDamageTypes(), "all"), ActionCore.getConditions()):toarray();
		EffectManager.addDescriptorGroup({ sKey = "damage", bBonus = true, bMulti = true, tTags = tDmgCond, });
	end
	EffectQueryManager.setConditionalCheckDescriptors("CONDITION", ActionCore.getConditions());
end
function addCondition(vParam)
	if not DataCommon then
		return;
	end
	DataCommon.conditions = DataCommon.conditions or {};
	if type(vParam) == "table" then
		for _,v in pairs(vParam) do
			table.insert(DataCommon.conditions, v);
		end
	elseif type(vParam) == "string" then
		table.insert(DataCommon.conditions, vParam);
	else
		return;
	end
	_setConditions = nil;

	EffectQueryManager.addDescriptorGroupTag("damage", vParam);
	EffectQueryManager.setConditionalCheckDescriptors("CONDITION", ActionCore.getConditions());
end

function getCreatureSizes()
	return DataCommon and DataCommon.creaturesize or {};
end

--
--	OUTPUT
--

function applyMessage(rSource, rTarget, rRoll, tApplyData)
	rRoll.sType = rRoll.sType or tApplyData.sType;
	rRoll.nTotal = tApplyData.nValue or rRoll.nTotal;

	local tShortOutput = {};
	local tLongOutput = {};

	if not rTarget and #(tApplyData.tNotifications or {}) == 0 then
		return;
	end

	-- Standard roll information
	local sResultOutput = string.format("[%s", tApplyData.sResultText or "");
	if (rRoll.nOrder or 1) > 1 then
		sResultOutput = string.format("%s #%d", sResultOutput, rRoll.nOrder);
	end
	if (rRoll.sRange or "") ~= "" then
		sResultOutput = string.format("%s (%s)", sResultOutput, rRoll.sRange);
	end
	sResultOutput = string.format("%s]", sResultOutput);
	if (rRoll.sLabel or "") ~= "" then
		sResultOutput = string.format("%s %s", sResultOutput, rRoll.sLabel);
	end
	table.insert(tShortOutput, sResultOutput);
	if rRoll.nTotal then
		sResultOutput = string.format("%s [%d]", sResultOutput, rRoll.nTotal);
	end
	if tApplyData.nTargetDC then
		sResultOutput = string.format("%s [vs DC %d]", sResultOutput, tApplyData.nTargetDC);
	end
	table.insert(tLongOutput, sResultOutput);

	-- Actor information
	if rSource then
		local sSourceOutput = string.format("[%s]", ActorManager.getDisplayName(rSource));
		table.insert(tShortOutput, sSourceOutput);
		table.insert(tLongOutput, sSourceOutput);
	end
	if rTarget then
		local sTargetName;
		if (rRoll.sSubtargetPath or "") ~= "" then
			sTargetName = string.format("%s (%s)", ActorManager.getDisplayName(rTarget), DB.getValue(DB.getPath(rRoll.sSubtargetPath, "name"), ""));
		else
			sTargetName = ActorManager.getDisplayName(rTarget);
		end
		local sTargetOutput = string.format("-> [%s]", sTargetName);
		table.insert(tShortOutput, sTargetOutput);
		table.insert(tLongOutput, sTargetOutput);
	end

	-- Handle MAX/HALF notifications
	if rRoll.bModMax then
		table.insert(tLongOutput, "[MAX]");
	end
	if rRoll.bModHalf then
		table.insert(tLongOutput, "[HALF]");
	end

	-- Extra roll information
	for _,s in ipairs(tApplyData.tNotifications or {}) do
		if s ~= "" then
			table.insert(tLongOutput, s);
		end
	end

	-- Build message
	local msgShort = { font = "msgfont" };
	local msgLong = { font = "msgfont" };
	if (tApplyData.sResultIcon or "") ~= "" then
		msgShort.icon = tApplyData.sResultIcon;
		msgLong.icon = tApplyData.sResultIcon;
	end
	if (tApplyData.sResultIconLong or "") ~= "" then
		msgLong.icon = tApplyData.sResultIconLong;
	end
	if (tApplyData.sResultIconShort or "") ~= "" then
		msgShort.icon = tApplyData.sResultIconShort;
	end
	msgShort.text = table.concat(tShortOutput, "\r");
	msgLong.text = table.concat(tLongOutput, "\r");

	ActionsManager.outputResult(rRoll.bTower, rSource, rTarget, msgLong, msgShort);
end

--
--	ROLL ENCODE / DECODE
--

function isActionText(s, sTextRes)
	if not s or not sTextRes then
		return false;
	end
	local sTag = Interface.getString(sTextRes);
	if sTag == "" then
		return false;
	end
	local sPattern = string.format("%%[%s[^]]*%%]", sTag);
	return (s:match(sPattern) and true or false);
end
function encodeActionText(rAction, sTextRes)
	local tOutput = {};
	table.insert(tOutput, Interface.getString(sTextRes));
	if (rAction and rAction.order or 1) > 1 then
		table.insert(tOutput, string.format("#%d", rAction.order));
	end
	if (rAction and rAction.range or "") ~= "" then
		table.insert(tOutput, string.format("(%s)", rAction.range));
	end
	return string.format("[%s] %s", table.concat(tOutput, " "), StringManager.capitalizeAll((rAction and rAction.label) or (rAction and rAction.name) or ""));
end
function decodeRollData(rRoll, sTextRes)
	if not rRoll or not sTextRes then
		return;
	end
	if not rRoll.sDesc then
		return;
	end
	local sTag = Interface.getString(sTextRes);
	if not rRoll.nOrder then
		local sPattern = string.format("%%[%s.-#(%%d+)", sTag);
		rRoll.nOrder = tonumber(rRoll.sDesc:match(sPattern)) or nil;
	end
	if not rRoll.sRange then
		local sPattern = string.format("%%[%s.-%%((%%w+)%%)%%]", sTag);
		rRoll.sRange = rRoll.sDesc:match(sPattern);
	end
	if not rRoll.sLabel then
		local sPattern = string.format("%%[%s.-%%]([^%%[]+)", sTag);
		rRoll.sLabel = StringManager.trim(rRoll.sDesc:match(sPattern));
	end
end

function decodeLabelText(s, sTextRes)
	if not s or not sTextRes then
		return "";
	end
	local sTag = Interface.getString(sTextRes);
	if sTag == "" then
		return "";
	end
	local sPattern = string.format("%%[%s[^]]*%%] ([^[]+)", sTag);
	return StringManager.trim(s:match(sPattern) or "");
end
function decodeRangeText(s, sTextRes, sDefault)
	if not s or not sTextRes then
		return sDefault or "";
	end
	local sTag = Interface.getString(sTextRes);
	if sTag == "" then
		return sDefault or "";
	end
	local sPattern = string.format("%%[%s.*%%((%%w+)%%)%%]", sTag);
	return s:match(sPattern) or sDefault or "";
end

--
--	ROLL CLAUSE MANAGEMENT
--

function addRightClickDiceToClauses(rRoll)
	if not rRoll or (#(rRoll.clauses or {}) <= 0) or not rRoll.clauses[1].dice then
		return;
	end

	local nOrigDice = 0;
	for _,tClause in ipairs(rRoll.clauses) do
		nOrigDice = nOrigDice + #(tClause.dice or {});
	end
	if #rRoll.aDice > nOrigDice then
		for i = nOrigDice + 1, #rRoll.aDice do
			if type(rRoll.aDice[i]) == "table" then
				table.insert(rRoll.clauses[1].dice, rRoll.aDice[i].type);
			else
				table.insert(rRoll.clauses[1].dice, rRoll.aDice[i]);
			end
		end
	end
end

function encodeRollClauses(rRoll)
	if not rRoll.clauses then
		return;
	end
	rRoll.sClauseData = UtilityManager.encodeTableToString(rRoll.clauses);
end
function decodeRollClauses(rRoll)
	if not rRoll.sClauseData then
		if not ActionHealthD20.isHealActionType(rRoll) and not ActionHealthD20.isDamageActionType(rRoll) then
			return false;
		end
	end

	local tClauses = UtilityManager.decodeStringToTable(rRoll.sClauseData);
	rRoll.sClauseData = nil;

	local nClauses = #tClauses;

	-- Handle total
	local nMainDieIndex = 0;
	for _,tClause in ipairs(tClauses) do
		tClause.nTotal = tClause.modifier or 0;
		for _,_ in ipairs(tClause.dice or {}) do
			nMainDieIndex = nMainDieIndex + 1;
			local tDie = rRoll.aDice[nMainDieIndex];
			if tDie then
				tClause.nTotal = tClause.nTotal + (tDie.value or tDie.result or 0);
			end
		end
	end

	-- Process each type clause in the damage description (DRAG ROLL RESULT OR APPLY DAMAGE)
	for sDamageType, sDamageDice in rRoll.sDesc:gmatch("%[TYPE: ([^(]*) %(([^)]*)%)]") do
		local sTotal = sDamageDice:match("=(%d+)");
		if (sTotal or "") ~= "" then
			local nTotal = tonumber(sTotal) or 0;
			local tClause = {
				dmgtype = StringManager.trim(sDamageType),
				dice = {},
				modifier = nTotal,
				nTotal = nTotal,
			};
			table.insert(tClauses, tClause);
		end
	end

	-- Add clause if no TYPE tag found
	if #tClauses == 0 then
		local tClause = {
			dmgtype = "",
			dice = {},
			modifier = rRoll.nMod,
			nTotal = rRoll.nMod,
		};
		for _,vDie in ipairs(rRoll.aDice) do
			if type(vDie) == "table" then
				table.insert(tClause.dice, vDie.type);
				tClause.nTotal = tClause.nTotal + (vDie.value or vDie.result or 0);
			else
				table.insert(tClause.dice, vDie);
			end
		end
		table.insert(tClauses, tClause);
	end

	-- Handle drag results that are halved or doubled
	if #(rRoll.aDice or {}) == 0 then
		local nResultTotal = 0;
		for i = nClauses + 1, #tClauses do
			nResultTotal = tClauses[i].nTotal;
		end
		if (nResultTotal > 0) and (nResultTotal ~= rRoll.nMod) then
			if math.floor(nResultTotal / 2) == rRoll.nMod then
				for _,tClause in ipairs(tClauses) do
					tClause.modifier = math.floor(tClause.modifier / 2);
					tClause.nTotal = math.floor(tClause.nTotal / 2);
				end
			elseif nResultTotal * 2 == rRoll.nMod then
				for _,tClause in ipairs(tClauses) do
					tClause.modifier = 2 * tClause.modifier;
					tClause.nTotal = 2 * tClause.nTotal;
				end
			end
		end
	end

	rRoll.clauses = tClauses;

	-- Remove damage type display information from roll description (if dragged from chat)
	rRoll.sDesc = rRoll.sDesc:gsub("%s?%[TYPE:[^]]*%]", "");
	return true;
end
function encodeDamageTypesDisplay(rRoll)
	local nFinalTotal = ActionsManager.total(rRoll);

	-- Capture any manual modifiers and adjust damage types accordingly
	-- NOTE: Positive values are added to first damage clause, Negative values reduce damage clauses until none remain
	local nClausesTotal = 0;
	for _,tClause in ipairs(rRoll.clauses) do
		nClausesTotal = nClausesTotal + tClause.nTotal;
	end
	if nFinalTotal ~= nClausesTotal then
		local nRemainder = nFinalTotal - nClausesTotal;
		if nRemainder > 0 then
			if #(rRoll.clauses) == 0 then
				table.insert(rRoll.clauses, { dmgtype = "", stat = "", dice = {}, modifier = nRemainder, nTotal = nRemainder})
			else
				rRoll.clauses[1].modifier = (rRoll.clauses[1].modifier or 0) + nRemainder;
				rRoll.clauses[1].nTotal = (rRoll.clauses[1].nTotal or 0) + nRemainder;
			end
		else
			for _,tClause in ipairs(rRoll.clauses) do
				if (tClause.nTotal or 0) >= -nRemainder then
					tClause.modifier = (tClause.modifier or 0) + nRemainder;
					tClause.nTotal = (tClause.nTotal or 0) + nRemainder;
					break;
				else
					tClause.modifier = (tClause.modifier or 0) - tClause.nTotal;
					nRemainder = nRemainder + tClause.nTotal;
					tClause.nTotal = 0;
				end
			end
		end
	end

	-- Collapse damage clauses into smallest set, then add to roll description as text
	for _, tClause in ipairs(ActionCore.getCombinedClauses(rRoll.clauses)) do
		if (tClause.sType or "") ~= "" then
			rRoll.sDesc = string.format("%s\r[TYPE: %s (%s=%d)]",
					rRoll.sDesc,
					tClause.sType,
					StringManager.convertDiceToString(tClause.aDice, tClause.nMod),
					tClause.nTotal);
		end
	end
end
-- Collapse damage clauses by damage type (in the original order, if possible)
function getCombinedClauses(tClauses)
	local tOrderedTypes = {};
	local tDmgTypes = {};
	for _,tClause in ipairs(tClauses) do
		local tDmgType = tDmgTypes[tClause.dmgtype or ""];
		if not tDmgType then
			tDmgType = {
				aDice = {},
				nMod = 0,
				nTotal = 0,
				sType = tClause.dmgtype or "",
			};
			tDmgTypes[tClause.dmgtype or ""] = tDmgType;
			table.insert(tOrderedTypes, tDmgType);
		end

		for _,vDie in ipairs(tClause.dice or {}) do
			table.insert(tDmgType.aDice, vDie);
		end
		tDmgType.nMod = tDmgType.nMod + (tClause.modifier or 0);
		tDmgType.nTotal = tDmgType.nTotal + (tClause.nTotal or 0);
	end
	return tOrderedTypes;
end

--
--	ROLL BUILD
--

function setupRollBuild(sType, _, rAction)
	local rRoll = {
		sType = sType or "",
		aDice = {},
		nMod = 0,
		tNotifications = {},
	};

	if rAction then
		rRoll.bSecret = rAction.bSecret;
		rRoll.sLabel = StringManager.capitalizeAll(rAction.label);
		rRoll.nOrder = rAction.order;
		rRoll.nMod = rAction.modifier or 0;
		rRoll.sRange = rAction.sRange or rAction.range;
	end

	table.insert(rRoll.tNotifications, ActionCore.encodeActionText(rAction, string.format("action_%s_tag", sType or "")));

	return rRoll;
end
function finalizeRollBuild(rRoll)
	rRoll.sDesc = table.concat(rRoll.tNotifications, "\r");
	rRoll.tNotifications = nil;
end

--
--	ROLL TARGETING
--

function onTargeting(_, tTargeting, rRolls)
	local bRemoveOnMiss = false;
	local sOptRMMT = OptionsManager.getOption("RMMT");
	if sOptRMMT == "on" then
		bRemoveOnMiss = true;
	elseif sOptRMMT == "multi" then
		-- Only remove on miss if attacking multiple targets
		local nTargetCount = 0;
		for _, vTargetGroup in ipairs(tTargeting) do
			for _,_ in ipairs(vTargetGroup) do
				nTargetCount = nTargetCount + 1;
				if nTargetCount > 1 then
					break;
				end
			end
		end
		bRemoveOnMiss = (nTargetCount > 1);
	end

	if bRemoveOnMiss then
		for _,rRoll in ipairs(rRolls) do
			rRoll.bRemoveOnMiss = true;
		end
	end

	return tTargeting;
end

--
--	ROLL MOD
--

function setupModRoll(rSource, rTarget, rRoll)
	if not rRoll then
		return;
	end

	if rRoll.sType == "damage" then
		ActionDamageCore.decodeRollData(rRoll);
		rRoll.sEffectBaseTag = "DMG";

		rRoll.bCritical = ModifierManager.getKey("DMG_CRIT") or rRoll.bCritical or Input.isShiftPressed();
		if ActionAttackCore.getCritState(rSource, rTarget) then
			rRoll.bCritical = true;
		end
		rRoll.tEffectFilter = ActionCore.buildEffectFilter(rRoll);
	elseif rRoll.sType == "heal" then
		ActionHealCore.decodeRollData(rRoll);
		if (rRoll.healtype or "") == "" then
			rRoll.sEffectBaseTag = "HEAL";
		elseif (rRoll.healtype or "") == "temp" then
			rRoll.sEffectBaseTag = "TEMP";
		end
	elseif rRoll.sType == "recovery" then
		rRoll.sEffectBaseTag = "HD";
	end

	if ActionCore.decodeRollClauses(rRoll) then
		ActionCore.addRightClickDiceToClauses(rRoll);
	end

	rRoll.tNotifications = {};
	rRoll.bEffects = false;
	rRoll.tEffectDice = {};
	rRoll.nEffectMod = 0;
	rRoll.bStatic = (#(rRoll.aDice or {}) == 0);
	rRoll.nOrigClauses = #(rRoll.clauses or {});
end
function finalizeModRoll(rSource, _, rRoll)
	if not rRoll then
		return;
	end

	if rRoll.bEffects then
		if not StringManager.contains({ "damage", "heal", "recovery", }, rRoll.sType) then
			DiceRollManager.addRollEffectDiceMod(rSource, rRoll, rRoll.tEffectDice, rRoll.nEffectMod);
		end
		if rRoll.tNotifications then
			table.insert(rRoll.tNotifications, EffectManager.buildEffectDiceModOutput(rRoll.tEffectDice, rRoll.nEffectMod));
		end
	end

	if rRoll.tNotifications then
		if rRoll.bModMax then
			table.insert(rRoll.tNotifications, "[MAX]");
		end
		if rRoll.bModDouble then
			table.insert(rRoll.tNotifications, "[DOUBLE]");
		end
		if rRoll.bModHalf then
			table.insert(rRoll.tNotifications, "[HALF]");
		end

		if #(rRoll.tNotifications) > 0 then
			rRoll.sDesc = rRoll.sDesc .. "\r" .. table.concat(rRoll.tNotifications, "\r");
		end

		rRoll.tNotifications = nil;
	end

	rRoll.bEffects = nil;
	rRoll.tEffectDice = nil;
	rRoll.nEffectMod = nil;
	rRoll.sEffectBaseTag = nil;
	rRoll.tEffectFilter = nil;

	ActionCore.encodeRollClauses(rRoll);
end

-- applyModClauseAbilityEffects(rSource, rTarget, rRoll)
function applyModClauseAbilityEffects(rSource, _, rRoll)
	if not rSource then
		return;
	end

	if GameManager.hasOption("abilityeffectskip") then
		return;
	end

	for _,tClause in ipairs(rRoll.clauses or {}) do
		local nEffectMod, nEffectCount = ActorCommonManager.getEffectsBonus(rSource, tClause.stat);
		if nEffectCount > 0 then
			rRoll.bEffects = true;

			if nEffectMod ~= 0 then
				-- Calc current and update bonus
				local nStartMod = ActorCommonManager.getBonus(rSource, tClause.stat);
				local nTotalMod = nStartMod + nEffectMod;

				-- Handle maximum stat mod setting
				-- NOTE: If max limited, then assume no penalty allowed (i.e. bows)
				local nMax = tClause.statmax or 0;
				if nMax > 0 then
					nStartMod = math.max(math.min(nStartMod, nMax), 0);
					nTotalMod = math.max(math.min(nTotalMod, nMax), 0);
				end

				-- Handle multipliers correctly
				-- NOTE: Negative values are not multiplied, but positive values are.
				local nMult = tClause.statmult or 1;
				if nMult ~= 1 then
					if nStartMod > 0 then
						nStartMod = math.floor(nStartMod * nMult);
					end
					if nTotalMod > 0 then
						nTotalMod = math.floor(nTotalMod * nMult);
					end
				end

				-- Apply bonus difference
				local nDiff = nTotalMod - nStartMod;
				tClause.modifier = tClause.modifier + nDiff;
				rRoll.nEffectMod = rRoll.nEffectMod + nDiff;
				rRoll.nMod = rRoll.nMod + nDiff;
			end
		end
	end
end
function applyModMaxEffects(rSource, rTarget, rRoll)
	if (rRoll.sEffectBaseTag or "") == "" then
		return;
	end
	local sEffectTag = rRoll.sEffectBaseTag .. "MAX";

	if rSource then
		local tData = {
			rTarget = rTarget,
			tFilter = rRoll.tEffectFilter,
			tActionTags = rRoll.tActionTags,
		};
		if EffectManager.hasTextOrTag(rSource, sEffectTag, tData) then
			rRoll.bModMax = true;
		end
	end

	if rTarget then
		local tAtData = {
			rTarget = rSource,
			tFilter = rRoll.tEffectFilter,
			tActionTags = rRoll.tActionTags,
		};
		if EffectManager.hasTextOrTag(rTarget, "@" .. sEffectTag, tAtData) then
			rRoll.bModMax = true;
		end
	end
end
function applyModHalfEffects(rSource, rTarget, rRoll)
	if (rRoll.sEffectBaseTag or "") == "" then
		return;
	end
	local sEffectTag = rRoll.sEffectBaseTag .. "HALF";

	if rSource then
		local tData = {
			rTarget = rTarget,
			tFilter = rRoll.tEffectFilter,
			tActionTags = rRoll.tActionTags,
		};
		if EffectManager.hasTextOrTag(rSource, sEffectTag, tData) then
			rRoll.bModHalf = true;
		end
	end

	if rTarget then
		local tAtData = {
			rTarget = rSource,
			tFilter = rRoll.tEffectFilter,
			tActionTags = rRoll.tActionTags,
		};
		if EffectManager.hasTextOrTag(rTarget, "@" .. sEffectTag, tAtData) then
			rRoll.bModHalf = true;
		end
	end
end
-- applyModTabletopButtons(rSource, rTarget, rRoll)
function applyModTabletopButtons(_, _, rRoll)
	if (rRoll.sEffectBaseTag or "") == "" then
		return;
	end

	if ModifierManager.getKey(rRoll.sEffectBaseTag .. "_MAX") then
		rRoll.bModMax = true;
	end
	if ModifierManager.getKey(rRoll.sEffectBaseTag .. "_HALF") then
		rRoll.bModHalf = true;
	end
end

function applyModRollEffectBonusDiceMod(rActor, rRoll, sEffectTag, tData)
	if not rRoll then
		return;
	end
	local tEffectDice, nEffectMod, nEffectCount = EffectManager.getBonusDiceMod(rActor, sEffectTag, tData);
	ActionCore.applyModRollEffect(rRoll, tEffectDice, nEffectMod, nEffectCount);
end
function applyModRollEffectBonusMod(rActor, rRoll, sEffectTag, tData)
	if not rRoll then
		return;
	end
	local nEffectMod, nEffectCount = EffectManager.getBonusMod(rActor, sEffectTag, tData);
	ActionCore.applyModRollEffect(rRoll, nil, nEffectMod, nEffectCount);
end
function applyModRollEffect(rRoll, tEffectDice, nEffectMod, nEffectCount)
	if not rRoll or ((nEffectCount or 0) <= 0) then
		return;
	end
	rRoll.bEffects = true;
	for _,sDie in ipairs(tEffectDice or {}) do
		table.insert(rRoll.tEffectDice, sDie);
	end
	rRoll.nEffectMod = rRoll.nEffectMod + (nEffectMod or 0);
end

--
--	ROLL COMPLETION (PRE-TARGET)
--

function applyRollGeneralModifiers(_, rRoll)
	if rRoll.bModMax then
		for i = 1, #rRoll.aDice do
			ActionCore.applyRollMaxDie(rRoll, i);
		end
		return;
	end

	local nMainDiceIndex = 1;
	for _,tClause in ipairs(rRoll.clauses or {}) do
		local nClauseDice = #(tClause.dice or {});
		if tClause.bMax then
			local i = 0;
			while i < nClauseDice do
				if rRoll.aDice[nMainDiceIndex + i] then
					if rRoll.aDice[nMainDiceIndex + i].dropped then
						nMainDiceIndex = nMainDiceIndex + 1;
					else
						ActionCore.applyRollMaxDie(rRoll, nMainDiceIndex + i);
						i = i + 1;
					end
				else
					break;
				end
			end
		elseif (tClause.nMin or 0) > 0 then
			local i = 0;
			while i < nClauseDice do
				if rRoll.aDice[nMainDiceIndex + i] then
					if rRoll.aDice[nMainDiceIndex + i].dropped then
						nMainDiceIndex = nMainDiceIndex + 1;
					else
						ActionCore.applyRollMinDie(rRoll, nMainDiceIndex + i, tClause.nMin);
						i = i + 1;
					end
				else
					break;
				end
			end
		end
		nMainDiceIndex = nMainDiceIndex + nClauseDice;
	end
end
function applyRollMaxDie(rRoll, kDie)
	if not rRoll or not rRoll.aDice then
		return false;
	end
	local tDie = rRoll.aDice[kDie];
	if not tDie then
		return false;
	end
	if tDie.dropped then
		return false;
	end

	local sSign,_,sDieSides = tDie.type:match("^([%-%+]?)([dDrRgGbBpP])([%dF]+)");
	if not sDieSides or (sSign == "-") then
		return false;
	end

	local nResult;
	if sDieSides == "F" then
		nResult = 1;
	else
		nResult = tonumber(sDieSides) or 0;
	end

	if nResult <= tDie.result then
		return false;
	end

	tDie.result = nResult;
	tDie.value = nil;
	return true;
end
function applyRollMinDie(rRoll, kDie, nMinValue)
	if not rRoll or not rRoll.aDice then
		return false;
	end
	local tDie = rRoll.aDice[kDie];
	if not tDie then
		return false;
	end
	if tDie.dropped then
		return false;
	end

	local sSign,_,sDieSides = tDie.type:match("^([%-%+]?)([dDrRgGbBpP])([%dF]+)");
	if not sDieSides or (sDieSides == "F") or (sSign == "-") then
		return false;
	end
	local nDieSides = tonumber(sDieSides) or 0;
	if nDieSides < 2 then
		return false;
	end

	local nMinValue = tonumber(nMinValue) or 0;
	if (nMinValue < 2) or (tDie.result >= nMinValue) then
		return false;
	end

	rRoll.sDesc = string.format("%s\r[MIN REPLACE D%d=%d]", rRoll.sDesc, kDie, tDie.result);

	tDie.result = nMinValue;
	tDie.value = nil;
	return true;
end

--
--	REST
--

local DEFAULT_SHORT_REST_DURATION = 10 * 60; -- 1 Hour
local DEFAULT_LONG_REST_DURATION = (10 * 60) * 24; -- 1 Day
local _tRestDuration = { ["short"] = DEFAULT_SHORT_REST_DURATION, ["long"] = DEFAULT_LONG_REST_DURATION, };
function getRestDuration(sKey)
	if (sKey or "") == "" then
		return DEFAULT_LONG_REST_DURATION;
	end
	return _tRestDuration[sKey] or DEFAULT_LONG_REST_DURATION;
end
function setRestDuration(sKey, n)
	if (sKey or "") == "" then
		return;
	end
	_tRestDuration[sKey] = n;
end

-- Rest Types assume:
--		Radial menu text defined as string named "menu_rest<resttype>"
--		Radial menu icon defined as icon named "menu_rest<resttype>"
--		Chat menu notification for single actor defined as string named "message_rest<resttype>"
--		Chat menu notification for all combatants defined as string named "message_restall<resttype>"
-- NOTE: If system as single rest type; just use "long"
-- NOTE 2: Standard rest types include "long", "short", "extended", "shortmilestone"
function getRestTypes()
	return DataCommon and DataCommon.resttypes or {};
end
function addRestType(vParam)
	if not DataCommon then
		return;
	end
	DataCommon.resttypes = ActionCore.getRestTypes();
	if type(vParam) == "table" then
		for _,v in pairs(vParam) do
			table.insert(DataCommon.resttypes, v);
		end
	elseif type(vParam) == "string" then
		table.insert(DataCommon.resttypes, vParam);
	else
		return;
	end
end

function buildRestMenu(vObj, nMenuIndex)
	local tRestTypes = ActionCore.getRestTypes();
	if #tRestTypes <= 0 then
		return;
	end
	vObj.registerMenuItem(Interface.getString("menu_rest"), "menu_rest", nMenuIndex);
	for k,s in ipairs(ActionCore.getRestTypes()) do
		vObj.registerMenuItem(Interface.getString("menu_rest" .. s), "menu_rest" .. s, nMenuIndex, k);
	end
end
function handleRestActor(vActor, nSelection)
	local sRestType = ActionCore.getRestTypes()[nSelection];
	if not sRestType then
		return;
	end
	local rActor = ActorManager.resolveActor(vActor)
	ChatManager.Message(Interface.getString("message_rest" .. sRestType), true, rActor);
	ActorCommonManager.rest(rActor, sRestType);
end
function handleRestCombat(nSelection)
	local sRestType = ActionCore.getRestTypes()[nSelection];
	if not sRestType then
		return;
	end
	ChatManager.Message(Interface.getString("message_restall" .. sRestType), true);
	CombatManager.rest(sRestType);
end

--
--	MISC
--

function applyRollEffectCompsMult(rRoll, tCompsData, sApplyType)
	if not rRoll or (#(tCompsData or {}) == 0) then
		return;
	end

	rRoll.nMult = rRoll.nMult or 1;

	local setRollDamageTypes = SetManager.new();
	for _,tClause in pairs(rRoll.clauses) do
		SetManager.add(setRollDamageTypes, StringManager.split(tClause.dmgtype, ",", true));
	end
	for _,tCompData in ipairs(tCompsData) do
		if tCompData.mod ~= 0 then
			local bApply = true;

			if (sApplyType or "") == "damage" then
				bApply = false;

				local tCompDamageTypes = {};
				for _,s in ipairs(tCompData.remainder) do
					local sLower = s:lower();
					if ActionCore.isDamageType(sLower) then
						table.insert(tCompDamageTypes, sLower);
					end
				end
				if #tCompDamageTypes == 0 then
					bApply = true;
				elseif SetManager.overlaps(setRollDamageTypes, tCompDamageTypes) then
					bApply = true;
				end
			end

			if bApply then
				if tCompData.mod < 0 and rRoll.nMult < 0 then
					rRoll.nMult = rRoll.nMult * (-tCompData.mod);
				else
					rRoll.nMult = rRoll.nMult * tCompData.mod;
				end
			end
		end
	end
end

function buildEffectFilter(tData)
	local tFilter = {};
	if (tData.sRange or "") ~= "" then
		if tData.sRange == "R" then
			table.insert(tFilter, "ranged");
		elseif tData.sRange == "M" then
			table.insert(tFilter, "melee");
		elseif tData.sRange == "C" then
			table.insert(tFilter, "close");
		elseif tData.sRange == "A" then
			table.insert(tFilter, "area");
		elseif tData.sRange == "P" then
			table.insert(tFilter, "psionic");
		end
	end
	if GameManager.isOption("atktype", { "3.5E", "5E", "PF", "PF2" }) then
		if tData.bSpell then
			table.insert(tFilter, "spell");
		else
			table.insert(tFilter, "weapon");
		end
	end
	if tData.bOpportunity then
		table.insert(tFilter, "opportunity");
	end
	return tFilter;
end

function matchAndOrClauses(s, tMatchWords)
	for _,tClausesAND in ipairs(ActionCore.decodeAndOrClauses(s)) do
		if #tClausesAND > 0 then
			local bMatchAND = true;
			for _,sClause in ipairs(tClausesAND) do
				if not StringManager.contains(tMatchWords, sClause) then
					bMatchAND = false;
					break;
				end
			end
			if bMatchAND then
				return true;
			end
		end
	end
	return false;
end
function decodeAndOrClauses(s)
	local tClausesOR = {};
	local tSkipOR = {};
	local nIndexOR = 1;
	while nIndexOR < #s do
		local nTempIndex = nIndexOR;
		local nParen;
		local nStartOR, nEndOR, nStartOR2, nEndOR2, nStartOR3, nEndOR3;
		repeat
			nParen = 0;

			nStartOR, nEndOR = s:find("%s+or%s+", nTempIndex);
			nStartOR2, nEndOR2 = s:find("%s*\n%s*", nTempIndex);
			nStartOR3, nEndOR3 = s:find("%s*;%s*", nTempIndex);
			-- Checks if nStartOR2 (\n = carriage return) exists and appears before " or "
			if nStartOR2 and (not nStartOR or nStartOR > nStartOR2) then
				nStartOR = nStartOR2;
				nEndOR = nEndOR2;
			end
			-- Checks if we have a ";" and appears before the two previously checked matches - " or " and "\n"
			if nStartOR3 and (not nStartOR or nStartOR > nStartOR3) then
				nStartOR = nStartOR3;
				nEndOR = nEndOR3;
			end

			if nStartOR then
				nParen = ActionCore.getParenDepth(s, nStartOR);
				if nParen ~= 0 then
					nTempIndex = nEndOR + 1;
				end
			end
		until not nStartOR or nParen == 0;

		local sPhraseOR;
		if nStartOR then
			sPhraseOR = s:sub(nIndexOR, nStartOR - 1);
		else
			sPhraseOR = s:sub(nIndexOR);
		end

		local tClausesAND = {};
		local tSkipAND = {};
		local nIndexAND = 1;
		while nIndexAND < #sPhraseOR do
			nTempIndex = nIndexAND;
			local nStartAND, nEndAND;
			repeat
				nParen = 0;
				nStartAND, nEndAND = sPhraseOR:find("%s+and%s+", nTempIndex);

				if nStartAND then
					nParen = ActionCore.getParenDepth(s, nIndexOR + nStartAND);
					if nParen ~= 0 then
						nTempIndex = nEndAND + 1;
					end
				end
			until not nStartAND or nParen == 0;

			if nStartAND then
				table.insert(tClausesAND, sPhraseOR:sub(nIndexAND, nStartAND - 1));
				nIndexAND = nEndAND + 1;
				table.insert(tSkipAND, nEndAND - nStartAND + 1);
			else
				table.insert(tClausesAND, sPhraseOR:sub(nIndexAND));
				nIndexAND = #sPhraseOR;
				if nStartOR then
					table.insert(tSkipAND, nEndOR - nStartOR + 1);
				else
					table.insert(tSkipAND, 0);
				end
			end
		end

		if nStartOR then
			nIndexOR = nEndOR + 1;
		else
			nIndexOR = #s;
		end

		table.insert(tClausesOR, tClausesAND);
		table.insert(tSkipOR, tSkipAND);
	end

	return tClausesOR, tSkipOR;
end
function getParenDepth(s, nIndex)
	local nDepth = 0;

	local cStart = string.byte("(");
	local cEnd = string.byte(")");

	for i = 1, nIndex do
		local cText = string.byte(s, i);
		if cText == cStart then
			nDepth = nDepth + 1;
		elseif cText == cEnd then
			nDepth = nDepth - 1;
		end
	end

	return nDepth;
end
