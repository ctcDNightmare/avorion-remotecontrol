package.path = package.path .. ";data/scripts/lib/?.lua"
-- namespace RemoteControl
RemoteControl = {}

-- vanilla libs
require ("stringutility")

-- constants
local MODULE = 'RemoteControl' -- our module name
local FS = '::' -- field separator

-- general
local libPath = "mods/ctccommon/scripts/lib"
local basePath = "mods/" .. MODULE
local modConfig = require(basePath .. '/config/' .. MODULE)
local requiredLibs = {'/serialize'}

-- server
local channels = {
    fleet = MODULE .. FS .. 'fleet',
    orders = MODULE .. FS .. 'orders'
}
local self
local player
local currentOrder
local orders = {}
local isActive
local uninstall = false -- set to true to terminate() scripts on intialize


--[[
-- RemoteControl.getUpdateInterval()
--
-- We don't need fast updates, once every 10 seconds is ok
]]
function RemoteControl.getUpdateInterval()
    return 5
end

--[[
-- RemoteControl.restore(data)
--
-- Tell the player we're back in business
--
-- @param data <table> whatever we need to save between sessions
]]
function RemoteControl.restore(data)
    currentOrder = data.currentOrder
    RemoteControl.setActive(true)
end

--[[
-- RemoteControl.secure()
--
-- TODO: Find a different way to tell if we are inactive / in hibernation
-- Since secure is called after restore and from time to time to save changes to the database we can't use it to set our status
]]
function RemoteControl.secure()
    RemoteControl.setActive(false)

    local data = {}
    data.currentOrder = currentOrder
    return data
end

--[[
-- RemoteControl.logDebug(__function__, message)
--
-- Logging of debugging or general information
--
-- @param __function__ <string> function that called us
-- @param message <string> message to log
--
-- TODO: Future options may include a switch do enable/disable log output, for now it always prints to console
]]
function RemoteControl.logDebug(__function__, message)
    __function__ = __function__ or 'unknown'
    if true then
        if onServer() then
            -- ex. "SERVER::RemoteControl::initialize::Failed to load config"
            print(self.name .. FS .. MODULE .. FS .. __function__ .. FS .. message)
        end
    else
        -- switch to chat or file output in the future, maybe?!
    end
end

--[[
-- RemoteControl.initialize()
--
-- Let's get down with the business and prepare for work
]]
function RemoteControl.initialize()
    local __function__ = 'initialize'
    if uninstall then
        terminate()
    end
    if onServer() then
        self = Entity()
        local startupError
        -- load required libs
        for _,lib in pairs(requiredLibs) do
            if not pcall(require, libPath .. lib) then
                RemoteControl.logDebug(__function__, 'Failed to load required library: ' .. libPath .. lib)
                startupError = 1
            end
        end
        -- load module config
        if not modConfig then
            RemoteControl.logDebug(__function__, 'Failed to load config')
            startupError = 1
        end

        if startupError ~= nil then
            -- something went wrong
            terminate()
        end

        RemoteControl.initOrders()

        local faction = Faction(self.factionIndex)
        if faction then
            if faction.isPlayer then
                player = Player(faction.index)
            else
                RemoteControl.logDebug(__function__, 'Allianceships are currently not supported :(')
                terminate()
            end
        end
        RemoteControl.notifyPlayer('Reporting for duty!')
        RemoteControl.logDebug(__function__, 'Initialization completed!')
    end
end

--[[
-- RemoteControl.notifyPlayer()
--
-- Send responses back via hyperspace-comms to our player
--
-- @param message <string> what we want to send
]]
function RemoteControl.notifyPlayer(message)
    local __function__ = debug.getinfo(1, "n").name
    if onServer() then
        if player and self then
--            RemoteControl.logDebug(__function__, 'Notify player via hyperspace-comms')
            player:sendChatMessage(self.name, 0, message);
        else
--            RemoteControl.logDebug(__function__, 'Hyperspace-comms down, writing to console')
            print('notifyPlayer: ' .. message)
        end
    end
end

--[[
-- RemoteControl.updateServer(timeStep)
--
-- This is where the magic happens (soon)
--
-- @param timeStep <float> time since last call
]]
function RemoteControl.updateServer(timeStep)
    local __function__ = 'updateServer'
    RemoteControl.setActive(true) -- because we don't know when we go to hibernate
    RemoteControl.checkForNewOrder()
end

--[[
-- RemoteControl.setStatus(status)
--
-- Let the player know what we are doing at the moment
--
-- @param status <string> what we are doing right now
]]
function RemoteControl.setStatus(status)
    local __function__ = debug.getinfo(1, "n").name
    if onServer() then
        -- deserialize
        local serialized = player:getValue(channels.fleet)
        if serialized then
            local fleet = loadstring(serialized)()
            if fleet then
                local me = fleet[self.id.string] or {}
                me.status = status
                fleet[self.id.string] = me
                player:setValue(channels.fleet, serialize(fleet))
            end
        end
    end
end

--[[
-- RemoteControl.setActive(active)
--
-- We need to let the player know if we are active and available
--
-- @param active <bool> entity is active or in hibernation
]]
function RemoteControl.setActive(active)
    local __function__ = debug.getinfo(1, "n").name
    if onServer() then
        if isActive ~= active then -- only update if it changed since last check
            -- deserialize
            local serialized = player:getValue(channels.fleet)
            if serialized then
                local fleet = loadstring(serialized)()
                if fleet then
                    local me = fleet[self.id.string] or {}
                    me.active = active
                    fleet[self.id.string] = me
                    player:setValue(channels.fleet, serialize(fleet))
                    isActive = active
                end
            end
        end
    end
end

--[[
-- RemoteControl.checkForNewOrder()
--
-- Check the hyperspace-comms for a new order from the player
]]
function RemoteControl.checkForNewOrder()
    local __function__ = debug.getinfo(1, "n").name
--    RemoteControl.logDebug(__function__, 'Checking for new work...')
    if onServer() then
        -- deserialize
        local serialized = player:getValue(channels.orders)
        if serialized then
            local orders = loadstring(serialized)()
            if type(orders) ~= "table" then
                orders = {}
            end
            local myNewOrder = orders[self.id.string]
            if currentOrder ~= myNewOrder then
                RemoteControl.logDebug(__function__, 'New order "' .. myNewOrder .. '" found. Start processing!')
                RemoteControl.notifyPlayer('Aye, aye Captain!')
                RemoteControl.executeNewOrder(myNewOrder)
            end
        end
    end
end

--[[
-- RemoteControl.executeNewOrder(newOrder)
--
-- If we find a new order given from the player, try to execute it
--
-- @param newOrder <string> our new workorder
]]
function RemoteControl.executeNewOrder(newOrder)
    local __function__ = debug.getinfo(1, "n").name
    local success
    if type(orders[newOrder]) == "function" then
        success = orders[newOrder]()
    end
    if success then
        RemoteControl.logDebug(__function__, 'Successfully executed "' .. newOrder .. '"')
        currentOrder = newOrder
        RemoteControl.setStatus(currentOrder)
    else
        RemoteControl.logDebug(__function__, 'There was an error processing "' .. newOrder .. '"')
    end
end

--[[
-- RemoteControl.executeNewOrder(newOrder)
--
-- Initialize all possible order-options
]]
function RemoteControl.initOrders()
    local __function__ = debug.getinfo(1, "n").name

    RemoteControl.logDebug(__function__, 'Initializing "idle"')
    -- "idle" aka "do nothing"
    orders['idle'] = function()
        RemoteControl.notifyPlayer('Standing by...')
        return true
    end

    RemoteControl.logDebug(__function__, 'Initializing "mine"')
    -- "mine" start gathering minerals
    orders['mine'] = function()
        RemoteControl.notifyPlayer('Hunting asteroids!')
        return true
    end

    RemoteControl.logDebug(__function__, 'Initializing "salvage"')
    -- "salvage" recycle junk
    orders['salvage'] = function()
        RemoteControl.notifyPlayer('Tasty wreckages ahead.')
        return true
    end

    -- "rendezvous" meet up with the player
    RemoteControl.logDebug(__function__, 'Initializing "rendezvous"')
    orders['rendezvous'] = function()
        RemoteControl.notifyPlayer('Got it, we need to talk.')
        return true
    end

    return false
end
