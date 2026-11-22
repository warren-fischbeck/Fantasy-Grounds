AttackEngine = {};

--
-- CONFIGURATION
--

-- Change this value if the master skill records are stored
-- under a different database path.
AttackEngine.SKILL_DEFINITION_PATH = "skills";

--
-- ATTACK SCALES
--

AttackEngine.SCALE_CHARACTER = "Character";
AttackEngine.SCALE_VEHICLE = "Vehicle";
AttackEngine.SCALE_STARFIGHTER = "Starfighter";
AttackEngine.SCALE_CAPITAL = "Capital";

--
-- STRING HELPERS
--

local function normalizeWhitespace(s)
	s = StringManager.trim(s or "");
	s = s:gsub("%s+", " ");

	return s;
end

local function normalizeName(s)
	return normalizeWhitespace(s):lower();
end

--
-- ATTACK SCALE
--

-- Converts the item's scale into one of the four canonical values:
--
--   Character
--   Vehicle
--   Starfighter
--   Capital
--
-- Missing, blank, or unrecognized values default to Character.
function AttackEngine.normalizeScale(sScale)
	local sNormalized = normalizeName(sScale);

	if sNormalized == "vehicle" then
		return AttackEngine.SCALE_VEHICLE;
	end

	if sNormalized == "starfighter" or
			sNormalized == "star fighter" then
		return AttackEngine.SCALE_STARFIGHTER;
	end

	if sNormalized == "capital" or
			sNormalized == "capital ship" or
			sNormalized == "capitalship" or
			sNormalized == "captial" or
			sNormalized == "captial ship" then
		return AttackEngine.SCALE_CAPITAL;
	end

	return AttackEngine.SCALE_CHARACTER;
end

--
-- SPECIALIZATION NORMALIZATION
--

-- Converts alternate specialization notation into:
--
--   Base Skill (Specialization)
--
-- Examples:
--
--   Melee Combat (Knife)  -> Melee Combat (Knife)
--   Melee Combat [Knife]  -> Melee Combat (Knife)
--   Melee Combat {Knife}  -> Melee Combat (Knife)
--   Melee Combat | Knife  -> Melee Combat (Knife)
--   Melee Combat - Knife  -> Melee Combat (Knife)
--   Melee Combat, Knife   -> Melee Combat (Knife)
--   Melee Combat: Knife   -> Melee Combat (Knife)
--   Melee Combat / Knife  -> Melee Combat (Knife)
--   Melee Combat \ Knife  -> Melee Combat (Knife)
--   Melee Combat "Knife"  -> Melee Combat (Knife)
--   Melee Combat 'Knife'  -> Melee Combat (Knife)
function AttackEngine.normalizeSpecializationName(
	sSpeciality,
	sBaseSkill
)
	sSpeciality = normalizeWhitespace(sSpeciality);
	sBaseSkill = normalizeWhitespace(sBaseSkill);

	if sSpeciality == "" then
		return "";
	end

	local sBase;
	local sDetail;

	--
	-- Parentheses
	--

	sBase, sDetail =
		sSpeciality:match("^%s*(.-)%s*%((.-)%)%s*$");

	--
	-- Square brackets
	--

	if not sBase then
		sBase, sDetail =
			sSpeciality:match("^%s*(.-)%s*%[(.-)%]%s*$");
	end

	--
	-- Curly brackets
	--

	if not sBase then
		sBase, sDetail =
			sSpeciality:match("^%s*(.-)%s*%{(.-)%}%s*$");
	end

	--
	-- Double quotes
	--

	if not sBase then
		sBase, sDetail =
			sSpeciality:match('^%s*(.-)%s*"(.-)"%s*$');
	end

	--
	-- Single quotes
	--

	if not sBase then
		sBase, sDetail =
			sSpeciality:match("^%s*(.-)%s*'(.-)'%s*$");
	end

	--
	-- Vertical bar
	--

	if not sBase then
		sBase, sDetail =
			sSpeciality:match("^%s*(.-)%s*|%s*(.-)%s*$");
	end

	--
	-- Comma
	--

	if not sBase then
		sBase, sDetail =
			sSpeciality:match("^%s*(.-)%s*,%s*(.-)%s*$");
	end

	--
	-- Colon
	--

	if not sBase then
		sBase, sDetail =
			sSpeciality:match("^%s*(.-)%s*:%s*(.-)%s*$");
	end

	--
	-- Hyphen
	--
	-- Whitespace is required around the hyphen to avoid splitting
	-- legitimate hyphenated skill or specialization names.
	--

	if not sBase then
		sBase, sDetail =
			sSpeciality:match("^%s*(.-)%s+%-%s+(.-)%s*$");
	end

	--
	-- Forward slash
	--
	-- Whitespace is required around the slash to avoid splitting
	-- names that legitimately contain a slash.
	--

	if not sBase then
		sBase, sDetail =
			sSpeciality:match("^%s*(.-)%s+/%s+(.-)%s*$");
	end

	--
	-- Backslash
	--

	if not sBase then
		sBase, sDetail =
			sSpeciality:match("^%s*(.-)%s+\\%s+(.-)%s*$");
	end

	--
	-- If no separator was found, use the explicit base skill,
	-- if it is available.
	--

	if not sBase then
		if sBaseSkill == "" then
			return sSpeciality;
		end

		local sLowerSpeciality = sSpeciality:lower();
		local sLowerBaseSkill = sBaseSkill:lower();

		if sLowerSpeciality:sub(1, #sLowerBaseSkill) ==
				sLowerBaseSkill then
			sBase = sBaseSkill;
			sDetail = sSpeciality:sub(#sBaseSkill + 1);
		else
			sBase = sBaseSkill;
			sDetail = sSpeciality;
		end
	end

	sBase = normalizeWhitespace(sBase);
	sDetail = normalizeWhitespace(sDetail);

	-- Remove any separator characters remaining at the start
	-- of the specialization detail.
	sDetail = sDetail:gsub(
		"^[%s%-%|,:/\\]+",
		""
	);

	sDetail = normalizeWhitespace(sDetail);

	if sBase == "" then
		return sSpeciality;
	end

	if sDetail == "" then
		return sBase;
	end

	return string.format(
		"%s (%s)",
		sBase,
		sDetail
	);
end

--
-- BASE SKILL NAME
--

-- An explicit itemskill value is authoritative.
--
-- If itemskill is missing, this attempts to derive the base skill
-- from itemskillspeciality.
function AttackEngine.getBaseSkillName(
	sBaseSkill,
	sSpeciality
)
	sBaseSkill = normalizeWhitespace(sBaseSkill);
	sSpeciality = normalizeWhitespace(sSpeciality);

	if sBaseSkill ~= "" then
		return sBaseSkill;
	end

	if sSpeciality == "" then
		return "";
	end

	local sCanonical =
		AttackEngine.normalizeSpecializationName(
			sSpeciality,
			""
		);

	local sDerived =
		sCanonical:match("^%s*(.-)%s*%((.-)%)%s*$");

	if sDerived and sDerived ~= "" then
		return normalizeWhitespace(sDerived);
	end

	return sCanonical;
end

--
-- WEAPON LOOKUP
--

-- vWeapon may be:
--
--   1. An inventory database node
--   2. An inventory database path
--   3. A weapon name
function AttackEngine.findWeaponNode(rActor, vWeapon)
	if not rActor or not vWeapon then
		return nil;
	end

	-- A database node was supplied directly.
	if type(vWeapon) == "databasenode" then
		return vWeapon;
	end

	if type(vWeapon) ~= "string" then
		return nil;
	end

	-- Check whether a database path was supplied.
	local nodeWeapon = DB.findNode(vWeapon);

	if nodeWeapon then
		return nodeWeapon;
	end

	-- Otherwise, search the character inventory by name.
	local nodeActor =
		ActorManager.getCreatureNode(rActor);

	if not nodeActor then
		return nil;
	end

	local nodeInventory =
		DB.getChild(nodeActor, "inventorylist");

	if not nodeInventory then
		return nil;
	end

	local sWantedName = normalizeName(vWeapon);

	if sWantedName == "" then
		return nil;
	end

	for _,nodeItem in pairs(
		DB.getChildren(nodeInventory)
	) do
		local sItemName =
			normalizeName(
				DB.getValue(
					nodeItem,
					"name",
					""
				)
			);

		if sItemName == sWantedName then
			return nodeItem;
		end
	end

	return nil;
end

--
-- CHARACTER ATTRIBUTE LOOKUP
--

function AttackEngine.findCharacterAttributeNode(
	rActor,
	sAttributeName
)
	if not rActor then
		return nil;
	end

	local sWantedName =
		normalizeName(sAttributeName);

	if sWantedName == "" then
		return nil;
	end

	local nodeActor =
		ActorManager.getCreatureNode(rActor);

	if not nodeActor then
		return nil;
	end

	local nodeAttributes =
		DB.getChild(nodeActor, "attributes");

	if not nodeAttributes then
		return nil;
	end

	for _,nodeAttribute in pairs(
		DB.getChildren(nodeAttributes)
	) do
		local sCurrentName =
			normalizeName(
				DB.getValue(
					nodeAttribute,
					"name",
					""
				)
			);

		if sCurrentName == sWantedName then
			return nodeAttribute;
		end
	end

	return nil;
end

--
-- CHARACTER SKILL LOOKUP
--

-- Searches every skill beneath every character attribute.
--
-- Matching is case-insensitive and ignores extra whitespace.
-- It does not perform fuzzy spelling correction.
--
-- If the character skill is misspelled, this function will not
-- match it. The attack lookup will then fall back to the governing
-- attribute.
--
-- Returns:
--
--   nodeSkill
--   nodeAttribute
function AttackEngine.findCharacterSkillNode(
	rActor,
	sSkillName
)
	if not rActor then
		return nil;
	end

	local sWantedName =
		normalizeName(sSkillName);

	if sWantedName == "" then
		return nil;
	end

	local nodeActor =
		ActorManager.getCreatureNode(rActor);

	if not nodeActor then
		return nil;
	end

	local nodeAttributes =
		DB.getChild(nodeActor, "attributes");

	if not nodeAttributes then
		return nil;
	end

	for _,nodeAttribute in pairs(
		DB.getChildren(nodeAttributes)
	) do
		local nodeSkills =
			DB.getChild(nodeAttribute, "skills");

		if nodeSkills then
			for _,nodeSkill in pairs(
				DB.getChildren(nodeSkills)
			) do
				local sCurrentName =
					normalizeName(
						DB.getValue(
							nodeSkill,
							"name",
							""
						)
					);

				if sCurrentName == sWantedName then
					return nodeSkill, nodeAttribute;
				end
			end
		end
	end

	return nil;
end

--
-- CHARACTER SPECIALIZATION LOOKUP
--

-- Both the requested specialization and the character skill name
-- are converted into canonical "Base Skill (Specialization)" form
-- before comparison.
function AttackEngine.findCharacterSpecializationNode(
	rActor,
	sSpeciality,
	sBaseSkill
)
	if not rActor then
		return nil;
	end

	local sWantedName =
		normalizeName(
			AttackEngine.normalizeSpecializationName(
				sSpeciality,
				sBaseSkill
			)
		);

	if sWantedName == "" then
		return nil;
	end

	local nodeActor =
		ActorManager.getCreatureNode(rActor);

	if not nodeActor then
		return nil;
	end

	local nodeAttributes =
		DB.getChild(nodeActor, "attributes");

	if not nodeAttributes then
		return nil;
	end

	for _,nodeAttribute in pairs(
		DB.getChildren(nodeAttributes)
	) do
		local nodeSkills =
			DB.getChild(nodeAttribute, "skills");

		if nodeSkills then
			for _,nodeSkill in pairs(
				DB.getChildren(nodeSkills)
			) do
				local sCharacterSkill =
					DB.getValue(
						nodeSkill,
						"name",
						""
					);

				local sCanonicalCharacterSkill =
					normalizeName(
						AttackEngine.normalizeSpecializationName(
							sCharacterSkill,
							sBaseSkill
						)
					);

				if sCanonicalCharacterSkill == sWantedName then
					return nodeSkill, nodeAttribute;
				end
			end
		end
	end

	return nil;
end

--
-- MASTER SKILL DEFINITION LOOKUP
--

-- Searches the master skills stored in db.xml.
--
-- A master skill definition is expected to contain:
--
--   <name type="string">Melee Combat</name>
--   <attribute type="string">Dexterity</attribute>
--
-- No skill key is used.
function AttackEngine.findSkillDefinitionNode(sSkillName)
	local sWantedName =
		normalizeName(sSkillName);

	if sWantedName == "" then
		return nil;
	end

	local nodeSkillList =
		DB.findNode(
			AttackEngine.SKILL_DEFINITION_PATH
		);

	if not nodeSkillList then
		return nil;
	end

	for _,nodeSkillDefinition in pairs(
		DB.getChildren(nodeSkillList)
	) do
		local sCurrentName =
			normalizeName(
				DB.getValue(
					nodeSkillDefinition,
					"name",
					""
				)
			);

		if sCurrentName == sWantedName then
			return nodeSkillDefinition;
		end
	end

	return nil;
end

--
-- DICE NORMALIZATION
--

-- Reads a Fantasy Grounds dice field and returns a plain dice array.
--
-- Examples:
--
--   d6  -> { "d6" }
--   2d6 -> { "d6", "d6" }
--   3d6 -> { "d6", "d6", "d6" }
function AttackEngine.getDiceFromPoolNode(nodePool)
	if not nodePool then
		return {};
	end

	local vDice =
		DB.getValue(
			nodePool,
			"dice",
			{}
		);

	local aDice = {};

	if type(vDice) == "table" then
		for _,vDie in ipairs(vDice) do
			if type(vDie) == "table" then
				local sDieType =
					vDie.type or "";

				if sDieType ~= "" then
					table.insert(
						aDice,
						sDieType
					);
				end

			elseif type(vDie) == "string" then
				table.insert(
					aDice,
					vDie
				);
			end
		end

	elseif type(vDice) == "string" then
		local sDice =
			normalizeName(vDice);

		local sCount =
			sDice:match("^(%d*)d6$");

		if sCount ~= nil then
			local nCount;

			if sCount == "" then
				nCount = 1;
			else
				nCount =
					tonumber(sCount) or 0;
			end

			for _ = 1, nCount do
				table.insert(
					aDice,
					"d6"
				);
			end
		end
	end

	return aDice;
end

--
-- POOL DATA
--

function AttackEngine.getPoolData(nodePool)
	if not nodePool then
		return nil;
	end

	return {
		aDice =
			AttackEngine.getDiceFromPoolNode(
				nodePool
			),

		nModifier =
			DB.getValue(
				nodePool,
				"bonus",
				0
			),

		sName =
			DB.getValue(
				nodePool,
				"name",
				""
			),

		sNodePath =
			DB.getPath(nodePool),
	};
end

--
-- BASE ATTACK LOOKUP
--

-- Lookup order:
--
--   1. The character's matching specialization
--   2. The character's matching base skill
--   3. The base skill's governing attribute
--
-- If the character's skill or specialization is misspelled, it will
-- not match. The system will use the governing character attribute.
function AttackEngine.getBaseAttack(rActor, vWeapon)
	--
	-- Find the inventory weapon.
	--

	local nodeWeapon =
		AttackEngine.findWeaponNode(
			rActor,
			vWeapon
		);

	if not nodeWeapon then
		return nil,
			"Weapon was not found in the character inventory.";
	end

	--
	-- Read weapon data.
	--

	local sWeaponName =
		DB.getValue(
			nodeWeapon,
			"name",
			""
		);

	local sSpeciality =
		DB.getValue(
			nodeWeapon,
			"itemskillspeciality",
			""
		);

	local sBaseSkill =
		DB.getValue(
			nodeWeapon,
			"itemskill",
			""
		);

	local sAttackScale =
		AttackEngine.normalizeScale(
			DB.getValue(
				nodeWeapon,
				"itemscale",
				"Character"
			)
		);

	--
	-- Determine the base skill name.
	--

	sBaseSkill =
		AttackEngine.getBaseSkillName(
			sBaseSkill,
			sSpeciality
		);

	if sSpeciality == "" and sBaseSkill == "" then
		return nil, string.format(
			"Weapon '%s' does not define a skill or specialization.",
			sWeaponName
		);
	end

	local sCanonicalSpeciality = "";

	if sSpeciality ~= "" then
		sCanonicalSpeciality =
			AttackEngine.normalizeSpecializationName(
				sSpeciality,
				sBaseSkill
			);
	end

	local nodePool;
	local nodeAttribute;
	local nodeSkillDefinition;

	local sMatchedName = "";
	local sAttributeName = "";
	local sRatingSource = "";

	--
	-- 1. Look for the character's specialization.
	--

	if sCanonicalSpeciality ~= "" then
		nodePool, nodeAttribute =
			AttackEngine.findCharacterSpecializationNode(
				rActor,
				sCanonicalSpeciality,
				sBaseSkill
			);

		if nodePool then
			sMatchedName =
				AttackEngine.normalizeSpecializationName(
					DB.getValue(
						nodePool,
						"name",
						sCanonicalSpeciality
					),
					sBaseSkill
				);

			sRatingSource = "speciality";
		end
	end

	--
	-- 2. Look for the character's base skill.
	--

	if not nodePool and sBaseSkill ~= "" then
		nodePool, nodeAttribute =
			AttackEngine.findCharacterSkillNode(
				rActor,
				sBaseSkill
			);

		if nodePool then
			sMatchedName =
				DB.getValue(
					nodePool,
					"name",
					sBaseSkill
				);

			sRatingSource = "skill";
		end
	end

	--
	-- 3. Fall back to the governing attribute.
	--
	-- The master skill definition is looked up by its display name.
	-- No fuzzy matching and no skill key are used.
	--

	if not nodePool then
		nodeSkillDefinition =
			AttackEngine.findSkillDefinitionNode(
				sBaseSkill
			);

		if not nodeSkillDefinition then
			return nil, string.format(
				"Master skill definition '%s' was not found for weapon '%s'.",
				sBaseSkill,
				sWeaponName
			);
		end

		sAttributeName =
			DB.getValue(
				nodeSkillDefinition,
				"attribute",
				""
			);

		if sAttributeName == "" then
			return nil, string.format(
				"Master skill '%s' does not define a governing attribute.",
				sBaseSkill
			);
		end

		nodeAttribute =
			AttackEngine.findCharacterAttributeNode(
				rActor,
				sAttributeName
			);

		if not nodeAttribute then
			return nil, string.format(
				"Character does not have the '%s' attribute required by '%s'.",
				sAttributeName,
				sBaseSkill
			);
		end

		nodePool = nodeAttribute;

		sMatchedName =
			DB.getValue(
				nodeAttribute,
				"name",
				sAttributeName
			);

		sRatingSource = "attribute";
	end

	--
	-- Read the selected pool.
	--

	local rPool =
		AttackEngine.getPoolData(nodePool);

	if not rPool or #rPool.aDice == 0 then
		return nil, string.format(
			"The selected %s rating '%s' does not have a valid dice pool.",
			sRatingSource,
			sMatchedName
		);
	end

	if nodeAttribute and sAttributeName == "" then
		sAttributeName =
			DB.getValue(
				nodeAttribute,
				"name",
				""
			);
	end

	--
	-- Return structured attack data.
	--

	return {
		nodeWeapon = nodeWeapon,
		nodePool = nodePool,
		nodeAttribute = nodeAttribute,
		nodeSkillDefinition = nodeSkillDefinition,

		sWeaponNode =
			DB.getPath(nodeWeapon),

		sPoolNode =
			DB.getPath(nodePool),

		sWeaponName = sWeaponName,

		sBaseSkill = sBaseSkill,
		sSpeciality = sSpeciality,
		sCanonicalSpeciality = sCanonicalSpeciality,

		sMatchedName = sMatchedName,
		sAttributeName = sAttributeName,

		-- Possible values:
		--   speciality
		--   skill
		--   attribute
		sRatingSource = sRatingSource,

		-- Canonical attack scale:
		--   Character
		--   Vehicle
		--   Starfighter
		--   Capital
		sAttackScale = sAttackScale,

		aDice = rPool.aDice,
		nModifier = rPool.nModifier,
	};
end