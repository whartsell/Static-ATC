local mainMenuPos, parameters = ...

--Menu
local menus = data.menus

menus['ATC'] = {
	name = _('ATC'),
	items = {
		{	name = _('Inbound'),
			command = sendMessage.new(Message.wMsgLeaderInbound),
			condition = {
				check = function(self)
					return data.pUnit:inAir()
				end
			}
		},
		{	name = _('I\'m lost'),
			command = sendMessage.new(Message.wMsgLeaderRequestAzimuth),
			condition = {
				check = function(self)
					return data.pUnit:inAir()
				end
			}
		},
		{	name = _('Request startup'),
			command = sendMessage.new(Message.wMsgLeaderRequestEnginesLaunch),
			condition = {
				check = function(self)
					return not data.pUnit:inAir()
				end
			}
		}
	}
}
-- our custom menu for static atcs
menus['VACATC'] = {
	name = _('VACATC'),
	items = {
		{ name = _('Nearest'), submenu={ name = _('Nearest'),items = {}}},
		{ name = _('Airports 1'), submenu={ name = _('Airports 1'),items = {}}},
		{ name = _('Airports 2'), submenu={ name = _('Airports 2'),items = {}}},
		{ name = _('Airports 3'), submenu={ name = _('Airports 3'),items = {}}},
		{ name = _('FARPs'), submenu={ name = _('FARPs'),items = {}}},
		{ name = _('Ships'), submenu={ name = _('Ships'),items = {}}},
		
	}
}
-- end change
local function getATCs()
		
	local atcs = {}
	
	local neutralAirbases = coalition.getServiceProviders(coalition.side.NEUTRAL, coalition.service.ATC)
	for i, airbase in pairs(neutralAirbases) do
		table.insert(atcs, airbase)
	end	
	
	local selfCoalition = data.pUnit:getCoalition()
	local ourAirbases = coalition.getServiceProviders(selfCoalition, coalition.service.ATC)
	for i, airbase in pairs(ourAirbases) do
		table.insert(atcs, airbase)
	end
	
	--[[
	local enemyCoalition = selfCoalition == coalition.RED and coalition.BLUE or coalition.RED
	local ourAirbases = coalition.getServiceProviders(enemycoalition. coalition.service.ATC)
	--print("ourAirbases size = "..table.getn(ourAirbases))
	for i, airbase in pairs(ourAirbases) do
		if filterAirbaseType(atc) then
			table.insert(atcs, airbase)
		end
	end
	--]]
		
	local selfPoint = data.pUnit:getPosition().p
	local function distanceSorter(lu, ru)
			
		local lpoint = lu:getPoint()
		local ldist2 = (lpoint.x - selfPoint.x) * (lpoint.x - selfPoint.x) + (lpoint.z - selfPoint.z) * (lpoint.z - selfPoint.z)
		
		local rpoint = ru:getPoint()
		local rdist2 = (rpoint.x - selfPoint.x) * (rpoint.x - selfPoint.x) + (rpoint.z - selfPoint.z) * (rpoint.z - selfPoint.z)
		
		return ldist2 < rdist2
	end
		
	table.sort(atcs, distanceSorter)
	
	return atcs
end

local function getVacATCs()
	print('getVacATCs:START---------------')
	local atcs = {}
	
	local neutralAirbases = coalition.getServiceProviders(coalition.side.NEUTRAL, coalition.service.ATC)
	for i, airbase in pairs(neutralAirbases) do
		table.insert(atcs, airbase)
	end	
	
	local redAirbases = coalition.getServiceProviders(coalition.side.RED,coalition.service.ATC)
	for i, airbase in pairs(redAirbases) do
		table.insert(atcs, airbase)
	end	
	local blueAirbases = coalition.getServiceProviders(coalition.side.BLUE,coalition.service.ATC)
	for i, airbase in pairs(blueAirbases) do
		table.insert(atcs, airbase)
	end	
	
	
	
	-- local selfCoalition = data.pUnit:getCoalition()
	-- local ourAirbases = coalition.getServiceProviders(selfCoalition, coalition.service.ATC)
	-- for i, airbase in pairs(ourAirbases) do
		-- table.insert(atcs, airbase)
	-- end
	
	
	
	
	--[[
	local enemyCoalition = selfCoalition == coalition.RED and coalition.BLUE or coalition.RED
	local ourAirbases = coalition.getServiceProviders(enemycoalition. coalition.service.ATC)
	--print("ourAirbases size = "..table.getn(ourAirbases))
	for i, airbase in pairs(ourAirbases) do
		if filterAirbaseType(atc) then
			table.insert(atcs, airbase)
		end
	end
	--]]
		
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
	
	table.sort(atcs, callsignSorter)
	
	
	print('getVacATCs:END-----------------')
	return atcs
	
end

-- change for static ATC menu
-- local function buildATCs(self, menu)
	-- local ATCs = getATCs()
	-- if 	not data.showingOnlyPresentRecepients or
		-- getRecepientsState(ATCs) ~= RecepientState.VOID then
		-- menu.items[mainMenuPos] = buildRecepientsMenu(ATCs, _('ATC'), { name = _('ATC'), submenu = menus['ATC'] })
	-- end
-- end

local function buildATCs(self, menu)
	print('BUILDATCS:START-------------')
	local ATCs = {}
	ATCs.vac = getVacATCs()
	ATCs.nearest = getATCs()
	if 	not data.showingOnlyPresentRecepients or
		getRecepientsState(ATCs.vac) ~= RecepientState.VOID then
		menu.items[mainMenuPos] = buildRecepientsMenu2(ATCs, _('ATC'),menus['VACATC'], { name = _('ATC'), submenu = menus['ATC'] })
		
	end
	print('BUILDATCS:END---------------')
end
-- end of changes
table.insert(data.rootItem.builders, buildATCs)


--Dialogs

--Departure Airdrome

dialogsData.dialogs['Departure Airdrome'] = {
	name = _('Departure Airdrome'),
	menus = {
		['Ready to taxi to runway'] = {
			name = _('Ready to taxi to runway'),
			items = {
				{ name = _('Request to taxi to runway'),	command = sendMessage.new(Message.wMsgLeaderRequestTaxiToRunway) },
				{ name = _('Request control hover'),
					command = sendMessage.new(Message.wMsgLeaderRequestControlHover),
					condition = {
						check = function(self)
							return data.pUnit:hasAttribute('Helicopters')
						end
					}
				},
				{ name = _('Abort takeoff'), 				command = sendMessage.new(Message.wMsgLeaderAbortTakeoff) }
			}
		},
		['Hover Check'] = {
			name = _('Hover Check'),
			items = {
				{ name = _('Request to taxi to runway'),	command = sendMessage.new(Message.wMsgLeaderRequestTaxiToRunway) },
				{ name = _('Abort takeoff'), 				command = sendMessage.new(Message.wMsgLeaderAbortTakeoff) }
			}
		},		
		['Ready to takeoff'] = {
			name = _('Ready to takeoff'),
			items = {
				{ name = _('Request takeoff'), 				command = sendMessage.new(Message.wMsgLeaderRequestTakeOff) },
				{ name = _('Abort takeoff'), 				command = sendMessage.new(Message.wMsgLeaderAbortTakeoff) }
			}
		},
		['Taking Off'] = {
			name = _('Taking Off'),
			items = {
				{ name = _('Abort takeoff'), 				command = sendMessage.new(Message.wMsgLeaderAbortTakeoff) }
			}
		}
	}
}
dialogsData.dialogs['Departure Airdrome'].stages = {
	['Closed'] = {	
		[events.NOTIFY_BIRTH_ON_RAMP_HOT]					= { menu = dialogsData.dialogs['Departure Airdrome'].menus['Ready to takeoff'], newStage = 'Ready to takeoff' },
		[events.DENY_TAKEOFF_FROM_AIRDROME] 				= { menu = dialogsData.dialogs['Departure Airdrome'].menus['Ready to takeoff'], newStage = 'Ready to takeoff' },
		[events.NOTIFY_BIRTH_ON_RUNWAY]						= { menu = dialogsData.dialogs['Departure Airdrome'].menus['Taking Off'], newStage = 'Taking Off' },
		[events.CLEAR_TO_TAKEOFF_FROM_AIRDROME]				= { menu = dialogsData.dialogs['Departure Airdrome'].menus['Taking Off'], newStage = 'Taking Off' },
		[events.STARTUP_PERMISSION_FROM_AIRDROME] 			= { menu = dialogsData.dialogs['Departure Airdrome'].menus['Ready to taxi to runway'], newStage = 'Ready to taxi to runway' },
		[Message.wMsgATCClearedToTaxiRunWay] 				= { menu = dialogsData.dialogs['Departure Airdrome'].menus['Ready to takeoff'], newStage = 'Ready to takeoff' },
		[events.TAKEOFF] 									= TERMINATE(),
		[events.LANDING]									= { menu = dialogsData.dialogs['Departure Airdrome'].menus['Ready to takeoff'], newStage = 'Ready to takeoff' }
	},
	['Hover Check'] = {
		[Message.wMsgATCClearedToTaxiRunWay] 			= { menu = dialogsData.dialogs['Departure Airdrome'].menus['Ready to takeoff'], newStage = 'Ready to takeoff' },
		[Message.wMsgATCYouHadTakenOffWithNoPermission]	= TERMINATE(),
		[Message.wMsgATCTaxiToParkingArea]				= TERMINATE(),
		[events.ENGINE_SHUTDOWN]						= TERMINATE()
	},	
	['Ready to taxi to runway'] = {
		[Message.wMsgATCClearedToTaxiRunWay] 			= { menu = dialogsData.dialogs['Departure Airdrome'].menus['Ready to takeoff'], newStage = 'Ready to takeoff' },
		[Message.wMsgATCClearedControlHover]			= { menu = dialogsData.dialogs['Departure Airdrome'].menus['Hover Check'], newStage = 'Hover Check' },
		[events.TAKEOFF] 								= TERMINATE(),
		[Message.wMsgATCTaxiToParkingArea]				= TERMINATE(),
		[events.ENGINE_SHUTDOWN]						= TERMINATE()
	},
	['Ready to takeoff'] = {
		[Message.wMsgATCYouAreClearedForTO]				= { menu = dialogsData.dialogs['Departure Airdrome'].menus['Taking Off'], newStage = 'Taking Off' },
		[events.TAKEOFF] 								= TERMINATE(),
		[Message.wMsgATCTaxiToParkingArea]				= TERMINATE(),
		[events.ENGINE_SHUTDOWN]						= TERMINATE()
	},
	['Taking Off'] = {
		[Message.wMsgATCClearedToTaxiRunWay] 			= { menu = dialogsData.dialogs['Departure Airdrome'].menus['Ready to takeoff'], newStage = 'Ready to takeoff' },
		[events.TAKEOFF] 								= TERMINATE(),
		[Message.wMsgATCTaxiToParkingArea]				= TERMINATE(),
		[events.ENGINE_SHUTDOWN]						= TERMINATE()
	}
}

--Departure Helipad

dialogsData.dialogs['Departure Helipad'] = {
	name = _('Departure Helipad'),
	menus = {
		['Hover Check'] = {
			name = _('Hover Check'),
			items = {
				{ name = _('Request takeoff'), 				command = sendMessage.new(Message.wMsgLeaderRequestTakeOff) },
				{ name = _('Abort takeoff'), 				command = sendMessage.new(Message.wMsgLeaderAbortTakeoff) }
			}
		},
		['Ready to takeoff'] = {
			name = _('Ready to takeoff'),
			items = {
				{ name = _('Request takeoff'), 				command = sendMessage.new(Message.wMsgLeaderRequestTakeOff) },
				{ name = _('Request control hover'),
						command = sendMessage.new(Message.wMsgLeaderRequestControlHover),
						condition = {
							check = function(self)
								return data.pUnit:hasAttribute('Helicopters')
							end
						}
				},
				{ name = _('Abort takeoff'), 				command = sendMessage.new(Message.wMsgLeaderAbortTakeoff) }
			}
		},
		['Taking Off'] = {
			name = _('Taking Off'),
			items = {
				{ name = _('Abort takeoff'), 				command = sendMessage.new(Message.wMsgLeaderAbortTakeoff) }
			}
		}		
	}
}
dialogsData.dialogs['Departure Helipad'].stages = {
	['Closed'] = {
		[events.DENY_TAKEOFF_FROM_HELIPAD]					= { menu = dialogsData.dialogs['Departure Helipad'].menus['Ready to takeoff'], newStage = 'Ready to takeoff' },
		[events.NOTIFY_BIRTH_ON_HELIPAD_HOT]				= { menu = dialogsData.dialogs['Departure Helipad'].menus['Ready to takeoff'], newStage = 'Ready to takeoff' },
		[events.STARTUP_PERMISSION_FROM_HELIPAD] 			= { menu = dialogsData.dialogs['Departure Helipad'].menus['Ready to takeoff'], newStage = 'Ready to takeoff' },
		[events.CLEAR_TO_TAKEOFF_FROM_HELIPAD]				= { menu = dialogsData.dialogs['Departure Helipad'].menus['Taking Off'], newStage = 'Taking Off' },
		[events.TAKEOFF] 									= TERMINATE(),
		[events.LANDING]									= { menu = dialogsData.dialogs['Departure Helipad'].menus['Ready to takeoff'], newStage = 'Ready to takeoff' }
	},
	['Hover Check'] = {
		[Message.wMsgATCYouAreClearedForTO]			= { menu = dialogsData.dialogs['Departure Helipad'].menus['Taking Off'], newStage = 'Taking Off' },
		[Message.wMsgATCTaxiToParkingArea]				= TERMINATE(),
		[events.ENGINE_SHUTDOWN]							= TERMINATE()
	},
	['Ready to takeoff'] = {
		[Message.wMsgATCYouAreClearedForTO]			= { menu = dialogsData.dialogs['Departure Helipad'].menus['Taking Off'], newStage = 'Taking Off' },
		[Message.wMsgATCClearedControlHover]			= { menu = dialogsData.dialogs['Departure Helipad'].menus['Hover Check'], newStage = 'Hover Check' },
		[events.TAKEOFF] 									= TERMINATE(),
		[Message.wMsgATCTaxiToParkingArea]				= TERMINATE(),
		[events.ENGINE_SHUTDOWN]							= TERMINATE()
	},
	['Taking Off'] = {
		[events.TAKEOFF] 									= TERMINATE(),
		[Message.wMsgATCTaxiToParkingArea]				= TERMINATE(),
		[events.ENGINE_SHUTDOWN]							= TERMINATE()
	}
}

--Departure Ship

dialogsData.dialogs['Departure Ship'] = {
	name = _('Departure Ship'),
	menus = {
		['Hover Check'] = {
			name = _('Hover Check'),
			items = {
				{ name = _('Request to taxi to runway'),	command = sendMessage.new(Message.wMsgLeaderRequestTaxiToRunway) },
				{ name = _('Abort takeoff'), 				command = sendMessage.new(Message.wMsgLeaderAbortTakeoff) }
			}
		},		
		['Ready to takeoff'] = {
			name = _('Ready to takeoff'),
			items = {
				{ name = _('Request takeoff'), 				command = sendMessage.new(Message.wMsgLeaderRequestTakeOff) },
				{ name = _('Abort takeoff'), 				command = sendMessage.new(Message.wMsgLeaderAbortTakeoff) },
				{ name = _('Request control hover'),
					command = sendMessage.new(Message.wMsgLeaderRequestControlHover),
					condition = {
						check = function(self)
							return data.pUnit:hasAttribute('Helicopters')
						end
					}
				}
			}
		},
		['Taking Off'] = {
			name = _('Taking Off'),
			items = {
				{ name = _('Abort takeoff'), 				command = sendMessage.new(Message.wMsgLeaderAbortTakeoff) }
			}
		}
	}
}
dialogsData.dialogs['Departure Ship'].stages = {
	['Closed'] = {	
		[events.NOTIFY_BIRTH_ON_SHIP_HOT]					= { menu = dialogsData.dialogs['Departure Ship'].menus['Taking Off'], newStage = 'Taking Off' },
		[events.DENY_TAKEOFF_FROM_SHIP] 					= { menu = dialogsData.dialogs['Departure Ship'].menus['Ready to takeoff'], newStage = 'Ready to takeoff' },
		[events.CLEAR_TO_TAKEOFF_FROM_SHIP]					= { menu = dialogsData.dialogs['Departure Ship'].menus['Taking Off'], newStage = 'Taking Off' },
		[events.STARTUP_PERMISSION_FROM_SHIP] 				= { menu = dialogsData.dialogs['Departure Ship'].menus['Ready to takeoff'], newStage = 'Ready to takeoff' },
		[events.TAKEOFF] 									= TERMINATE(),
		[events.LANDING]									= { menu = dialogsData.dialogs['Departure Ship'].menus['Ready to takeoff'], newStage = 'Ready to takeoff' }
	},
	['Hover Check'] = {
		[Message.wMsgATCYouHadTakenOffWithNoPermission]		= TERMINATE(),
		[Message.wMsgATCTaxiToParkingArea]					= TERMINATE(),
		[events.ENGINE_SHUTDOWN]							= TERMINATE()
	},
	['Ready to takeoff'] = {
		[Message.wMsgATCClearedControlHover]				= { menu = dialogsData.dialogs['Departure Ship'].menus['Hover Check'], newStage = 'Hover Check' },
		[Message.wMsgATCYouAreClearedForTO]					= { menu = dialogsData.dialogs['Departure Ship'].menus['Taking Off'], newStage = 'Taking Off' },
		[events.TAKEOFF] 									= TERMINATE(),
		[Message.wMsgATCTaxiToParkingArea]					= TERMINATE(),
		[events.ENGINE_SHUTDOWN]							= TERMINATE()
	},
	['Taking Off'] = {
		[events.TAKEOFF] 									= TERMINATE(),
		[Message.wMsgATCTaxiToParkingArea]					= TERMINATE(),
		[events.ENGINE_SHUTDOWN]							= TERMINATE()
	}
}

--Arrival

dialogsData.dialogs['Arrival'] = {}
dialogsData.dialogs['Arrival'].name = _('Arrival')
dialogsData.dialogs['Arrival'].menus = {}
dialogsData.dialogs['Arrival'].menus['Inbound'] = {
	name = _('Inbound'),
	items = {
		{ name = _('Abort Inbound'), 						command = sendMessage.new(Message.wMsgLeaderAbortInbound) },
		{ name = _('I\'m lost'), 							command = sendMessage.new(Message.wMsgLeaderRequestAzimuth)},		
	}
}
dialogsData.dialogs['Arrival'].menus['Orbit'] = {
	name = _('Orbit'),
	items = {
		{ name = _('Abort Inbound'), 						command = sendMessage.new(Message.wMsgLeaderAbortInbound) },
		{ name = _('I\'m lost'), 							command = sendMessage.new(Message.wMsgLeaderRequestAzimuth)}
	}
}
dialogsData.dialogs['Arrival'].menus['Ready to land'] = {
	name = _('Ready to land'),
	items = {
		{ name = _('Request Landing'), 						command = sendMessage.new(Message.wMsgLeaderRequestLanding) },
		{ name = _('Abort Inbound'), 						command = sendMessage.new(Message.wMsgLeaderAbortInbound) },
		{ name = _('I\'m lost'), 							command = sendMessage.new(Message.wMsgLeaderRequestAzimuth)}
	}
}
dialogsData.dialogs['Arrival'].menus['Landing'] = {
	name = _('Landing'),
	items = {
		{ name = _('Abort Inbound'), 						command = sendMessage.new(Message.wMsgLeaderAbortInbound) }		
	}
}
dialogsData.dialogs['Arrival'].menus['Parking'] = {
	name = _('Parking'),
	items = {
		{ name = _('Request takeoff'), 						command = sendMessage.new(Message.wMsgLeaderRequestTakeOff) },
	}
}

dialogsData.dialogs['Arrival'].stages = {
	['Closed'] = {
		[Message.wMsgATCFlyHeading] 					= TO_STAGE('Arrival', 'Inbound'),
		[Message.wMsgATCGoAround]						= TO_STAGE('Arrival', 'Ready to land'),
		[events.LANDING]								= TO_STAGE('Arrival', 'Parking'),
		[Message.wMsgATCTaxiToParkingArea]				= TO_STAGE('Arrival', 'Parking'),
		[Message.wMsgLeaderAbortInbound]				= TERMINATE()
	},
	['Inbound'] = {
		[Message.wMsgATCOrbitForSpacing] 				= TO_STAGE('Arrival', 'Orbit'),
		[Message.wMsgATCClearedForVisual] 				= TO_STAGE('Arrival', 'Ready to land'),
		[events.LANDING]								= TO_STAGE('Arrival', 'Parking'),
		[Message.wMsgLeaderAbortInbound]				= TERMINATE()		
	},
	['Orbit'] = {
		[Message.wMsgATCClearedForVisual] 				= TO_STAGE('Arrival', 'Ready to land'),
		[events.LANDING]								= TO_STAGE('Arrival', 'Parking'),
		[Message.wMsgLeaderAbortInbound]				= TERMINATE(),
	},
	['Ready to land'] = {
		[Message.wMsgATCYouAreClearedForLanding] 		= TO_STAGE('Arrival', 'Landing'),
		[Message.wMsgATCCheckLandingGear]				= TO_STAGE('Arrival', 'Landing'),
		[Message.wMsgATCOrbitForSpacing] 				= TO_STAGE('Arrival', 'Orbit'),
		[events.LANDING]								= TO_STAGE('Arrival', 'Parking'),
		[Message.wMsgLeaderAbortInbound]				= TERMINATE(),
		[Message.wMsgATCGoSecondary]					= TERMINATE(),
	},
	['Landing'] = {
		[Message.wMsgATCGoAround]						= TO_STAGE('Arrival', 'Ready to land'),
		[events.LANDING]								= TO_STAGE('Arrival', 'Parking'),
		[Message.wMsgLeaderAbortInbound]				= TERMINATE(),
		[Message.wMsgATCGoSecondary]					= TERMINATE(),
	},
	['Parking'] = {
		[events.ENGINE_SHUTDOWN]						= TERMINATE(),
		[Message.wMsgATCTaxiDenied]						= TERMINATE(),
		[Message.wMsgATCClearedToTaxiRunWay]			= TERMINATE(),
		[Message.wMsgATCYouAreClearedForTO]				= TERMINATE(),
		[Message.wMsgATCTakeoffDenied]					= TERMINATE(),
		[events.TAKEOFF] 								= TERMINATE(),
	}
}

--Dialog Triggers

local arrivalDialogTrigger = DialogStartTrigger:new(dialogsData.dialogs['Arrival'])
dialogsData.triggers[Message.wMsgATCFlyHeading] 				= arrivalDialogTrigger
dialogsData.triggers[Message.wMsgATCGoAround] 					= arrivalDialogTrigger
dialogsData.triggers[Message.wMsgATCTaxiToParkingArea]			= arrivalDialogTrigger

local departureAirdromeDialogTrigger = DialogStartTrigger:new(dialogsData.dialogs['Departure Airdrome'])
dialogsData.triggers[events.NOTIFY_BIRTH_ON_RAMP_HOT]				= departureAirdromeDialogTrigger
dialogsData.triggers[events.NOTIFY_BIRTH_ON_RUNWAY]					= departureAirdromeDialogTrigger
dialogsData.triggers[events.STARTUP_PERMISSION_FROM_AIRDROME]		= departureAirdromeDialogTrigger
dialogsData.triggers[Message.wMsgATCClearedToTaxiRunWay]			= departureAirdromeDialogTrigger
dialogsData.triggers[events.DENY_TAKEOFF_FROM_AIRDROME]				= departureAirdromeDialogTrigger
dialogsData.triggers[events.CLEAR_TO_TAKEOFF_FROM_AIRDROME]			= departureAirdromeDialogTrigger

local departureHelipadDialogTrigger = DialogStartTrigger:new(dialogsData.dialogs['Departure Helipad'])
dialogsData.triggers[events.NOTIFY_BIRTH_ON_HELIPAD_HOT]			= departureHelipadDialogTrigger
dialogsData.triggers[events.STARTUP_PERMISSION_FROM_HELIPAD]		= departureHelipadDialogTrigger
dialogsData.triggers[events.DENY_TAKEOFF_FROM_HELIPAD]				= departureHelipadDialogTrigger
dialogsData.triggers[events.CLEAR_TO_TAKEOFF_FROM_HELIPAD]			= departureHelipadDialogTrigger

local departureShipDialogTrigger = DialogStartTrigger:new(dialogsData.dialogs['Departure Ship'])
dialogsData.triggers[events.NOTIFY_BIRTH_ON_SHIP_HOT]				= departureShipDialogTrigger
dialogsData.triggers[events.STARTUP_PERMISSION_FROM_SHIP]			= departureShipDialogTrigger
dialogsData.triggers[events.DENY_TAKEOFF_FROM_SHIP]					= departureShipDialogTrigger
dialogsData.triggers[events.CLEAR_TO_TAKEOFF_FROM_SHIP]				= departureShipDialogTrigger
	--Event Handler

local enginesAreStarted = false

local worldEventHandler = {
	onEvent = function(self, event)
		--print('data.pUnit = '..tostring(data.pUnit and data.pUnit))
		--print('event.id = '..tostring(event.id))
		--print('event.initiator = '..tostring(event.initiator))
		if event.initiator == data.pUnit then
			local airbaseCommunicator= nil
			if event.place ~= nil and event.place:isExist() then
				airbaseCommunicator = event.place:getCommunicator()
			end
			if event.id == world.event.S_EVENT_BIRTH then
				if event.place ~= nil then
					--print('event.subPlace = '..tostring(event.subPlace))
					if event.subPlace == world.BirthPlace.wsBirthPlace_Park then
						return events.NOTIFY_BIRTH_ON_RAMP_COLD, airbaseCommunicator
					elseif event.subPlace == world.BirthPlace.wsBirthPlace_Park_Hot then
						enginesAreStarted = true
						return events.NOTIFY_BIRTH_ON_RAMP_HOT, airbaseCommunicator
					elseif event.subPlace == world.BirthPlace.wsBirthPlace_RunWay then
						enginesAreStarted = true
						return events.NOTIFY_BIRTH_ON_RUNWAY, airbaseCommunicator
					elseif event.subPlace == world.BirthPlace.wsBirthPlace_Heliport_Cold then
						return events.NOTIFY_BIRTH_ON_HELIPAD_COLD, airbaseCommunicator
					elseif event.subPlace == world.BirthPlace.wsBirthPlace_Heliport_Hot then
						enginesAreStarted = true
						return events.NOTIFY_BIRTH_ON_HELIPAD_HOT, airbaseCommunicator
					elseif event.subPlace == world.BirthPlace.wsBirthPlace_Ship_Cold then
						return events.NOTIFY_BIRTH_ON_SHIP_COLD, airbaseCommunicator
					elseif event.subPlace == world.BirthPlace.wsBirthPlace_Ship then
						enginesAreStarted = true
						return events.NOTIFY_BIRTH_ON_SHIP_HOT, airbaseCommunicator
					end
				end
			elseif event.id == world.event.S_EVENT_TAKEOFF then
				return events.TAKEOFF, airbaseCommunicator
			elseif event.id == world.event.S_EVENT_LAND then
				return events.LANDING, airbaseCommunicator
			elseif event.id == world.event.S_EVENT_ENGINE_STARTUP then
				enginesAreStarted = true
				return events.ENGINE_STARTUP, airbaseCommunicator
			elseif event.id == world.event.S_EVENT_ENGINE_SHUTDOWN then
				enginesAreStarted = false
				return events.ENGINE_SHUTDOWN, airbaseCommunicator
			end
		end
	end
}

table.insert(data.worldEventHandlers, worldEventHandler)

--Message Handler

local msgHandler = {
	onMsg = function(self, pMessage, pRecepient)
		self:onMsgEvent(pMessage:getEvent(), pMessage:getSender(), pRecepient)
	end,
	onMsgEvent = function(self, event, pMsgSender, pRecepient)
		local pUnit = pMsgSender:getUnit()
		local nUnitCategory = pUnit:getCategory()
		if nUnitCategory == Object.Category.BASE or nUnitCategory == Object.Category.UNIT then
			local airbaseCategory = pUnit:getDesc().category
			if event == Message.wMsgATCClearedForEngineStartUp then
				if airbaseCategory == Airbase.Category.HELIPAD then
					return events.STARTUP_PERMISSION_FROM_HELIPAD
				elseif airbaseCategory == Airbase.Category.AIRDROME then
					return events.STARTUP_PERMISSION_FROM_AIRDROME
				elseif airbaseCategory == Airbase.Category.SHIP then
					return events.STARTUP_PERMISSION_FROM_SHIP
				end
			elseif event == Message.wMsgATCTakeoffDenied then
				local typeName = pMsgSender:getUnit():getTypeName()
				if airbaseCategory == Airbase.Category.HELIPAD then
					return events.DENY_TAKEOFF_FROM_HELIPAD
				elseif airbaseCategory == Airbase.Category.AIRDROME then
					return events.DENY_TAKEOFF_FROM_AIRDROME
				elseif airbaseCategory == Airbase.Category.SHIP then
					return events.DENY_TAKEOFF_FROM_SHIP
				end
			elseif event == Message.wMsgATCYouAreClearedForTO then
				local typeName = pMsgSender:getUnit():getTypeName()
				if airbaseCategory == Airbase.Category.HELIPAD then
					return events.CLEAR_TO_TAKEOFF_FROM_HELIPAD
				elseif airbaseCategory == Airbase.Category.AIRDROME then
					return events.CLEAR_TO_TAKEOFF_FROM_AIRDROME
				elseif airbaseCategory == Airbase.Category.SHIP then
					return events.CLEAR_TO_TAKEOFF_FROM_SHIP
				end
			end
		end
	end	
}

table.insert(data.msgHandlers, msgHandler)