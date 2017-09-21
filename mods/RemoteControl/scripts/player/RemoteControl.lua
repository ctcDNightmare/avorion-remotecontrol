
-- namespace RemoteControl
RemoteControl = {}

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

function RemoteControl.initialize()
    if onServer() then
        -- load required libs
        for _,lib in pairs(requiredLibs) do
            if not pcall(require, libPath .. lib) then
                print('failed loading ' .. lib)
            end
        end
        Player():registerCallback("onSectorEntered", "findShips")
        Player():registerCallback("onShipChanged", "onShipChanged")

        local serialized = Player():getValue(channels.orders)
        local orders
        if serialized then
            orders = loadstring(serialized)()
        else
            orders = {}
        end
        Player():setValue(channels.orders, serialize(orders))

        local CurrentShip = Player().craftIndex
        MoveUILoader.onShipChanged(Player().index, CurrentShip)
    end
end

function RemoteControl.ping()
    displayChatMessage('Pong!', MODULE, 0)
end

function RemoteControl.attachToShip(name)
    local sector = Sector()
    if sector then
        local x, y = sector:getCoordinates()
        local allShips = {sector:getEntitiesByType(EntityType.Ship) }
        for _,ship in pairs(allShips) do
            if ship.name == name then
                if ship.hasPilot or ship:getCrewMembers(CrewProfessionType.Captain) == 0 then
                    break
                end
                ship:addScriptOnce("mods/RemoteControl/scripts/entity/ai/RemoteControl")
                print(ship.name .. ' @ ' .. x .. ':' .. y)
                print('Adding to fleet!')
                local serialized = Player():getValue(channels.fleet)
                local fleet
                if serialized then
                    fleet = loadstring(serialized)()
                else
                    fleet = {}
                end
                fleet[ship.id.string] = newShip
                Player():setValue(channels.fleet, serialize(fleet))
            end
        end
    end
end

function RemoteControl.findShips()
    local shipnames = {Player():getShipNames(Player()) }
    for _, name in pairs(shipnames) do
        RemoteControl.attachToShip(name)
    end
end

function RemoteControl.onShipChanged(playerIndex, craftIndex)
    if Player().index ~= playerIndex then return end  --WTF, why is this function run against every player?
    local ship = Entity(craftIndex) --assign the ship entity so we can protect it later
    if not ship then return end
    local faction = Faction(ship.factionIndex)
    if faction.isPlayer or faction.isAlliance then
        if not ship:hasScript(basePath .. '/scripts/ui/RemoteControl') then
            ship:addScriptOnce(basePath .. '/scripts/ui/RemoteControl')
        end
    end
end