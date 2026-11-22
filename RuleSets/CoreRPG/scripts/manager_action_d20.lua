--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

--
--	D20 GAME OPTIONS
--
--	GENERAL
--		"abilityeffectskip"
--			isOption (2E) = Skip adding ability effects to action rolls (usually because effects updated on sheet already)
--		"abilityeffectcond"
--			isOption (PF2) = Applies Exhausted (STR: -6; DEX: -6)
--			isOption (3.5E) = Applies Entangled (DEX: -4); Applies Exhausted (STR: -6; DEX: -6); Applies Fatigued (STR: -2; DEX: -2)
--			isOption (PF) = Applies Entangled (DEX: -4); Applies Grappled (DEX: -4); Applies Exhausted (STR: -6; DEX: -6); Applies Fatigued (STR: -2; DEX: -2)
--			isOption (SF) = Applies Entangled (DEX: -4); Applies Exhausted (STR: -6; DEX: -6); Applies Fatigued (STR: -2; DEX: -2);
--							Applies Encumbered (STR: -10; DEX: -10); Applies Overburdened (STR: -10; DEX: -10)
--
--	REST
--		"rest"
--			isOption(2E) = Health is not automatically healed at all
-- 			isOption(3.5E/PF/SF) = Heals lethal damage at level for long rest; Heals nonlethal at level per hour (assume 8 for long rest); Heals ability damage at one per long rest
--			isOption(PF2/SF2) = Heals damage at level * CON per long rest; Heals ability damage at one per long rest
--			Otherwise = Heals all damage on long rest
--			(All temporary hit points cleared on long rest; heal surges reset based on rest)
--			(Depending on rest type and options; death saves reset, heal surges replenished, )
--			isOption(PF2/SF2) = Support spell vs. weapon attack type for damage rolls
--
--	DAMAGE/HEAL
--		"atktype"
--			isOption(3.5E/PF/SF/PF2/SF2) = Support spell vs. weapon attack type for damage rolls
--		"critical"
--			isOption (5E) = Double damage dice on critical
--			isOption (3.5E/PF/SF/D20M) = Apply critical multiplier to damage clauses before applying effects
--			isOption (2E) = Apply house rule option for critical damage (doubledice/none/max/timestwo)
--		"critmult"
-- 			isOption (3.5E/PF/SF/D20M) = Support mult variable in individual damage clauses
--		"deathsave"
--			isOption (5E) = Support death saving throws
--		"dmgdr"
--			isOption (3.5E/PF/SF/D20M) = Apply DR damage adjustment effects
--		"dmghalfonweakened"
--			isOption (4E/13A) = Apply half damage when damage applied by source with Weakened effect
--		"dmghardness"
--			isOption (SF) = Support damage hardness rules
--		"dmgmin"
--			isOption (3.5E/PF/SF/D20M) = Support minimum damage of 1 for all damage rolls (zero is default)
--		"dmgmishap"
--			isOption (5E) = Support damage mishap rules for vehicles
--		"dmgsplit"
--			isOption (SF) = Support splitting damage values per individual damage type
--		"dmgstaticnoeffect"
--			isOption (4E/13A) = No DMG/@DMG effects applied on static damage rolls (i.e. no dice)
--		"dmgthreshold"
--			isOption (5E) = Support damage threshold rules
--		"healsurge"
--			isOption (4E) = Support healing surge adjustments as part of healing actions
--		"incorporeal"
--			isOption (2E) = Check incorporeal effect
--			isOption (3.5E/PF/SF/D20M) = Check incorporeal effect (non-spell, not incorporeal touch)
--		"metamagic"
--			isOption (3.5E/PF/SF/D20M) = Apply metamagic options to damage/heal rolls (MAXIMIZE / EMPOWER)
--		"negativehp"
--			isOption (3.5E/PF/D20M) = Allow negative hit points
--		"nonlethal"
--			isOption (3.5E/PF/SF/D20M) = Nonlethal damage support
--		"regeneration"
--			isOption (5E) = Disable REGEN effect if damage matches descriptor;  REGEN does not work below 1 hp if no descriptor
--			isOption (4E/13A) = Disable REGEN effect if damage matches descriptor; REGEN does not work below 1 hp
--			isOption (PF/SF) = Disable REGEN effect if damage matches descriptor; REGEN always works
--			isOption (3.5E/D20M) = Apply 3.5E regeneration rules (nonlethal only); All damage not defined in REGEN effect descriptor is turned nonlethal
--		"systemshock"
--			isOption (5E) = Support system shock rules
--

function setupRollBuild(sType, rActor, rAction)
	local rRoll = ActionCore.setupRollBuild(sType, rActor, rAction);
	DiceRollManager.addRollActorDice(rActor, rRoll, { "d20" });

	if rAction then
		rRoll.bADV = rAction.bADV or false;
		rRoll.bDIS = rAction.bDIS or false;
		rRoll.bWeapon = rAction.bWeapon;
		rRoll.bSpell = rAction.bSpell;
	end

	return rRoll;
end
function finalizeRollBuild(rRoll)
	ActionCore.finalizeRollBuild(rRoll);
end

function setupRollMod(rSource, rTarget, rRoll)
	ActionCore.setupModRoll(rSource, rTarget, rRoll);
end
function finalizeModRoll(rSource, rTarget, rRoll)
	ActionCore.finalizeModRoll(rSource, rTarget, rRoll);
end

function encodeAdvantage(rRoll)
	if ModifierManager.getKey("ADV") then
		rRoll.bADV = true;
	end
	if ModifierManager.getKey("DIS") then
		rRoll.bDIS = true;
	end

	if (rRoll.bADV and not rRoll.bDIS) or (rRoll.bDIS and not rRoll.bADV) then
		if rRoll.aDice[1] then
			table.insert(rRoll.aDice, 2, UtilityManager.copyDeep(rRoll.aDice[1]));
			rRoll.aDice.expr = nil;
		end
	end
end
function decodeAdvantage(rRoll)
	if (rRoll.bADV and not rRoll.bDIS) or (rRoll.bDIS and not rRoll.bADV) then
		if #(rRoll.aDice) > 1 then
			local tOutput = {};
			if rRoll.sDesc ~= "" then
				table.insert(tOutput, rRoll.sDesc);
			end
			local tSuffix = {};

			local nDroppedDie;
			if (rRoll.bADV and not rRoll.bDIS) then
				if rRoll.aDice[1].result < rRoll.aDice[2].result then
					local tTemp = rRoll.aDice[1];
					rRoll.aDice[1] = rRoll.aDice[2];
					rRoll.aDice[2] = tTemp;
				end
				nDroppedDie = rRoll.aDice[2].result;
				rRoll.aDice[1].type = "g" .. string.sub(rRoll.aDice[1].type, 2);
				table.insert(tSuffix, "[ADV]");
			else
				if rRoll.aDice[1].result > rRoll.aDice[2].result then
					local tTemp = rRoll.aDice[1];
					rRoll.aDice[1] = rRoll.aDice[2];
					rRoll.aDice[2] = tTemp;
				end
				nDroppedDie = rRoll.aDice[2].result;
				rRoll.aDice[1].type = "r" .. string.sub(rRoll.aDice[1].type, 2);
				table.insert(tSuffix, "[DIS]");
			end
			rRoll.aDice[1].value = nil;
			rRoll.aDice[2].value = nil;
			rRoll.aDice[2].dropped = true;
			rRoll.aDice[2].backcolor = "80808080";
			rRoll.aDice[2].iconcolor = "80FFFFFF";
			rRoll.aDice.expr = nil;

			table.insert(tSuffix, string.format("[DROPPED %d]", nDroppedDie));
			table.insert(tOutput, table.concat(tSuffix, " "));
			rRoll.sDesc = table.concat(tOutput, "\r");

			rRoll.nTotal = ActionsManager.total(rRoll);
		end
	end
end

function applyRollMetaMagic(_, rRoll)
	if not GameManager.hasOption("metamagic") then
		return;
	end

	-- Meta spell processing
	local bMaximize = rRoll.sDesc:match("%[MAXIMIZE%]");
	local bEmpower = rRoll.sDesc:match("%[EMPOWER%]");
	local bEpicIntensify = rRoll.sDesc:match("%[EPIC INTENSIFY%]");
	if bMaximize or bEpicIntensify then
		for i = 1, #rRoll.aDice do
			ActionCore.applyRollMaxDie(rRoll, i);
		end
	end
	if bEmpower then
		local nTotal = ActionsManager.total(rRoll);
		local nMod = math.floor(nTotal / 2);

		local sReplace = string.format("[EMPOWER %+d]", nMod);
		rRoll.sDesc = rRoll.sDesc:gsub("%[EMPOWER%]", sReplace);
		rRoll.nMod = rRoll.nMod + nMod;
	end
	if bEpicIntensify then
		local nTotal = ActionsManager.total(rRoll);
		local nMod = nTotal;

		local sReplace = string.format("[EPIC INTENSIFY %+d]", nMod);
		rRoll.sDesc = rRoll.sDesc:gsub("%[EPIC INTENSIFY%]", sReplace);
		rRoll.nMod = rRoll.nMod + nMod;
	end
end
