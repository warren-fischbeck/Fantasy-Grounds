
CharacterEngine = {}

function buildCharacter(nodeWindow)
  local nodeChar = nodeWindow;
  if nodeChar then
    addDefaultCategories(nodeChar);
  end
end

local function getDiceCount(s)
    s = tostring(s);
    local count = string.match(s, "^(%d*)d");
    if count == "" then
        return 1;   -- default when no number is present (e.g., "d6")
    end
    return tonumber(count);
end

local function hasSpecialChars(s)
    return string.find(s, "[()%[%]-:]") ~= nil
end

function attributeIncrease(window)
    local wWindow = window;
    local nodeObjSkill = wWindow.getDatabaseNode(); -- single skill node
    local nodeColSkills = nodeObjSkill.getParent(); -- container of skill nodes
    local nodeObjAttribute = nodeColSkills.getParent(); -- single attribute node
    local nodeColAttributes = nodeObjAttribute.getParent(); -- container of attribute nodes
    local nodeObjCharacter = nodeColAttributes.getParent(); -- single character nodes

    -- get current character points on the charactersheet
    local nCPValue = DB.getValue(nodeObjCharacter, "characterpoints", 0);
    local sLabel = DB.getValue(nodeObjSkill, "label", "");

    -- get current pip count for the skill
    local nBonus = DB.getValue(nodeObjSkill, "bonus", 0);

    -- get current die quantity for the skill (e.g., "3d6" -> 3)
    local nSkillDieCount = getDiceCount(wWindow.dice.getValue());

    -- calculate cost to increase pip (1 CP per die)
    local nCostToIncrease = nSkillDieCount * 1;
    if hasSpecialChars(sLabel) then
        nCostToIncrease = nSkillDieCount *.5; 
    end
    nCostToIncrease = math.ceil(nCostToIncrease)

    -- Check if the character has enough CP to increase the pip
    if nCPValue <= 0 then
        nCPValue = DB.getValue(nodeColAttributes, "characterpoints", 0);
        if nCPValue <= 0 then
            ChatManager.SystemMessage("You have no character points.");
            return;
        end
    end

    if nCPValue < nCostToIncrease then
        ChatManager.SystemMessage("Not enough character points to increase your pip.");
        return;
    end

    -- Deduct CP
    DB.setValue(nodeObjCharacter, "characterpoints", "number", nCPValue - nCostToIncrease);

    -- Increase bonus
    nBonus = nBonus + 1;
    DB.setValue(nodeObjSkill, "bonus", "number", nBonus);

    --------------------------------------------------------------------
    -- ⭐ NEW RULE: If bonus reaches 3, convert to +1D and reset bonus
    --------------------------------------------------------------------
    if nBonus > 2 then
        -- increase the die quantity by 1
        nSkillDieCount = nSkillDieCount + 1;

        -- update the dice string in the skill node (e.g., "3d6" -> "4d6")
        local sDiceString = nSkillDieCount .. "d6";

        -- update the dice field in the skill node
        wWindow.dice.setValue(sDiceString);

        -- reset the bonus to 0
        wWindow.bonus.setValue(0);

        ChatManager.SystemMessage("Bonus reached 3! Converted to +1D. New dice: " .. sDiceString);
    else
        ChatManager.SystemMessage("Pip increased! Bonus is now " .. nBonus);
    end
end

function categoryIncrease(window)
    local nodeChar = window;
    local nodeAttributes = nodeChar.getDatabaseNode()
    local nodeAttribute = nodeAttributes.getParent()
    local nodeCharacter = nodeAttribute.getParent()

    -- Character Points
    local nCPValue = DB.getValue(nodeCharacter, "characterpoints", 0)

    -- Dice string (e.g., "3d6")
    local sDice = nodeChar.dice.getValue()

    -- Bonus
    local nBonus = DB.getValue(nodeAttributes, "bonus", 0)

    -- Cost to increase pip
    local nCurrentAttributeValue = getDiceCount(sDice) * 10

    if nCPValue <= 0 then
        ChatManager.SystemMessage("You have no character points.")
        return;
    end

    if nCPValue < nCurrentAttributeValue then
        ChatManager.SystemMessage("Not enough character points to increase your pip.")
        return;
    end

    -- Deduct CP
    DB.setValue(nodeCharacter, "characterpoints", "number", nCPValue - nCurrentAttributeValue)

    -- Increase bonus
    nBonus = nBonus + 1
    DB.setValue(nodeAttributes, "bonus", "number", nBonus)
    skillIncrease(nodeChar);
    --------------------------------------------------------------------
    -- ⭐ NEW RULE: If bonus reaches 3, convert to +1D and reset bonus
    --------------------------------------------------------------------
    if nBonus > 2 then
        local nDiceCount = getDiceCount(sDice)
        local newDiceCount = nDiceCount + 1

        -- Build new dice string (always d6 in Star Wars D6)
        local newDiceString = tostring(newDiceCount) .. "d6"

        -- Update dice field
        nodeChar.dice.setValue(newDiceString)

        -- Reset bonus
        nodeChar.bonus.setValue(0)

        ChatManager.SystemMessage("Bonus reached +3! Dice increased to " .. newDiceString .. " and bonus reset to 0.")
    else
        ChatManager.SystemMessage("Pip increased! Bonus is now " .. nBonus)
    end
end

function skillIncrease(window)
    local nodeChar = window.getDatabaseNode()

    local nodeSkills = nodeChar.getChild("skills");
    if nodeSkills then

        for _, nodeSkillChild in pairs(nodeSkills.getChildren()) do

            -- get current bonus value
            local nBonus = DB.getValue(nodeSkillChild, "bonus", 0);

            -- get curent dice value
            local aDice, nMod = TableManager.getTableDice(nodeSkillChild);
	        local sDice = DiceManager.convertDiceToString(aDice, nMod);

            -- increment bonus value
            nBonus = nBonus + 1;

            -- update bonus value in the database
            DB.setValue(nodeSkillChild, "bonus", "number", nBonus);

            --------------------------------------------------------------------
            -- ⭐ NEW RULE: If bonus reaches 3, convert to +1D and reset bonus
            --------------------------------------------------------------------
            if nBonus > 2 then
                local nDiceCount = getDiceCount(sDice);
                local newDiceCount = nDiceCount + 1;

                -- Build new dice string (always d6 in Star Wars D6)
                local newDiceString = tostring(newDiceCount) .. "d6";
                local tDice = Utility.convertStringToDice(newDiceString)

                DB.setValue(nodeSkillChild, "bonus", "number", 0);
                DB.setValue(nodeSkillChild, "dice", "dice", tDice);

                ChatManager.SystemMessage(
                    "Skill '" .. DB.getValue(nodeSkillChild, "label", "Skill") ..
                    "' upgraded from " .. nDiceCount .. " - " .. newDiceString .. " - and bonus reset to 0."
                );
            end
        end
    end
end

function forceAttributeIncrease(window)
    local wWindow = window;
    local nodeObjSkill = wWindow.getDatabaseNode(); -- single skill node
    local nodeColSkills = nodeObjSkill.getParent(); -- container of skill nodes
    local nodeObjAttribute = nodeColSkills.getParent(); -- single attribute node
    local nodeColAttributes = nodeObjAttribute.getParent(); -- container of attribute nodes
    local nodeObjCharacter = nodeColAttributes.getParent(); -- single character nodes

    -- get current character points on the charactersheet
    local nCPValue = DB.getValue(nodeColAttributes, "characterpoints", 0);
    local sLabel = DB.getValue(nodeObjSkill, "name", "");

    -- get current pip count for the skill
    local nBonus = DB.getValue(nodeObjSkill, "bonus", 0);

    -- get current die quantity for the skill (e.g., "3d6" -> 3)
    local dDice = wWindow.dice.getValue();
    local nSkillDieCount = getDiceCount(dDice);

    -- calculate cost to increase pip
    local nCostToIncrease;

    if not aDice then
        nCostToIncrease = 1;
    else
        nCostToIncrease = nSkillDieCount;

        if hasSpecialChars(sLabel) then
            nCostToIncrease = nSkillDieCount * 0.5;
        end
    end
    nCostToIncrease = math.ceil(nCostToIncrease);

    -- Check if the character has enough CP to increase the pip
    if nCPValue <= 0 then
        ChatManager.SystemMessage("You have no character points.");
        return;
    end

    if nCPValue < nCostToIncrease then
        ChatManager.SystemMessage("Not enough character points to increase your pip.");
        return;
    end

    -- Deduct CP
    DB.setValue(nodeColAttributes, "characterpoints", "number", nCPValue - nCostToIncrease);

    -- Increase bonus
    nBonus = nBonus + 1;
    DB.setValue(nodeObjSkill, "bonus", "number", nBonus);

    --------------------------------------------------------------------
    -- ⭐ NEW RULE: If bonus reaches 3, convert to +1D and reset bonus
    --------------------------------------------------------------------
    if nBonus > 2 then
        -- increase the die quantity by 1
        if not nSkillDieCount then
            nSkillDieCount = 0
        end
        nSkillDieCount = nSkillDieCount + 1;
        Debug.console(nSkillDieCount);

        -- update the dice string in the skill node (e.g., "3d6" -> "4d6")
        local sDiceString = nSkillDieCount .. "d6";

        -- update the dice field in the skill node
        wWindow.dice.setValue(sDiceString);

        -- reset the bonus to 0
        wWindow.bonus.setValue(0);

        ChatManager.SystemMessage("Bonus reached 3! Converted to +1D. New dice: " .. sDiceString);
    else
        ChatManager.SystemMessage("Pip increased! Bonus is now " .. nBonus);
    end
end

function addDefaultCategories(nodeChar)
    -- Check if defaults already added
    local nAdded = DB.getValue(nodeChar, "defaultattributesadded", 0)
    if nAdded == 1 then
        -- Already initialized; do nothing
        return
    end

    -- Create or fetch the attributes node
    local nodeAttributes = DB.createChild(nodeChar, "attributes")

    local tDefaults = {
        { name = "Dexterity", skills = { "Archaic Guns", "Blaster", "Blaster Artillery", "Bowcaster", "Brawling Parry", "Dodge", "Grenade", "Lightsaber", "Melee Combat", "Melee Parry", "Missile Weapons", "Pick Pocket", "Running", "Thrown Weapons", "Vehicle Blasters" } },
        { name = "Knowledge", skills = { "Alien Species", "Bureaucracy", "Business", "Cultures", "Intimidation", "Languages", "Law Enforcement", "Planetary Systems", "Scholar", "Streetwise", "Survival", "Tactics", "Value", "Willpower" } },
        { name = "Mechanical", skills = { "Archaic Starship Piloting", "Astrogation", "Beast Riding", "Capital Ship Gunnery", "Capital Ship Piloting", "Capital Ship Shields", "Communications", "Ground Vehicle Operation", "Hover Vehicle Operation", "Jet Pack Operation", "Powersuit Operation", "Repulsorlift Operation", "Rocket Pack Operation", "Sensors", "Space Transports", "Starfighter Piloting", "Starship Gunnery", "Starship Shields", "Swoop Operation", "Walker Operation" } },
        { name = "Perception", skills = { "Bargain", "Command", "Con", "Forgery", "Gambling", "Hide", "Investigation", "Persuasion", "Search", "Sneak" } },
        { name = "Strength", skills = { "Brawling", "Climbing/Jumping", "Lifting", "Stamina", "Swimming" } },
        { name = "Technical", skills = { "Armor Repair", "Blaster Repair", "Capital Ship Repair", "Capital Ship Weapon Repair", "Computer Programming/Repair", "Demolitions", "Droid Programming", "Droid Repair", "First Aid", "Ground Vehicle Repair", "Hover Vehicle Repair", "Medicine", "Repulsorlift Repair", "Security", "Space Transports Repair", "Starfighter Repair", "Starship Weapon Repair", "Walker Repair" } },
    }

    for _, cat in ipairs(tDefaults) do
        local nodeCat = nil

        -- Check existing attributes for a matching name
        for _, nodeExisting in pairs(DB.getChildren(nodeAttributes)) do
            local sname = DB.getValue(nodeExisting, "name", "")
            if sname == cat.name then
                nodeCat = nodeExisting
                break
            end
        end

        -- Create attribute category if it does not exist
        if not nodeCat then
            nodeCat = DB.createChild(nodeAttributes)
            DB.setValue(nodeCat, "name", "string", cat.name)
            DB.setValue(nodeCat, "dice", "dice", { "d6" })
            DB.setValue(nodeCat, "bonus", "number", 0)
        end

        -- Create or fetch the skill list inside the category
        local nodeSkillList = DB.createChild(nodeCat, "skills")

        -- Add skills only if they do not already exist
        for _, skillName in ipairs(cat.skills) do
            local bSkillExists = false

            for _, nodeExistingSkill in pairs(DB.getChildren(nodeSkillList)) do
                local sExisting = DB.getValue(nodeExistingSkill, "name", "")
                if sExisting == skillName then
                    bSkillExists = true
                    break
                end
            end

            if not bSkillExists then
                local nodeSkill = DB.createChild(nodeSkillList)
                DB.setValue(nodeSkill, "name", "string", skillName)
                DB.setValue(nodeSkill, "dice", "dice", { "d6" })
                DB.setValue(nodeSkill, "bonus", "number", 0)
            end
        end
    end

    -- test if the character is force positive or not and set the force points accordingly
    local nForcePositive = DB.getValue(nodeChar, "forcepositive", 0)
    if nForcePositive == 0 then
        DB.setValue(nodeChar, "forcepoints", "number", 1)
    else
        DB.setValue(nodeChar, "forcepoints", "number", 2)
    end

    -- set movement
    DB.setValue(nodeChar, "movement", "number", 10)

    populateForcePowers(nodeChar);
    -- Mark defaults as added so this never runs again
    DB.setValue(nodeChar, "defaultattributesadded", "number", 1)
end

function populateForcePowers(nodeChar)
    local nodeCharacter = nodeChar;

    local nodeForce = DB.createChild(nodeCharacter, "force")
    local nodeCorePowers = DB.createChild(nodeForce, "corepowers")
    local nodeAdvancedPowers = DB.createChild(nodeForce, "advancedpowers")


    local tCorePowers = {
        { name = "Sense", skills = { "Life Detection", "Life Sense", "Magnify Senses", "Receptiive Telepathy", "Postcognition", "Sense Force" } },
        { name = "Control", skills = { "Absorb/Dissipate Energy", "Accelerate Healing", "Concentration", "Control Disease", "Control Pain", "Detoxify Poison", "Emptiness", "Hibernation Trance", "Reduce Injury", "Remain Conscious", "Resist Stun" } },
        { name = "Alter", skills = { "Injury/Kill", "Telekinesis"  } },
    }

    local tAdvancedPowers = {
        { name = "Control & Sense", skills = { "Lightsaber Combat", "Projective Telepathy"  } },
        { name = "Control & Alter", skills = { "Accelerate Another's Healing", "Control Another's Disease", "Control Another's Pain", "Place Another in Hibernation Trance", "Return Another to Consciousness", "Transfer Force"  } },
        { name = "Control, Sense & Alter", skills = { "Affect Mind"  } },
    }

    for _, power in ipairs(tCorePowers) do
        local nodePower = DB.createChild(nodeCorePowers)
        DB.setValue(nodePower, "name", "string", power.name)
        DB.setValue(nodePower, "dice", "dice", 0)
        DB.setValue(nodePower, "bonus", "number", 0)
        local nodeSkillList = DB.createChild(nodePower, "skills")
        for _, skillName in ipairs(power.skills) do
            local nodeSkill = DB.createChild(nodeSkillList)
            DB.setValue(nodeSkill, "name", "string", skillName)
            DB.setValue(nodeSkill, "trained", "number", 0)
        end
    end

    for _, advancedpower in ipairs(tAdvancedPowers) do
        local nodePower = DB.createChild(nodeAdvancedPowers)
        DB.setValue(nodePower, "name", "string", advancedpower.name)
        local nodeSkillList = DB.createChild(nodePower, "skills")
        for _, skillName in ipairs(advancedpower.skills) do
            local nodeSkill = DB.createChild(nodeSkillList)
            DB.setValue(nodeSkill, "name", "string", skillName)
            DB.setValue(nodeSkill, "trained", "number", 0)
        end
    end
end