--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

function getPowerChoices(nodePower, sAutoKey)
	if not nodePower then
		return {};
	end

	local tPowerChoices = {};
	for _, nodeAction in ipairs(DB.getChildList(nodePower, "actions")) do
		local sActionAutoKey = DB.getValue(nodeAction, "autokey", "");
		if not sAutoKey or (sActionAutoKey == sAutoKey) then
			for _,tOptions in ipairs(ActionsChoiceManager.getPowerActionChoices(nodeAction)) do
				table.insert(tPowerChoices, tOptions);
			end
		end
	end
	return tPowerChoices;
end
function getPowerChoiceSelections(nodePower, sAutoKey)
	if not nodePower then
		return {};
	end

	local tPowerChoiceSelections = {};
	for _, nodeAction in ipairs(DB.getChildList(nodePower, "actions")) do
		local sActionAutoKey = DB.getValue(nodeAction, "autokey", "");
		if not sAutoKey or (sActionAutoKey == sAutoKey) then
			for _,tSelections in ipairs(ActionsChoiceManager.getPowerActionChoiceSelections(nodeAction)) do
				table.insert(tPowerChoiceSelections, tSelections);
			end
		end
	end
	return tPowerChoiceSelections;
end
function getPowerChoiceSelectionsDisplayList(nodePower, sSeparator)
	if not nodePower then
		return {};
	end
	local tPowerChoiceSelectionList = {};
	for _, nodeAction in ipairs(DB.getChildList(nodePower, "actions")) do
		for _,tSelections in ipairs(ActionsChoiceManager.getPowerActionChoiceSelections(nodeAction)) do
			table.insert(tPowerChoiceSelectionList, StringManager.capitalizeAll(table.concat(tSelections, sSeparator or ",")));
		end
	end
	return tPowerChoiceSelectionList;
end

function getPowerActionChoices(nodeAction)
	if not nodeAction then
		return {};
	end
	if DB.getValue(nodeAction, "type", "") ~= "cast" then
		return {};
	end

	local tActionChoices = {};

	for _,v in ipairs(UtilityManager.getNodeSortedChildren(nodeAction, "choicelist")) do
		local sTag = StringManager.trim(DB.getValue(v, "tag", ""));
		if sTag ~= "" then
			local tOptions = StringManager.splitByPattern(DB.getValue(v, "options", ""), "|", true);
			if #tOptions > 0 then
				tOptions.node = nodeAction;
				tOptions.sTag = sTag;
				if DB.getValue(v, "allowmult", 0) == 1 then
					tOptions.bMultiple = true;
				end
				table.insert(tActionChoices, tOptions);
			end
		end
	end

	local tOptions = StringManager.splitByPattern(DB.getValue(nodeAction, "autokeychoice", ""), "|", true);
	if #tOptions > 0 then
		tOptions.node = nodeAction;
		tOptions.sTag = "__autokey";
		table.insert(tActionChoices, tOptions);
	end

	return tActionChoices;
end
function getPowerActionChoiceSelections(nodeAction)
	if not nodeAction then
		return {};
	end
	local sType = DB.getValue(nodeAction, "type", "");
	if sType ~= "cast" then
		return {};
	end

	local tActionChoiceSelections = {};

	local tSelections = StringManager.splitByPattern(DB.getValue(nodeAction, "autokeyselection", ""), "|", true);
	if #tSelections > 0 then
		tSelections.node = nodeAction;
		tSelections.sTag = "__autokey";
		table.insert(tActionChoiceSelections, tSelections);
	end

	for _,v in ipairs(UtilityManager.getNodeSortedChildren(nodeAction, "choicelist")) do
		local sTag = StringManager.trim(DB.getValue(v, "tag", ""));
		if sTag ~= "" then
			local tSelections = StringManager.splitByPattern(DB.getValue(v, "selection", ""), "|", true);
			if #tSelections > 0 then
				tSelections.node = nodeAction;
				tSelections.sTag = sTag;
				table.insert(tActionChoiceSelections, tSelections);
			end
		end
	end

	return tActionChoiceSelections;
end

function setPowerChoiceSelections(nodePower, tChoiceSelections)
	if not nodePower then
		return;
	end

	for _, tSelections in ipairs(tChoiceSelections) do
		local nodeAction = tSelections.node;
		if (type(nodeAction) == "databasenode") and (DB.getValue(nodeAction, "type", "") == "cast") then
			if tSelections.sTag == "__autokey" then
				DB.setValue(nodeAction, "autokeyselection", "string", table.concat(tSelections, "|"));
			else
				for _,nodeChoice in ipairs(DB.getChildList(nodeAction, "choicelist")) do
					if DB.getValue(nodeChoice, "tag", "") == tSelections.sTag then
						DB.setValue(nodeChoice, "selection", "string", table.concat(tSelections, "|"));
						break;
					end
				end
			end
		end
	end
end
function deletePowerChoiceSelections(nodePower)
	if not nodePower then
		return;
	end
	for _, nodeAction in ipairs(DB.getChildList(nodePower, "actions")) do
		if DB.getValue(nodeAction, "type", "") == "cast" then
			DB.deleteChild(nodeAction, "autokeyselection");
			for _,nodeChoice in ipairs(DB.getChildList(nodeAction, "choicelist")) do
				DB.deleteChild(nodeChoice, "selection");
			end
		end
	end
end

function performActionChoicesSubstitution(rAction)
	if not rAction or not rAction.bPower or not rAction.nodeAction then
		return;
	end

	local nodePower = DB.getChild(rAction.nodeAction, "...");

	local tPowerChoices = ActionsChoiceManager.getPowerChoices(nodePower);
	if #tPowerChoices <= 0 then
		return;
	end

	local tChoiceData = {
		tChoices = tPowerChoices,
		tChoiceSelections = ActionsChoiceManager.getPowerChoiceSelections(nodePower),
	};

	if rAction.type == "damage" then
		for _,tClause in ipairs(rAction.clauses or {}) do
			local sNewDmgType = ActionsChoiceManager.performStringChoicesSubstitution(tClause.dmgtype, tChoiceData);
			if sNewDmgType ~= tClause.dmgtype then
				tClause.dmgtype = sNewDmgType;
				PowerActionManagerCore.appendDamagePowerTags(rAction.tActionTags, sNewDmgType);
			end
		end
	elseif rAction.type == "effect" then
		local sNewName = ActionsChoiceManager.performStringChoicesSubstitution(rAction.sName, tChoiceData);
		if sNewName ~= rAction.sName then
			rAction.sName = sNewName;
			PowerActionManagerCore.appendEffectPowerTags(rAction.tActionTags, sNewName);
		end
	end
end
function performStringChoicesSubstitution(s, tChoiceData)
	if (s or "") == "" then
		return s;
	end

	for _,tOptions in ipairs(tChoiceData.tChoices) do
		if ((tOptions.sTag or "") ~= "") and ((tOptions.sTag or "") ~= "__autokey") then
			local tSelectionsMatch;
			for _,tSelections in ipairs(tChoiceData.tChoiceSelections) do
				if (tSelections.sTag or "") == tOptions.sTag then
					tSelectionsMatch = tSelections;
					break;
				end
			end

			if tSelectionsMatch then
				s = s:gsub(string.format("%%[%s%%]", tOptions.sTag), table.concat(tSelectionsMatch, ","));
			else
				s = s:gsub(string.format("%%[%s%%]", tOptions.sTag), tOptions[1] or "");
			end
		end
	end

	return s;
end
