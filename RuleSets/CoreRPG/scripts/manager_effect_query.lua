--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

function onInit()
	GameManager.setFunction("onEffectCheckApply", EffectQueryManager.checkEffectApplyDefault);
	GameManager.setFunction("onEffectCheckCompFilter", EffectQueryManager.checkDataCompFilterDefault);
end

--
--	REGISTRATIONS
--

local _tTagOptions = {};
function getTagOptions(sTag)
	if (sTag or "") == "" then
		return {};
	end
	return _tTagOptions[sTag] or {};
end
function setTagOptions(sTag, tOptions)
	if (sTag or "") == "" then
		return;
	end
	_tTagOptions[sTag] = tOptions;
end

local _tDescriptorGroups = {};
function getDescriptorGroups()
	return _tDescriptorGroups;
end
function getDescriptorGroup(sKey)
	if (sKey or "") == "" then
		return;
	end
	for _,v in ipairs(EffectQueryManager.getDescriptorGroups()) do
		if (v.sKey or "") == sKey then
			return v;
		end
	end
	return nil;
end
function hasDescriptorGroup(sKey)
	return (EffectQueryManager.getDescriptorGroup(sKey) ~= nil);
end
function addDescriptorGroup(tData)
	if not tData or ((tData.sKey or "") == "") then
		return;
	end
	local tGroups = EffectQueryManager.getDescriptorGroups();
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
function removeDescriptorGroup(sKey)
	if (sKey or "") == "" then
		return;
	end
	local tGroups = EffectQueryManager.getDescriptorGroups();
	for k,v in ipairs(tGroups) do
		if (v.sKey or "") == sKey then
			table.remove(tGroups, k);
			break;
		end
	end
end
function addDescriptorGroupTag(sKey, v)
	local tGroup = EffectQueryManager.getDescriptorGroup(sKey);
	if not tGroup then
		return false;
	end
	tGroup.tTags = SetManager.union(tGroup.tTags, v):toarray();
	return true;
end
function removeDescriptorGroupTag(sKey, v)
	local tGroup = EffectQueryManager.getDescriptorGroup(sKey);
	if not tGroup then
		return false;
	end
	tGroup.tTags = SetManager.difference(tGroup.tTags, v):toarray();
	return true;
end

local _tCondCheck = {};
local _tCondCheckDescriptors = {};
function getConditionalCheck(s)
	if (s or "") == "" then
		return nil;
	end
	return _tCondCheck[s:upper()];
end
function setConditionalCheck(s, fn, tDescriptors)
	if (s or "") == "" then
		return;
	end
	_tCondCheck[s:upper()] = fn;
	_tCondCheckDescriptors[s:upper()] = tDescriptors;
end
function hasConditionalCheck(s)
	return (EffectQueryManager.getConditionalCheck(s) ~= nil);
end
function getConditionalCheckDescriptorData()
	return _tCondCheckDescriptors;
end
function getConditionalCheckDescriptors(s)
	if (s or "") == "" then
		return {};
	end
	return _tCondCheckDescriptors[s:upper()];
end
function setConditionalCheckDescriptors(s, tDescriptors)
	if not EffectQueryManager.hasConditionalCheck(s) then
		return;
	end
	_tCondCheckDescriptors[s:upper()] = tDescriptors;
end
function addConditionalCheckDescriptors(s, tDescriptors)
	if not EffectQueryManager.hasConditionalCheck(s) then
		return;
	end
	local sUpper = s:upper();
	_tCondCheckDescriptors[sUpper] = _tCondCheckDescriptors[sUpper] or {};
	for _,s in ipairs(tDescriptors or {}) do
		table.insert(_tCondCheckDescriptors[sUpper], s);
	end
end
function getConditionalCheckFromDescriptor(s)
	local sClean = StringManager.trim(s or "");
	if sClean == "" then
		return "", "", false;
	end

	local bInvert = StringManager.startsWith(sClean, "!");
	if bInvert then
		sClean = StringManager.trim(sClean:sub(2));
	end
	if EffectQueryManager.hasConditionalCheck(sClean) then
		return sClean, "", bInvert;
	end

	local sLower = sClean:lower();
	for sKey, tDescriptors in pairs(EffectQueryManager.getConditionalCheckDescriptorData()) do
		if SetManager.contains(tDescriptors, sLower) then
			return sKey, sClean, bInvert;
		end
	end
	return "", sClean, bInvert;
end

local _tTagFollowOn = { "AFTER", "FAIL", };
function isFollowOnCompData(tCompData)
	if not tCompData then
		return;
	end
	return EffectQueryManager.isFollowOnTag(tCompData.type) or EffectQueryManager.isFollowOnTag(tCompData.original);
end
function isFollowOnTag(s)
	return StringManager.contains(_tTagFollowOn, s);
end
function addFollowOnTag(s)
	if (s or "") == "" then
		return;
	end
	for _,sTag in ipairs(_tTagFollowOn) do
		if s == sTag then
			return;
		end
	end
	table.insert(_tTagFollowOn, s);
end
function removeFollowOnTag(s)
	if (s or "") == "" then
		return;
	end
	for k,sTag in ipairs(_tTagFollowOn) do
		if s == sTag then
			table.remove(_tTagFollowOn, k);
			return;
		end
	end
end

--
--	QUERY FUNCTIONS - EXTERNAL
--

function hasTag(rActor, sEffectTag, tData)
	local tCheckData = EffectQueryManager.checkActorData(rActor, sEffectTag, false, tData);
	local bReturn = EffectQueryManager.checkHasResults(tCheckData);
	return bReturn;
end
function hasText(rActor, sEffectTag, tData)
	local tCheckData = EffectQueryManager.checkActorData(rActor, sEffectTag, true, tData);
	local bReturn = EffectQueryManager.checkHasResults(tCheckData);
	return bReturn;
end
function hasTextOrTag(rActor, sEffectTag, tData)
	if EffectQueryManager.hasText(rActor, sEffectTag, tData) then
		return true;
	end
	return EffectQueryManager.hasTag(rActor, sEffectTag, tData);
end

function getEffectsDataByTag(rActor, sEffectTag, tData)
	local tCheckData = EffectQueryManager.checkActorData(rActor, sEffectTag, false, tData);
	local tEffectsData = EffectQueryManager.getCheckEffectResults(tCheckData);
	return tEffectsData;
end
function getEffectsDataByText(rActor, sEffectTag, tData)
	local tCheckData = EffectQueryManager.checkActorData(rActor, sEffectTag, true, tData);
	local tEffectsData = EffectQueryManager.getCheckEffectResults(tCheckData);
	return tEffectsData;
end

function getCompsDataByTag(rActor, sEffectTag, tData)
	local tCheckData = EffectQueryManager.checkActorData(rActor, sEffectTag, false, tData);
	local tCompsData = EffectQueryManager.getCheckCompResults(tCheckData);
	return tCompsData;
end
function getCompsDataByText(rActor, sEffectTag, tData)
	local tCheckData = EffectQueryManager.checkActorData(rActor, sEffectTag, true, tData);
	local tCompsData = EffectQueryManager.getCheckCompResults(tCheckData);
	return tCompsData;
end

function getActiveEffectCompsData(rActor, nodeEffect, tData)
	local tResults = {};

	local tCheckData = { rActor = rActor, bIgnoreExpire = true, sEffectTag = tData and tData.sEffectTag, rTarget = tData and tData.rTarget, };
	local tEffectData = EffectIndexManager.getEffectData(nodeEffect);
	for _,tCompData in ipairs(EffectManager.parseEffectComps(tEffectData)) do
		if EffectQueryManager.checkConditional(tCompData, tEffectData, tCheckData) then
			table.insert(tResults, tCompData);
		end
	end

	return tResults;
end

--
--	QUERY FUNCTIONS - INTERNAL
--

function checkActorData(rActor, sEffectTag, bFullText, tData)
	if not rActor then
		return nil;
	end
	return EffectQueryManager.checkData(rActor, sEffectTag, bFullText, tData);
end
function checkData(rActor, sEffectTag, bFullText, tData)
	if ((sEffectTag or "") == "") then
		return nil;
	end

	local tCheckData = EffectQueryManager.checkDataBuild(rActor, sEffectTag, bFullText, tData);
	EffectQueryManager.checkDataEffects(tCheckData);
	EffectQueryManager.checkDataFinalize(tCheckData);
	return tCheckData;
end

function checkDataBuild(rActor, sEffectTag, bFullText, tData)
	local tTagOptions = EffectQueryManager.getTagOptions(sEffectTag);
	local tCheckData = {
		rActor = ActorManager.resolveActor(rActor),
		rTarget = tData and tData.rTarget,
		bTargetedOnly = tData and tData.bTargetedOnly,
		tEffectsData = ActorEffectManager.getEffectsData(rActor, { bIncludeGlobal = true, bIgnoreDisabled = (tTagOptions and tTagOptions.bIgnoreDisabled), }),
		sEffectTag = sEffectTag,
		bFullText = bFullText,
		tTagOptions = tTagOptions,
		bIgnoreExpire = tData and tData.bIgnoreExpire,
		tEffectsIgnore = tData and tData.tEffectsIgnore,
		tFilters = EffectQueryManager.buildCheckFilter(tData and tData.tFilter, tData and tData.bFilterAllDesc),
		bFilterAllDesc = tData and tData.bFilterAllDesc,
		tActionTags = tData and tData.tActionTags,
		bSkipConditionals = tData and tData.bSkipConditionals,
		tMatch = {},
		tEffectResults = {},
		tCompResults = {},
		-- For conditional debugging
		-- For topmost check, use local tParent = tCheckData; while tParent.tParent do tParent = tParent.tParent; end
		tParent = tData and tData.tParent,
	};

	return tCheckData;
end
function checkDataEffects(tCheckData)
	for k,_ in ipairs(tCheckData.tEffectsData or {}) do
		tCheckData.nEffectCheck = k;
		if GameManager.callFunction("onEffectCheckApply", tCheckData) then
			EffectQueryManager.checkDataComps(tCheckData);
		end
	end
	tCheckData.nEffectCheck = nil;
end
function checkEffectApplyDefault(tCheckData)
	if not tCheckData or not tCheckData.tEffectsData then
		return false;
	end
	local tEffectData = tCheckData.tEffectsData[tCheckData.nEffectCheck or 0];
	if not tEffectData then
		return false;
	end

	for _,nodeEffect in ipairs(tCheckData.tEffectsIgnore or {}) do
		if nodeEffect == tEffectData.node then
			return false;
		end
	end

	local bActive = tCheckData.tTagOptions.bIgnoreDisabled or
			(tCheckData.tTagOptions.bIgnoreExpire and (tEffectData.nActive == 1)) or
			(not tCheckData.tTagOptions.bIgnoreExpire and (tEffectData.nActive ~= 0));
	if not bActive then
		return false;
	end

	if tCheckData.rSource then
		local sSourcePath = ActorManager.getCTNodeName(tCheckData.rSource);
		if (sSourcePath or "") == "" then
			return false;
		end
		if EffectVarManager.getEffectVarFromNode(tEffectData.node, "sSource", "") ~= sSourcePath then
			return false;
		end
	end

	if not tCheckData.tTagOptions.bIgnoreTarget then
		if EffectManager.isTargetedEffect(tEffectData.node) then
			return EffectManager.isEffectTarget(tEffectData.node, tCheckData.rTarget);
		end
		return not tCheckData.bTargetedOnly;
	end

	return true;
end
function checkDataFinalize(tCheckData)
	EffectQueryManager.checkEffectsExpiration(tCheckData);
end
function checkEffectsExpiration(tCheckData)
	if not tCheckData then
		return;
	end
	if tCheckData.bIgnoreExpire then
		return;
	end
	if tCheckData.tTagOptions and tCheckData.tTagOptions.bIgnoreExpire then
		return;
	end
	for k,tEffectCompMatch in pairs(tCheckData.tMatch) do
		if #tEffectCompMatch > 0 then
			local tEffectData = tCheckData.tEffectsData[k];
			if tEffectData then
				EffectManager.applyEffectExpiration(tEffectData.node, tEffectCompMatch[1]);
			end
		end
	end
end

function checkDataComps(tCheckData)
	if not tCheckData or not tCheckData.tEffectsData then
		return;
	end
	local tEffectData = tCheckData.tEffectsData[tCheckData.nEffectCheck or 0];
	if not tEffectData then
		return;
	end

	EffectQueryManager.checkDataCompSetup(tCheckData);
	for k,_ in ipairs(EffectManager.parseEffectComps(tEffectData)) do
		tCheckData.nCompCheck = k;
		if EffectQueryManager.checkDataCompConditional(tCheckData) then
			if EffectQueryManager.checkDataCompApply(tCheckData) then
				EffectQueryManager.checkDataCompOnMatch(tCheckData);
			end
		end
	end
	EffectQueryManager.checkDataCompCleanup(tCheckData);
end
function checkDataCompSetup(tCheckData)
	if not tCheckData then
		return;
	end
	tCheckData.bStopProcessing = false;
	tCheckData.tMatch[tCheckData.nEffectCheck] = {};
end
function checkDataCompConditional(tCheckData)
	if not tCheckData then
		return;
	end
	local tEffectData = tCheckData.tEffectsData[tCheckData.nEffectCheck or 0];
	if not tEffectData then
		return;
	end
	local tCompData = tEffectData.tComps[tCheckData.nCompCheck or 0];
	if not tCompData then
		return;
	end

	return EffectQueryManager.checkConditional(tCompData, tEffectData, tCheckData);
end
function checkDataCompApply(tCheckData)
	if not tCheckData then
		return false;
	end
	local tEffectData = tCheckData.tEffectsData[tCheckData.nEffectCheck or 0];
	if not tEffectData then
		return false;
	end
	local tCompData = tEffectData.tComps[tCheckData.nCompCheck or 0];
	if not tCompData then
		return false;
	end

	if tCheckData.bFullText then
		return (tCompData.original:lower() == tCheckData.sEffectTag:lower());
	end

	if tCompData.type ~= tCheckData.sEffectTag then
		return false;
	end

	return GameManager.callFunction("onEffectCheckCompFilter", tCompData, tCheckData);
end
function checkDataCompFilterDefault(tCompData, tCheckData)
	if not tCompData or not tCheckData then
		return false;
	end

	local tCompFilters = EffectQueryManager.buildCheckFilter(tCompData.remainder, tCheckData.bFilterAllDesc);
	if not tCompFilters then
		return true;
	end
	if tCompFilters["_self_"] and not ActorManager.isEqual(tCheckData.rActor, tCheckData.rTarget) then
		return false;
	elseif tCompFilters["_notself_"] and ActorManager.isEqual(tCheckData.rActor, tCheckData.rTarget) then
		return false;
	end

	if not tCheckData.tFilters then
		return true;
	end

	for sKey, tFilter in pairs(tCompFilters) do
		if (type(tFilter) == "table") and (#tFilter > 0) then
			if not SetManager.overlaps(tFilter, tCheckData.tFilters[sKey] or {}) then
				return false;
			end
		end
	end

	-- Negated descriptors (i.e. "!ranged") exclude matching actions
	-- NOTE: Multi-value groups (i.e. damage types) are not excluded here, since a single action
	--		can contain multiple clauses (i.e. "fire" and "slashing,magic"); the tag handlers
	--		(i.e. RESIST, DMGR, DMGWARD) resolve negated multi-value descriptors per clause.
	for sKey, tNegFilter in pairs(tCompFilters["_negated_"] or {}) do
		local tGroup = EffectQueryManager.getDescriptorGroup(sKey);
		if not (tGroup and tGroup.bMulti) then
			if SetManager.overlaps(tNegFilter, tCheckData.tFilters[sKey] or {}) then
				return false;
			end
		end
	end
	return true;
end
function checkDataCompOnMatch(tCheckData)
	if not tCheckData then
		return false;
	end
	tCheckData.tMatch[tCheckData.nEffectCheck] = tCheckData.tMatch[tCheckData.nEffectCheck] or {};
	table.insert(tCheckData.tMatch[tCheckData.nEffectCheck], tCheckData.nCompCheck);
end
function checkDataCompCleanup(tCheckData)
	tCheckData.tCondData = nil;
	tCheckData.nCompCheck = nil;
end

function checkHasResults(tCheckData)
	if not tCheckData then
		return false;
	end
	for k,tEffectCompMatch in pairs(tCheckData.tMatch) do
		if #tEffectCompMatch > 0 then
			local tEffectData = tCheckData.tEffectsData[k];
			if tEffectData and ((tEffectData.nActive or 0) == 1) or tCheckData.tTagOptions.bIgnoreDisabled then
				return true;
			end
		end
	end
	return false;
end
function getCheckEffectResults(tCheckData)
	EffectQueryManager.buildCheckResults(tCheckData);
	return tCheckData and tCheckData.tEffectResults or {};
end
function getCheckCompResults(tCheckData)
	EffectQueryManager.buildCheckResults(tCheckData);
	return tCheckData and tCheckData.tCompResults or {};
end
function buildCheckResults(tCheckData)
	if not tCheckData then
		return;
	end
	for k,tEffectCompMatch in pairs(tCheckData.tMatch) do
		if #tEffectCompMatch > 0 then
			local tEffectData = tCheckData.tEffectsData[k];
			if tEffectData then
				local tResultEffectData = UtilityManager.copyDeep(tEffectData);
				table.insert(tCheckData.tEffectResults, tResultEffectData);

				if ((tResultEffectData.nActive or 0) == 1) or tCheckData.tTagOptions.bIgnoreDisabled then
					for _,nComp in ipairs(tEffectCompMatch) do
						local tCompData = tResultEffectData.tComps[nComp];
						if tCompData then
							table.insert(tCheckData.tCompResults, tCompData);
						end
					end
				end
			end
		end
	end
end

function buildCheckFilter(tTags, bFilterAllDesc)
	if not tTags or not next(tTags) then
		return nil;
	end

	-- NOTE: Negated descriptors (i.e. "!ranged") are stored separately in tFilters["_negated_"][<group key>],
	--		so that they act as exclusions instead of requirements.
	local tFilters = { ["_other_"] = {}, ["_negated_"] = {}, };
	local tNonFilters = {};

	for _,tGroup in ipairs(EffectQueryManager.getDescriptorGroups()) do
		if bFilterAllDesc or tGroup.bFilter then
			tFilters[tGroup.sKey] = {};
		else
			tNonFilters[tGroup.sKey] = {};
		end
	end

	for _,s in ipairs(tTags) do
		if type(s) == "string" then
			if s == "self" then
				tFilters["_self_"] = true;
			elseif s == "!self" then
				tFilters["_notself_"] = true;
			else
				local bNegated = StringManager.startsWith(s, "!");
				if bNegated then
					s = s:sub(2);
				end
				local bHandled = false;
				for _,tGroup in ipairs(EffectQueryManager.getDescriptorGroups()) do
					if StringManager.contains(tGroup.tTags, s) then
						if bFilterAllDesc or tGroup.bFilter then
							if bNegated then
								EffectQueryManager.helperAddNegatedFilter(tFilters, tGroup.sKey, s);
							else
								table.insert(tFilters[tGroup.sKey], s);
							end
						else
							table.insert(tNonFilters[tGroup.sKey], s);
						end
						bHandled = true;
					end
				end
				if not bHandled then
					if bNegated then
						EffectQueryManager.helperAddNegatedFilter(tFilters, "_other_", s);
					else
						table.insert(tFilters["_other_"], s);
					end
				end
			end
		end
	end
	for k,v in pairs(tTags) do
		if type(k) == "string" then
			tFilters[k] = v;
		end
	end

	return tFilters, tNonFilters;
end
function helperAddNegatedFilter(tFilters, sKey, s)
	tFilters["_negated_"][sKey] = tFilters["_negated_"][sKey] or {};
	table.insert(tFilters["_negated_"][sKey], s);
end

--
--	EFFECT QUERY CONDITIONAL HANDLING
--

function checkConditional(tCompData, tEffectData, tCheckData)
	if not tCompData or not tEffectData or not tCheckData then
		return false;
	end
	if tCheckData.bStopProcessing then
		return false;
	end

	EffectQueryManager.checkConditionalProcess(tCompData, tEffectData, tCheckData);

	if tCheckData.bStopProcessing then
		return false;
	end
	if StringManager.contains({ "IF", "IFT", "ELSE", "ELSEIF", "ELSEIFT", }, tCompData.type) then
		return false;
	end

	local tCondCurrent = tCheckData.tCondData and tCheckData.tCondData[#(tCheckData.tCondData)];
	if tCondCurrent then
		if tCheckData.bTargetedOnly and not tCheckData.bCondTargeted then
			return false;
		end
		for _,v in ipairs(tCheckData.tCondData or {}) do
			if not v.bCurrent then
				return false;
			end
		end
	end

	return true;
end
function checkConditionalProcess(tCompData, tEffectData, tCheckData)
	if not tCompData or not tEffectData or not tCheckData then
		return;
	end

	tCheckData.tCondIgnore = {};
	if EffectQueryManager.isFollowOnCompData(tCompData) then
		tCheckData.bStopProcessing = true;

	elseif StringManager.contains({ "IF", "IFT", }, tCompData.type) then
		if tCheckData.bSkipConditionals then
			tCheckData.bStopProcessing = true;
		else
			local bMatch;
			if tCompData.type == "IF" then
				tCheckData.rCondActor = tCheckData.rActor;
				tCheckData.rCondTarget = tCheckData.rTarget;
				tCheckData.bCondTargeted = false;
			elseif tCompData.type == "IFT" then
				tCheckData.rCondActor = tCheckData.rTarget;
				tCheckData.rCondTarget = tCheckData.rActor;
				tCheckData.bCondTargeted = true;
			end
			if tCheckData.rCondActor then
				bMatch = EffectQueryManager.checkCondition(tCompData, tEffectData, tCheckData);
			else
				local sCheck = StringManager.trim((tCompData.sRemainder or ""):match("([^([]+)"));
				bMatch = StringManager.startsWith(sCheck, "!");
			end
			tCheckData.tCondData = tCheckData.tCondData or {};
			table.insert(tCheckData.tCondData, { bCurrent = bMatch, bAny = bMatch, });
		end

	elseif StringManager.contains({ "ELSEIF", "ELSEIFT", }, tCompData.type) then
		if tCheckData.bSkipConditionals then
			tCheckData.bStopProcessing = true;
		elseif tCheckData.tCondData then
			local tCondCurrent = tCheckData.tCondData[#(tCheckData.tCondData)];
			if tCondCurrent and tCondCurrent.bAny then
				tCondCurrent.bCurrent = false;
			else
				local bMatch;
				if tCompData.type == "ELSEIF" then
					tCheckData.rCondActor = tCheckData.rActor;
					tCheckData.rCondTarget = tCheckData.rTarget;
					tCheckData.bCondTargeted = false;
				elseif tCompData.type == "ELSEIFT" then
					tCheckData.rCondActor = tCheckData.rTarget;
					tCheckData.rCondTarget = tCheckData.rActor;
					tCheckData.bCondTargeted = true;
				end
				if tCheckData.rCondActor then
					bMatch = EffectQueryManager.checkCondition(tCompData, tEffectData, tCheckData);
				else
					local sCheck = StringManager.trim((tCompData.sRemainder or ""):match("([^([]+)"));
					bMatch = StringManager.startsWith(sCheck, "!");
				end
				if tCondCurrent then
					tCondCurrent.bCurrent = bMatch;
					tCondCurrent.bAny = bMatch;
				else
					tCheckData.tCondData = tCheckData.tCondData or {};
					table.insert(tCheckData.tCondData, { bCurrent = bMatch, bAny = bMatch, });
				end
			end
		else
			tCheckData.bStopProcessing = true;
		end

	elseif (tCompData.type == "ELSE") or (tCompData.original == "ELSE") then
		if tCheckData.bSkipConditionals then
			tCheckData.bStopProcessing = true;
		elseif tCheckData.tCondData then
			local tCondCurrent = tCheckData.tCondData[#(tCheckData.tCondData)];
			if tCondCurrent and tCondCurrent.bAny then
				tCondCurrent.bCurrent = false;
			else
				tCheckData.bCondTargeted = false;
				local bMatch = tCondCurrent and not tCondCurrent.bAny or true;
				if tCondCurrent then
					tCondCurrent.bCurrent = bMatch;
					tCondCurrent.bAny = bMatch;
				else
					tCheckData.tCondData = tCheckData.tCondData or {};
					table.insert(tCheckData.tCondData, { bCurrent = bMatch, bAny = bMatch, });
				end
			end
		else
			tCheckData.bStopProcessing = true;
		end
	end
	tCheckData.rCondActor = nil;
	tCheckData.rCondTarget = nil;
	tCheckData.tCondIgnore = nil;
end
function checkCondition(tCompData, tEffectData, tCheckData)
	if not tCompData or not tEffectData or not tCheckData then
		return false;
	end

	local sRemainder = table.concat(tCompData.remainder, " OR ");
	local tSplitOR = StringManager.splitByPattern(sRemainder, "%s+OR%s+", true);
	if #tSplitOR == 0 then
		return false;
	end

	-- Ignore this effect in determining whether conditional is satisfied
	table.insert(tCheckData.tCondIgnore, DB.getPath(tEffectData.node));

	local bMatch = false;
	for _,sORPhrase in ipairs(tSplitOR) do
		local tSplitAND = StringManager.splitByPattern(sORPhrase, "%s+AND%s+", true)
		if #tSplitAND > 0 then
			local bMatchAND = true;
			for _,sANDPhrase in ipairs(tSplitAND) do
				local sConditionTag, sCheck, bInvert = EffectQueryManager.checkConditionParse(sANDPhrase);
				if not EffectQueryManager.checkConditionResult(sConditionTag, sCheck, bInvert, tCompData, tEffectData, tCheckData) then
					bMatchAND = false;
				end
			end
			if bMatchAND then
				bMatch = true;
				break;
			end
			if bMatch then
				break;
			end
		end
	end

	table.remove(tCheckData.tCondIgnore);

	return bMatch;
end
function checkConditionParse(s)
	local sInvert, sConditionTag, sCheck = (s or ""):match("^(!?)([^(]+)%(([^)]+)%)$");
	if (sConditionTag or "") ~= "" then
		return StringManager.trim(sConditionTag or ""), StringManager.trim(sCheck or ""), ((sInvert or "") == "!");
	end
	return EffectQueryManager.getConditionalCheckFromDescriptor(s);
end
function checkConditionResult(sConditionTag, sCheck, bInvert, tCompData, tEffectData, tCheckData)
	if (sConditionTag or "") == "" then
		return bInvert;
	end

	local fn = EffectQueryManager.getConditionalCheck(sConditionTag);
	if not fn then
		return bInvert;
	end
	local bReturn = fn(tCheckData and tCheckData.rCondActor, sCheck, tCheckData, tEffectData, tCompData);
	if bInvert then
		bReturn = not bReturn;
	end
	return bReturn;
end

--
--	BONUS AND PENALTY QUERIES
--

function getBonusKeyAndGroupFromList(tArray)
	for _,tGroup in ipairs(EffectQueryManager.getDescriptorGroups()) do
		if tGroup.bBonus then
			if tGroup.bMulti then
				local tMatch = {};
				for _,s in ipairs(tArray or {}) do
					if StringManager.contains(tGroup.tTags or {}, s) or
							(StringManager.startsWith(s, "!") and StringManager.contains(tGroup.tTags or {}, s:sub(2))) then
						table.insert(tMatch, s);
					end
				end
				if #tMatch > 0 then
					return table.concat(tMatch, ","), tGroup;
				end
			else
				for _,s in ipairs(tArray or {}) do
					if StringManager.contains(tGroup.tTags or {}, s) then
						return s, tGroup;
					end
				end
			end
		end
	end
	return nil, nil;
end

function getBonusDiceMod(rActor, sEffectTag, tData)
	local tEffectBonusByTag, nEffectCount = EffectManager.getBonusData(rActor, sEffectTag, tData);
	local aDice = {};
	local nMod = 0;
	for _,tModType in pairs(tEffectBonusByTag) do
		for _,sDie in pairs(tModType.dice) do
			table.insert(aDice, sDie);
		end
		nMod = nMod + tModType.mod;
	end
	return aDice, nMod, nEffectCount;
end
function getBonusMod(rActor, sEffectTag, tData)
	local tEffectBonusByTag, nEffectCount = EffectManager.getBonusData(rActor, sEffectTag, tData);
	local nMod = 0;
	for _,tModType in pairs(tEffectBonusByTag) do
		nMod = nMod + tModType.mod;
	end
	return nMod, nEffectCount;
end
function getMinMod(rActor, sEffectTag, tData)
	local tEffectBonusByTag, nEffectCount = EffectManager.getBonusData(rActor, sEffectTag, tData);
	local nMod = nil;
	for _,tModType in pairs(tEffectBonusByTag) do
		if nMod then
			nMod = math.min(nMod, tModType.mod);
		else
			nMod = tModType.mod;
		end
	end
	return nMod, nEffectCount;
end
function getMaxMod(rActor, sEffectTag, tData)
	local tEffectBonusByTag, nEffectCount = EffectManager.getBonusData(rActor, sEffectTag, tData);
	local nMod = nil;
	for _,tModType in pairs(tEffectBonusByTag) do
		if nMod then
			nMod = math.max(nMod, tModType.mod);
		else
			nMod = tModType.mod;
		end
	end
	return nMod, nEffectCount;
end
function getBonusData(rActor, vEffectTags, tData)
	if not rActor or not vEffectTags then
		return {}, 0;
	end

	local tEffectTags;
	if type(vEffectTags) == "table" then
		tEffectTags = vEffectTags;
	else
		tEffectTags = { vEffectTags };
	end

	local tResults = {};
	local tBonuses = {};
	local tPenalties = {};
	local nEffectCount = 0;
	for _,sEffectTag in pairs(tEffectTags) do
		local tEffectComps = EffectManager.getCompsDataByTag(rActor, sEffectTag, tData);

		-- Accumulate dice and mod results by damage, bonus type, or other keyword
		for _,tCompData in pairs(tEffectComps) do
			local sGroupKey, tGroupData = EffectQueryManager.getBonusKeyAndGroupFromList(tCompData.remainder);
			local sResultKey = sGroupKey or "";
			tResults[sResultKey] = tResults[sResultKey] or { dice = {}, mod = 0, remainder = {} };
			local tResult = tResults[sResultKey];

			local bAllowDice = true;
			local bNoStack = false;
			local bInvert = false;
			if tGroupData then
				bAllowDice = not tGroupData.bNoDice;
				bNoStack = tGroupData.bNoStack;
				bInvert = tGroupData.bInvert;
			end
			if tData and tData.bNoStack then
				bNoStack = true;
			end

			if bAllowDice then
				for _,v3 in pairs(tCompData.dice) do
					table.insert(tResult.dice, v3);
				end
			end
			if bNoStack then
				if tCompData.mod >= 0 then
					if bInvert then
						if not tPenalties[sResultKey] then
							tPenalties[sResultKey] = tCompData.mod;
						else
							tPenalties[sResultKey] = math.min(tPenalties[sResultKey], tCompData.mod);
						end
					else
						tBonuses[sResultKey] = math.max(tBonuses[sResultKey] or 0, tCompData.mod);
					end
				else
					if bInvert then
						if not tPenalties[sResultKey] then
							tPenalties[sResultKey] = tCompData.mod;
						else
							tPenalties[sResultKey] = math.max(tPenalties[sResultKey], tCompData.mod);
						end
					else
						tPenalties[sResultKey] = math.min(tPenalties[sResultKey] or 0, tCompData.mod);
					end
				end
			else
				tResult.mod = tResult.mod + tCompData.mod;
			end

			nEffectCount = nEffectCount + 1;
		end
	end

	if tData and tData.bReturnDetails then
		return tResults, tBonuses, tPenalties, nEffectCount;
	end

	-- Apply bonus type keyword biggest bonus/penalty
	for sKey,nMod in pairs(tBonuses) do
		tResults[sKey] = tResults[sKey] or { dice = {}, mod = 0, remainder = {} };
		tResults[sKey].mod = tResults[sKey].mod + nMod;
	end
	for sKey,nMod in pairs(tPenalties) do
		tResults[sKey] = tResults[sKey] or { dice = {}, mod = 0, remainder = {} };
		tResults[sKey].mod = tResults[sKey].mod + nMod;
	end

	return tResults, nEffectCount;
end

--
--	CONDITIONALS
--

function onConditionCheck(rActor, sCheck, tCheckData, tEffectData)
	if StringManager.isBlank(sCheck) then
		return false;
	end
	local tData = {
		rTarget = tCheckData and tCheckData.rCondTarget,
		tEffectsIgnore = UtilityManager.copyDeep(tCheckData and tCheckData.tEffectsIgnore) or {};
		bIgnoreExpire = true,
		tParent = tCheckData,
	};
	if tEffectData then
		table.insert(tData.tEffectsIgnore, tEffectData.node);
	end
	return EffectManager.hasCondition(rActor, sCheck, tData);
end
function onFactionCheck(rActor, sCheck, tCheckData, tEffectData)
	if StringManager.isBlank(sCheck) then
		return false;
	end
	local sCheckLower = StringManager.trim(sCheck):lower();
	if sCheckLower == "all" then
		return true;
	elseif sCheckLower == "notself" then
		if not tCheckData then
			return false;
		end
		return not ActorManager.isEqual(rActor, tCheckData.rCondTarget);
	elseif sCheckLower == "self" then
		if not tCheckData then
			return false;
		end
		return ActorManager.isEqual(rActor, tCheckData.rCondTarget);
	elseif sCheckLower == "ally" then
		local rCompareActor = tCheckData and tCheckData.rCondTarget or EffectManager.getSourceActor(tEffectData.node);
		return ActorManager.getFaction(rActor) == ActorManager.getFaction(rCompareActor);
	elseif sCheckLower == "enemy" then
		local rCompareActor = tCheckData and tCheckData.rCondTarget or EffectManager.getSourceActor(tEffectData.node);
		local sFaction = ActorManager.getFaction(rActor);
		if sFaction == "friend" then
			return ActorManager.isFaction(rCompareActor, "foe");
		elseif sFaction == "foe" then
			return ActorManager.isFaction(rCompareActor, "friend");
		end
		return false;
	elseif sCheckLower == "none" then
		return ActorManager.isFaction(rActor, "");
	end
	return ActorManager.isFaction(rActor, sCheck);
end
function onNameCheck(rActor, sCheck)
	if StringManager.isBlank(sCheck) then
		return false;
	end
	local nodeCT = ActorManager.getCTNode(rActor);
	if not nodeCT then
		return false;
	end
	local sActorNameLower = DB.getValue(nodeCT, "name", ""):lower();
	local sCheckLower = StringManager.trim(sCheck):lower();
	if not sActorNameLower:match(sCheckLower) then
		return false;
	end
	return true;
end
function onRangeCheck(rActor, sCheck, tCheckData)
	if StringManager.isBlank(sCheck) or not rActor then
		return false;
	end

	local tParts = StringManager.splitByPattern(sCheck, ",", true);
	if #tParts <= 0 then
		return false;
	end

	local sParamOp, sRange = tParts[1]:match("^([<>=]*)(%d+)$");
	if not sParamOp or not sRange then
		return false;
	end
	local nRange = tonumber(sRange);
	if not nRange then
		return false;
	end

	if #tParts < 2 then
		if not (tCheckData and tCheckData.rCondTarget) then
			return false;
		end
		local nTokenRange = ActorManager.getDistanceBetween(rActor, tCheckData.rCondTarget);
		if not nTokenRange then
			return false;
		end

		if (sParamOp == ">") then
			return (nTokenRange > nRange);
		elseif (sParamOp == ">=") then
			return (nTokenRange >= nRange);
		elseif (sParamOp == "<") then
			return (nTokenRange < nRange);
		elseif (sParamOp == "=") then
			return (nTokenRange == nRange);
		end
		-- Default param operator is <=
		return (nTokenRange <= nRange);
	end

	local tokenActor = ActorManager.getToken(rActor);
	if not tokenActor then
		return false;
	end

	local tFilters = {
		["faction"] = {},
		["type"] = {},
		["condition"] = {},
		["name"] = {},
	};
	for k,s in ipairs(tParts) do
		local sClean = s;
		if StringManager.startsWith(sClean, "!") then
			sClean = sClean:sub(2);
		end
		if k == 1 then
			-- SKIP
		elseif StringManager.contains({ "friend", "foe", "neutral", "ally", "enemy", }, sClean) then
			table.insert(tFilters["faction"], s);
		elseif StringManager.contains(ActorCommonManager.getCreatureTypes(), sClean) or
					StringManager.contains(ActorCommonManager.getCreatureSubtypes(), sClean) then
			table.insert(tFilters["type"], s);
		elseif StringManager.contains(ActionCore.getConditions(), sClean) then
			table.insert(tFilters["condition"], s);
		else
			table.insert(tFilters["name"], s);
		end
	end

	for _, tokenCT in pairs(Token.getTokensWithinDistance(tokenActor, nRange)) do
		local rTarget = ActorManager.resolveActor(tokenCT);
		if not ActorManager.isEqual(rActor, rTarget) then
			if EffectQueryManager.onRangeCheckTargetMatch(rActor, rTarget, tFilters) then
				return true;
			end
		end
	end
	return false;
end
	-- NOTES: Pathfinder
	-- The rogue’s attack deals extra damage anytime her target would be denied a Dexterity bonus to AC (whether the target actually has a Dexterity bonus or not)
	-- or when the rogue flanks her target.

	-- NOTES: 5E
	-- Sneak Attack
	-- if you have advantage on the attack roll OR
	-- You don't need advantage on the attack roll if another enemy of the target is within 5 feet of it,
	-- that enemy isn't incapacitated,
	-- and you don't have disadvantage on the attack roll.
	-- (Prototype) IF: ADV; ...; ELSEIFT: RANGE(5,enemy,!target,!incapacitated)
	--
	-- Rakish Audacity
	-- you don't need advantage on the attack roll to use your Sneak Attack against a creature if you are within 5 feet of it,
	-- no other creatures are within 5 feet of you,
	-- and you don't have disadvantage on the attack roll.
	-- (Prototype) IF: !DIS; IF: RANGE(5); IF: !RANGE(5,!target); ...
	--
	-- Pack Tactics
	-- The creature has advantage on attack rolls against another creature
	-- if at least one of the attacking creature's allies is within 5 feet of the target creature
	-- and the ally isn't incapacitated.
	-- (Prototype) IFT: RANGE(5,enemy,!target,!incapacitated); ADVATK
	--
function onRangeCheckTargetMatch(rActor, rTarget, tFilters)
	if EffectQueryManager.onRangeCheckFactionMatch(rActor, rTarget, tFilters["faction"]) and
			EffectQueryManager.onRangeCheckTypeMatch(rActor, rTarget, tFilters["type"]) and
			EffectQueryManager.onRangeCheckNameMatch(rActor, rTarget, tFilters["name"]) and
			EffectQueryManager.onRangeCheckConditionMatch(rActor, rTarget, tFilters["condition"]) then
		return true;
	end
	return false;
end
function onRangeCheckFactionMatch(rActor, rTarget, tList)
	if #(tList or {}) <= 0 then
		return true;
	end

	for _,s in ipairs(tList) do
		local bInvert = StringManager.startsWith(s, "!");
		if bInvert then
			s = StringManager.trim(s:sub(2));
		end
		local bReturn = EffectQueryManager.onFactionCheck(rTarget, s, { rCondTarget = rActor, });
		if bInvert then
			bReturn = not bReturn;
		end
		if bReturn then
			return true;
		end
	end
	return false;
end
function onRangeCheckTypeMatch(rActor, rTarget, tList)
	if #(tList or {}) <= 0 then
		return true;
	end

	local fnTypeCheck = EffectQueryManager.getConditionalCheck("TYPE");
	if not fnTypeCheck then
		return true;
	end

	for _,s in ipairs(tList) do
		local bInvert = StringManager.startsWith(s, "!");
		if bInvert then
			s = StringManager.trim(s:sub(2));
		end
		local bReturn = fnTypeCheck(rTarget, s, { rCondTarget = rActor, });
		if bInvert then
			bReturn = not bReturn;
		end
		if bReturn then
			return true;
		end
	end
	return false;
end
-- onRangeCheckConditionMatch(rActor, rTarget, tList)
function onRangeCheckConditionMatch(_, rTarget, tList)
	if #(tList or {}) <= 0 then
		return true;
	end

	for _,s in ipairs(tList) do
		local bInvert = StringManager.startsWith(s, "!");
		if bInvert then
			s = StringManager.trim(s:sub(2));
		end
		local bReturn = EffectQueryManager.onConditionCheck(rTarget, s);
		if bInvert then
			bReturn = not bReturn;
		end
		if bReturn then
			return true;
		end
	end
	return false;
end
function onRangeCheckNameMatch(rActor, rTarget, tList)
	if #(tList or {}) <= 0 then
		return true;
	end

	for _,s in ipairs(tList) do
		local bInvert = StringManager.startsWith(s, "!");
		if bInvert then
			s = StringManager.trim(s:sub(2));
		end
		local bReturn = EffectQueryManager.onNameCheck(rTarget, s, { rCondTarget = rActor, });
		if bInvert then
			bReturn = not bReturn;
		end
		if bReturn then
			return true;
		end
	end
	return false;
end
function onStatusCheck(rActor, sCheck)
	if StringManager.isBlank(sCheck) then
		return false;
	end

	local nPercentWounded = ActorHealthManager.getWoundPercent(rActor);
	local sCheckLower = StringManager.trim(sCheck):lower();
	if sCheckLower == (DataCommon and DataCommon.healthstatusfull or "healthy") then
		return (nPercentWounded <= 0);
	elseif sCheckLower == (DataCommon and DataCommon.healthstatushalf or "bloodied") then
		return (nPercentWounded >= 0.5);
	elseif sCheckLower == (DataCommon and DataCommon.healthstatuswounded or "wounded") then
		return (nPercentWounded > 0);
	elseif sCheckLower == "light" then
		return ((nPercentWounded > 0) and (nPercentWounded < 0.25));
	elseif sCheckLower == "moderate" then
		return ((nPercentWounded >= 0.25) and (nPercentWounded < 0.5));
	elseif sCheckLower == "heavy" then
		return ((nPercentWounded >= 0.50) and (nPercentWounded < 0.75));
	elseif sCheckLower == "critical" then
		return ((nPercentWounded >= 0.75) and (nPercentWounded < 1));
	elseif sCheckLower == "dying" then
		return (nPercentWounded >= 1);
	end
	return false;
end
-- onActionTagCheck(rActor, sCheck, tCheckData)
function onActionTagCheck(_, sCheck, tCheckData)
	if StringManager.isBlank(sCheck) then
		return false;
	end
	return SetManager.overlaps(StringManager.split(sCheck:lower(), ",", true), tCheckData and tCheckData.tActionTags or {});
end

function onCustomCheck(rActor, sCheck, tCheckData, tEffectData)
	if StringManager.isBlank(sCheck) then
		return false;
	end
	local tData = {
		rTarget = tCheckData and tCheckData.rCondTarget,
		tEffectsIgnore = UtilityManager.copyDeep(tCheckData.tEffectsIgnore) or {};
		bIgnoreExpire = true,
		tParent = tCheckData,
	};
	table.insert(tData.tEffectsIgnore, tEffectData.node);
	return EffectManager.hasText(rActor, sCheck, tData);
end
