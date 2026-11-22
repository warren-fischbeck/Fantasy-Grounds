--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

-----------------------
--  EXISTENCE FUNCTIONS
-----------------------

function isEmpty(s)
	return ((s or "") == "");
end
function isNotEmpty(s)
	return not StringManager.isEmpty(s);
end

function isBlank(s)
	return ((StringManager.trim(s) or "") == "");
end
function isNotBlank(s)
	return not StringManager.isBlank(s)
end

function startsWith(s, vCheck)
	if type(vCheck) == "table" then
		for _,v in ipairs(vCheck) do
			if StringManager.startsWith(s, v) then
				return true;
			end
		end
		return false;
	end
	if not s or not vCheck then
		return false;
	end
	return (s:find(vCheck, 1, true) == 1);
end
function endsWith(s, vCheck)
	if type(vCheck) == "table" then
		for _,v in ipairs(vCheck) do
			if StringManager.endsWith(s, v) then
				return true;
			end
		end
		return false;
	end
	if not s or not vCheck then
		return false;
	end
	if vCheck == "" then
		return true;
	end
	return (s:sub(-#vCheck) == vCheck);
end

function isWord(sWord, vTarget)
	if not sWord then
		return false;
	end
	if type(vTarget) == "string" then
		if sWord ~= vTarget then
			return false;
		end
	elseif type(vTarget) == "table" then
		if not StringManager.contains(vTarget, sWord) then
			return false;
		end
	else
		return false;
	end
	return true;
end
function isPhrase(aWords, nIndex, aPhrase)
	if not aPhrase or not aWords then
		return false;
	end
	if #aPhrase == 0 then
		return false;
	end

	local i = nIndex - 1;
	for j = 1, #aPhrase do
		if not StringManager.isWord(aWords[i+j], aPhrase[j]) then
			return false;
		end
	end
	return true;
end
function isNumberString(s)
	if s then
		if s:match("^[%+%-]?%d+$") then
			return true;
		elseif s:match("^[%+%-]?%d+%.%d*$") then
			return true;
		elseif s:match("^[%+%-]?%.%d+$") then
			return true;
		end
	end
	return false;
end

-----------------------
-- SET FUNCTIONS
-----------------------

function append(s, vAppend, sSeparator)
	if type(vAppend) == "table" then
		return string.format("%s%s%s", StringManager.trim(s), (sSeparator or ","), table.concat(vAppend, (sSeparator or ",")));
	end
	if StringManager.isBlank(vAppend) then
		return s or "";
	end
	if StringManager.isBlank(s) then
		return vAppend or "";
	end
	return string.format("%s%s%s", StringManager.trim(s), (sSeparator or ","), StringManager.trim(vAppend));
end
function appendUnique(s, vAppend, sSeparator)
	if type(vAppend) == "table" then
		return SetManager.concat(SetManager.union(SetManager.new(StringManager.split(s, (sSeparator or ","), true)), vAppend), (sSeparator or ","));
	end
	if StringManager.isBlank(vAppend) then
		return s or "";
	end
	return SetManager.concat(SetManager.union(SetManager.new(StringManager.split(s, (sSeparator or ","), true)), vAppend), (sSeparator or ","));
end
function appendLine(s, vAppend)
	return StringManager.append(s, vAppend, "\r");
end

function containsItem(s, vFind, sSeparator)
	return SetManager.overlaps(SetManager.new(StringManager.split(s, (sSeparator or ","), true)), vFind);
end
function removeItem(s, vRemove, sSeparator)
	if type(vRemove) == "table" then
		return SetManager.concat(SetManager.difference(SetManager.new(StringManager.split(s, (sSeparator or ","), true)), vRemove), (sSeparator or ","));
	end
	if StringManager.isBlank(vRemove) then
		return s or "";
	end
	return SetManager.concat(SetManager.difference(SetManager.new(StringManager.split(s, (sSeparator or ","), true)), vRemove), (sSeparator or ","));
end
function replaceItem(s, vFind, sReplace, sSeparator)
	if type(vFind) == "table" then
		local set = SetManager.new(StringManager.split(s, (sSeparator or ","), true));
		if not SetManager.overlaps(set, vFind) then
			return s;
		end
		return SetManager.concat(SetManager.union(SetManager.difference(set, vFind), sReplace), (sSeparator or ","));
	end
	if StringManager.isBlank(vFind) then
		return s or "";
	end
	if StringManager.isBlank(sReplace) then
		return StringManager.removeItem(s, vFind, sSeparator);
	end
	return SetManager.concat(SetManager.union(SetManager.difference(SetManager.new(StringManager.split(s, (sSeparator or ","), true)), vFind), sReplace), (sSeparator or ","));
end

function contains(tList, vItem, bIgnoreCase)
	if not tList or not vItem then
		return false;
	end
	if type(vItem) == "table" then
		for _, sCheckItem in ipairs(vItem) do
			if StringManager.contains(tList, sCheckItem, bIgnoreCase) then
				return true;
			end
		end
	elseif type(vItem) == "string" then
		for _, sListItem in ipairs(tList) do
			if bIgnoreCase then
				if sListItem:lower() == vItem:lower() then
					return true;
				end
			else
				if sListItem == vItem then
					return true;
				end
			end
		end
	end
	return false;
end

function autoComplete(tList, sItem, bIgnoreCase)
	if not tList or not sItem then
		return nil;
	end
	if bIgnoreCase then
		for i = 1, #tList do
			if sItem:lower() == tList[i]:sub(1, #sItem):lower() then
				return tList[i]:sub(#sItem + 1);
			end
		end
	else
		for i = 1, #tList do
			if sItem == tList[i]:sub(1, #sItem) then
				return tList[i]:sub(#sItem + 1);
			end
		end
	end

	return nil;
end

-----------------------
-- MODIFY FUNCTIONS
-----------------------

-- Strips parenthesized text and extra spaces
function sanitize(s)
	if not s then
		return nil;
	end
	return StringManager.trim(s:gsub("%([^%)]*%)", ""):gsub("%s%s+", " "));
end

-- Strips punctuation, parentheses, brackets, spaces; then converts to lower case
function simplify(s)
	if not s then
		return nil;
	end
	return s:gsub("[%(%)%.%+%-%*%?,:'’/–]", ""):gsub("%s", ""):lower();
end

-- Strips extra spaces
function strip(s)
	if not s then
		return nil;
	end
	return StringManager.trim(s:gsub("%s+", " "));
end

-- Capitalize first letter in string
function capitalize(s)
	if not s then
		return nil;
	end
	return (s:gsub("^%l", string.upper));
end

-- Capitalize every word in string
function capitalizeAll(s)
	if not s then
		return nil;
	end
	return (s:gsub("^%l", string.upper):gsub("%s%l", string.upper));
end

-- Capitalize every word in string
function titleCase(s)
	if not s then
		return nil;
	end
	function titleCaseInternal(sFirst, sRemaining)
		return sFirst:upper() .. sRemaining:lower();
	end
	return (s:gsub("(%a)([%w_']*)", StringManager.titleCaseInternal));
end

function insertBefore(s, sPattern, sInsert)
	if ((sPattern or "") == "") or ((sInsert or "") == "") then
		return s;
	end
	if (s or "") == "" then
		return sInsert;
	end
	local nFind = s:find(sPattern);
	if nFind then
		return s:sub(1, nFind) .. sInsert .. s:sub(nFind);
	end
	return s .. sInsert;
end

function multireplace(s, aPatterns, sReplace)
	if not s or not sReplace then
		return s;
	end
	if type(aPatterns) == "string" then
		s = s:gsub(aPatterns, sReplace);
	elseif type(aPatterns) == "table" then
		for _,v in pairs(aPatterns) do
			s = s:gsub(v, sReplace);
		end
	end

	return s;
end

function addTrailing(s, c)
	if not s then
		return s;
	end
	if s:len() > 0 and s[-1] ~= c then
		s = s .. c;
	end
	return s;
end

function extract(s, nStart, nEnd)
	if not s or not nStart or not nEnd then
		return "", s;
	end

	local sExtract = s:sub(nStart, nEnd);
	local sRemainder;
	if nStart == 1 then
		sRemainder = s:sub(nEnd + 1);
	else
		sRemainder = s:sub(1, nStart - 1) .. s:sub(nEnd + 1);
	end

	return sExtract, sRemainder;
end

function extractPattern(s, sPattern)
	if not s or not sPattern then
		return "", s;
	end

	local nStart, nEnd = s:find(sPattern);
	if not nStart then
		return "", s;
	end

	local sExtract = s:sub(nStart, nEnd);
	local sRemainder;
	if nStart == 1 then
		sRemainder = s:sub(nEnd + 1);
	else
		sRemainder = s:sub(1, nStart - 1) .. s:sub(nEnd + 1);
	end

	return sExtract, sRemainder;
end

function combine(sSeparator, ...)
	local aCombined = {};

	for i = 1, select("#", ...) do
		local v = select(i, ...);
		if type(v) == "string" and v:len() > 0 then
			table.insert(aCombined, v);
		end
	end

	return table.concat(aCombined, sSeparator);
end

function ordinalize(n)
	if type(n) ~= "number" then
		return n;
	end
	local nHundredMod = (n % 100);
	if (nHundredMod > 10) and (nHundredMod < 20) then
		return tostring(n) .. Interface.getString("numbersuffix_default");
	end
	return tostring(n) .. Interface.getString("numbersuffix" .. (nHundredMod % 10));
end

function encodeAsPattern(s)
	if not s then
		return s;
	end
    return s:gsub("([%^%$%(%)%[%]%.%%%+%-%*%?])", "%%%1")
end


-----------------------
-- TRIM FUNCTIONS
-----------------------

-- Strips any spacing characters from the beginning and end of a string.
--
-- The function returns the following parameters:
--   1. The trimmed string
--   2. The starting position of the trimmed string within the original string
--   3. The ending position of the trimmed string within the original string
--

function trim(s)
	if not s then
		return nil;
	end
	-- Include parentheses on return value to force only single return value, since gsub returns 2 normally
	return (s:gsub("^%s+", ""):gsub("%s+$", ""));
end
function trimfind(s)
	if not s then
		return nil;
	end
	local _, i1 = s:find("^%s*");
	if not i1 then
		i1 = 0;
	end
	local i2 = s:find("%s*$");
	if not i2 then
		i2 = #s + 1;
	end
	return i1 + 1, i2 - 1;
end

-----------------------
-- PARSE FUNCTIONS
-----------------------

function parseWords(s, extra_delimiters)
	local delim = "^%w%+%-'’";
	if extra_delimiters then
		delim = delim .. extra_delimiters;
	end
	return StringManager.split(s, delim, true);
end
function splitWords(s, extra_delimiters)
	local delim = "^%w%+%-'’";
	if extra_delimiters then
		delim = delim .. extra_delimiters;
	end
	return StringManager.splitByPattern(s, "[" .. delim .. "]+", true);
end
function splitTokens(s, extra_delimiters)
	local delim = "^%S";
	if extra_delimiters then
		delim = delim .. extra_delimiters;
	end
	return StringManager.splitByPattern(s, "[" .. delim .. "]+", true);
end
function splitLines(s)
	return StringManager.splitByPattern(s, "\n", true);
end

-----------------------
-- SPLIT FUNCTIONS
-----------------------

-- The source string is divided into substrings as defined by the delimiters parameter.
-- Each resulting string is stored in a table along with the start and end position of
-- the result string within the original string.  The result tables are combined into
-- a table which is then returned.
--
-- NOTE: Set trimspace flag to trim any spaces that trail delimiters before next result
-- string
--

function split(sToSplit, sDelimiters, bTrimSpace)
	if not sToSplit or not sDelimiters then
		return {}, {};
	end

	-- SETUP
	local aStrings = {};
	local aStringStats = {};

	-- BUILD DELIMITER PATTERN
	local sDelimiterPattern = "[" .. sDelimiters .. "]+";
	if bTrimSpace then
		sDelimiterPattern = sDelimiterPattern .. "%s*";
	end

	-- DEAL WITH LEADING/TRAILING SPACES
	local nStringStart = 1;
	local nStringEnd = #sToSplit;
	if bTrimSpace then
		nStringStart, nStringEnd = StringManager.trimfind(sToSplit);
	end

	-- SPLIT THE STRING, BASED ON THE DELIMITERS
	local sNextString;
	local nIndex = nStringStart;
	local nDelimiterStart, nDelimiterEnd = sToSplit:find(sDelimiterPattern, nIndex);
	while nDelimiterStart do
		sNextString = sToSplit:sub(nIndex, nDelimiterStart - 1);
		if sNextString ~= "" then
			table.insert(aStrings, sNextString);
			table.insert(aStringStats, {startpos = nIndex, endpos = nDelimiterStart});
		end

		nIndex = nDelimiterEnd + 1;
		nDelimiterStart, nDelimiterEnd = sToSplit:find(sDelimiterPattern, nIndex);
	end
	sNextString = sToSplit:sub(nIndex, nStringEnd);
	if sNextString ~= "" then
		table.insert(aStrings, sNextString);
		table.insert(aStringStats, {startpos = nIndex, endpos = nStringEnd + 1});
	end

	-- RESULTS
	return aStrings, aStringStats;
end
function splitByPattern(sToSplit, sPattern, bTrimSpace, bPreserveEmpty)
	if not sToSplit or not sPattern then
		return {};
	end

	local tResult = {};

	local sNonGreedyPatternMatch = "(.-)" .. sPattern;
	local nIndex = 1;
	local nPatternStart, nPatternEnd, s = sToSplit:find(sNonGreedyPatternMatch, nIndex);
	while nPatternStart do
		if bTrimSpace then
			s = StringManager.trim(s);
		end
		if bPreserveEmpty or (s ~= "") then
			table.insert(tResult, s);
		end
		nIndex = nPatternEnd + 1;
		nPatternStart, nPatternEnd, s = sToSplit:find(sNonGreedyPatternMatch, nIndex);
	end
	local sFinal = sToSplit:sub(nIndex);
	if bTrimSpace then
		sFinal = StringManager.trim(sFinal);
	end
	if sFinal ~= "" then
		table.insert(tResult, sFinal);
	end

	return tResult;
end

-----------------------
--  CONVERSION FUNCTIONS
-----------------------

function convertStringToDice(s, bClean)
	return DiceManager.convertStringToDice(s, bClean);
end
function convertDiceToString(aDice, nMod, bSign)
	return DiceManager.convertDiceToString(aDice, nMod, bSign);
end

function convertStringToPoint(s)
	if (s or "") == "" then
		return nil;
	end

	local tSplit = StringManager.split(s, ",");
	if #tSplit ~= 2 then
		return nil;
	end

	local x = tonumber(tSplit[1]) or 0;
	local y = tonumber(tSplit[2]) or 0;
	return { x = x, y = y};
end
function convertPointToString(tPoint)
	return string.format("%d,%d", tPoint.x, tPoint.y);
end

-- Converts number to A-Z
function convertNumberToAlpha(n)
	if not n then
		return "0";
	end
	if (n < 1) or (n > 26) then
		return tostring(n);
	end

	return string.char(string.byte("A") + (n - 1));
end

function convertNumberToOrdinal(n)
	if n <= 0 then
		return tostring(n) or "";
	end
	if n == 1 then
		return "1st";
	elseif n == 2 then
		return "2nd";
	elseif n == 3 then
		return "3rd";
	end
	return (tostring(n) or "") .. "th";
end

-----------------------
--  DICE FUNCTIONS
-----------------------

function isDiceString(s)
	return DiceManager.isDiceString(s);
end
function isDiceMathString(s)
	return DiceManager.isDiceMathString(s);
end

function evalDiceString(s, _, bMaxDice)
	return DiceManager.evalDiceString(s, { bMax = bMaxDice });
end
function evalDice(tDice, nMod, bMax)
	return DiceManager.evalDice(tDice, nMod, { bMax = bMax });
end
function evalDiceMathExpression(s, bMaxDice)
	return DiceManager.evalDiceMathExpression(s, { bMax = bMaxDice });
end
