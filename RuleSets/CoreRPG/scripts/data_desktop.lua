--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

function addDataModuleSet(sMode, tData)
	CampaignSetupManager.addModuleSetData(sMode, tData);
end

aCoreDesktopStack =
{
	["host"] =
	{
		{
			sIcon = "sidebar_icon_link_ct",
			tooltipres="sidebar_tooltip_ct",
			class="combattracker_host",
			path="combattracker",
		},
		{
			sIcon = "sidebar_icon_link_ps",
			tooltipres="sidebar_tooltip_ps",
			class="partysheet_host",
			path="partysheet",
		},
		{
			class="calendar",
			path="calendar",
		},
		{
			class="diceselect",
		},
		{
			class="modifiers",
			path="modifiers",
		},
		{
			class="effectlist",
			path="effects",
		},
		{
			class="options",
		},
	},
	["client"] =
	{
		{
			sIcon = "sidebar_icon_link_ct",
			tooltipres="sidebar_tooltip_ct",
			class="combattracker_client",
			path="combattracker",
		},
		{
			sIcon = "sidebar_icon_link_ps",
			tooltipres="sidebar_tooltip_ps",
			class="partysheet_client",
			path="partysheet",
		},
		{
			class="calendar",
			path="calendar",
		},
		{
			class="diceselect",
		},
		{
			class="modifiers",
			path="modifiers",
		},
		{
			class="effectlist",
			path="effects",
		},
		{
			class="options",
		},
	},
};
aCoreDesktopDockV4 =
{
	["live"] =
	{
		{
			tooltipres="sidebar_tooltip_assets",
			class="tokenbag",
		},
		{
			class="library",
		},
		{
			sIcon = "sidebar_icon_link_story_book",
			tooltipres="sidebar_tooltip_story_book",
			class="story_book_list",
		},
	},
};
