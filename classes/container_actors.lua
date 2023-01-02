-- actor container file

	local _detalhes = 		_G._detalhes
	local Details = _G.Details
	local DF = _G.DetailsFramework
	local _
	local addonName, Details222 = ...

	local bIsDragonflight = DetailsFramework.IsDragonflight()

	local CONST_CLIENT_LANGUAGE = DF.ClientLanguage

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--local pointers

	local _UnitClass = UnitClass --api local
	local _IsInInstance = IsInInstance --api local
	local UnitGUID = UnitGUID --api local
	local strsplit = strsplit --api local
	
	local setmetatable = setmetatable --lua local
	local _getmetatable = getmetatable --lua local
	local _bit_band = bit.band --lua local
	local _table_sort = table.sort --lua local
	local ipairs = ipairs --lua local
	local pairs = pairs --lua local
	
	local AddUnique = DetailsFramework.table.addunique --framework
	local UnitGroupRolesAssigned = DetailsFramework.UnitGroupRolesAssigned --framework

	local GetNumDeclensionSets = _G.GetNumDeclensionSets
	local DeclineName = _G.DeclineName

	local pet_tooltip_frame = _G.DetailsPetOwnerFinder

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--constants

	local actorContainer =	_detalhes.container_combatentes

	local alvo_da_habilidade = 	_detalhes.alvo_da_habilidade
	local atributo_damage =		_detalhes.atributo_damage
	local atributo_heal =			_detalhes.atributo_heal
	local atributo_energy =		_detalhes.atributo_energy
	local atributo_misc =			_detalhes.atributo_misc

	local container_playernpc = 	_detalhes.container_type.CONTAINER_PLAYERNPC
	local container_damage =		_detalhes.container_type.CONTAINER_DAMAGE_CLASS
	local container_heal = 		_detalhes.container_type.CONTAINER_HEAL_CLASS
	local container_heal_target = 	_detalhes.container_type.CONTAINER_HEALTARGET_CLASS
	local container_friendlyfire =	_detalhes.container_type.CONTAINER_FRIENDLYFIRE
	local container_damage_target = _detalhes.container_type.CONTAINER_DAMAGETARGET_CLASS
	local container_energy = 		_detalhes.container_type.CONTAINER_ENERGY_CLASS
	local container_energy_target =	_detalhes.container_type.CONTAINER_ENERGYTARGET_CLASS
	local container_misc = 		_detalhes.container_type.CONTAINER_MISC_CLASS
	local container_misc_target = 	_detalhes.container_type.CONTAINER_MISCTARGET_CLASS
	local container_enemydebufftarget_target = _detalhes.container_type.CONTAINER_ENEMYDEBUFFTARGET_CLASS

	local container_pets = {}
	
	--flags
	local REACTION_HOSTILE	=	0x00000040
	local IS_GROUP_OBJECT 	= 	0x00000007
	local REACTION_FRIENDLY	=	0x00000010 
	local OBJECT_TYPE_MASK =	0x0000FC00
	local OBJECT_TYPE_OBJECT =	0x00004000
	local OBJECT_TYPE_PETGUARDIAN =	0x00003000
	local OBJECT_TYPE_GUARDIAN =	0x00002000
	local OBJECT_TYPE_PET =		0x00001000
	local OBJECT_TYPE_NPC =		0x00000800
	local OBJECT_TYPE_PLAYER =	0x00000400
	local OBJECT_TYPE_PETS = 	OBJECT_TYPE_PET + OBJECT_TYPE_GUARDIAN

	local debugPetname = false

	local SPELLID_SANGUINE_HEAL = 226510
	local sanguineActorName = GetSpellInfo(SPELLID_SANGUINE_HEAL)

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--api functions

--[=[
["AzeriteItemPowerDescription"] = 9,
["SellPrice"] = 11,
["CurrencyTotal"] = 14,
["GemSocket"] = 3,
["QuestObjective"] = 8,
["UnitName"] = 2,
["SpellName"] = 13,
["ItemEnchantmentPermanent"] = 15,
["RuneforgeLegendaryPowerDescription"] = 10,
["QuestPlayer"] = 18,
["Blank"] = 1,
["UnitOwner"] = 16,
["LearnableSpell"] = 6,
["ProfessionCraftingQuality"] = 12,
["UnitThreat"] = 7,
["QuestTitle"] = 17,
["ItemBinding"] = 20,
["NestedBlock"] = 19,
["AzeriteEssencePower"] = 5,
["AzeriteEssenceSlot"] = 4,
["None"] = 0,
--]=]

---attempt to get the owner of rogue's Akaari's Soul from Secrect Technique
---@param petGUID string
---@return string|any
---@return string|any
---@return number|any
function Details222.Pets.AkaarisSoulOwner(petGUID)
	local tooltipData = C_TooltipInfo.GetHyperlink("unit:" .. petGUID)
	local args = tooltipData.args

	local playerGUID
	--iteragfe among args and find into the value field == guid and it must have guidVal
	for i = 1, #args do
		local arg = args[i]
		if (arg.field == "guid") then
			playerGUID = arg.guidVal
			break
		end
	end

	if (playerGUID) then
		local actorObject = Details:GetActorFromCache(playerGUID) --quick cache only exists during conbat
		if (actorObject) then
			return actorObject.nome, playerGUID, actorObject.flag_original
		end
		local guidCache = Details:GetParserPlayerCache() --cahe exists until the next combat starts
		local ownerName = guidCache[playerGUID]
		if (ownerName) then
			return ownerName, playerGUID, 0x514
		end
	end
end

---attempt to the owner of a pet using tooltip scan, if the owner isn't found, return nil
---@param petGUID string
---@param petName string
---@return string|nil ownerName
---@return string|nil ownerGUID
---@return integer|nil ownerFlags
	function Details222.Pets.GetPetOwner(petGUID, petName)
		pet_tooltip_frame:SetOwner(WorldFrame, "ANCHOR_NONE")
		pet_tooltip_frame:SetHyperlink(("unit:" .. petGUID) or "")

		--C_TooltipInfo.GetHyperlink 

		if (bIsDragonflight) then
			local tooltipData = pet_tooltip_frame:GetTooltipData() --is pet tooltip reliable with the new tooltips changes?
			if (tooltipData) then

				local tooltipLines = tooltipData.lines
				for lineIndex = 1, #tooltipLines do
					local thisLine = tooltipLines[lineIndex]
					--get the type of information this line is showing
					local lineType = thisLine.type --type 0 = 'friendly' type 2 = 'name' type 16 = controller guid

					--parse the different types of information
					if (lineType == 2) then --unit name
						if (thisLine.leftText ~= petName) then
							--tooltip isn't showing our pet
							return
						end

					elseif (lineType == 16) then --controller guid
						--assuming the unit name always comes before the controller guid
						local GUID = thisLine.guid
						--very fast way to get an actorObject, this cache only lives while in combat
						local actorObject = Details:GetActorFromCache(GUID)
						if (actorObject) then
							--Details:Msg("(debug) pet found (1)", petName, "owner:", actorObject.nome)
							return actorObject.nome, GUID, actorObject.flag_original
						else
							--return the actor name for a guid, this cache lives for current combat until next segment
							local guidCache = Details:GetParserPlayerCache()
							local ownerName = guidCache[GUID]
							if (ownerName) then
								--Details:Msg("(debug) pet found (2)", petName, "owner:", ownerName)
								return ownerName, GUID, 0x514
							end
						end
					end
				end

				--[=[
				if (tooltipData.lines[1].leftText == petName) then --should rely on the first line carrying the pet name?
					for i = 2, #tooltipData.lines do
						local tooltipLine = tooltipData.lines[i]
						local args = tooltipLine.args
						if (args) then
							if (args[4] and args[4].field == "guid") then
								local ownerGUID = args[4].guidVal
								local guidCache = Details:GetParserPlayerCache()
								local ownerName = guidCache[ownerGUID]
								if (ownerName) then
									return ownerName, ownerGUID, 0x514
								end
							end
						end
					end
				end
				--]=]
			end
		end

		local actorNameString = _G["DetailsPetOwnerFinderTextLeft1"]
		local ownerName, ownerGUID, ownerFlags

		if (actorNameString) then
			local actorName = actorNameString:GetText()
			if (actorName and type(actorName) == "string") then
				local isInRaid = _detalhes.tabela_vigente.raid_roster[actorName]
				if (isInRaid) then
					ownerGUID = UnitGUID(actorName)
					ownerName = actorName
					ownerFlags = 0x514
				else
					for playerName in actorName:gmatch("([^%s]+)") do
						playerName = playerName:gsub(",", "")
						local playerIsOnRaidCache = _detalhes.tabela_vigente.raid_roster[playerName]
						if (playerIsOnRaidCache) then
							ownerGUID = UnitGUID(playerName)
							ownerName = playerName
							ownerFlags = 0x514
							break
						end
					end
				end
			end
		end

		if (ownerGUID) then
			return ownerName, ownerGUID, ownerFlags
		end
	end

	---return the actor object for a given actor name
	---@param actorName string
	---@return table|nil
	function actorContainer:GetActor(actorName)
		local index = self._NameIndexTable [actorName]
		if (index) then
			return self._ActorTable [index]
		end
	end

	---return an actor name which used the spell passed 'spellId'
	---@param spellId number
	---@return string|nil
	function actorContainer:GetSpellSource(spellId)
		local t = self._ActorTable
		for i = 1, #t do
			if (t[i].spells._ActorTable[spellId]) then
				return t[i].nome
			end
		end
	end

	---return the value stored in the 'key' for an actor, the key can be any value stored in the actor table such like 'total', 'damage_taken', 'heal', 'interrupt', etc
	---@param actorName string
	---@param key string
	---@return number
	function actorContainer:GetAmount(actorName, key)
		key = key or "total"
		local index = self._NameIndexTable[actorName]
		if (index) then
			return self._ActorTable[index][key] or 0
		else
			return 0
		end
	end

	---return the total value stored in the 'key' for all actors, the key can be any value stored in the actor table such like 'total', 'damage_taken', 'heal', 'interrupt', etc
	---@param key string
	---@return number
	function actorContainer:GetTotal(key)
		local total = 0
		key = key or "total"
		for _, actor in ipairs(self._ActorTable) do
			total = total + (actor[key] or 0)
		end
		return total
	end

	function actorContainer:GetTotalOnRaid(key, combat)
		local total = 0
		key = key or "total"
		local roster = combat.raid_roster
		for _, actor in ipairs(self._ActorTable) do
			if (roster [actor.nome]) then
				total = total + (actor[key] or 0)
			end
		end
		return total
	end

	---return an ipairs iterator for all actors stored in this Container
	---usage: for index, actorObject in container:ListActors() do
	---@return function
	function actorContainer:ListActors()
		return ipairs(self._ActorTable)
	end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--internals

	---create a new actor container, can be a damage container, heal container, enemy container or utility container
	---actors can be added by using newContainer.GetOrCreateActor
	---actors can be retrieved using the same function above
	---@param containerType number
	---@param combatObject table
	---@param combatId number
	---@return table
	function actorContainer:NovoContainer(containerType, combatObject, combatId)
		local newContainer = {
			funcao_de_criacao = actorContainer:FuncaoDeCriacao(containerType),
			tipo = containerType,
			combatId = combatId,
			_ActorTable = {},
			_NameIndexTable = {}
		}

		setmetatable(newContainer, actorContainer)
		return newContainer
	end

	--try to get the actor class from name
	local function get_actor_class (novo_objeto, nome, flag, serial)
		--get spec
		if (_detalhes.track_specs) then
			local have_cached = _detalhes.cached_specs [serial]
			if (have_cached) then
				novo_objeto:SetSpecId(have_cached)
				--check is didn't changed the spec:
				if (_detalhes.streamer_config.quick_detection) then
					--validate the spec more times if on quick detection
					_detalhes:ScheduleTimer("ReGuessSpec", 2, {novo_objeto})
					_detalhes:ScheduleTimer("ReGuessSpec", 4, {novo_objeto})
					_detalhes:ScheduleTimer("ReGuessSpec", 6, {novo_objeto})
				end
				_detalhes:ScheduleTimer("ReGuessSpec", 15, {novo_objeto})
				--print(nome, "spec em cache:", have_cached)
			else
				if (_detalhes.streamer_config.quick_detection) then
					--shoot detection early if in quick detection
					_detalhes:ScheduleTimer("GuessSpec", 1, {novo_objeto, nil, 1})
				else
					_detalhes:ScheduleTimer("GuessSpec", 3, {novo_objeto, nil, 1})
				end
			end
		end

		local _, engClass = _UnitClass(nome or "")

		if (engClass) then
			novo_objeto.classe = engClass
			return
		else
			if (flag) then
				--conferir se o jogador � um player
				if (_bit_band (flag, OBJECT_TYPE_PLAYER) ~= 0) then
					novo_objeto.classe = "UNGROUPPLAYER"
					return
				elseif (_bit_band (flag, OBJECT_TYPE_PETGUARDIAN) ~= 0) then
					novo_objeto.classe = "PET"
					return
				end
			end

			novo_objeto.classe = "UNKNOW"
			return true
		end
	end

	--check if the nickname fit some minimal rules to be presented to other players
	local checkValidNickname = function(nickname, playerName)
		if (nickname and type(nickname) == "string") then
			if (nickname == "") then
				return playerName

			elseif (nickname:find(" ")) then
				return playerName

			--elseif(#nickname > 14) then --cannot check for size as other alphabets uses 2 or 4 bytes to represent letters
			--	return playerName
			end
		else
			return playerName
		end

		--remove scapes
		--nickname = nickname:gsub("|","") --a bug report told about covenant icons plugin being broke, this like is probably the culprit
		return nickname
	end

	--read the actor flag
	local read_actor_flag = function(actorObject, dono_do_pet, serial, flag, nome, container_type)

		if (flag) then
			--this is player actor
			if (_bit_band (flag, OBJECT_TYPE_PLAYER) ~= 0) then
				if (not _detalhes.ignore_nicktag) then
					actorObject.displayName = checkValidNickname(Details:GetNickname(nome, false, true), nome) --defaults to player name
					if (_detalhes.remove_realm_from_name) then
						actorObject.displayName = actorObject.displayName:gsub(("%-.*"), "")
					end
				end

				if (not actorObject.displayName) then
					if (_detalhes.remove_realm_from_name) then
						actorObject.displayName = nome:gsub(("%-.*"), "")
					else
						actorObject.displayName = nome
					end
				end

				if (_detalhes.all_players_are_group or _detalhes.immersion_enabled) then
					actorObject.grupo = true
				end

				--special spells to add into the group view
				local spellId = Details.SpecialSpellActorsName[actorObject.nome]
				if (spellId) then
					actorObject.grupo = true

					if (Details.KyrianWeaponSpellIds[spellId]) then
						actorObject.spellicon = GetSpellTexture(Details.KyrianWeaponActorSpellId)
						actorObject.nome = Details.KyrianWeaponActorName
						actorObject.displayName = Details.KyrianWeaponActorName
						actorObject.customColor = Details.KyrianWeaponColor
						nome = Details.KyrianWeaponActorName

					elseif (Details.GrimrailDepotCannonWeaponSpellIds[spellId]) then
						actorObject.spellicon = GetSpellTexture(Details.GrimrailDepotCannonWeaponActorSpellId)
						actorObject.nome = Details.GrimrailDepotCannonWeaponActorName
						actorObject.displayName = Details.GrimrailDepotCannonWeaponActorName
						actorObject.customColor = Details.GrimrailDepotCannonWeaponColor
						nome = Details.GrimrailDepotCannonWeaponActorName

					else
						actorObject.spellicon = GetSpellTexture(spellId)
					end
				end

				if ((_bit_band (flag, IS_GROUP_OBJECT) ~= 0 and actorObject.classe ~= "UNKNOW" and actorObject.classe ~= "UNGROUPPLAYER") or _detalhes:IsInCache(serial)) then
					actorObject.grupo = true

					if (_detalhes:IsATank(serial)) then
						actorObject.isTank = true
					end
				else
					if (_detalhes.pvp_as_group and (_detalhes.tabela_vigente and _detalhes.tabela_vigente.is_pvp) and _detalhes.is_in_battleground) then
						actorObject.grupo = true
					end
				end

				--pvp duel
				if (_detalhes.duel_candidates [serial]) then
					--check if is recent
					if (_detalhes.duel_candidates [serial]+20 > GetTime()) then
						actorObject.grupo = true
						actorObject.enemy = true
					end
				end

				if (_detalhes.is_in_arena) then
					--local my_team_color = GetBattlefieldArenaFaction and GetBattlefieldArenaFaction() or 0

					--my team
					if (actorObject.grupo) then
						actorObject.arena_ally = true
						actorObject.arena_team = 0 -- former my_team_color | forcing the player team to always be the same color

					--enemy team
					else
						actorObject.enemy = true
						actorObject.arena_enemy = true
						actorObject.arena_team = 1 -- former my_team_color

						Details:GuessArenaEnemyUnitId(nome)
					end

					local arena_props = _detalhes.arena_table [nome]

					if (arena_props) then
						actorObject.role = arena_props.role

						if (arena_props.role == "NONE") then
							local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(nome)
							if (role and role ~= "NONE") then
								actorObject.role = role
							end
						end
					else
						local oponentes = GetNumArenaOpponentSpecs and GetNumArenaOpponentSpecs() or 5
						local found = false
						for i = 1, oponentes do
							local name = GetUnitName("arena" .. i, true)
							if (name == nome) then
								local spec = GetArenaOpponentSpec and GetArenaOpponentSpec (i)
								if (spec) then
									local id, name, description, icon, role, class = DetailsFramework.GetSpecializationInfoByID (spec) --thanks pas06
									actorObject.role = role
									actorObject.classe = class
									actorObject.enemy = true
									actorObject.arena_enemy = true
									found = true
								end
							end
						end
						
						local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(nome)
						if (role and role ~= "NONE") then
							actorObject.role = role
							found = true
						end
						
						if (not found and nome == _detalhes.playername) then
							local role = UnitGroupRolesAssigned("player")
							if (role and role ~= "NONE") then
								actorObject.role = role
							end
						end
						
					end
				
					actorObject.grupo = true
				end

				--player custom bar color
				--at this position in the code, the color will replace colors from arena matches
				if (Details.use_self_color) then
					if (nome == _detalhes.playername) then
						actorObject.customColor = Details.class_colors.SELF
					end
				end
			
			--� um pet
			elseif (dono_do_pet) then
				actorObject.owner = dono_do_pet
				actorObject.ownerName = dono_do_pet.nome
				
				if (_IsInInstance() and _detalhes.remove_realm_from_name) then
					actorObject.displayName = nome:gsub(("%-.*"), ">")
				else
					actorObject.displayName = nome
				end
				
				--local pet_npc_template = _detalhes:GetNpcIdFromGuid (serial)
				--if (pet_npc_template == 86933) then --viviane
				--	actorObject.grupo = true
				--end
				
			else
				--anything else that isn't a player or a pet
				actorObject.displayName = nome
				
				--[=[
				--Chromie - From 'The Deaths of Chromie'
				if (serial and type(serial) == "string") then
					if (serial:match ("^Creature%-0%-%d+%-%d+%-%d+%-122663%-%w+$")) then
						actorObject.grupo = true
					end
				end
				--]=]
			end
			
			--check if is hostile
			if (_bit_band (flag, REACTION_HOSTILE) ~= 0) then 
			
				if (_bit_band (flag, OBJECT_TYPE_PLAYER) == 0) then
					--is hostile and isn't a player
					
					if (_bit_band (flag, OBJECT_TYPE_PETGUARDIAN) == 0) then
						--isn't a pet or guardian
						actorObject.monster = true
					end
					
					if (serial and type(serial) == "string") then
						local npcID = _detalhes:GetNpcIdFromGuid (serial)
						if (npcID and not _detalhes.npcid_pool [npcID] and type(npcID) == "number") then
							_detalhes.npcid_pool [npcID] = nome
						end
					end
					
				end

			end
		end

	end

	local petBlackList = {}
	local pet_text_object = _G ["DetailsPetOwnerFinderTextLeft2"] --not in use
	local follower_text_object = _G ["DetailsPetOwnerFinderTextLeft3"] --not in use

	local petOwnerFound = function(ownerName, petGUID, petName, petFlags, self, ownerGUID)
		local ownerGuid = ownerGUID or UnitGUID(ownerName)
		if (ownerGuid) then
			_detalhes.tabela_pets:Adicionar(petGUID, petName, petFlags, ownerGuid, ownerName, 0x00000417)
			local petNameWithOwner, ownerName, ownerGUID, ownerFlags = _detalhes.tabela_pets:PegaDono(petGUID, petName, petFlags)

			local petOwnerActorObject

			if (petNameWithOwner and ownerName) then
				petName = petNameWithOwner
				petOwnerActorObject = self:PegarCombatente(ownerGUID, ownerName, ownerFlags, true)
			end

			return petName, petOwnerActorObject
		end
	end

	--check pet owner name with correct declension for ruRU locale (from user 'denis-kam' on github)
	local find_name_declension = function(petTooltip, playerName)
		--2 - male, 3 - female
		for gender = 3, 2, -1 do
			for declensionSet = 1, GetNumDeclensionSets(playerName, gender) do
				--check genitive case of player name
				local genitive = DeclineName(playerName, gender, declensionSet)
				if petTooltip:find(genitive) then
					--print("found genitive: ", gender, declensionSet, playerName, petTooltip:find(genitive))
					return true
				end
			end
		end
		return false
	end

	local find_pet_owner = function(petGUID, petName, petFlags, self)
		if (not _detalhes.tabela_vigente) then
			return
		end

		if (bIsDragonflight) then
			pet_tooltip_frame:SetOwner(WorldFrame, "ANCHOR_NONE")
			pet_tooltip_frame:SetHyperlink("unit:" .. (petGUID or ""))
			local tooltipData = pet_tooltip_frame:GetTooltipData()

			if (tooltipData and tooltipData.lines[1]) then
				if (tooltipData.lines[1].leftText == petName) then
					for i = 2, #tooltipData.lines do
						local tooltipLine = tooltipData.lines[i]
						local args = tooltipLine.args
						if (args) then
							if (args[4] and args[4].field == "guid") then
								local guidVal = args[4].guidVal
								local guidCache = Details:GetParserPlayerCache()
								if (guidCache[guidVal]) then
									return petOwnerFound(guidCache[guidVal], petGUID, petName, petFlags, self, guidVal)
								end
							end
						end
					end
				end
			end
		end

		Details.tabela_vigente.raid_roster_indexed = Details.tabela_vigente.raid_roster_indexed or {}

		local line1 = _G ["DetailsPetOwnerFinderTextLeft2"]
		local text1 = line1 and line1:GetText()
		if (text1 and text1 ~= "") then
			--for _, playerName in ipairs(Details.tabela_vigente.raid_roster_indexed) do
			for playerName, _ in pairs(_detalhes.tabela_vigente.raid_roster) do
				local pName = playerName
				playerName = playerName:gsub("%-.*", "") --remove realm name

				--if the user client is in russian language
				--make an attempt to remove declensions from the character's name
				--this is equivalent to remove 's from the owner on enUS
				if (CONST_CLIENT_LANGUAGE == "ruRU") then
					if (find_name_declension (text1, playerName)) then
						return petOwnerFound (pName, petGUID, petName, petFlags, self)
					else
						--print("not found declension (1):", pName, nome)
						if (text1:find(playerName)) then
							return petOwnerFound (pName, petGUID, petName, petFlags, self)
						end
					end
				else
					if (text1:find(playerName)) then
						return petOwnerFound (pName, petGUID, petName, petFlags, self)
					else
						local ownerName = (string.match(text1, string.gsub(UNITNAME_TITLE_PET, "%%s", "(%.*)")) or string.match(text1, string.gsub(UNITNAME_TITLE_MINION, "%%s", "(%.*)")) or string.match(text1, string.gsub(UNITNAME_TITLE_GUARDIAN, "%%s", "(%.*)")))
						if (ownerName) then
							if (_detalhes.tabela_vigente.raid_roster[ownerName]) then
								return petOwnerFound (ownerName, petGUID, petName, petFlags, self)
							end
						end
					end
				end
			end
		end

		local line2 = _G ["DetailsPetOwnerFinderTextLeft3"]
		local text2 = line2 and line2:GetText()
		if (text2 and text2 ~= "") then
			for playerName, _ in pairs(_detalhes.tabela_vigente.raid_roster) do
			--for _, playerName in ipairs(Details.tabela_vigente.raid_roster_indexed) do
				local pName = playerName
				playerName = playerName:gsub("%-.*", "") --remove realm name

				if (CONST_CLIENT_LANGUAGE == "ruRU") then
					if (find_name_declension (text2, playerName)) then
						return petOwnerFound (pName, petGUID, petName, petFlags, self)
					else
						--print("not found declension (2):", pName, nome)
						if (text2:find(playerName)) then
							return petOwnerFound (pName, petGUID, petName, petFlags, self)
						end
					end
				else
					if (text2:find(playerName)) then
						return petOwnerFound (pName, petGUID, petName, petFlags, self)
					else
						local ownerName = (string.match(text2, string.gsub(UNITNAME_TITLE_PET, "%%s", "(%.*)")) or string.match(text2, string.gsub(UNITNAME_TITLE_MINION, "%%s", "(%.*)")) or string.match(text2, string.gsub(UNITNAME_TITLE_GUARDIAN, "%%s", "(%.*)")))
						if (ownerName) then
							if (_detalhes.tabela_vigente.raid_roster[ownerName]) then
								return petOwnerFound (ownerName, petGUID, petName, petFlags, self)
							end
						end
					end
				end
			end
		end
	end

	---get an actor from the container, if the actor doesn't exists, and the bShouldCreate is true, create a new actor
	---@param serial string
	---@param actorName string
	---@param actorFlags number
	---@param bShouldCreate boolean
	---@return table
	function actorContainer:GetOrCreateActor (serial, actorName, actorFlags, bShouldCreate)
		return self:PegarCombatente(serial, actorName, actorFlags, criar)
	end

	function actorContainer:PegarCombatente (serial, nome, flag, criar)
		--[[statistics]]-- _detalhes.statistics.container_calls = _detalhes.statistics.container_calls + 1
	
		--if (flag and nome:find("Kastfall") and bit.band(flag, 0x2000) ~= 0) then
			--print("PET:", nome, _detalhes.tabela_pets.pets [serial], container_pets [serial])
		--else
			--print(nome, flag)
		--end

		local npcId = Details:GetNpcIdFromGuid(serial or "")

		--verifica se � um pet, se for confere se tem o nome do dono, se n�o tiver, precisa por
		local dono_do_pet
		serial = serial or "ns"

		if (container_pets[serial]) then --� um pet reconhecido
			--[[statistics]]-- _detalhes.statistics.container_pet_calls = _detalhes.statistics.container_pet_calls + 1
			local petName, ownerName, ownerGUID, ownerFlag = _detalhes.tabela_pets:PegaDono (serial, nome, flag)
			if (petName and ownerName) then
				nome = petName
				dono_do_pet = self:PegarCombatente(ownerGUID, ownerName, ownerFlag, true)
			end

		elseif (not petBlackList[serial]) then --verifica se � um pet
			petBlackList[serial] = true

			--try to find the owner
			if (flag and _bit_band(flag, OBJECT_TYPE_PETGUARDIAN) ~= 0) then
				--[[statistics]]-- _detalhes.statistics.container_unknow_pet = _detalhes.statistics.container_unknow_pet + 1
				local find_nome, find_owner = find_pet_owner(serial, nome, flag, self)
				if (find_nome and find_owner) then
					nome, dono_do_pet = find_nome, find_owner
				end
			end
		end

		--pega o index no mapa
		local index = self._NameIndexTable[nome]
		--retorna o actor
		if (index) then
			return self._ActorTable[index], dono_do_pet, nome

		--n�o achou, criar
		elseif (criar) then
			local novo_objeto = self.funcao_de_criacao(_, serial, nome)
			novo_objeto.nome = nome
			novo_objeto.flag_original = flag
			novo_objeto.serial = serial

			--seta a classe default para desconhecido, assim nenhum objeto fica com classe nil
			novo_objeto.classe = "UNKNOW"
			local forceClass

			--get the aID (actor id)
			if (serial:match("^C")) then
				novo_objeto.aID = tostring(Details:GetNpcIdFromGuid(serial))

				if (Details.immersion_special_units) then
					local shouldBeInGroup, class = Details.Immersion.IsNpcInteresting(novo_objeto.aID)
					novo_objeto.grupo = shouldBeInGroup
					if (class) then
						novo_objeto.classe = class
						forceClass = novo_objeto.classe
					end
				end

			elseif (serial:match("^P")) then
				novo_objeto.aID = serial:gsub("Player%-", "")

			else
				novo_objeto.aID = ""
			end

			--check ownership
			if (dono_do_pet and Details.immersion_pets_on_solo_play) then
				if (UnitIsUnit("player", dono_do_pet.nome)) then
					if (not Details.in_group) then
						novo_objeto.grupo = true
					end
				end
			end

		-- tipo do container
	------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	

			if (self.tipo == container_damage) then --CONTAINER DAMAGE

				local shouldScanOnce = get_actor_class (novo_objeto, nome, flag, serial)
				
				read_actor_flag (novo_objeto, dono_do_pet, serial, flag, nome, "damage")
				
				if (dono_do_pet) then
					AddUnique (dono_do_pet.pets, nome)
				end
				
				if (self.shadow) then
					if (novo_objeto.grupo and _detalhes.in_combat) then
						_detalhes.cache_damage_group [#_detalhes.cache_damage_group+1] = novo_objeto
					end
				end
				
				if (novo_objeto.classe == "UNGROUPPLAYER") then --is a player
					if (_bit_band (flag, REACTION_HOSTILE ) ~= 0) then --is hostile
						novo_objeto.enemy = true 
					end
					
					--try to guess his class
					if (self.shadow) then --n�o executar 2x
						_detalhes:ScheduleTimer("GuessClass", 1, {novo_objeto, self, 1})
					end
					
				elseif (shouldScanOnce) then
					
					
				end
				
				if (novo_objeto.isTank) then
					novo_objeto.avoidance = _detalhes:CreateActorAvoidanceTable()
				end
				
			elseif (self.tipo == container_heal) then --CONTAINER HEALING
				
				local shouldScanOnce = get_actor_class (novo_objeto, nome, flag, serial)
				read_actor_flag (novo_objeto, dono_do_pet, serial, flag, nome, "heal")
				
				if (dono_do_pet) then
					AddUnique (dono_do_pet.pets, nome)
				end
				
				if (self.shadow) then
					if (novo_objeto.grupo and _detalhes.in_combat) then
						_detalhes.cache_healing_group [#_detalhes.cache_healing_group+1] = novo_objeto
					end
				end
				
				if (novo_objeto.classe == "UNGROUPPLAYER") then --is a player
					if (_bit_band (flag, REACTION_HOSTILE ) ~= 0) then --is hostile
						novo_objeto.enemy = true --print(nome.." EH UM INIMIGO -> " .. engRace)
					end
					
					--try to guess his class
					if (self.shadow) then --n�o executar 2x
						_detalhes:ScheduleTimer("GuessClass", 1, {novo_objeto, self, 1})
					end
				end
				
				
			elseif (self.tipo == container_energy) then --CONTAINER ENERGY
				
				local shouldScanOnce = get_actor_class (novo_objeto, nome, flag, serial)
				read_actor_flag (novo_objeto, dono_do_pet, serial, flag, nome, "energy")
				
				if (dono_do_pet) then
					AddUnique (dono_do_pet.pets, nome)
				end
				
				if (novo_objeto.classe == "UNGROUPPLAYER") then --is a player
					if (_bit_band (flag, REACTION_HOSTILE ) ~= 0) then --is hostile
						novo_objeto.enemy = true
					end
					
					--try to guess his class
					if (self.shadow) then --n�o executar 2x
						_detalhes:ScheduleTimer("GuessClass", 1, {novo_objeto, self, 1})
					end
				end
				
			elseif (self.tipo == container_misc) then --CONTAINER MISC
				
				local shouldScanOnce = get_actor_class (novo_objeto, nome, flag, serial)
				read_actor_flag (novo_objeto, dono_do_pet, serial, flag, nome, "misc")

				if (dono_do_pet) then
					AddUnique (dono_do_pet.pets, nome)
				end

				if (novo_objeto.classe == "UNGROUPPLAYER") then --is a player
					if (_bit_band (flag, REACTION_HOSTILE ) ~= 0) then --is hostile
						novo_objeto.enemy = true
					end
					
					--try to guess his class
					if (self.shadow) then --n�o executar 2x
						_detalhes:ScheduleTimer("GuessClass", 1, {novo_objeto, self, 1})
					end
				end
			
			elseif (self.tipo == container_damage_target) then --CONTAINER ALVO DO DAMAGE
			
			elseif (self.tipo == container_energy_target) then --CONTAINER ALVOS DO ENERGY
			
				novo_objeto.mana = 0
				novo_objeto.e_rage = 0
				novo_objeto.e_energy = 0
				novo_objeto.runepower = 0

			elseif (self.tipo == container_enemydebufftarget_target) then
				
				novo_objeto.uptime = 0
				novo_objeto.actived = false
				novo_objeto.activedamt = 0

			elseif (self.tipo == container_misc_target) then --CONTAINER ALVOS DO MISC

				
			elseif (self.tipo == container_friendlyfire) then --CONTAINER FRIENDLY FIRE
				
				local shouldScanOnce = get_actor_class (novo_objeto, nome, serial)

			end
		
			--sanguine affix
			if (nome == sanguineActorName) then
				novo_objeto.grupo = true
			end

	------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- grava o objeto no mapa do container
			local size = #self._ActorTable+1
			self._ActorTable [size] = novo_objeto --grava na tabela de indexes
			self._NameIndexTable [nome] = size --grava no hash map o index deste jogador

			if (_detalhes.is_in_battleground or _detalhes.is_in_arena) then
				novo_objeto.pvp = true
			end
			
			if (_detalhes.debug) then	
				if (_detalhes.debug_chr and nome:find(_detalhes.debug_chr) and self.tipo == 1) then
					local logLine = ""
					local when = "[" .. date ("%H:%M:%S") .. format(".%4f", GetTime()-floor(GetTime())) .. "]"
					local log = "actor created - class: " .. (novo_objeto.classe or "noclass")
					local from = debugstack (2, 1, 0)
					logLine = logLine .. when .. " " .. log .. " " .. from .. "\n"
					
					_detalhes_global.debug_chr_log = _detalhes_global.debug_chr_log .. logLine
				end
			end	
			
			--only happens with npcs from immersion feature
			if (forceClass) then
				novo_objeto.classe = forceClass
			end

			return novo_objeto, dono_do_pet, nome
		else
			return nil, nil, nil
		end
	end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--core
	
	--_detalhes:AddToNpcIdCache (novo_objeto)
	function _detalhes:AddToNpcIdCache (actor)
		if (flag and serial) then
			if (_bit_band (flag, REACTION_HOSTILE) ~= 0 and _bit_band (flag, OBJECT_TYPE_NPC) ~= 0 and _bit_band (flag, OBJECT_TYPE_PETGUARDIAN) == 0) then
				local npc_id = _detalhes:GetNpcIdFromGuid (serial)
				if (npc_id) then
					_detalhes.cache_npc_ids [npc_id] = nome
				end
			end
		end		
	end

	function _detalhes:UpdateContainerCombatentes()
		container_pets = _detalhes.tabela_pets.pets
		_detalhes:UpdatePetsOnParser()
	end
	function _detalhes:ClearCCPetsBlackList()
		table.wipe(petBlackList)
	end

	function actorContainer:FuncaoDeCriacao (tipo)
		if (tipo == container_damage_target) then
			return alvo_da_habilidade.NovaTabela
			
		elseif (tipo == container_damage) then
			return atributo_damage.NovaTabela
			
		elseif (tipo == container_heal_target) then
			return alvo_da_habilidade.NovaTabela
			
		elseif (tipo == container_heal) then
			return atributo_heal.NovaTabela
			
		elseif (tipo == container_enemydebufftarget_target) then
			return alvo_da_habilidade.NovaTabela
			
		elseif (tipo == container_energy) then
			return atributo_energy.NovaTabela
			
		elseif (tipo == container_energy_target) then
			return alvo_da_habilidade.NovaTabela
			
		elseif (tipo == container_misc) then
			return atributo_misc.NovaTabela
			
		elseif (tipo == container_misc_target) then
			return alvo_da_habilidade.NovaTabela
			
		end
	end

	--chama a fun��o para ser executada em todos os atores
	function actorContainer:ActorCallFunction (funcao, ...)
		for index, actor in ipairs(self._ActorTable) do
			funcao (nil, actor, ...)
		end
	end

	local bykey
	local sort = function(t1, t2)
		return (t1 [bykey] or 0) > (t2 [bykey] or 0)
	end
	
	function actorContainer:SortByKey (key)
		assert(type(key) == "string", "Container:SortByKey() expects a keyname on parameter 1.")
		bykey = key
		_table_sort (self._ActorTable, sort)
		self:remapear()
	end
	
	function actorContainer:Remap()
		return self:remapear()
	end
	
	function actorContainer:remapear()
		local mapa = self._NameIndexTable
		local conteudo = self._ActorTable
		for i = 1, #conteudo do
			mapa [conteudo[i].nome] = i
		end
	end

	function _detalhes.refresh:r_container_combatentes (container, shadow)
		--reconstr�i meta e indexes
			setmetatable(container, _detalhes.container_combatentes)
			container.__index = _detalhes.container_combatentes
			container.funcao_de_criacao = actorContainer:FuncaoDeCriacao (container.tipo)

		--repara mapa
			local mapa = {}
			for i = 1, #container._ActorTable do
				mapa [container._ActorTable[i].nome] = i
			end
			container._NameIndexTable = mapa

		--seta a shadow
			container.shadow = shadow
	end

	function _detalhes.clear:c_container_combatentes (container)
		container.__index = nil
		container.shadow = nil
		--container._NameIndexTable = nil
		container.need_refresh = nil
		container.funcao_de_criacao = nil
	end
	function _detalhes.clear:c_container_combatentes_index (container)
		container._NameIndexTable = nil
	end
