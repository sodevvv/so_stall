local stall = {
    props = {},
    products = {},
    isPlacing = false
}


RegisterNetEvent(GetCurrentResourceName() .. ':SpawnStand')
AddEventHandler(GetCurrentResourceName() .. ':SpawnStand', function ()
    if not stall.isPlacing then
        stall.isPlacing = true

        if lib.progressBar({
                duration = 4000,
                label = 'Installation du stand de nourriture',
                useWhileDead = false,
                canCancel = true,
                disable = {
                    car = true,
                    move = true,
                    combat = true,
                },
                anim = {
                    dict = 'mp_car_bomb',
                    clip = 'car_bomb_mechanic'
                },
            }) then
            local props = MainConfig.Props
            local model = props

            if type(props) == 'string' then
                model = GetHashKey(props)
            end

            local playerPed = PlayerPedId()
            local coords = GetEntityCoords(playerPed)
            local heading = GetEntityHeading(playerPed)
            local forward = GetEntityForwardVector(playerPed)
            local spawnPos = coords + (forward * 2.0)

            RequestModel(model)
            local timeout = GetGameTimer() + 5000
            while not HasModelLoaded(model) and GetGameTimer() < timeout do
                Wait(0)
            end

            if HasModelLoaded(model) then
                local obj = CreateObject(model, spawnPos.x, spawnPos.y, spawnPos.z - 1.0, true, true, false)
                SetEntityHeading(obj, heading)
                PlaceObjectOnGroundProperly(obj)
                FreezeEntityPosition(obj, true)
                SetModelAsNoLongerNeeded(model)

                local netId = NetworkGetNetworkIdFromEntity(obj)
                local stallId = lib.callback.await(GetCurrentResourceName() .. ':CreateStand', false, netId)

                if stallId then
                    stall.props[stallId] = obj

                    lib.notify({
                        title = "Stand de nourriture",
                        description = "Vous avez installé un stand de nourriture.",
                        icon = "fas fa-check",
                        position = "bottom-center",
                        duration = 5000
                    })
                else
                    stall:DeleteProp(obj)
                    lib.notify({
                        title = "Stand de nourriture",
                        description = "Impossible d'installer le stand de nourriture.",
                        icon = "fas fa-xmark",
                        type = "error",
                        position = "bottom-center",
                        duration = 5000
                    })
                end
            else
                lib.notify({
                    title = "Stand de nourriture",
                    description = "Impossible de charger le modèle du stand.",
                    icon = "fas fa-xmark",
                    type = "error",
                    position = "bottom-center",
                    duration = 5000
                })
            end
        end

        stall.isPlacing = false
    end
end)


function stall:OpenStallProducts(stallId)
    local options = {}
    local stocks = lib.callback.await(GetCurrentResourceName() .. ':GetStock', false, stallId)

    if stocks then
        local categories = {}

        for _, v in ipairs(MainConfig.products) do
            local stock = stocks[v.name] or 0
            categories[v.type] = (categories[v.type] or 0) + stock
        end

        for category, stock in pairs(categories) do
            table.insert(options, {
                title = ("%s - Stock total : %s"):format(category, stock),
                disabled = true,
            })
        end
        table.insert(options, {
            title = "Renouveler les stocks",
            description = "Renouveler les stocks de vos produits.",
            icon = "fas fa-box",
            onSelect = function()
               local input = lib.inputDialog("Renouveler les stocks", {
                 {type = "select", label = "Moyen de payements", options = {
                    {label = "Cash", value = "cash"},
                    {label = "Banque", value = "bank"},
                 }, required = true},
               })

               if input then
                    if input[1] == "cash" then
                        TriggerServerEvent(GetCurrentResourceName() .. ':RestockProducts', "cash", stallId)
                    end

                    if input[1] == "bank" then
                        TriggerServerEvent(GetCurrentResourceName() .. ':RestockProducts', "bank", stallId)
                    end
               end
            end
        })
        for _, v in ipairs(MainConfig.products) do
            local stock = stocks[v.name] or 0
            table.insert(options, {
                title = v.label,
                description = ("Prix de revente : $%s"):format(v.price),
                icon = "fas fa-box",
                disabled = stock <= 0,
                onSelect = function()
                    TriggerServerEvent(GetCurrentResourceName() .. ':GiveProducts', v.name, stallId)
                    stall:OpenStallProducts(stallId)
                end
            })
        end

        lib.registerContext({
            id = "_stall:products:" .. stallId,
            title = "Gérer vos produits",
            menu = "_stall:open:" .. stallId,
            options = options
        })

        lib.showContext("_stall:products:" .. stallId)
    else
        lib.notify({
            title = "Stand de nourriture",
            description = "Ce stand n'existe plus ou ne vous appartient pas.",
            icon = "fas fa-xmark",
            type = "error",
            position = "bottom-center",
            duration = 5000
        })
    end
end
function stall:OpenStall(stallId)
    lib.registerContext({
        id = "_stall:open:" .. stallId,
        title = "Gérer le stand",
        options = {
            {
                title = "Supprimer le stand",
                description = "Supprime le stand de nourriture.",
                icon = "fas fa-trash",
                onSelect = function()
                    stall:RemoveStallById(stallId)
                    lib.notify({
                        title = "Stand de nourriture",
                        description = "Vous avez supprimé le stand de nourriture.",
                        icon = "fas fa-check",
                        position = "bottom-center",
                        duration = 5000
                    })

                    TriggerServerEvent(GetCurrentResourceName() .. ':addStall', stallId)
                end
            }, 

            {
                title = "Gérer vos produits",
                description = "Gérer vos produits à vendre.",
                icon = "fas fa-box",
                onSelect = function()
                     stall:OpenStallProducts(stallId)
                end
            }

        }
    })

    lib.showContext("_stall:open:" .. stallId)
end

exports.ox_target:addModel(MainConfig.Props, {
    {
        label = "Gérer le stand",
        icon = "fas fa-box",
        distance = 2.5,
        canInteract = function(entity)
            local canInteract = false
            if NetworkGetEntityIsNetworked(entity) then
                canInteract = Entity(entity).state.stallOwner == GetPlayerServerId(PlayerId())
            end
            return canInteract
        end,
        onSelect = function(data)
            local stallId = nil
            if NetworkGetEntityIsNetworked(data.entity) then
                stallId = Entity(data.entity).state.stallId
            end

            if stallId then
                stall:OpenStall(stallId)
            end
        end
    }
})

AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() == resourceName then
        for stallId, prop in pairs(stall.props) do
            stall:DeleteProp(prop)
            TriggerServerEvent(GetCurrentResourceName() .. ':addStall', stallId)
        end

        stall.props = {}
    end
end)

function stall:DeleteProp(prop)
    if DoesEntityExist(prop) then
        NetworkRequestControlOfEntity(prop)
        SetEntityAsMissionEntity(prop, true, true)
        DeleteEntity(prop)
    end
end

function stall:RemoveAllStall()
    for stallId, prop in pairs(stall.props) do
        stall:DeleteProp(prop)
    end
    stall.props = {}
end

function stall:RemoveStallById(stallId)
    local prop = stall.props[stallId]

    if prop then
        stall:DeleteProp(prop)
        stall.props[stallId] = nil
    end
end

function stall:RemoveStallByEntity(entity)
    for stallId, prop in pairs(stall.props) do
        if prop == entity then
            stall:DeleteProp(prop)
            stall.props[stallId] = nil
            break
        end
    end
end