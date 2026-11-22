--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

--luacheck: globals button.subroll

function onInit()
	self.onDataChanged();
	DB.addHandler(getDatabaseNode(), "onChildUpdate", self.onDataChanged);
	DB.addHandler(DB.getPath(DB.getChild(getDatabaseNode(), "..."), "group"), "onUpdate", self.onDataChanged);
end
function onClose()
	DB.removeHandler(getDatabaseNode(), "onChildUpdate", self.onDataChanged);
	DB.removeHandler(DB.getPath(DB.getChild(getDatabaseNode(), "..."), "group"), "onUpdate", self.onDataChanged);
end

-- onDataChanged(nodeParent)
function onDataChanged(_)
	local tData = self.getActionOptions();
	local sButton, sButtonDown = PowerActionManagerCore.getActionButtonIcons(getDatabaseNode(), tData);
	button.setIcons(sButton, sButtonDown);
	button.setTooltipText(PowerActionManagerCore.getActionTooltip(getDatabaseNode(), tData));
end

function performAction(draginfo)
	local tData = self.getActionOptions();
	PowerActionManagerCore.performAction(draginfo, getDatabaseNode(), tData);
end

function getActionOptions()
	local tData = {};
	if button and button.subroll then
		tData.sSubRoll = button.subroll[1];
	end
	return tData;
end
