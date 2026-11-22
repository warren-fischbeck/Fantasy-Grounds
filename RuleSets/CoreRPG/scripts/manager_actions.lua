--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

--  ACTION FLOW
--
--	1. INITIATE ACTION (DRAG OR DOUBLE-CLICK)
--	2. DETERMINE TARGETS (DROP OR TARGETING SUBSYSTEM)
--	3. APPLY MODIFIERS
--	4. PERFORM ROLLS (IF ANY)
--	5. RESOLVE ACTION

-- 	NOTE: Rolls with sTargeting = "all" which use effect modifiers need to
-- 		handle effect application on resolution by checking target order field;
--		since there will be no target specified in mod handler,
--		but will be specified in the result handler.
--		i.e. "if rSource and rTarget and rTarget.nOrder then"

-- 	ROLL
--		.sType
--		.sDesc
--		.aDice
--		.nMod
--		(Any other fields added as string -> string map, if possible)

-- 	FLOW
--
--	(DIRECT)
--		PerformAction -> performMultiAction ->
--		actionDirect -> actionRoll -> ...
--	(DRAG)
--		PerformAction -> performMultiAction ->
--		encodeActionForDrag -> (drag/drop) ->
--		decodeActionFromDrag -> actionRoll -> ...
--	(ALL)
--		actionRoll -> applyModifiersToRolls ->
--		roll -> (dice roll) -> onDiceLanded ->
--		decodeActionFromDrag -> handleResolution

ROLL_TAG = "[__ActionsManagerRoll__]";
ROLL_TAG_PATTERN = "%[__ActionsManagerRoll__%]$";

function onTabletopInit()
	Interface.addKeyedEventHandler("onHotkeyActivated", "", ActionsManager.actionHotkey);
end

--
-- HANDLERS
--

function initAction(sActionType)
	if not GameManager.isAction(sActionType) then
		GameManager.addAction(sActionType);
	end
end

local aTargetingHandlers = {};
function getTargetingHandler(sActionType)
	return aTargetingHandlers[sActionType];
end
function registerTargetingHandler(sActionType, callback)
	ActionsManager.initAction(sActionType);
	aTargetingHandlers[sActionType] = callback;
end
function unregisterTargetingHandler(sActionType)
	if aTargetingHandlers then
		aTargetingHandlers[sActionType] = nil;
	end
end

local aModHandlers = {};
function getModHandler(sActionType)
	return aModHandlers[sActionType];
end
function registerModHandler(sActionType, callback)
	ActionsManager.initAction(sActionType);
	aModHandlers[sActionType] = callback;
end
function unregisterModHandler(sActionType)
	if aModHandlers then
		aModHandlers[sActionType] = nil;
	end
end

local aPostRollHandlers = {};
function getPostRollHandler(sActionType)
	return aPostRollHandlers[sActionType];
end
function registerPostRollHandler(sActionType, callback)
	ActionsManager.initAction(sActionType);
	aPostRollHandlers[sActionType] = callback;
end
function unregisterPostRollHandler(sActionType)
	if aPostRollHandlers then
		aPostRollHandlers[sActionType] = nil;
	end
end

local aResultHandlers = {};
function getResultHandler(sActionType)
	return aResultHandlers[sActionType];
end
function registerResultHandler(sActionType, callback)
	ActionsManager.initAction(sActionType);
	aResultHandlers[sActionType] = callback;
end
function unregisterResultHandler(sActionType)
	if aResultHandlers then
		aResultHandlers[sActionType] = nil;
	end
end

--
-- HELPER FUNCTIONS
--

function doesRollHaveDice(rRoll)
	if rRoll and rRoll.aDice then
		if #(rRoll.aDice) > 0 then
			return true;
		end
		if (rRoll.aDice.expr or "") ~= "" then
			return true;
		end
	end
	return false;
end

--
--  ACTIONS
--

function performAction(draginfo, rActor, rRoll)
	if not rRoll then
		return;
	end

	if Session.IsHost and CombatManager.isCTHidden(ActorManager.getCTNode(rActor)) then
		rRoll.bSecret = true;
	end

	ActionsManager.performMultiAction(draginfo, rActor, rRoll.sType, { rRoll });
end

function performMultiAction(draginfo, rActor, sType, rRolls)
	if not rRolls or #rRolls < 1 then
		return false;
	end

	if draginfo then
		ActionsManager.encodeActionForDrag(draginfo, rActor, sType, rRolls);
	else
		ActionsManager.actionDirect(rActor, sType, rRolls);
	end
	return true;
end

function actionHotkey(draginfo)
	local sDragType = draginfo.getType();
	if not GameManager.isAction(sDragType) then
		return;
	end

	local rSource, rRolls = ActionsManager.decodeActionFromDrag(draginfo, false);
	ActionsManager.actionDirect(rSource, sDragType, rRolls);
	return true;
end

function actionDrop(draginfo, rTarget)
	local sDragType = draginfo.getType();
	if not GameManager.isAction(sDragType) then
		return false;
	end

	local rSource, rRolls = ActionsManager.decodeActionFromDrag(draginfo, false);
	ActionsManager.actionRoll(rSource, rTarget, rRolls);
	return true;
end
function actionDropHelper(draginfo)
	local rSource, rRolls, tTargets = ActionsManager.decodeActionFromDrag(draginfo, false);

	ActionsManager.lockModifiers();
	local bModStackUsed = ActionsManager.applyModifiersToRolls(rSource, tTargets, rRolls);
	ActionsManager.unlockModifiers(bModStackUsed);

	return rSource, rRolls, tTargets;
end

function actionDirect(rActor, sDragType, rRolls, vPreTargeted)
	if not rRolls then
		return;
	end
	rRolls.sDragType = sDragType;
	ActionsManager.actionRoll(rActor, vPreTargeted, rRolls);
end

-- NOTE: vPreTargeted parameter assumes a single actor or a list of targeting groups containing actors
function getTargetingGroups(rSource, vPreTargeted, rRolls)
	if not rRolls then
		return { { } };
	end
	local tResults;
	if vPreTargeted then
		if (type(vPreTargeted) == "table") and (#vPreTargeted > 0) then
			tResults = vPreTargeted;
		else
			tResults = { { vPreTargeted } };
		end
	end
	if not tResults then
		if ModifierStack.getTargeting() then
			tResults = ActionsManager.getTargeting(rSource, nil, rRolls.sDragType, rRolls);
		else
			tResults = { { } };
		end
	end

	local fn = ActionsManager.getTargetingHandler(rRolls.sDragType);
	if fn then
		tResults = fn(rSource, tResults, rRolls) or {};
	end
	if #tResults == 0 then
		table.insert(tResults, {});
	end

	GameManager.callEventFunctions("onActionPostTargeting", rSource, tResults, rRolls);

	return tResults;
end
-- NOTE: tTargetGroups return value assumes a list of targeting groups returned
function getTargeting(rSource, rTarget, sDragType, rRolls)
	local tTargetGroups = {};

	if rTarget then
		table.insert(tTargetGroups, { rTarget });
	else
		local sTargeting = GameManager.getActionProperty(sDragType, "sTargeting");
		if sTargeting then
			if (#rRolls == 1) and rRolls[1].bSelfTarget then
				tTargetGroups = { { rSource } };
			elseif sTargeting == "all" then
				tTargetGroups = { TargetingManager.getFullTargets(rSource) };
			elseif sTargeting == "each" then
				local aTempTargets = TargetingManager.getFullTargets(rSource);
				if #aTempTargets <= 1 then
					tTargetGroups = { aTempTargets };
				else
					tTargetGroups = {};
					for _,vTarget in ipairs(aTempTargets) do
						table.insert(tTargetGroups, { vTarget });
					end
				end
			end
		end
	end

	return tTargetGroups;
end

function encodeActors(draginfo, rSource, aTargets)
	local sSourceNode = nil;
	if rSource then
		sSourceNode = ActorManager.getCreatureNodeName(rSource);
	end
	if sSourceNode then
		draginfo.addShortcut(ActorManager.getRecordType(rSource), sSourceNode);
		ActionsManager.encodeActorActiveEffectNodes(draginfo, rSource, 1);
	else
		draginfo.addShortcut();
	end

	if aTargets then
		for kTarget,vTarget in ipairs(aTargets) do
			local sTargetNode = ActorManager.getCreatureNodeName(vTarget);
			if sTargetNode then
				draginfo.addShortcut(ActorManager.getRecordType(vTarget), sTargetNode);
				ActionsManager.encodeActorActiveEffectNodes(draginfo, vTarget, kTarget + 1);
			end
		end
	end
end
function encodeActorActiveEffectNodes(draginfo, rActor, nActorIndex)
	local tActive = ActorEffectManager.getActiveEffectNodes(rActor);
	local sMetaKey = "__actor" .. nActorIndex .. "_active";
	for kActive,vActive in ipairs(tActive) do
		if type(vActive) == "databasenode" then
			draginfo.setMetaData(sMetaKey .. kActive, DB.getPath(vActive));
		else
			draginfo.setMetaData(sMetaKey .. kActive, tostring(vActive) or "");
		end
	end
end

function decodeActors(draginfo)
	local rSource = nil;
	local aTargets = {};

	for k,v in ipairs(draginfo.getShortcutList()) do
		local rActor = ActorManager.resolveActor(v.recordname);
		ActionsManager.decodeActorActiveEffectNodes(draginfo, rActor, k);
		if k == 1 then
			rSource = rActor;
		else
			if rActor then
				table.insert(aTargets, rActor);
			end
		end
	end

	return rSource, aTargets;
end
function decodeActorActiveEffectNodes(draginfo, rActor, nActorIndex)
	if not rActor then
		return;
	end

	local sMetaKey = "__actor" .. nActorIndex .. "_active";
	local tMetaData = draginfo.getMetaDataList();
	local kActive = 1;
	while tMetaData[sMetaKey .. kActive] do
		ActorEffectManager.addActiveEffectNode(rActor, tMetaData[sMetaKey .. kActive]);
		kActive = kActive + 1;
	end
end

function encodeActionForDrag(draginfo, rSource, sType, rRolls)
	ActionsManager.encodeActors(draginfo, rSource);

	draginfo.setType(sType);

	local sIcon = GameManager.getActionProperty(sType, "sIcon");
	if sIcon then
		draginfo.setIcon(sIcon);
	elseif sType ~= "dice" then
		draginfo.setIcon("action_roll");
	end
	if #rRolls == 1 then
		draginfo.setDescription(rRolls[1].sDesc);
	end

	for kRoll, rRoll in ipairs(rRolls) do
		ActionsManager.encodeRollForDrag(draginfo, kRoll, rRoll);
	end

	local bSecret = (#rRolls > 0 and rRolls[1].bSecret);
	draginfo.setSecret(bSecret);
end
function encodeRollForDrag(draginfo, i, rRoll)
	DiceManager.onPreEncodeRoll(rRoll);

	draginfo.setSlot(i);
	ActionsManager.helperEncodeRollToDrag(draginfo, rRoll);
end
function helperEncodeRollToDrag(draginfo, rRoll, nOrigDice)
	for k,v in pairs(rRoll) do
		if k == "sType" then
			draginfo.setSlotType(v);
		elseif k == "sDesc" then
			draginfo.setStringData(v);
		elseif k == "aDice" then
			if nOrigDice then
				local nNewDice = #(rRoll.aDice or {});
				for i = nOrigDice + 1, nNewDice do
					local vDie = rRoll.aDice[i];
					if type(vDie) == "table" then
						draginfo.addDie(vDie.type);
					else
						draginfo.addDie(vDie);
					end
				end
			else
				draginfo.setDiceData(v);
			end
		elseif k == "nMod" then
			draginfo.setNumberData(v);
		elseif k == "tActionTags" then
			if type(v) == "table" then
				draginfo.setMetaData(k, table.concat(v, "|"));
			end
		elseif k == "clauses" then
			if type(v) == "table" then
				draginfo.setMetaData("jsonClauses", Utility.encodeJSON(rRoll.clauses or {}) or "");
			end
		elseif type(k) ~= "table" then
			local sk = tostring(k) or "";
			if sk ~= "" then
				if type(v) == "boolean" then
					draginfo.setMetaData(sk, v and 1 or 0);
				elseif type(v) ~= "table" then
					draginfo.setMetaData(sk, tostring(v) or "");
				end
			end
		end
	end
end

function decodeActionFromDrag(draginfo, bFinal)
	local rSource, aTargets = ActionsManager.decodeActors(draginfo);

	local rRolls = {};
	for i = 1, draginfo.getSlotCount() do
		table.insert(rRolls, ActionsManager.decodeRollFromDrag(draginfo, i, bFinal));
	end
	rRolls.sDragType = draginfo.getType();

	return rSource, rRolls, aTargets;
end
function decodeRollFromDrag(draginfo, i, bFinal)
	draginfo.setSlot(i);
	local rRoll = ActionsManager.helperDecodeRollFromDrag(draginfo, bFinal);

	DiceManager.onPostDecodeRoll(rRoll, bFinal);

	return rRoll;
end
function helperDecodeRollFromDrag(draginfo, bFinal)
	local rRoll = {};
	for k,v in pairs(draginfo.getMetaDataList()) do
		if k == "tActionTags" then
			rRoll[k] = StringManager.split(v, "|");
		elseif k == "jsonClauses" then
			rRoll.clauses = Utility.decodeJSON(v or "") or {};
		elseif k:match("^n[A-Z]") then
			rRoll[k] = tonumber(v) or nil;
		elseif k:match("^b[A-Z]") then
			rRoll[k] = ((tonumber(v) or 0) == 1);
		else
			rRoll[k] = v;
		end
	end

	rRoll.sType = draginfo.getSlotType();
	if rRoll.sType == "" then
		rRoll.sType = draginfo.getType();
	end

	rRoll.sDesc = draginfo.getStringData();
	if bFinal and (rRoll.sDesc or "") == "" then
		rRoll.sDesc = draginfo.getDescription();
	end
	rRoll.nMod = draginfo.getNumberData();

	rRoll.aDice = draginfo.getDiceData() or {};
	rRoll.nTotal = rRoll.aDice.total;

	rRoll.bSecret = draginfo.getSecret();

	return rRoll;
end

--
--  APPLY MODIFIERS
--

-- NOTE: tTargetGroups parameter for this function assumes a list of targeting groups
function actionRoll(rSource, vPreTargeted, rRolls)
	local tTargetGroups = ActionsManager.getTargetingGroups(rSource, vPreTargeted, rRolls);

	local bModStackUsed = false;
	ActionsManager.lockModifiers();

	for _,tTargets in ipairs(tTargetGroups) do
		local rNewRolls = UtilityManager.copyDeep(rRolls);
		if ActionsManager.applyModifiersToRolls(rSource, tTargets, rNewRolls) then
			bModStackUsed = true;
		end
		for _,rRoll in ipairs(rNewRolls) do
			ActionsManager.roll(rSource, tTargets, rRoll, true);
		end
	end

	ActionsManager.unlockModifiers(bModStackUsed);
end

function applyModifiersToRolls(rSource, tTargets, rRolls)
	local bModStackUsed = false;
	for _,rRoll in ipairs(rRolls) do
		if ActionsManager.applyModifiersToRoll(rSource, tTargets, rRoll) then
			bModStackUsed = true;
		end
	end
	return bModStackUsed;
end
function applyModifiersToRoll(rSource, tTargets, rRoll)
	local bModStackUsed;
	if tTargets and (#tTargets == 1) then
		bModStackUsed = ActionsManager.applyModifiers(rSource, tTargets[1], rRoll);
	else
		-- Only apply non-target specific modifiers before roll
		bModStackUsed = ActionsManager.applyModifiers(rSource, nil, rRoll);
	end
	return bModStackUsed;
end

function lockModifiers()
	ModifierStack.lock();
	EffectManager.startDelayedUpdates();
end
function unlockModifiers(bReset)
	ModifierStack.unlock(bReset);
	EffectManager.endDelayedUpdates();
end

function applyModifiers(rSource, rTarget, rRoll, bSkipModStack)
	local bAddModStack = ActionsManager.doesRollHaveDice(rRoll);
	if bSkipModStack then
		bAddModStack = false;
	elseif GameManager.isAction(rRoll.sType) then
		bAddModStack = GameManager.getActionProperty(rRoll.sType, "bUseModStack");
	end

	ActionCore.setupModRoll(rSource, rTarget, rRoll);
	GameManager.callMultiKeyFunctionPreLayered("onActionPreModRoll", rRoll.sType, rSource, rTarget, rRoll);
	local fMod = ActionsManager.getModHandler(rRoll.sType);
	if fMod then
		local bReturn = fMod(rSource, rTarget, rRoll);
		if bReturn ~= true then
			rRoll.aDice.expr = nil;
		end
	end
	GameManager.callMultiKeyFunctionPostLayered("onActionPostModRoll", rRoll.sType, rSource, rTarget, rRoll);
	ActionCore.finalizeModRoll(rSource, rTarget, rRoll);

	if bAddModStack then
		local bDescNotEmpty = ((rRoll.sDesc or "") ~= "");
		local sStackDesc, nStackMod = ModifierStack.getStack(bDescNotEmpty);

		if sStackDesc ~= "" then
			if bDescNotEmpty then
				rRoll.sDesc = rRoll.sDesc .. " [" .. sStackDesc .. "]";
			else
				rRoll.sDesc = sStackDesc;
			end
		end
		rRoll.nMod = rRoll.nMod + nStackMod;
	end

	return bAddModStack;
end

--
--	RESOLVE DICE
--

function buildThrow(rSource, vTargets, rRoll, bMultiTarget)
	local rThrow = {};

	rThrow.type = rRoll.sType;
	rThrow.description = (rRoll.sDesc or "") .. ActionsManager.ROLL_TAG;
	rThrow.secret = rRoll.bSecret;

	rThrow.shortcuts = {};
	if rSource then
		local sSourceActorPath = ActorManager.getCreatureNodeName(rSource);
		table.insert(rThrow.shortcuts, { recordname = sSourceActorPath });
	else
		table.insert(rThrow.shortcuts, {});
	end
	if vTargets then
		if bMultiTarget then
			for _,v in ipairs(vTargets) do
				local sTargetActorPath = ActorManager.getCreatureNodeName(v);
				table.insert(rThrow.shortcuts, { recordname = sTargetActorPath });
			end
		else
			local sTargetActorPath = ActorManager.getCreatureNodeName(vTargets);
			table.insert(rThrow.shortcuts, { recordname = sTargetActorPath });
		end
	end

	local tMeta = {};
	for k,v in pairs(rRoll) do
		if type(k) ~= "table" then
			local sk = tostring(k) or "";
			if sk ~= "" then
				local sTypeVar = type(v);
				if sTypeVar == "boolean" then
					tMeta[sk] = tostring(v and 1 or 0);
				elseif (sTypeVar == "string") or (sTypeVar == "number") then
					tMeta[sk] = v;
				elseif (sTypeVar == "table") then
					if (sk == "tActionTags") then
						tMeta[sk] = table.concat(v, "|");
					end
				end
			end
		end
	end

	local rSlot = {};
	rSlot.number = rRoll.nMod;
	rSlot.dice = rRoll.aDice;
	rSlot.metadata = tMeta;

	rThrow.slots = { rSlot };

	return rThrow;
end

function roll(rSource, vTargets, rRoll, bMultiTarget)
	if ActionsManager.doesRollHaveDice(rRoll) then
		DiceManager.onPreEncodeRoll(rRoll);

		if not rRoll.bTower and OptionsManager.isOption("MANUALROLL", "on") then
			if bMultiTarget then
				ManualRollManager.addRoll(rRoll, rSource, vTargets);
			else
				ManualRollManager.addRoll(rRoll, rSource, { vTargets });
			end
		else
			local rThrow = ActionsManager.buildThrow(rSource, vTargets, rRoll, bMultiTarget);
			Comm.throwDice(rThrow);
		end
	else
		if bMultiTarget then
			ActionsManager.handleResolution(rRoll, rSource, vTargets);
		else
			ActionsManager.handleResolution(rRoll, rSource, { vTargets });
		end
	end
end

function onDiceLaunched(draginfo)
	if (draginfo.getDescription() or ""):match(ActionsManager.ROLL_TAG_PATTERN) then
		return;
	end

	return ActionsManager.actionDrop(draginfo);
end
function onDiceLanded(draginfo)
	local s = draginfo.getDescription();
	if s:match(ActionsManager.ROLL_TAG_PATTERN) then
		draginfo.setDescription(s:gsub(ActionsManager.ROLL_TAG_PATTERN, ""));
	end

	if not GameManager.isAction(draginfo.getType()) then
		return;
	end

	local rSource, rRolls, aTargets = ActionsManager.decodeActionFromDrag(draginfo, true);
	for _,rRoll in ipairs(rRolls) do
		if ActionsManager.doesRollHaveDice(rRoll) then
			ActionsManager.handleResolution(rRoll, rSource, aTargets);
		end
	end
	return true;
end

function handleResolution(rRoll, rSource, aTargets)
	if rRoll.sReplaceDieResult then
		local aReplaceDieResult = StringManager.split(rRoll.sReplaceDieResult, "|");
		for kDie,vDie in ipairs(rRoll.aDice) do
			if aReplaceDieResult[kDie] then
				vDie.result = tonumber(aReplaceDieResult[kDie]) or 0;
				vDie.value = vDie.result;
			end
		end
	end

	GameManager.callMultiKeyFunctionPreLayered("onActionPreOnRoll", rRoll.sType, rSource, rRoll);
	local fPostRoll = ActionsManager.getPostRollHandler(rRoll.sType);
	if fPostRoll then
		fPostRoll(rSource, rRoll);
	end
	GameManager.callMultiKeyFunctionPostLayered("onActionPostOnRoll", rRoll.sType, rSource, rRoll);
	rRoll.nTotal = ActionsManager.total(rRoll);

	if not aTargets or (#aTargets == 0) then
		ActionsManager.resolveAction(rSource, nil, rRoll);
	elseif #aTargets == 1 then
		ActionsManager.resolveAction(rSource, aTargets[1], rRoll);
	else
		for kTarget,rTarget in ipairs(aTargets) do
			local rRollTarget = UtilityManager.copyDeep(rRoll);
			rTarget.nOrder = kTarget;
			ActionsManager.resolveAction(rSource, rTarget, rRollTarget);
		end
	end
end

function onChatDragStart(draginfo)
	local sIcon = GameManager.getActionProperty(draginfo.getType(), "sIcon");
	if sIcon then
		draginfo.setIcon(sIcon);
	end
end

--
--  RESOLVE ACTION
--  (I.E. DISPLAY CHAT MESSAGE, COMPARISONS, ETC.)
--

function resolveAction(rSource, rTarget, rRoll)
	GameManager.callMultiKeyFunctionPreLayered("onActionPreResolve", rRoll.sType, rSource, rTarget, rRoll);

	local fResult = ActionsManager.getResultHandler(rRoll.sType);
	if fResult then
		fResult(rSource, rTarget, rRoll);
	else
		local rMessage = ActionsManager.createActionMessage(rSource, rRoll);
		Comm.deliverChatMessage(rMessage);
	end

	GameManager.callMultiKeyFunctionPostLayered("onActionPostResolve", rRoll.sType, rSource, rTarget, rRoll);

	ActionsPerformManager.notifyActionRollCompleted(rSource, rTarget, rRoll);
end

function createActionMessage(rSource, rRoll, tData)
	if not rSource and not Session.IsHost then
		rSource = ActorManager.getActiveActor();
	end

	-- Build the basic message to deliver
	local rMessage = ChatManager.createBaseMessage(rSource, rRoll.sUser);
	if not rSource then
		if Session.IsHost then
			rMessage.sender = ChatIdentityManager.getGMIdentity();
		else
			rMessage.sender = User.getUsername();
		end
	end
	rMessage.type = rRoll.sType;
	rMessage.text = rRoll.sDesc;
	rMessage.dice = rRoll.aDice;
	rMessage.diemodifier = rRoll.nMod;
	rMessage.diceskipexpr = rRoll.diceskipexpr;

	-- Check to see if this roll should be secret (GM or dice tower tag)
	if rRoll.bSecret then
		rMessage.secret = true;
		if rRoll.bTower then
			rMessage.assets = rMessage.assets or {};
			table.insert(rMessage.assets, ChatIdentityManager.getDiceTowerAsset());
		end
	elseif Session.IsHost and OptionsManager.isOption("REVL", "off") then
		rMessage.secret = true;
	end

	if tData then
		if ((tData.sIcon or "") ~= "") then
			rMessage.icon = tData.sIcon;
		end
		if tData.rTarget then
			rMessage.text = StringManager.appendLine(rMessage.text, string.format("[at %s]", ActorManager.getDisplayName(tData.rTarget)));
		end
	end

	return rMessage;
end

function total(rRoll)
	return Utility.getDiceTotal(rRoll.aDice) + rRoll.nMod;
end

function getShowResult(rSource, rTarget)
	if Session.IsHost then
		return true;
	end
	return ActionsManager.getShowResultToPlayer(rSource, rTarget);
end
function getShowResultToPlayer(rSource, rTarget)
	local bShowResultsToPlayer;
	local bInvolvesFriendlyUnits =
		(not rSource or ActorManager.isFaction(rSource, "friend")) or
		(not rTarget or ActorManager.isFaction(rTarget, "friend"));
	local bInvolvesFriendlyUnitsOnly =
		(not rSource or ActorManager.isFaction(rSource, "friend")) and
		(not rTarget or ActorManager.isFaction(rTarget, "friend"));
	local sOptSHRR = OptionsManager.getOption("SHRR");
	if sOptSHRR == "off" then
		bShowResultsToPlayer = false;
	elseif sOptSHRR == "pc" then
		bShowResultsToPlayer = bInvolvesFriendlyUnits;
	elseif sOptSHRR == "pconly" then
		bShowResultsToPlayer = bInvolvesFriendlyUnitsOnly;
	else
		bShowResultsToPlayer = true;
	end

	if bShowResultsToPlayer then
		if rTarget and not ActorManager.isVisible(rTarget) then
			bShowResultsToPlayer = false;
		end
	end

	return bShowResultsToPlayer;
end

function outputResult(bTower, rSource, rTarget, rMessageGM, rMessagePlayer)
	if bTower then
		rMessageGM.secret = true;
		Comm.deliverChatMessage(rMessageGM, "");
	else
		ActionsManager.messageResult(false, rSource, rTarget, rMessageGM, rMessagePlayer);
	end
end

function messageResult(_, rSource, rTarget, rMessageGM, rMessagePlayer)
	if ActionsManager.getShowResultToPlayer(rSource, rTarget) then
		rMessageGM.secret = false;
		Comm.deliverChatMessage(rMessageGM);
	else
		rMessageGM.secret = true;
		Comm.deliverChatMessage(rMessageGM, "");

		local bInvolvesFriendlyUnits =
			(not rSource or ActorManager.isFaction(rSource, "friend")) or
			(not rTarget or ActorManager.isFaction(rTarget, "friend"));
		if bInvolvesFriendlyUnits then
			if Session.IsHost then
				local tUsers = User.getActiveUsers();
				if #tUsers > 0 then
					Comm.deliverChatMessage(rMessagePlayer, tUsers);
				end
			else
				Comm.addChatMessage(rMessagePlayer);
			end
		end
	end
end
