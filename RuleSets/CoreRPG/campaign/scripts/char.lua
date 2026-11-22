--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

function onInit()
	WindowTabManager.populate(self);

	if Session.IsHost then
		ActionCore.buildRestMenu(self, 7);
	end

	GameManager.callEventFunctions("onActorEncumbranceLimitChanged", getDatabaseNode());
end

function onMenuSelection(selection, subselection)
	if super and super.onMenuSelection then
		super.onMenuSelection(selection, subselection);
	end

	if selection == 7 then
		ActionCore.handleRestActor(getDatabaseNode(), subselection);
	end
end
