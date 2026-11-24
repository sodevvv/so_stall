local Stalls = {}

local function GetStallModel()
    local model = MainConfig.Props

    if type(model) == 'string' then
        model = GetHashKey(model)
    end

    return model
end

local function GenerateStallId()
    local stallId = math.random(100000, 999999)

    while Stalls[stallId] do
        stallId = math.random(100000, 999999)
    end

    return stallId
end

local function CreateStallStock()
    local stock = {}

    for _, product in ipairs(MainConfig.products) do
        stock[product.name] = product.stock
    end

    return stock
end

local function GetOwnedStall(source, stallId)
    local stall = nil
    local id = nil

    if stallId then
        id = tonumber(stallId)

        if id and Stalls[id] then
            if Stalls[id].owner == source then
                stall = Stalls[id]
            end
        end
    end

    return stall, id
end

local function IsNetIdUsed(netId)
    local used = false

    for _, stall in pairs(Stalls) do
        if stall.netId == netId then
            used = true
        end
    end

    return used
end

local function WaitForStallEntity(netId)
    local entity = 0
    local attempts = 0

    while attempts < 20 and entity == 0 do
        local found = NetworkGetEntityFromNetworkId(netId)

        if found and found ~= 0 and DoesEntityExist(found) then
            entity = found
        else
            attempts = attempts + 1
            Wait(100)
        end
    end

    return entity
end

local function DeleteStallEntity(stall)
    if stall and stall.netId then
        local entity = NetworkGetEntityFromNetworkId(stall.netId)

        if entity and entity ~= 0 and DoesEntityExist(entity) then
            DeleteEntity(entity)
        end
    end
end

lib.callback.register(GetCurrentResourceName() .. ':CreateStand', function(source, netId)
    local stallId = nil
    local xPlayer = ESX.GetPlayerFromId(source)

    if xPlayer and type(netId) == 'number' then
        local entity = WaitForStallEntity(netId)

        if entity ~= 0 and GetEntityModel(entity) == GetStallModel() and not IsNetIdUsed(netId) then
            local item = xPlayer.getInventoryItem(MainConfig.UsableItemName)

            if item and item.count and item.count > 0 then
                xPlayer.removeInventoryItem(MainConfig.UsableItemName, 1)

                stallId = GenerateStallId()

                Stalls[stallId] = {
                    owner = source,
                    netId = netId,
                    stock = CreateStallStock()
                }

                Entity(entity).state:set('stallId', stallId, true)
                Entity(entity).state:set('stallOwner', source, true)
            end
        end
    end

    return stallId
end)

lib.callback.register(GetCurrentResourceName() .. ':GetStock', function(source, stallId)
    local stock = nil
    local stall = GetOwnedStall(source, stallId)

    if stall then
        stock = stall.stock
    end

    return stock
end)

ESX.RegisterUsableItem(MainConfig.UsableItemName, function(source)
    local xPlayer = ESX.GetPlayerFromId(source)

    if xPlayer then
        TriggerClientEvent(GetCurrentResourceName() .. ':SpawnStand', source)
    end
end)

RegisterServerEvent(GetCurrentResourceName() .. ':addStall')
AddEventHandler(GetCurrentResourceName() .. ':addStall', function(stallId)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)

    if xPlayer then
        local stall, id = GetOwnedStall(source, stallId)

        if stall then
            DeleteStallEntity(stall)
            Stalls[id] = nil

            xPlayer.addInventoryItem(MainConfig.UsableItemName, 1)
        end
    end
end)

RegisterServerEvent(GetCurrentResourceName() .. ':GiveProducts')
AddEventHandler(GetCurrentResourceName() .. ':GiveProducts', function(productName, stallId)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)

    if xPlayer then
        local stall = GetOwnedStall(source, stallId)

        if stall then
            local stock = stall.stock[productName]

            if stock then
                if stock <= 0 then
                    TriggerClientEvent('ox_lib:notify', source, {
                        title = 'Stand',
                        description = 'Produit en rupture de stock.',
                        type = 'error',
                        position = "bottom-center",
                        duration = 5000
                    })
                else
                    local canCarry = true

                    if xPlayer.canCarryItem then
                        canCarry = xPlayer.canCarryItem(productName, 1)
                    end

                    if canCarry then
                        stall.stock[productName] = stall.stock[productName] - 1
                        xPlayer.addInventoryItem(productName, 1)
                        TriggerClientEvent('ox_lib:notify', source, {
                            title = 'Stand',
                            description = ('Stock restant : %s'):format(stall.stock[productName]),
                            position = "bottom-center",
                            duration = 5000
                        })
                    else
                        TriggerClientEvent('ox_lib:notify', source, {
                            title = 'Stand',
                            description = 'Vous ne pouvez pas porter plus de ce produit.',
                            type = 'error',
                            position = "bottom-center",
                            duration = 5000
                        })
                    end
                end
            end
        end
    end
end)

RegisterServerEvent(GetCurrentResourceName() .. ':RestockProducts')
AddEventHandler(GetCurrentResourceName() .. ':RestockProducts', function(paymentType, stallId)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)

    if xPlayer then
        local stall = GetOwnedStall(source, stallId)

        if stall then
            local totalPrice = 0

            for _, product in ipairs(MainConfig.products) do
                local currentStock = stall.stock[product.name] or 0
                if currentStock < product.stock then
                    local missingStock = product.stock - currentStock
                    totalPrice = totalPrice + (missingStock * product.price) * 3
                end
            end

            if totalPrice > 0 then
                local canPay = false
                if paymentType == "cash" then
                    if xPlayer.getMoney() >= totalPrice then
                        xPlayer.removeMoney(totalPrice)
                        canPay = true
                    end
                elseif paymentType == "bank" then
                    if xPlayer.getAccount('bank').money >= totalPrice then
                        xPlayer.removeAccountMoney('bank', totalPrice)
                        canPay = true
                    end
                end

                if canPay then
                    for _, product in ipairs(MainConfig.products) do
                        local currentStock = stall.stock[product.name] or 0
                        if currentStock < product.stock then
                            stall.stock[product.name] = product.stock
                        end
                    end
                    TriggerClientEvent('ox_lib:notify', source, {
                        title = 'Stand',
                        description = ('Stocks renouvelés pour $%s'):format(totalPrice),
                        position = "bottom-center",
                        duration = 5000
                    })

                else
                    TriggerClientEvent('ox_lib:notify', source, {
                        title = 'Stand',
                        description = ('Il vous faut $%s'):format(totalPrice),
                        type = 'error',
                        position = "bottom-center",
                        duration = 5000
                    })

                end
            else
                TriggerClientEvent('ox_lib:notify', source, {
                    title = 'Stand',
                    description = 'Tous les stocks sont déjà pleins.',
                    type = 'error',
                    position = "bottom-center",
                    duration = 5000
                })
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local source = source

    for stallId, stall in pairs(Stalls) do
        if stall.owner == source then
            DeleteStallEntity(stall)
            Stalls[stallId] = nil
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        for stallId, stall in pairs(Stalls) do
            local xPlayer = ESX.GetPlayerFromId(stall.owner)

            DeleteStallEntity(stall)
            Stalls[stallId] = nil

            if xPlayer then
                xPlayer.addInventoryItem(MainConfig.UsableItemName, 1)
            end
        end
    end
end)