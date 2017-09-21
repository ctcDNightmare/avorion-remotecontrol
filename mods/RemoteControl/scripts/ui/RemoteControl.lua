package.path = package.path .. ";data/scripts/lib/?.lua"
require ("stringutility")
require ("utility")

-- constants
local MODULE = 'RemoteControl' -- our module name
local FS = '::' -- field separator

-- general
local libPath = "mods/ctccommon/scripts/lib"
local basePath = "mods/" .. MODULE
local modConfig = require(basePath .. '/config/' .. MODULE)
local requiredLibs = {'/serialize' }

local window
local uiGroups = {}

local channels = {
fleet = MODULE .. FS .. 'fleet',
orders = MODULE .. FS .. 'orders'
}

function initialize()
    -- load required libs
    for _,lib in pairs(requiredLibs) do
        if not pcall(require, libPath .. lib) then
            print('failed loading ' .. lib)
        end
    end
end

function interactionPossible(playerIndex)
    local factionIndex = Entity().factionIndex
    if factionIndex == playerIndex or factionIndex == Player().allianceIndex then
        return true
    end
    return false
end

function getIcon()
    return "data/textures/icons/radar-dish.png"
end

function initUI()

    local res = getResolution()
    local size = vec2(500, 250)

    local menu = ScriptUI()
    window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))

    window.caption = "RemoteControl"
    window.showCloseButton = 1
    window.moveable = 1
    menu:registerWindow(window, "RemoteControl");

    local btnMine = window:createButton(Rect(size.x - 210, 15, size.x - 10, 55), "Mine" % _t, "onButtonPressed")
    local btnSalvage = window:createButton(Rect(size.x - 210, 60, size.x - 10, 100), "Salvage" % _t, "onButtonPressed")
    local btnIdle = window:createButton(Rect(size.x - 210, 105, size.x - 10, 145), "Idle" % _t, "onButtonPressed")
    local btnRendevouz = window:createButton(Rect(size.x - 210, 150, size.x - 10, 190), "rendezvous" % _t, "onButtonPressed")

    table.insert(uiGroups, {
        order = 'mine',
        button = btnMine
    })

    table.insert(uiGroups, {
        order = 'salvage',
        button = btnSalvage
    })

    table.insert(uiGroups, {
        order = 'idle',
        button = btnIdle
    })

    table.insert(uiGroups, {
        order = 'rendezvous',
        button = btnRendevouz
    })

end

function onButtonPressed(button)
    local fleet
    local serialized = Player():getValue(channels.fleet)
    if serialized then
        fleet = loadstring(serialized)()
    else
        fleet = {}
    end
    local orders = {}
    local newOrder
    for _,group in pairs(uiGroups) do
        if group.button.index == button.index then
            newOrder = group.order
        end
    end

    -- for now, sending command to all ships
    if newOrder then
        for id,_ in pairs(fleet) do
            orders[id] = newOrder
        end
        invokeServerFunction('setPlayerValue', Player().index, channels.orders, serialize(orders))
    end
end

function setPlayerValue(playerIndex, key, value)
    Player(playerIndex):setValue(key, value)
end