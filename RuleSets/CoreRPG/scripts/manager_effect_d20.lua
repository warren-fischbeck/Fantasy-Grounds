--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

--
--	CONDITIONAL CHECK FUNCTIONS
--

function registerStandardConditionals()
	EffectManager.registerBasicConditionals();
	EffectManagerD20.registerAlignConditional(ActorCommonManager.isCreatureAlignmentDnD);
	EffectManagerD20.registerSizeConditional(ActorCommonManager.isCreatureSizeDnD);
	EffectManagerD20.registerTypeConditional(ActorCommonManager.isCreatureTypeDnD);
end
function registerAlignConditional(fn)
	local tDescriptors = { "n", };
	for s,_ in pairs(DataCommon and DataCommon.alignment_lawchaos or {}) do
		if s ~= "" then
			table.insert(tDescriptors, s);
		end
	end
	for s,_ in pairs(DataCommon and DataCommon.alignment_goodevil or {}) do
		if s ~= "" then
			table.insert(tDescriptors, s);
		end
	end
	EffectManager.setConditionalCheck("ALIGN", fn, tDescriptors);
end
function registerSizeConditional(fn)
	local tDescriptors = {};
	for s,_ in pairs(DataCommon and DataCommon.creaturesize or {}) do
		if s ~= "" then
			table.insert(tDescriptors, s);
		end
	end
	EffectManager.setConditionalCheck("SIZE", fn, tDescriptors);
end
function registerTypeConditional(fn)
	if DataCommon then
		DataCommon.creaturetype = DataCommon.creaturetype or {};
		table.insert(DataCommon.creaturetype, "object");
		table.insert(DataCommon.creaturetype, "vehicle");
	end

	local tDescriptors = {};
	for _,s in ipairs(ActorCommonManager.getCreatureTypes()) do
		if s ~= "" then
			table.insert(tDescriptors, s);
		end
	end
	for _,s in ipairs(ActorCommonManager.getCreatureSubtypes()) do
		if s ~= "" then
			table.insert(tDescriptors, s);
		end
	end
	EffectManager.setConditionalCheck("TYPE", fn, tDescriptors);
end

--
--	EXPIRATION FUNCTIONS
--

function clearExpiringEffects()
	CombatManager.callForEachCombatant(EffectManagerD20.clearRestExpiringEffectsByActor, "short");
end

function clearRestExpiringEffectsByActor(vActor, sRestType)
	local rActor = ActorManager.resolveActor(vActor);
	EffectManager.startDelayedUpdates();
	for _,nodeEffect in pairs(ActorEffectManager.getCombatantEffectNodes(rActor)) do
		EffectManagerD20.clearRestExpiringEffect(nodeEffect, rActor, sRestType);
	end
	EffectManager.endDelayedUpdates();
end
function clearRestExpiringEffect(nodeEffect, rActor, sRestType)
	if type(nodeEffect) ~= "databasenode" then
		return;
	end

	local sExpire = EffectVarManager.getEffectVarFromNode(nodeEffect, "sExpiration", "");
	if (sExpire == "restshort") or
			(StringManager.contains({ "long", "overnight", }, sRestType) and (sExpire == "restlong")) then
		EffectManager.expireEffectByNode(rActor, nodeEffect);
	elseif (sExpire ~= "restshort") and (sExpire ~= "restlong") then
		if EffectVarManager.hasEffectVar("nDuration") then
			local nDecrement = ActionCore.getRestDuration(sRestType);
			local nDuration = EffectVarManager.getEffectVarFromNode(nodeEffect, "nDuration", 0);
			if nDuration ~= 0 then
				if nDuration > nDecrement then
					EffectVarManager.setEffectVarToNode(nodeEffect, "nDuration", nDuration - nDecrement);
				else
					EffectManager.expireEffectByNode(rActor, nodeEffect);
				end
			end
		end
	end
end

--
--	ACTION FUNCTIONS
--

function getStandardEffectDataFromAction(nodeAction, rAction)
	if not nodeAction or not rAction then
		return;
	end

	rAction.sName = EffectVarManager.getEffectVarFromNode(nodeAction, "sName", "");

	rAction.sExpiration = EffectVarManager.getEffectVarFromNode(nodeAction, "sExpiration", "");
	rAction.sInitSource = EffectVarManager.getEffectVarFromNode(nodeAction, "sInitSource", "");
	rAction.sApply = EffectVarManager.getEffectVarFromNode(nodeAction, "sApply", "");

	-- TODO: We don't want targeting information loaded/saved from base effects; only actions
	--rAction.sTargeting = EffectVarManager.getEffectVarFromNode(nodeAction, "sTargeting", "");
	rAction.sTargeting = DB.getValue(nodeAction, "targeting", "");

	rAction.nDuration = DB.getValue(nodeAction, "durmod", 0);
	rAction.sUnits = DB.getValue(nodeAction, "durunit", "");
end

--
--	CT FUNCTIONS
--

function encodeEffectForCT(rEffect)
	if not rEffect then
		return "";
	end

	local tOutput = {};
	table.insert(tOutput, "EFF:");
	table.insert(tOutput, rEffect.sName);

	local sDurDice = StringManager.convertDiceToString(rEffect.aDice, rEffect.nDuration);
	if sDurDice ~= "" then
		local sOutputUnits = nil;
		if (rEffect.sUnits or "") ~= "" then
			if rEffect.sUnits == "minute" then
				sOutputUnits = "MIN";
			elseif rEffect.sUnits == "hour" then
				sOutputUnits = "HR";
			elseif rEffect.sUnits == "day" then
				sOutputUnits = "DAY";
			elseif rEffect.sUnits == "turn" then
				sOutputUnits = "TURN";
			end
		end
		if sOutputUnits then
			table.insert(tOutput, "(D:" .. sDurDice .. " " .. sOutputUnits .. ")");
		else
			table.insert(tOutput, "(D:" .. sDurDice .. ")");
		end
	end

	if (rEffect.sTargeting or "") ~= "" then
		table.insert(tOutput, "(T:" .. rEffect.sTargeting:upper() .. ")");
	end

	if (rEffect.sApply or "") ~= "" then
		table.insert(tOutput, "(A:" .. rEffect.sApply:upper() .. ")");
	end

	if (rEffect.sExpiration or "") ~= "" then
		table.insert(tOutput, "(E:" .. rEffect.sExpiration:upper() .. ")");
	end

	if (rEffect.sInitSource or "") ~= "" then
		table.insert(tOutput, "(IS:" .. rEffect.sInitSource:upper() .. ")");
	end

	return string.format("[%s]", table.concat(tOutput, " "));
end
function decodeEffectFromCT(s)
	local sName = s:match("EFF: ?(.+)");
	if not sName then
		return nil;
	end

	local rEffect = {
		type = "effect",
		sType = "effect", -- ct_power.lua script requirement
		nDuration = 0,
		sUnits = "",
		sTargeting = "",
		sApply = "",
	};

	local sDurDice, sUnits = s:match("%(D:([d%dF%+%-]+) ?([^)]*)%)");
	if sDurDice then
		rEffect.aDice, rEffect.nDuration = StringManager.convertStringToDice(sDurDice);
		if sUnits then
			if sUnits == "MIN" then
				rEffect.sUnits = "minute";
			elseif sUnits == "HR" then
				rEffect.sUnits = "hour";
			elseif sUnits == "DAY" then
				rEffect.sUnits = "day";
			elseif sUnits == "TURN" then
				rEffect.sUnits = "turn";
			end
		end
	end
	sName = sName:gsub("%(D:[^)]*%)", "");

	rEffect.sTargeting = "";
	local sTargeting = s:match("%(T:([^)]*)%)");
	if sTargeting then
		rEffect.sTargeting = sTargeting:lower();
	end
	sName = sName:gsub("%(T:[^)]*%)", "");

	rEffect.sApply = "";
	local sApply = s:match("%(A:([^)]*)%)");
	if sApply then
		rEffect.sApply = sApply:lower();
	end
	sName = sName:gsub("%(A:[^)]*%)", "");

	rEffect.sExpiration = "";
	local sExpiration = s:match("%(E:([^)]*)%)");
	if sExpiration then
		rEffect.sExpiration = sExpiration:lower();
	end
	sName = sName:gsub("%(E:[^)]*%)", "");

	rEffect.sInitSource = "";
	local sInitSource = s:match("%(IS:([^)]*)%)");
	if sInitSource then
		rEffect.sInitSource = sInitSource:lower();
	end
	sName = sName:gsub("%(IS:[^)]*%)", "");

	rEffect.sName = StringManager.trim(sName);

	return rEffect;
end

--
--	MISC
--

function getDamageTypeDescriptors(rActor, sEffectTag, tData)
	local setDamageTypes = SetManager.new();
	for _,s in ipairs(EffectManager.getDescriptorsByTag(rActor, sEffectTag, tData)) do
		local sLower = s:lower();
		if ActionCore.isDamageType(sLower) then
			SetManager.add(setDamageTypes, sLower);
		end
	end
	return SetManager.toarray(setDamageTypes);
end
