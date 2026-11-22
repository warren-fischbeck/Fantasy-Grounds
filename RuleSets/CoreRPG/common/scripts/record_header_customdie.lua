--
--  Please see the license.html file included with this distribution for
--  attribution and copyright information.
--

function onInit()
	self.updateMenu();
	self.onValueChanged();
	DB.addHandler(DB.getPath(window.getDatabaseNode(), "customdie"), "onUpdate", self.onValueChanged);
end
function onClose()
	DB.removeHandler(DB.getPath(window.getDatabaseNode(), "customdie"), "onUpdate", self.onValueChanged);
end

function updateMenu()
	resetMenuItems();
	if DB.getValue(window.getDatabaseNode(), "customdie", "") ~= "" then
		registerMenuItem(Interface.getString("customdie_menu_clear"), "erase", 4);
	end
end
function onMenuSelection(selection)
	if selection == 4 then
		DB.setValue(window.getDatabaseNode(), "customdie", "string", "");
	end
end

function onValueChanged()
	local tDiceSkin = DiceRollManager.getActorDiceSkin(ActorManager.resolveActor(window.getDatabaseNode()));
	DiceSkinManager.setupCustomControl(self, tDiceSkin);

	if window.onCustomDieChanged then
		window.onCustomDieChanged();
	elseif window.update then
		window.update();
	end

	self.updateMenu();
end
