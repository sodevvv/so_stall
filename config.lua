
local MainConfig <const> = {
    UsableItemName = 'stall',
    Props = "prop_hotdogstand_01", 

    products = {
        { label = "Burger", name = "burger", price = 5, type = "Nourritures", stock = 10},
        { label = "Hot Dog", name = "hotdog", price = 3, type = "Nourritures", stock = 10},
        { label = "Cola", name = "cola", price = 2, type = "Boissons", stock = 10},
        { label = "Pepsi", name = "pepsi", price = 4, type = "Boissons", stock = 10},
    }
}

_ENV.MainConfig = MainConfig
