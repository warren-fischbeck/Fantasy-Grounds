--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

OOB_MSGTYPE_DICETOWER = "dicetower";

function onTabletopInit()
	if Session.IsHost then
		OOBManager.registerOOBMsgHandler(DiceTowerManager.OOB_MSGTYPE_DICETOWER, DiceTowerManager.handleDiceTower);
	end
end

local _control = nil;
function registerControl(c)
	_control = c;
	DiceTowerManager.activate();
end
function activate()
	OptionsManager.registerCallback("TBOX", DiceTowerManager.update);
	OptionsManager.registerCallback("REVL", DiceTowerManager.update);

	DiceTowerManager.update();
end
function update()
	if _control then
		local bShow = false;
		if OptionsManager.isOption("TBOX", "on") then
			bShow = not Session.IsHost or not OptionsManager.isOption("REVL", "off");
		end
		_control.setVisible(bShow);
		if _control.window.setEnabled then
			_control.window.setEnabled(bShow);
		end

		if not Session.IsHost then
			_control.resetMenuItems();
			if bShow then
				_control.registerMenuItem(Interface.getString("dicetower_menu_whisper"), "broadcast", 7);
			end
		end
	end
end
function onMenuSelection(selection)
	if Session.IsHost then
		return;
	end

	if selection == 7 then
		ChatManager.sendWhisperToGM();
	end
end

function encodeOOBFromRoll(rRoll, rSource)
	local msgOOB = {
		type = DiceTowerManager.OOB_MSGTYPE_DICETOWER,
		sender = ActorManager.getCreatureNodeName(rSource),
		sUser = Session.UserName,
		jsonRoll = Utility.encodeJSON(rRoll) or "",
	};
	return msgOOB;
end
function decodeRollFromOOB(msgOOB)
	return Utility.decodeJSON(msgOOB.jsonRoll) or {};
end

function onHover(bOnControl)
	if _control then
		local bShowHover = false;
		if bOnControl then
			local draginfo = Input.getDragData();
			if draginfo then
				bShowHover = GameManager.isAction(draginfo.getType());
			end
		end
		if bShowHover then
			_control.setIcon("dicetower_drop");
		else
			_control.setIcon("dicetower_normal");
		end
	end
end
function onDrop(draginfo)
	DiceTowerManager.onHover(false);
	if _control then
		if OptionsManager.isOption("TBOX", "on") then
			local sDragType = draginfo.getType();
			if GameManager.isAction(sDragType) then
				local rSource, rRolls = ActionsManager.actionDropHelper(draginfo, false);
				if not rSource then
					local sIdentity = User.getCurrentIdentity();
					if sIdentity then
						rSource = ActorManager.resolveActor("charsheet." .. sIdentity);
					end
				end
				for _,rRoll in ipairs(rRolls) do
					DiceTowerManager.sendRoll(rRoll, rSource);
				end
			elseif sDragType == "string" then
				ChatManager.processWhisperHelper("GM", draginfo.getStringData());
			end
		end
	end
	return true;
end

function sendRoll(rRoll, rSource)
	local msgOOB = DiceTowerManager.encodeOOBFromRoll(rRoll, rSource);

	if not Session.IsHost then
		local sDice;
		if rRoll.aDice and rRoll.aDice.expr then
			if (rRoll.nMod or 0) ~= 0 then
				sDice = string.format("%s%+d", rRoll.aDice.expr, rRoll.nMod);
			else
				sDice = rRoll.aDice.expr;
			end
		else
			sDice = DiceManager.convertDiceToString(rRoll.aDice, rRoll.nMod);
		end
		local msg = {
			sender = ActorManager.getDisplayName(rSource),
			font = "chatfont",
			assets = {
				ChatIdentityManager.getActorAsset(rSource),
				ChatIdentityManager.getDiceTowerAsset(),
			},
			text = string.format("%s [%s]", rRoll.sDesc or "", sDice),
		};
		Comm.addChatMessage(msg);
	end

	Comm.deliverOOBMessage(msgOOB, "");
end
function handleDiceTower(msgOOB)
	local rActor = nil;
	if (msgOOB.sender or "") ~= "" then
		rActor = ActorManager.resolveActor(msgOOB.sender);
	end

	local rRoll = DiceTowerManager.decodeRollFromOOB(msgOOB);
	rRoll.bTower = true;
	rRoll.bSecret = true;
	if rActor then
		rRoll.sDesc = string.format("[%s] %s", Interface.getString("dicetower_tag"), (rRoll.sDesc or ""));
	else
		rRoll.sDesc = string.format("%s: [%s] %s", msgOOB.sUser or "", Interface.getString("dicetower_tag"), (rRoll.sDesc or ""));
	end
	ActionsManager.roll(rActor, nil, rRoll);
end
