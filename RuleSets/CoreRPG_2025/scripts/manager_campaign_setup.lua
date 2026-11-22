-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

--
--	AUTO LOAD HANDLING
--
--	NOTE: Results of rules are saved to registry to only trigger once per product add
-- 	NOTE 2: Two rule types:
--		By Key - { key = <key>, load = <list of module id strings>, playerload = <list of module id strings>, }
--			First module in load list is secondary key (existence triggers rule)
--			Processed in order with first matching rule taking priority (unloads previous matched rule; and loads new rule instead)
--			Ex: { key = "PHB", load = { "WOTC50PHB", }, playerload = { "WOTC50PHB", }, },
--				{ key = "PHB", load = { "WOTC5EPHB", }, playerload = { "WOTC5EPHB", }, },
--		By Product - { load = <list of module id strings>, playerload = <list of module id strings>, }
--			First module in load list is primary key (existence triggers rule)
--

local _tAutoLoadRules = {};
function getAutoLoadRules()
	return _tAutoLoadRules;
end
function getAutoLoadRulesByKey(sKey)
	if (sKey or "") == "" then
		return {};
	end
	local tResults = {};
	for _, tRule in ipairs(CampaignSetupManager.getAutoLoadRules()) do
		table.insert(tResults, tRule);
	end
	return tResults;
end
function addAutoLoadRules(tRules)
	for _,v in ipairs(tRules or {}) do
		CampaignSetupManager.addAutoLoadRule(v);
	end
end
function addAutoLoadRule(tRule)
	if not tRule or not tRule.load then
		return;
	end
	table.insert(_tAutoLoadRules, tRule);
end
function clearAutoLoadRules()
	_tAutoLoadRules = {};
end

function disableAutoLoad()
	if not CampaignRegistry then
		return;
	end
	CampaignRegistry.autoload = CampaignRegistry.autoload or {};
	CampaignRegistry.autoload.disable = true;
end
function handleAutoLoad()
	if not Session.IsHost then
		return;
	end
	if not CampaignRegistry then
		return;
	end
	if CampaignRegistry.autoload and CampaignRegistry.autoload.disable then
		return;
	end

	CampaignSetupManager.handleAutoLoadRules();
end
function handleAutoLoadRules()
	for _, tRule in ipairs(CampaignSetupManager.getAutoLoadRules()) do
		CampaignSetupManager.handleAutoLoadRule(tRule);
	end
end
function handleAutoLoadRule(tRule)
	if not tRule then
		return;
	end
	if (tRule.key or "") ~= "" then
		CampaignSetupManager.handleAutoLoadRuleByKey(tRule);
	else
		CampaignSetupManager.handleAutoLoadRuleByProduct(tRule);
	end
end
function handleAutoLoadRuleByKey(tRule)
	local sCheck = tRule.load and tRule.load[1];
	if (sCheck or "") == "" then
		return;
	end

	if not ModuleManager.getModuleInfo(sCheck) then
		return;
	end

	local sCurr = CampaignRegistry.autoload and CampaignRegistry.autoload.bykey and CampaignRegistry.autoload.bykey[tRule.key];
	if (sCurr or "") ~= "" then
		local tKeyRules = CampaignSetupManager.getAutoLoadRulesByKey(tRule.key);
		for _, tKeyRule in ipairs(tKeyRules) do
			local sKeyCheck = tKeyRule.load and tKeyRule.load[1] or "";
			if sKeyCheck == sCurr then
				return;
			end
			if sKeyCheck == sCheck then
				for _, tKeyRule2 in ipairs(tKeyRules) do
					local sKeyCheck2 = tKeyRule2.load and tKeyRule2.load[1] or "";
					if sKeyCheck2 == sCurr then
						CampaignSetupManager.unapplyAutoLoadRule(tKeyRule2);
						break;
					end
				end
				break;
			end
		end
	end

	CampaignSetupManager.applyAutoLoadRule(tRule);
end
function handleAutoLoadRuleByProduct(tRule)
	local sCheck = tRule.load and tRule.load[1];
	if (sCheck or "") == "" then
		return;
	end
	if CampaignRegistry.autoload and CampaignRegistry.autoload.byproduct and CampaignRegistry.autoload.byproduct[sCheck] then
		return;
	end

	if ModuleManager.getModuleInfo(sCheck) then
		CampaignSetupManager.applyAutoLoadRule(tRule);
	end
end

function applyAutoLoadRule(tRule)
	if not tRule then
		return;
	end
	local sCheck = tRule.load and tRule.load[1];
	if (sCheck or "") == "" then
		return;
	end

	if (tRule.key or "") ~= "" then
		CampaignRegistry.autoload = CampaignRegistry.autoload or {};
		CampaignRegistry.autoload.bykey = CampaignRegistry.autoload.bykey or {};
		CampaignRegistry.autoload.bykey[tRule.key] = sCheck;
	else
		CampaignRegistry.autoload = CampaignRegistry.autoload or {};
		CampaignRegistry.autoload.byproduct = CampaignRegistry.autoload.byproduct or {};
		CampaignRegistry.autoload.byproduct[sCheck] = true;
	end

	for _,sModule in ipairs(tRule.load or {}) do
		Module.activate(sModule);
	end
	for _,sModule in ipairs(tRule.playerload or {}) do
		Module.setModulePermissions(sModule, "autoload");
	end
end
function unapplyAutoLoadRule(tRule)
	if not tRule then
		return;
	end

	for _,sModule in ipairs(tRule.load or {}) do
		Module.deactivate(sModule);
	end
	for _,sModule in ipairs(tRule.playerload or {}) do
		Module.setModulePermissions(sModule, false);
	end
end

--
--	SETUP WINDOW MODULE DATA
--

function handleSetup()
	if CampaignRegistry and CampaignRegistry.setup then
		return;
	end
	Interface.openWindow("setup", "");
end

function getShowOnLoad()
	return (CampaignRegistry.setup == nil);
end
function setShowOnLoad(bValue)
	if bValue then
		CampaignRegistry.setup = nil;
	else
		CampaignRegistry.setup = true;
	end
end

--
--	MODULE SET DATA
--

local _tModuleSet = {};
function getModuleSets()
	return _tModuleSet;
end
function addModuleSetsByMode(tSetsData)
	for sMode,tList in pairs(tSetsData) do
		for _,tData in ipairs(tList) do
			CampaignSetupManager.addModuleSetData(sMode, tData);
		end
	end
end
function addModuleSetData(sMode, tData)
	if Session.IsHost then
		if sMode == "host" then
			table.insert(_tModuleSet, tData);
		end
	else
		if sMode == "client" then
			table.insert(_tModuleSet, tData);
		end
	end
end
