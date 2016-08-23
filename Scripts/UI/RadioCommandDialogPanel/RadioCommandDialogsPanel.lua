--Implementation of Command Dialogs Panel for DCS objects.
--RadioCommandDialogsPanel receives messags (wMessage), world events (world.event), generates internal events and passes them to
--CommandDialogsPanel.onEvent().
--Indicates if at least one of the radios is tuned into the given recepient.
--Selects and tunes radios to the recepient.

local base = _G

local function clean()
	base.RadioCommandDialogsPanel = nil
	base.package.loaded['RadioCommandDialogsPanel'] = nil
	base.CommandDialogsPanel = nil
	base.package.loaded['CommandDialogsPanel'] = nil
	base.CommandDialog = nil
	base.package.loaded['CommandDialog'] = nil
	base.CommandMenu = nil
	base.package.loaded['CommandMenu'] = nil
	base.StaticMenu = nil
	base.package.loaded['StaticMenu'] = nil
	base.StaticList = nil
	base.package.loaded['StaticList'] = nil
	base.TabSheetBar = nil
	base.package.loaded['TabSheetBar'] = nil
end

module('RadioCommandDialogsPanel') --singleton!

local self = base.getfenv()
local theRadioCommandDialogsPanel = self

local commandDialogsPanel = base.require('CommandDialogsPanel')
local commandDialog = base.require('CommandDialog')
local utils = base.require('utils')

local gettext = base.require("i_18n")
local _ = gettext.translate

base.setmetatable(base.getfenv(), commandDialogsPanel)

--properties

--private data

local data = {
	base=base,
	pUnit = nil,
	pComm = nil,
	initialized = false,
	worldEventHandlers = {}, --World event handles handle world events and passes them into RadioCommandDialogsPanel.onEvent()
	msgHandlers = {}, --Message handlers converts messages into internal events and passes them into RadioCommandDialogsPanel.onEvent()
	
	menus = {},
	menuOther = { --Misson command menu
		name = _('Other'),
		submenu = {
			name  = _('Other'),
			items = {}
		}
	},
	menuEmbarkToTransport = { --Misson command menu
		name = _('Descent'),
		submenu = {
			name = _('Descent'),
			items = {}
		}
	},
	--Communication
	curCommunicatorId = nil,
	intercomId = nil,
	communicators = nil,
	VoIP = false,

	--Settings
	showingOnlyPresentRecepients = true,
	highlighting = true,
	radioAutoTune = true,
	recepientInfo = true,
	rootItem = function() end,
}

local commById = {}

--Internal events
local events = {
	--Created from world events
	NOTIFY_BIRTH_ON_RAMP_COLD 	= 10000,
	NOTIFY_BIRTH_ON_RAMP_HOT	= 10001,
	NOTIFY_BIRTH_ON_RUNWAY		= 10002,
	NOTIFY_BIRTH_ON_HELIPAD_COLD= 10003,
	NOTIFY_BIRTH_ON_HELIPAD_HOT	= 10004,
	NOTIFY_BIRTH_ON_SHIP_COLD	= 10005,
	NOTIFY_BIRTH_ON_SHIP_HOT	= 10006,
	TAKEOFF						= 10007,
	LANDING						= 10008,
	ENGINE_STARTUP				= 10009,
	ENGINE_SHUTDOWN				= 10010,
	
	--Created from radio messages
	STARTUP_PERMISSION_FROM_AIRDROME = 10101,
	STARTUP_PERMISSION_FROM_HELIPAD = 10102,
	STARTUP_PERMISSION_FROM_SHIP = 10103,
	
	DENY_TAKEOFF_FROM_HELIPAD = 10104,
	DENY_TAKEOFF_FROM_AIRDROME = 10105,
	DENY_TAKEOFF_FROM_SHIP = 10106,
	
	CLEAR_TO_TAKEOFF_FROM_HELIPAD = 10107,
	CLEAR_TO_TAKEOFF_FROM_AIRDROME = 10108,
	CLEAR_TO_TAKEOFF_FROM_SHIP = 10109,
	
	--Other
	START_WP_DIALOG 		= 10200,
	START_IR_POINTER_DIALOG = 10201,
	START_LASER_DIALOG 		= 10202,
}

--Menu actions

local sendMessage = {
	perform = function(self, parameters)
		local messageParameters = {}
		local command = self.command
		for i, p in base.pairs(parameters) do
			if 	command == nil and 
				self.commandPos == i then
				command = p
			else
				base.table.insert(messageParameters, p)
			end
		end
		if self.parameters then
			for i, p in base.pairs(self.parameters) do
				base.table.insert(messageParameters, p)
			end
		elseif self.getParameter then
			base.table.insert(messageParameters, self.getParameter())	
		end
		data.pComm:sendRawMessage(command, messageParameters)
	end
}
sendMessage.__index = sendMessage

function sendMessage.new(command, ...)
	base.assert(command ~= nil)
	local newSendMessage = { command = command,  parameters = {...} }
	base.setmetatable(newSendMessage, sendMessage)
	return newSendMessage
end

function sendMessage.new2(commandPos, ...)
	base.assert(commandPos ~= nil)
	local newSendMessage = { commandPos = commandPos,  parameters = {...} }
	base.setmetatable(newSendMessage, sendMessage)
	return newSendMessage
end
function sendMessage.new3(command, getParameter)
	base.assert(command ~= nil)
	local newSendMessage = { command = command,  getParameter = getParameter }
	base.setmetatable(newSendMessage, sendMessage)
	return newSendMessage
end

local DoMissionAction = {
	perform = function(self, parameters)
		base.missionCommands.doAction(self.actionIndex)
	end
}
DoMissionAction.__index = DoMissionAction
function DoMissionAction.new(actionIndex)
	local doMissionAction = { actionIndex = actionIndex }
	base.setmetatable(doMissionAction, DoMissionAction)
	return doMissionAction
end

local setBehaviorOption = {
	perform = function(self, parameters)
		data.pUnit:getGroup():getController():setOption(self.optionName, self.optionValue)
	end
}

function setBehaviorOption:new(optionNameIn, optionValueIn)
	local instance = { optionName = optionNameIn, optionValue = optionValueIn }
	self.__index = self
	base.setmetatable(instance, self)
	return instance
end

--communicator features

local function findCommunicatorChannel(channels, targetFrequency)
	for channelNum, frequency in base.pairs(channels) do
		if base.math.abs(frequency - targetFrequency) < 10000.0  then
			return channelNum
		end
	end
	return nil
end

local function checkCommunicator(communicator, targetFrequency, targetModulation)
	if communicator ~= nil then
		if communicator.interphone then
			if targetFrequency == nil or targetModulation == nil then --wired
				return true
			end
		else
			if targetFrequency == nil or targetModulation == nil then
				return false
			elseif 	(targetModulation == base.Communicator.MODULATION_AM and communicator.AM) or
					(targetModulation == base.Communicator.MODULATION_FM and communicator.FM) then
				if communicator.channels then
					if findCommunicatorChannel(communicator.channels, targetFrequency) ~= nil then
						return true
					end
				end				
				if communicator.range then
					if communicator.range.min < targetFrequency and targetFrequency < communicator.range.max  then
						return true
					end
				elseif communicator.ranges then
					for rangeNum, range in base.pairs(communicator.ranges) do
						--base.print('targetFrequency = '..targetFrequency)
						--base.print('range.min = '..range.min)
						--base.print('range.max = '..range.max)
						if range.min < targetFrequency and targetFrequency < range.max then
							return true
						end
					end
				end
			end
		end
	end
	return false
end

local function selectCommunicatorDeviceId(targetCommunicator)
	if 	data.intercomId ~= nil and 
		data.communicators ~= nil and
		targetCommunicator ~= nil then
		
		if data.curCommunicatorId == COMMUNICATOR_AUTO then
			for communicatorId, communicator in base.pairs(data.communicators) do
				if 	base.GetDevice(data.intercomId):is_communicator_available(communicatorId) then
					local freqModTbl = targetCommunicator:getFrequenciesModulations()
					for transiverId, freqMod in base.pairs(freqModTbl) do
						if checkCommunicator(communicator, freqMod.frequency, freqMod.modulation) then
							return communicatorId
						end
					end
				end
			end		
		elseif data.curCommunicatorId ~= COMMUNICATOR_VOID then
			if 	base.GetDevice(data.intercomId):is_communicator_available(data.curCommunicatorId) then
				local freqModTbl = targetCommunicator:getFrequenciesModulations()
				if freqModTbl ~= nil then
					for transiverId, freqMod in base.pairs(freqModTbl) do
						if checkCommunicator(data.communicators[data.curCommunicatorId], freqMod.frequency, freqMod.modulation) then
							return data.curCommunicatorId
						end
					end
				end
			end
		end
	end
	return nil
end

local function selectAndTuneCommunicator(targetCommunicator)
	if not data.radioAutoTune then
		return nil
	end
	local communicatorId = selectCommunicatorDeviceId(targetCommunicator)
	if communicatorId ~= nil then
		local communicator = data.communicators[communicatorId]
		if communicator.interphone then
		
		else
			local commDevice = base.GetDevice(communicatorId)
			local freqModTbl = targetCommunicator:getFrequenciesModulations()
			for transiverId, freqMod in base.pairs(freqModTbl) do
				local haveFreq = false
				if communicator.channels then
					local channelNum = findCommunicatorChannel(communicator.channels, freqMod.frequency)
					if channelNum ~= nil then
						haveFreq = true
						commDevice:set_channel(channelNum)
					end
				else
					if commDevice:is_frequency_in_range(freqMod.frequency) then
						commDevice:set_frequency(freqMod.frequency)
						haveFreq = true
					end
				end
				if haveFreq == true then
					local commDevice = base.GetDevice(communicatorId)
					if communicator.AM and communicator.FM then
						commDevice:set_modulation(freqMod.modulation)
					end	
					break
				end
			end
		end	
		if data.curCommunicatorId ~= communicatorId then
			base.GetDevice(data.intercomId):set_communicator(communicatorId)
		end
		return communicatorId
	end
	return nil
end

local RecepientState = {
	VOID			= 0, --no radio
	TUNED 			= 1, --selected communicator tuned onto recepient
	CAN_BE_TUNED 	= 2, --selected communicator can be tuned onto recepient
	CANNOT_BE_TUNED	= 3  --selected communicator can not be tuned onto recepient due the frequency range or switched off state
}

local function getRecepientState(targetCommunicator)
	if 	data.intercomId ~= nil and 
		data.communicators ~= nil then
		local commDeviceId = selectCommunicatorDeviceId(targetCommunicator)
		if commDeviceId ~= nil then			
			if base.GetDevice(data.intercomId):is_communicator_available(commDeviceId) then
				if data.communicators[commDeviceId].interphone then
					return RecepientState.TUNED
				else
					base.assert(targetCommunicator ~= nil)
					local device = base.GetDevice(commDeviceId)
					if device:is_on() then
						local currentFrequency = device:get_frequency()
						--base.print('selected '..data.communicators[commDeviceId].displayName..' '..currentFrequency)
						local targetFrequency = targetCommunicator:getFrequency();
						if base.math.abs(currentFrequency - targetFrequency) < 10000 then
							return RecepientState.TUNED
						else
							return RecepientState.CAN_BE_TUNED
						end
					end
				end
			end
		end
		return RecepientState.CANNOT_BE_TUNED
	else
		return RecepientState.TUNED
	end
end

--[[
local function getInterphoneRecepientState()
	if data.curCommunicatorId == nil then
		for communicatorId, communicator in base.pairs(data.communicators) do
			if data.communicators[data.curCommunicatorId].interphone then
				return RecepientState.TUNED
			end
		end		
	else
		if data.communicators[data.curCommunicatorId].interphone then
			return RecepientState.TUNED
		end
	end
	return RecepientState.CANNOT_BE_TUNED
end
--]]

local colorByRecepientState = {
	[RecepientState.VOID] 				= utils.COLOR.WHITE,
	[RecepientState.TUNED] 				= utils.COLOR.WHITE,
	[RecepientState.CAN_BE_TUNED] 		= utils.COLOR.LIGHT_GRAY,
	[RecepientState.CANNOT_BE_TUNED] 	= utils.COLOR.BLACK
}

local function getRecepientColor(targetCommunicator)
	return data.highlighting and colorByRecepientState[getRecepientState(targetCommunicator)]
end

local speech = base.require('speech')

--Utilities for variable recepients list

local function makeItemByCommunicator(pCommunicator, submenu)
	base.assert(submenu ~= nil)
	
	local commName
	local selfCoalition = data.pUnit:getCoalition()
	local callsignStr = speech.protocols[speech.protocolByCountry[selfCoalition] or speech.defaultProtocol]:makeCallsignString(pCommunicator)
	if pCommunicator:getUnit():hasAttribute("Ships") or callsignStr == nil or pCommunicator:getUnit():hasAttribute("Airfields") then
		callsignStr = pCommunicator:getUnit():getDesc().displayName
	end
	
	local frequency = pCommunicator:getFrequency()
	local modulation = pCommunicator:getModulation()
	
	--base.print('pCommunicator:getCallsign() = '..base.tostring(pCommunicator:getCallsign()))
	--base.print('callsignStr = '..base.tostring(callsignStr)..', frequency = '..base.tostring(frequency)..', modulation = '..base.tostring(modulation))
	
	if data.recepientInfo and frequency ~= nil and modulation ~= nil then
		local frequency = base.math.floor(frequency / 1000.0) / 1000
		local frequency25Khz = 0.025 * base.math.floor(frequency / 0.025 + 0.5)
		local frequencyStr = base.tostring(frequency25Khz)..' MHz'
		local modulationStr = (modulation == base.Communicator.MODULATION_AM) and "AM" or "FM"
		commName = (callsignStr or '')..'-'..frequencyStr..' '..modulationStr
		if pCommunicator:getUnit():getCoalition() ~= selfCoalition then
			commName = commName..' '.._('(Neutral)')
		end
	else
		commName = callsignStr
	end
	
	base.assert(commName ~= nil)
	
	local dialogIsOpened = theRadioCommandDialogsPanel:getDialogFor(pCommunicator:tonumber()) ~= nil
	
	return {	name = commName,
				color = {
					get = function(self)
						return getRecepientColor(pCommunicator)
					end
				},
				receiver = pCommunicator,
				isDialogOpened = function()
					return self:getDialogFor(pCommunicator:tonumber()) ~= nil
				end,
				command = {
					perform = function(self)
						selectAndTuneCommunicator(pCommunicator)
						local dialogIsOpened = theRadioCommandDialogsPanel:getDialogFor(pCommunicator:tonumber()) ~= nil
						if dialogIsOpened then
							theRadioCommandDialogsPanel:switchToDialogFor(pCommunicator:tonumber())
						end
					end
				},
				submenu = not dialogIsOpened and submenu or nil,
				parameter = pCommunicator }
end


local function chooseItem(pCargo)
	pCargo:choosingCargo()
end


local function makeItemByCargo(pCargo, submenu)
	base.assert(submenu ~= nil)
	local cargoName = pCargo:getCargoDisplayName().." - "..pCargo:getName()
	
	local dialogIsOpened = theRadioCommandDialogsPanel:getDialogFor(pCargo:tonumber()) ~= nil

	return {
				name = cargoName,
				cargo = pCargo,
				isDialogOpened = function()
					return self:getDialogFor(pCargo:tonumber()) ~= nil
				end,
				submenu = nil,
				command = 
				{
					perform = function(self)
						chooseItem(pCargo)
					end
				},
				parameter = pCargo 
				
	}	
end

local function buildCargosMenu(Cargos, new_menu_name, child_menu_item, unit)
	local bChoosing = base.coalition.checkChooseCargo(unit:getObjectID())
	if bChoosing == true then	
		local new_menu_item = {
				name = new_menu_name,
				menuUnit = unit,
				submenu = {
					name = new_menu_name,
					items = {}
				}		
			}
		local CargoItem = {
				name = "Cancel choosing cargo",
				submenu = nil,
				command = 
				{
					perform = function(self)
						base.print("Cancel choosing cargo!!!!")
						unit:cancelChoosingCargo()
					end
				},
		}
		base.table.insert(new_menu_item.submenu.items, CargoItem)
		return new_menu_item
	else
		if Cargos ~= nil then
			if #Cargos > 0 then
				local new_menu_item = {
					name = new_menu_name,
					menuUnit = unit,
					submenu = {
						name = new_menu_name,
						items = {}
					}
				}
				local maxListItems = 10
				local counter = 0
				for index, cargo in base.pairs(Cargos) do
					counter = counter + 1
					local CargoItem = makeItemByCargo(cargo, child_menu_item.submenu)
					base.table.insert(new_menu_item.submenu.items, CargoItem)
					if counter >= maxListItems then
						break
					end
				end
				return new_menu_item
			end
		end
	end
end


local function makeItemByCommunicatorATC2(pCommunicator, submenu)
	base.assert(submenu ~= nil)
	
	local commName
	local selfCoalition = data.pUnit:getCoalition()
	local callsignStr = speech.protocols[speech.protocolByCountry[selfCoalition] or speech.defaultProtocol]:makeCallsignString(pCommunicator)
	--if pCommunicator:getUnit():hasAttribute("Ships") or callsignStr == nil then
		callsignStr = pCommunicator:getUnit():getDesc().displayName
	--end
	local frequency = pCommunicator:getFrequency()
	local modulation = pCommunicator:getModulation()
	
	base.print('callsignStr = ', callsignStr )
	base.print('pCommunicator:getCallsign() = '..base.tostring(pCommunicator:getCallsign()))
	base.print('callsignStr = '..base.tostring(callsignStr)..', frequency = '..base.tostring(frequency)..', modulation = '..base.tostring(modulation))
	
	if data.recepientInfo and frequency ~= nil and modulation ~= nil then
		local frequency = base.math.floor(frequency / 1000.0) / 1000
		local frequency25Khz = 0.025 * base.math.floor(frequency / 0.025 + 0.5)
		local frequencyStr = base.tostring(frequency25Khz)..' MHz'
		local modulationStr = (modulation == base.Communicator.MODULATION_AM) and "AM" or "FM"
		commName = (callsignStr or '')..'-'..frequencyStr..' '..modulationStr
		if pCommunicator:getUnit():getCoalition() ~= selfCoalition then
			commName = commName..' '.._('(Neutral)')
		end
	else
		commName = callsignStr
	end
	base.assert(commName ~= nil)
	local dialogIsOpened = theRadioCommandDialogsPanel:getDialogFor(pCommunicator:tonumber()) ~= nil
	
	return {	name = commName,
				color = {
					get = function(self)
						return getRecepientColor(pCommunicator)
					end
				},
				receiver = pCommunicator,
				isDialogOpened = function()
					return self:getDialogFor(pCommunicator:tonumber()) ~= nil
				end,
				command = {
					perform = function(self)
						selectAndTuneCommunicator(pCommunicator)
						local dialogIsOpened = theRadioCommandDialogsPanel:getDialogFor(pCommunicator:tonumber()) ~= nil
						if dialogIsOpened then
							theRadioCommandDialogsPanel:switchToDialogFor(pCommunicator:tonumber())
						end
					end
				},
				submenu = not dialogIsOpened and submenu or nil,
				parameter = pCommunicator }
end


local function buildRecepientsMenuATC2(recepients, new_menu_name, child_menu_item)

	if #recepients == 1 then
		local communicator = recepients[1]:getCommunicator()
		local item = makeItemByCommunicatorATC2(communicator, child_menu_item.submenu)
		item.name = new_menu_name..' - '..item.name
		return item
	elseif #recepients > 1 then
		local new_menu_item = {
			name = new_menu_name,
			submenu = {
				name = new_menu_name,
				items = {}
			}
		}
		local maxListItems = 10
		local counter = 0
		for index, recepient in base.pairs(recepients) do
			local communicator = recepient:getCommunicator()
			if communicator:hasTransiver() then
				counter = counter + 1
				local recepientItem = makeItemByCommunicatorATC2(communicator, child_menu_item.submenu)
				base.table.insert(new_menu_item.submenu.items, recepientItem)
				if counter >= maxListItems then
					break
				end
			end
		end
		
		return new_menu_item
	end
end

local function buildRecepientsMenu(recepients, new_menu_name, child_menu_item)
	if #recepients == 1 then
		local communicator = recepients[1]:getCommunicator()
		local item = makeItemByCommunicator(communicator, child_menu_item.submenu)
		item.name = new_menu_name..' - '..item.name
		return item
	elseif #recepients > 1 then
		local new_menu_item = {
			name = new_menu_name,
			submenu = {
				name = new_menu_name,
				items = {}
			}
		}
		local maxListItems = 10
		local counter = 0
		for index, recepient in base.pairs(recepients) do
			local communicator = recepient:getCommunicator()
			if communicator:hasTransiver() then
				counter = counter + 1
				local recepientItem = makeItemByCommunicator(communicator, child_menu_item.submenu)
				base.table.insert(new_menu_item.submenu.items, recepientItem)
				if counter >= maxListItems then
					break
				end
			end
		end
		
		return new_menu_item
	end
end

local function buildRecepientsMenu2(ATCs, new_menu_name, submenu_item, child_menu_item)
	
	base.print('BUILDRECEPIENTMENU2---------')
	submenu_item.items[1].submenu.items={}
	submenu_item.items[2].submenu.items={}
	submenu_item.items[3].submenu.items={}
	submenu_item.items[4].submenu.items={}
	submenu_item.items[5].submenu.items={}
	submenu_item.items[6].submenu.items={}
	
	local selfPoint = data.pUnit:getPosition().p
	local function distanceSorter(lu, ru)
			
		local lpoint = lu:getPoint()
		local ldist2 = (lpoint.x - selfPoint.x) * (lpoint.x - selfPoint.x) + (lpoint.z - selfPoint.z) * (lpoint.z - selfPoint.z)
		
		local rpoint = ru:getPoint()
		local rdist2 = (rpoint.x - selfPoint.x) * (rpoint.x - selfPoint.x) + (rpoint.z - selfPoint.z) * (rpoint.z - selfPoint.z)
		
		return ldist2 < rdist2
	end
	
	local function callsignSorter(l, r)
		
		local lcallsign = l:getCallsign()
		local rcallsign = r:getCallsign()
		
		return lcallsign < rcallsign
	
	end
	-- base.print('ready to call sort')
	-- base.table.sort(recepients, callsignSorter)
	local recepients = ATCs.vac
	local nearest = ATCs.nearest
	
	if #recepients == 1 then
		local communicator = recepients[1]:getCommunicator()
		local item = makeItemByCommunicator(communicator, child_menu_item.submenu)
		item.name = new_menu_name..' - '..item.name
		return item
	elseif #recepients > 1 then
		local new_menu_item = {
			name = new_menu_name,




			submenu = submenu_item
		}


		local menuListSize = 10 -- max size of the menu
		local maxATCItems = 3*menuListSize -- there are currently 3 pages for atc
		local maxFARPItems = 1*menuListSize -- only one page for FARPS 
		local maxShipItems = 1*menuListSize -- one page for ships
		local maxNearestItems = 1*menuListSize -- one page for nearest
		--base.print('maxATCItems:'..maxATCItems)
		--base.print('recepientsSize:'..#recepients)
		local ATCcounter = 0
		local shipCounter = 0
		local farpCounter = 0
		local nearestCounter = 0
		for index, recepient in base.pairs(recepients) do
			
			local communicator = recepient:getCommunicator()
		
			if communicator:hasTransiver() then

				ATCindex = base.math.floor(ATCcounter/menuListSize)+2
				local recepientItem = makeItemByCommunicator(communicator, child_menu_item.submenu)
				--base.print(communicator:getUnit():getDesc().displayName)
				if communicator:getUnit():hasAttribute("Airfields") and ATCcounter < maxATCItems then
				--	base.print(index..' is an Airfield')
					base.table.insert(new_menu_item.submenu.items[ATCindex].submenu.items, recepientItem)


					ATCcounter = ATCcounter + 1 -- only add to counter if we are adding it to the menu
			
				elseif communicator:getUnit():hasAttribute("Ships") then
				--		base.print(index..' is a ship')
						base.table.insert(new_menu_item.submenu.items[6].submenu.items, recepientItem)
						shipCounter = shipCounter + 1 -- only add to counter if we are adding it to the menu
				
				elseif communicator:getUnit():getDesc().displayName == "FARP" then
				--	base.print(index..' is a FARP')
					base.table.insert(new_menu_item.submenu.items[5].submenu.items, recepientItem)
					farpCounter = farpCounter + 1 -- only add to counter if we are adding it to the menu
				else 
					base.print(index..' is Unknown')
				end
				
				
				
				-- if ATCcounter >= maxATCItems then
					-- break
				-- end
			end
		end

	
		--- handle dynamic nearest menuitem here
		for index, recepient in base.pairs(nearest) do
			local communicator = recepient:getCommunicator()
			if communicator:hasTransiver() and nearestCounter < maxNearestItems then
				local recepientItem = makeItemByCommunicator(communicator, child_menu_item.submenu)
				base.table.insert(new_menu_item.submenu.items[1].submenu.items, recepientItem)
				nearestCounter = nearestCounter +1
			end
		end
		
		base.print('BUILDRECEPIENTMENU2:DONE----')
		return new_menu_item
	end
end


local function checkRecepients(recepients)
	local recepientStateCounter = nil
	for index, recepient in base.pairs(recepients) do
		recepientStateCounter = recepientStateCounter or
		{
			[RecepientState.VOID] = 0,
			[RecepientState.TUNED] = 0,
			[RecepientState.CAN_BE_TUNED] = 0,
			[RecepientState.CANNOT_BE_TUNED] = 0,
		}
		local communicator = recepient:getCommunicator()
		local recepientState = getRecepientState(communicator)
		recepientStateCounter[recepientState] = recepientStateCounter[recepientState] + 1
	end
	return recepientStateCounter
end

local function getRecepientsState(recepients)
	if 	data.intercomId ~= nil and 
		data.communicators ~= nil then
		local recepientsState = checkRecepients(recepients)
		if recepientsState == nil then
			return RecepientState.VOID
		elseif recepientsState[RecepientState.TUNED] > 0 then
			return RecepientState.TUNED
		elseif recepientsState[RecepientState.CAN_BE_TUNED] > 0 then
			return RecepientState.CAN_BE_TUNED
		elseif recepientsState[RecepientState.CANNOT_BE_TUNED] > 0 then
			return RecepientState.CANNOT_BE_TUNED
		else
			return RecepientState.VOID
		end
	else
		return RecepientState.TUNED
	end
end

local function getRecepientsColor(recepients)
	return data.highlighting and colorByRecepientState[getRecepientsState(recepients)]
end

local function staticParamsEvent(event, params)
	return {
			type = base.Message.type.TYPE_CONSTRUCTABLE,
			playMode = base.Message.playMode.PLAY_MODE_LIMITED_DURATION,	
			event = event,
			params = params,
			perform = function(self,parameters)
					   data.pComm:sendMessage({	type		= self.type,
												playMode	= self.playMode,
												event		= self.event,
												parameters	= self.params})
						end	
			}
end

--Dialogs

local DialogStartTrigger = {
	new = function(self, dialogIn)
		return commandDialogsPanel.DialogStartTrigger.new(self, theRadioCommandDialogsPanel, dialogIn)
	end,	
	run = function(self, senderId)
		local pCommunicator = commById[senderId]
		local function tuneCommunicator()
			selectAndTuneCommunicator(pCommunicator)
		end
		local color = {
			get = function(self)
				return getRecepientColor(pCommunicator)
			end			
		}
		--base.print('start dialog 2'..self.dialog.name)
		local dialog = self.commandDialogsPanel:openDialog(self.dialog, senderId, tuneCommunicator, color)
		if dialog then
			dialog.isAvailable = function(self)
				if not data.showingOnlyPresentRecepients then
					return true
				else
					return 	data.curCommunicatorId == COMMUNICATOR_AUTO or
							data.communicators == nil or
							#data.communicators == 0 or
							(	data.curCommunicatorId ~= COMMUNICATOR_VOID and
								checkCommunicator(	data.communicators[data.curCommunicatorId],
													pCommunicator:getFrequency(), pCommunicator:getModulation()) )
				end
			end
		end
	end
}
DialogStartTrigger.__index = DialogStartTrigger
base.setmetatable(DialogStartTrigger, commandDialogsPanel.DialogStartTrigger)

--Private

local function hasUnit()
	return true
	--return data.pUnit ~= nil and data.pUnit:isExist()
end

local function getMessageColor(pMsgSender, pMsgReceiver, event)
	return utils.COLOR.WHITE
end

--Callbacks

--CommandMenus & CommandDialogs events handlers

function onDialogCommand(self, dialog, command, parameters)
	--base.print('onCommand('..base.tostring(command)..')')
	self.mainCaption:setVisible(false)
	dialog:setMainMenu()
	if command then
		command:perform(parameters)
	end
end

function onMenuShow(self, menu)
	acquireCommandMenu()
end

function onMenuHide(self, menu)
	freeCommandMenu()
end

local function setUnit_(pUnitIn)
	data.pUnit = pUnitIn
	data.pComm = pUnitIn and pUnitIn:getCommunicator()
	data.curCommunicatorId = COMMUNICATOR_VOID
end

local worldEventHandler = {
	onEvent = function(self, event)
		for index, handler in base.pairs(data.worldEventHandlers) do
			local internalEvent, sender, recepient = handler:onEvent(event)
			if internalEvent ~= nil then
				if sender ~= nil then
					commById[sender:tonumber()] = sender
				end
				if recepient ~= nil then
					commById[recepient:tonumber()] = recepient
				end
				theRadioCommandDialogsPanel:onEvent(internalEvent, sender and sender:tonumber(), recepient and recepient:tonumber())
			end
		end
	end
}

--Interface

--Interface for ICommandDialogsPanel in ICommandDialogsPanel.h

local function setEasyComm(on)
	data.showingOnlyPresentRecepients	= on
	data.highlighting					= on
	data.radioAutoTune					= on
	data.recepientInfo					= on
end

local function updateMainCaption()
	if not data.initialized then
		return
	end
	if not hasUnit() then
		return
	end
	local mainCaption = ''
	if data.curCommunicatorId == COMMUNICATOR_AUTO then
		mainCaption = _('AUTO')
	elseif data.curCommunicatorId ~= COMMUNICATOR_VOID then
		local communicator = data.communicators[data.curCommunicatorId]
		if communicator then
			mainCaption =  communicator.displayName
		else
			mainCaption = '???'
		end
	end
	if data.VoIP then
		mainCaption = mainCaption.._(' ...VoIP...')
	end
	commandDialogsPanel.setMainCaption(self, mainCaption)
end

local function TERMINATE()
	return commandDialog.makeDialogTermination()
end

local function TO_DIALOG_STAGE(dialogsData, dialogName, stageName, pushToStack)
	local stageMenu = dialogsData.dialogs[dialogName].menus[stageName]
	return commandDialog.makeStageTransition(stageMenu, stageName, pushToStack)
end

local function RETURN_TO_STAGE(stage)
	return commandDialog.makeStageReturn()
end

-- local function buildOthers(self, menu)
	
-- end


local count=0
local heightMenu=0
function initialize(pUnitIn, easyComm, intercomId, communicators)
	count=count+1
	
	--base.print("init count"..count)
	
	base.assert(COMMUNICATOR_VOID ~= nil)
	base.assert(COMMUNICATOR_AUTO ~= nil)
	data.curCommunicatorId = COMMUNICATOR_VOID

	base.assert(data.initialized == false)
	
	setEasyComm(easyComm == nil or easyComm)
	setUnit_(pUnitIn)
	
	data.intercomId = data.intercomId or intercomId
	base.assert(data.communicators == nil)
	data.communicators = {}
	if communicators ~= nil then
		for communicatorId, communicator in base.pairs(communicators) do
			data.communicators[communicatorId] = communicator
		end
	end
	
	local dialogsData = {
		dialogs = {},
		triggers = {}
	}
	
	local function TO_STAGE(dialogName, stageName, pushToStack)
		return TO_DIALOG_STAGE(dialogsData, dialogName, stageName, pushToStack)
	end	

	local groundUnitScriptNameDefault = 'Scripts/UI/RadioCommandDialogPanel/Config/GroundUnit.lua'
	local specificScriptName = nil
	if pUnitIn ~= nil then
		specificScriptName = pUnitIn:hasAttribute('Air') and base.Objects[pUnitIn:getTypeName()].HumanCommPanelPath or groundUnitScriptNameDefault
	end
	local scriptNameDefault = 'Scripts/UI/RadioCommandDialogPanel/Config/default.lua'
	
	local env =
	{
		table						= base.table,
		math						= base.math,
		pairs						= base.pairs,
		getfenv						= base.getfenv,
		require						= base.require,
		assert						= base.assert,
		print						= base.print,
		
		_ 							= _,
		db							= base.db,
		
		world						= base.world,
		Object						= base.Object,
		Airbase						= base.Airbase,
		Message						= base.Message,
		coalition					= base.coalition,
		MissionResourcesDialog		= base.MissionResourcesDialog,
		
		utils						= base.utils,
		
		data 						= data,
		getSelectedReceiver			= function()
			return self.curDialogIt.element_.receiver
		end,
		RecepientState 				= RecepientState,
		getRecepientsState  		= getRecepientsState,
		getRecepientColor 			= getRecepientColor,
		getRecepientsColor 			= getRecepientsColor,
		selectAndTuneCommunicator 	= selectAndTuneCommunicator,
			
		setBehaviorOption			= setBehaviorOption,
		sendMessage					= sendMessage,
		buildRecepientsMenu 		= buildRecepientsMenu,
		buildRecepientsMenuATC2		= buildRecepientsMenuATC2,
		buildRecepientsMenu2		= buildRecepientsMenu2,
		buildCargosMenu				= buildCargosMenu,
		
		staticParamsEvent			= staticParamsEvent,
			
		events 						= events,
		dialogsData 				= dialogsData,
		TERMINATE					= TERMINATE,
		TO_STAGE 					= TO_STAGE,
		RETURN_TO_STAGE 			= RETURN_TO_STAGE,
		DialogStartTrigger 			= DialogStartTrigger
	}
	
	local scriptName = specificScriptName or scriptNameDefault
	
	if scriptName ~= nil then
		--base.print('Loading command panel from \"'..scriptName..'\"')
		local aircraftRadioCommandPanel, errMsg = utils.loadfileIn(scriptName, env)
		if aircraftRadioCommandPanel == nil then
			base.error(errMsg)
		end
		aircraftRadioCommandPanel()
	end
	
	heightMenu = commandDialogsPanel.initialize(self, data.menus, data.rootItem, dialogsData)
	base.world.addEventHandler(worldEventHandler)
	
	self:toggle(true)
	data.initialized = true

	setHeightCommandMenu( heightMenu )
end

function setIntercom(deviceId)
	data.intercomId = deviceId
end

function addRadio(deviceId, communicatorData)
	base.assert(communicatorData ~= nil)
	if not communicatorData.interphone then
		base.assert(communicatorData.AM or communicatorData.FM)
		base.assert(communicatorData.range or communicatorData.ranges or communicatorData.channels)	
	end
	base.assert(communicatorData.displayName)
	data.communicators[deviceId] = communicatorData
end

function release()
	--base.assert(data.initialized == true)
	if not data.initialized then
		return
	end
	setShowMenu(false)
	self:toggle(false)
		
	data.curCommunicatorId = nil
	data.intercomId = nil
	data.communicators = nil
	
	data.pUnit = nil
	data.pComm = nil
	commById = {}
	--
	commandDialogsPanel.release(self)
	base.world.removeEventHandler(worldEventHandler)
	data.initialized = false
end

function setUnit(pUnitIn)
	base.assert(pUnitIn ~= nil)
	commandDialogsPanel:clear()	
	setUnit_(pUnitIn)
end

function clear(self)
	if not data.initialized then
		return
	end
	commandDialogsPanel.clear(self)
end

function setShowSubtitles(on)
	commandDialogsPanel.setShowSubtitles(self, on)
end

function setShowMenu(on)
	--base.print('setShowMenu')
	if not data.initialized then
		return
	end
	if not hasUnit() then
		return
	end
	self.mainCaption:setVisible(on or data.VoIP)
	commandDialogsPanel.setShowMenu(self, on)
end

function selectAndTuneCommunicatorFor(pCommunicator)
	if not data.initialized then
		return
	end
	selectAndTuneCommunicator(pCommunicator)
end

function setCommunicatorId(curCommunicatorIdIn)
	data.curCommunicatorId = curCommunicatorIdIn
	if self.showMenu then
		self.curDialogIt.element_:setMainMenu()
	end
	updateMainCaption()
end

function setVoIP(on)
	data.VoIP = on
	updateMainCaption()
	self.mainCaption:setVisible(self.showMenu or data.VoIP)
end

function getCommunicatorId()
	return data.curCommunicatorId
end

function onCommunicatorDeath(pCommunicator)
	if not data.initialized then
		return
	end	
	self:closeSenderDialogs(pCommunicator:tonumber())
end

function switchToMainMenu()
	if not data.initialized then
		return
	end
	commandDialogsPanel.switchToMainMenu(self)
end

function switchToNextDialog()
	if not data.initialized then
		return
	end
	commandDialogsPanel.switchToNextDialog(self)
end

function isVisible()
	return data.initialized and commandDialogsPanel.isMenuVisible(self)
end

function getSenderName(senderId)
	local selfCoalition = data.pUnit:getCoalition()
	local pCommunicator = commById[senderId]
	local callsignStr = speech.protocols[speech.protocolByCountry[selfCoalition] or speech.defaultProtocol]:makeCallsignString(pCommunicator)
	return callsignStr
end

--Receives radio message and generates event
function onMsgStart(pMessage, pRecepient, text)

	if not data.initialized then
		return
	end
	
	local pMsgSender	= pMessage:getSender()
	local pMsgReceiver	= pMessage:getReceiver()
	local event			= pMessage:getEvent()

	base.assert(pMsgSender.id_ ~= nil)
	local ttt = { id_ = pMsgSender.id_ }
	base.setmetatable(ttt, base.getmetatable(pMsgSender) )
	base.assert(pMsgSender == ttt)
	if pMsgSender ~= nil then
		commById[pMsgSender:tonumber()] = pMsgSender
	end
	if pMsgReceiver ~= nil then
		commById[pMsgReceiver:tonumber()] = pMsgReceiver
	end	
	
	--base.print('RadioCommandDialogsPanel:onMsgStart()')
	--base.print('data.pComm = '..base.tostring(data.pComm))
	--base.print('pMsgSender = '..base.tostring(pMsgSender))
	--base.print('pMsgReceiver = '..base.tostring(pMsgReceiver))
	--base.print('pRecepient = '..base.tostring(pRecepient))
	--base.print('event = '..base.tostring(event))
	if 	data.pComm == nil or
		pRecepient ~= data.pComm then
		return
	end
	local textColor = getMessageColor(pMsgSender, pMsgReceiver, event)
	if pMsgReceiver == data.pComm or pMsgSender == data.pComm then
		--Checking if message induces internal event(s)
		for msgHandlerIndex, msgHandler in base.pairs(data.msgHandlers) do
			local internalEvent, receiverAsRecepient = msgHandler:onMsg(pMessage, pRecepient)
			if internalEvent ~= nil then
				self:onEvent(internalEvent, pMsgSender and pMsgSender, pMsgReceiver:tonumber() and pMsgReceiver:tonumber(), receiverAsRecepient)
			end
		end
		--Processing message by dialog(s) FSM
		self:onEvent(event, pMsgSender and pMsgSender:tonumber(), pMsgReceiver and pMsgReceiver:tonumber())
	end
	--Processing message by GUI
	if pMsgReceiver == data.pComm or pMsgSender == data.pComm then
		commandDialogsPanel.onMsgStart(self, pMsgSender:tonumber(), pMsgReceiver and pMsgReceiver:tonumber(), text, textColor)
	else
		--if self.showSubtitles then
		--	self.commonCommandMenuIt.element_:onMsgStart(text, textColor)
		--end
	end
end

function onMsgFinish(pMessage, pRecepient, text)
	if not data.initialized then
		return
	end
	local pMsgSender	= pMessage:getSender()
	local pMsgReceiver	= pMessage:getReceiver()
	if pMsgSender ~= nil then
		commById[pMsgSender:tonumber()] = pMsgSender
	end
	if pMsgReceiver ~= nil then
		commById[pMsgReceiver:tonumber()] = pMsgReceiver
	end	
	if pMsgReceiver == data.pComm or pMsgSender == data.pComm then
		commandDialogsPanel.onMsgFinish(self, pMsgSender:tonumber(), pMsgReceiver and pMsgReceiver:tonumber(), text)
	else
		--if self.showSubtitles then
		--	self.commonCommandMenuIt.element_:onMsgFinish(text)
		--end
	end
end

--Receives event of radio message without a message recepetion iself. It is assumed that the message is sent to the player.
--Generates event.
function onMsgEvent(event, pMsgSender) 
	base.assert(pMsgSender ~= nil)
	if pMsgSender ~= nil then
		commById[pMsgSender:tonumber()] = pMsgSender
	end	
	--checking if message induces internal event(s)
	for msgHandlerIndex, msgHandler in base.pairs(data.msgHandlers) do
		if msgHandler.onMsgEvent ~= nil then
			local internalEvent = msgHandler:onMsgEvent(event, pMsgSender, data.pComm)
			if internalEvent ~= nil then
				self:onEvent(internalEvent, pMsgSender and pMsgSender:tonumber(), data.pComm:tonumber())
			end
		end
	end
	--processing message by dialog(s) FSM
	self:onEvent(event, pMsgSender and pMsgSender:tonumber(), data.pComm:tonumber())
end

function selectMenuItem(num)
	commandDialogsPanel.selectMenuItem(self, num)
end

--Other submenu

local function findItemByName(menu, name)
	for itemIndex, item in base.pairs(menu.items) do
		if item.name == name then
			return itemIndex, item
		end
	end
end

local function getSomeSubMenu(path, primaryMenuItem)
	local menu = data[primaryMenuItem]
	if menu and menu.submenu then
		menu=menu.submenu
		if path ~= nil then
			for index, name in base.pairs(path) do
				local itemIndex, item = findItemByName(menu, name)
				menu = item.submenu
			end
		end
	else
		menu=data[primaryMenuItem]
	end
	return menu
end

local function copyPath(src)
	local dst = {}
	if src ~= nil then
		for index, name in base.pairs(src) do
			base.table.insert(dst, name)
		end
	end
	return dst
end

local function addSomeMenuItem(item, path, primaryMenuItem)
	local menu = getSomeSubMenu(path, primaryMenuItem)
	base.table.insert(menu.items, item)
	local result = copyPath(path)
	base.table.insert(result, item.name)
	return result
end

function addSomeSubmenu(name, path, primaryMenuItem)
	local item = { name = name, submenu = { name = name, items = {} }}
	return addSomeMenuItem(item, path, primaryMenuItem)
end

local function addSomeCommand_(name, command, path, primaryMenuItem)
	local item = { name = name, command = command}
	return addSomeMenuItem(item, path, primaryMenuItem)
end


function removeSomeMenuItem(path, primaryMenuItem)
	if data[primaryMenuItem] then
		if path == nil or #path == 0 then
			data[primaryMenuItem].items = {}
			return nil
		else
			local result = copyPath(path)
			local name = path[#path]
			base.table.remove(result)
			local menu = getSomeSubMenu(result,primaryMenuItem)
			local itemIndex, item = findItemByName(menu, name)
			base.table.remove(menu.items, itemIndex)
			return result
		end
	end
end

function clearSomeMenu(primaryMenuItem)
	local menu = data[primaryMenuItem]
	if menu then
		menu.items = {}
		if menu.submenu then
			menu = menu.submenu
			local menuItems = menu.items
			local countMenu = #menuItems
			while countMenu > 0 do
				countMenu = countMenu - 1
				base.table.remove(menu.items)
			end
		end
	end
end

function addSomeCommand(name, actionIndex, path, primaryMenuItem)	
	return addSomeCommand_(name, DoMissionAction.new(actionIndex), path, primaryMenuItem)
end

function getDataParameter(parameter)
	local result=data[parameter]
	return result
end

function newMessage(command, ...)
	return sendMessage.new(command, ...)
end

function selectCommunicator(communicator)
	selectAndTuneCommunicator(communicator)
end

--other menu functions---------------------

local function getOtherSubMenu(path)
	return getSomeSubMenu(path, 'menuOther')
end

function addOtherCommand(name, actionIndex, path)	
	return addSomeCommand(name, actionIndex, path, 'menuOther')
end

function clearOtherMenu()
	clearSomeMenu('menuOther')
end

function removeOtherMenuItem(path)
	removeSomeMenuItem(path, 'menuOther')
end

local function addOtherCommand_(name, command, path)
	return addSomeCommand_(name, command, path, 'menuOther')
end

function addOtherSubmenu(name, path)
	return addSomeSubmenu(name, path, 'menuOther')
end

local function addOtherMenuItem(item, path)
	return addSomeMenuItem(item, path, 'menuOther')
end

--other menu functions end---------------------

if not _FINAL_VERSION then

function reload()
	local pSavedUnit = data.pUnit
	
	local easyComm = 	data.showingOnlyPresentRecepients or
						data.highlighting or
						data.radioAutoTune or
						data.recepientInfo
	local showSubtitles = self.showSubtitles
	
	local CONST_COMMUNICATOR_VOID = COMMUNICATOR_VOID
	local CONST_COMMUNICATOR_AUTO = COMMUNICATOR_AUTO
	
	local intercomId = data.intercomId
	local communicators = data.communicators	
	
	if data.initialized then
		theRadioCommandDialogsPanel.release()
	end

	local acquireCommandMenu = self.acquireCommandMenu
	local freeCommandMenu = self.freeCommandMenu
	local setHeightCommandMenu = self.setHeightCommandMenu
	clean()
	base.dofile('Scripts/UI/RadioCommandDialogPanel/RadioCommandDialogsPanel.lua')
	base.RadioCommandDialogsPanel.COMMUNICATOR_VOID = CONST_COMMUNICATOR_VOID
	base.RadioCommandDialogsPanel.COMMUNICATOR_AUTO = CONST_COMMUNICATOR_AUTO
	base.RadioCommandDialogsPanel.initialize(pSavedUnit, easyComm, intercomId, communicators)
	base.RadioCommandDialogsPanel.setShowSubtitles(showSubtitles)
	base.RadioCommandDialogsPanel.acquireCommandMenu = acquireCommandMenu
	base.RadioCommandDialogsPanel.freeCommandMenu = freeCommandMenu
	base.RadioCommandDialogsPanel.setHeightCommandMenu = setHeightCommandMenu
end

end