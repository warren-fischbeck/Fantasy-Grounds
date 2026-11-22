--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

--
--	Registrations and Handlers
--

local _sActionsPath = "actions";
function registerPowerActionsPath(s)
	_sActionsPath = s;
end
function getPowerActionsPath()
	return _sActionsPath;
end

local _tHandlers = nil;
function registerPowerHandlers(tPowerItemHandlers)
	_tHandlers = tPowerItemHandlers;
end

function getPowerActor(node)
	return ActorManager.resolveActor(PowerManagerCore.getPowerActorNode(node));
end
function getPowerActorNode(node)
	if _tHandlers and _tHandlers.fnGetActorNode then
		return _tHandlers.fnGetActorNode(node);
	end
	return nil;
end
function usePower(node)
	if _tHandlers and _tHandlers.fnUsePower then
		_tHandlers.fnUsePower(node);
		return;
	end
	PowerManagerCore.performDefaultPowerUse(node);
end
function parsePower(node)
	if _tHandlers and _tHandlers.fnParse then
		_tHandlers.fnParse(node);
		return;
	end
end
function updatePowerDisplay(w)
	if _tHandlers and _tHandlers.fnUpdateDisplay then
		_tHandlers.fnUpdateDisplay(w);
		return;
	end
end

--
--	Common Functions
--

function getPowerName(node)
	return DB.getValue(node, "name", "");
end
function getPowerOutput(node)
	local sShort = DB.getValue(node, "shortdescription", "");
	if sShort ~= "" then
		return string.format("%s - %s", PowerManagerCore.getPowerName(node), sShort);
	end
	return PowerManagerCore.getPowerName(node);
end

function performDefaultPowerUse(node)
	local rActor = PowerManagerCore.getPowerActor(node);
	ChatManager.sendMessage(PowerManagerCore.getPowerOutput(node), { sIcon = "action_cast", bSecret = not ActorManager.isPC(rActor), rActor = rActor, });
end

function handleDefaultPowerInitParse(node)
	local nParse = DB.getValue(node, "parse", 0);
	if nParse ~= 0 then
		DB.deleteChild(node, "parse");
		PowerManagerCore.parsePower(node);
	end
end

--
--	Context Menu Functions
--

function registerDefaultPowerMenu(w)
	w.resetMenuItems();

	local tTypes = PowerActionManagerCore.getSortedActionTypes();
	if #tTypes > 0 then
		w.registerMenuItem(Interface.getString("power_menu_action_add"), "pointer", 4);
		for k,v in ipairs(tTypes) do
			w.registerMenuItem(Interface.getString("power_menu_action_add_" .. v), "radial_power_action_" .. v, 4, k);
		end
	end

	if _tHandlers and _tHandlers.fnParse then
		w.registerMenuItem(Interface.getString("power_menu_action_reparse"), "textlist", 3);
	end

	w.registerMenuItem(Interface.getString("list_menu_deleteitem"), "delete", 2);
	w.registerMenuItem(Interface.getString("list_menu_deleteconfirm"), "delete", 2, 7);
end
function onDefaultPowerMenuSelection(w, selection, subselection)
	if selection == 2 and subselection == 7 then
		DB.deleteNode(w.getDatabaseNode());
	elseif selection == 4 then
		local tTypes = PowerActionManagerCore.getSortedActionTypes();
		local sType = tTypes[subselection];
		if sType then
			PowerManagerCore.createPowerAction(w, sType);
		end
	elseif selection == 3 then
		PowerManagerCore.parsePower(w.getDatabaseNode());
		if w.activatedetail then
			w.activatedetail.setValue(1);
		end
	end
end
function createPowerAction(w, sType)
	local node = w.getDatabaseNode();
	if not node then
		return;
	end
	local nodeActions = DB.createChild(node, PowerManagerCore.getPowerActionsPath());
	if not nodeActions then
		return;
	end
	local nodeAction = DB.createChild(nodeActions);
	if not nodeAction then
		return;
	end
	DB.setValue(nodeAction, "type", "string", sType);
	if w.activatedetail then
		w.activatedetail.setValue(1);
	end
end
