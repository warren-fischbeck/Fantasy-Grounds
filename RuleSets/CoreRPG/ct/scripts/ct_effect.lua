--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

--luacheck: globals idelete duration expiration init

function onInit()
	self.updateOwner();
	self.onExpirationChanged();
	if not Session.IsHost then
		DB.addHandler(getDatabaseNode(), "onObserverUpdate", self.updateOwner);
	end
end
function onClose()
	if not Session.IsHost then
		DB.removeHandler(getDatabaseNode(), "onObserverUpdate", self.updateOwner);
	end
end

function updateOwner()
	resetMenuItems();
	if self.allowEdit() then
		registerMenuItem(Interface.getString("ct_menu_effectdelete"), "deletepointer", 3);
		registerMenuItem(Interface.getString("list_menu_deleteconfirm"), "delete", 3, 3);
	end
	self.setEditMode(DB.isOwner(getDatabaseNode()));
end

function allowEdit()
	if Session.IsHost then
		return true;
	end
	if DB.isOwner(getDatabaseNode()) then
		return true;
	end
	return false;
end
function setEditMode(bEditMode)
	local bShow = false;
	if self.allowEdit() then bShow = bEditMode; end
	if StringManager.contains({ "combattracker_host", "combattracker_client", }, WindowManager.getTopWindow(self).getClass()) then
		idelete.editmode = nil;
		idelete.setVisible(bShow);
	end
	targeting_add_button.setVisible(bShow);
end

function checkData()
	if label.getValue() ~= DB.getValue(getDatabaseNode(), "label", "") then
		label.setValue(label.getValue());
	end
end

function onExpirationChanged()
	if not expiration then
		return;
	end
	local sExpire = expiration.getValue();
	local bShowDuration = ((sExpire ~= "restlong") and (sExpire ~= "restshort"));
	if init then
		init.setVisible(bShowDuration);
	end
	if duration then
		duration.setVisible(bShowDuration);
	end
end

function onMenuSelection(selection, subselection)
	if selection == 3 and subselection == 3 then
		WindowManager.safeDelete(self);
	end
end
function onDragStart(_, _, _, draginfo)
	if not self.allowEdit() then
		return;
	end
	self.checkData();
	local rEffect = EffectManager.getEffect(getDatabaseNode());
	return ActionEffect.performRoll(draginfo, nil, rEffect);
end
function onDrop(_, _, draginfo)
	if not Session.IsHost then
		return;
	end
	if draginfo.isType("combattrackerentry") then
		EffectManager.setEffectSource(getDatabaseNode(), draginfo.getCustomData());
		return true;
	end
end
