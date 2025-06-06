AutoLootPlus = {}
AutoLootPlus.name = "AutoLootPlus"
AutoLootPlus.savedVars = {}

local LAM = LibAddonMenu2

-- Lokalisierungstabellen
local localization = {
    ["de"] = {
        LANGUAGE = "Sprache",
        LANGUAGE_TOOLTIP = "Wähle die Sprache für das AddOn.",
        MIN_PRICE = "Mindestwert (Gold)",
        MIN_PRICE_TOOLTIP = "Items unter diesem Preis werden ignoriert. Nutzt LibPrice, falls verfügbar.",
        INCLUDE_STOLEN = "Gestohlene Items looten",
        INCLUDE_STOLEN_TOOLTIP = "Wenn deaktiviert, werden gestohlene Items ignoriert.",
        ONLY_SET_ITEMS = "Nur Set-Items looten",
        ONLY_SET_ITEMS_TOOLTIP = "Lootet nur Gegenstände, die Teil eines Sets sind.",
        ONLY_UNKNOWN_RECIPES = "Nur unbekannte Rezepte",
        ONLY_UNKNOWN_RECIPES_TOOLTIP = "Lootet nur Rezepte, die du noch nicht kennst.",
        QUALITY_FILTER = "Qualitätsfilter",
        ITEM_TYPES = "Itemtypen",
        ARMOR_TYPES = "Rüstungsarten",
        WEAPON_TYPES = "Waffenarten",
    },
    ["en"] = {
        LANGUAGE = "Language",
        LANGUAGE_TOOLTIP = "Choose the language for the addon.",
        MIN_PRICE = "Minimum Value (Gold)",
        MIN_PRICE_TOOLTIP = "Items below this value are ignored. Uses LibPrice if available.",
        INCLUDE_STOLEN = "Loot stolen items",
        INCLUDE_STOLEN_TOOLTIP = "If disabled, stolen items are ignored.",
        ONLY_SET_ITEMS = "Only loot set items",
        ONLY_SET_ITEMS_TOOLTIP = "Loot only items that are part of a set.",
        ONLY_UNKNOWN_RECIPES = "Only unknown recipes",
        ONLY_UNKNOWN_RECIPES_TOOLTIP = "Loot only recipes you don't already know.",
        QUALITY_FILTER = "Quality Filter",
        ITEM_TYPES = "Item Types",
        ARMOR_TYPES = "Armor Types",
        WEAPON_TYPES = "Weapon Types",
    },
}

local function L(key)
    local lang = AutoLootPlus.savedVars and AutoLootPlus.savedVars.language or "de"
    return localization[lang] and localization[lang][key] or key
end

local defaults = {
    language = "de",
    minPrice = 0,
    quality = {
        [ITEM_QUALITY_NORMAL] = true,
        [ITEM_QUALITY_MAGIC] = true,
        [ITEM_QUALITY_ARCANE] = true,
        [ITEM_QUALITY_ARTIFACT] = true,
        [ITEM_QUALITY_LEGENDARY] = true,
    },
    itemTypes = {
        [ITEMTYPE_WEAPON] = true,
        [ITEMTYPE_ARMOR] = true,
        [ITEMTYPE_RECIPE] = true,
        [ITEMTYPE_INGREDIENT] = true,
    },
    armorTypes = {
        [ARMORTYPE_LIGHT] = true,
        [ARMORTYPE_MEDIUM] = true,
        [ARMORTYPE_HEAVY] = true,
    },
    weaponTypes = {
        [WEAPONTYPE_SWORD] = true,
        [WEAPONTYPE_DAGGER] = true,
        [WEAPONTYPE_BOW] = true,
        [WEAPONTYPE_FIRE_STAFF] = true,
    },
    onlySetItems = false,
    onlyUnknownRecipes = false,
    includeStolen = false,
}

local function ShouldLootItem(itemLink, bagId, slotIndex, isStolen)
    local sv = AutoLootPlus.savedVars
    if isStolen and not sv.includeStolen then return false end

    local price = (LibPrice and LibPrice.ItemLinkToPriceGold(itemLink)) or GetItemLinkValue(itemLink)
    if price < sv.minPrice then return false end

    local quality = GetItemLinkQuality(itemLink)
    if not sv.quality[quality] then return false end

    local itemType = GetItemLinkItemType(itemLink)
    if not sv.itemTypes[itemType] then return false end

    if itemType == ITEMTYPE_ARMOR then
        local armorType = GetItemLinkArmorType(itemLink)
        if not sv.armorTypes[armorType] then return false end
    elseif itemType == ITEMTYPE_WEAPON then
        local weaponType = GetItemLinkWeaponType(itemLink)
        if not sv.weaponTypes[weaponType] then return false end
    end

    if sv.onlySetItems and GetItemLinkSetInfo(itemLink) == "" then return false end

    if sv.onlyUnknownRecipes and itemType == ITEMTYPE_RECIPE and IsItemLinkRecipeKnown(itemLink) then
        return false
    end

    return true
end

local function onLootUpdated()
    if IsLooting() then
        for i = 1, GetNumLootItems() do
            local lootId, _, _, _, _, _, _, isStolen = GetLootItemInfo(i)
            local itemLink = GetLootItemLink(lootId, LINK_STYLE_DEFAULT)
            if CanItemLinkBeVirtual(itemLink) and ShouldLootItem(itemLink, BAG_BACKPACK, lootId, isStolen) then
                LootItemById(lootId)
            end
        end
    end
end

local function makeCheckboxTable(varName, labelFunc)
    local controls = {}
    for k, _ in pairs(defaults[varName]) do
        local label = labelFunc(k)
        table.insert(controls, {
            type = "checkbox",
            name = label,
            getFunc = function() return AutoLootPlus.savedVars[varName][k] end,
            setFunc = function(val) AutoLootPlus.savedVars[varName][k] = val end,
            width = "full",
        })
    end
    return controls
end

local function GetItemQualityName(q)
    return zo_strformat("<<C:1>>", GetString("SI_ITEMQUALITY", q))
end

local function GetItemTypeName(t)
    return GetString("SI_ITEMTYPE", t) or tostring(t)
end

local function GetArmorTypeName(t)
    return GetString("SI_ARMORTYPE", t) or tostring(t)
end

local function GetWeaponTypeName(t)
    return GetString("SI_WEAPONTYPE", t) or tostring(t)
end

function AutoLootPlus.OnAddOnLoaded(event, addonName)
    if addonName ~= AutoLootPlus.name then return end

    AutoLootPlus.savedVars = ZO_SavedVars:NewAccountWide("AutoLootPlusSavedVars", 1, nil, defaults)

    local panelData = {
        type = "panel",
        name = "AutoLoot Plus",
        displayName = "|c00FF00AutoLoot Plus|r",
        author = "@JahmesMS",
        version = "1.0",
        registerForRefresh = true,
        registerForDefaults = true,
    }

    local optionsData = {
        {
            type = "dropdown",
            name = L("LANGUAGE"),
            tooltip = L("LANGUAGE_TOOLTIP"),
            choices = { "de", "en" },
            getFunc = function() return AutoLootPlus.savedVars.language end,
            setFunc = function(value)
                AutoLootPlus.savedVars.language = value
                ReloadUI()
            end,
            warning = "Erfordert Neuladen der Benutzeroberfläche.",
        },
        {
            type = "slider",
            name = L("MIN_PRICE"),
            tooltip = L("MIN_PRICE_TOOLTIP"),
            min = 0,
            max = 10000,
            step = 10,
            getFunc = function() return AutoLootPlus.savedVars.minPrice end,
            setFunc = function(value) AutoLootPlus.savedVars.minPrice = value end,
        },
        {
            type = "checkbox",
            name = L("INCLUDE_STOLEN"),
            tooltip = L("INCLUDE_STOLEN_TOOLTIP"),
            getFunc = function() return AutoLootPlus.savedVars.includeStolen end,
            setFunc = function(value) AutoLootPlus.savedVars.includeStolen = value end,
        },
        {
            type = "checkbox",
            name = L("ONLY_SET_ITEMS"),
            tooltip = L("ONLY_SET_ITEMS_TOOLTIP"),
            getFunc = function() return AutoLootPlus.savedVars.onlySetItems end,
            setFunc = function(value) AutoLootPlus.savedVars.onlySetItems = value end,
        },
        {
            type = "checkbox",
            name = L("ONLY_UNKNOWN_RECIPES"),
            tooltip = L("ONLY_UNKNOWN_RECIPES_TOOLTIP"),
            getFunc = function() return AutoLootPlus.savedVars.onlyUnknownRecipes end,
            setFunc = function(value) AutoLootPlus.savedVars.onlyUnknownRecipes = value end,
        },
        {
            type = "submenu",
            name = L("QUALITY_FILTER"),
            tooltip = L("QUALITY_FILTER"),
            controls = makeCheckboxTable("quality", GetItemQualityName),
        },
        {
            type = "submenu",
            name = L("ITEM_TYPES"),
            tooltip = L("ITEM_TYPES"),
            controls = makeCheckboxTable("itemTypes", GetItemTypeName),
        },
        {
            type = "submenu",
            name = L("ARMOR_TYPES"),
            tooltip = L("ARMOR_TYPES"),
            controls = makeCheckboxTable("armorTypes", GetArmorTypeName),
        },
        {
            type = "submenu",
            name = L("WEAPON_TYPES"),
            tooltip = L("WEAPON_TYPES"),
            controls = makeCheckboxTable("weaponTypes", GetWeaponTypeName),
        },
    }

    LAM:RegisterAddonPanel("AutoLootPlusOptions", panelData)
    LAM:RegisterOptionControls("AutoLootPlusOptions", optionsData)

    EVENT_MANAGER:RegisterForEvent(AutoLootPlus.name, EVENT_LOOT_UPDATED, onLootUpdated)
end

EVENT_MANAGER:RegisterForEvent(AutoLootPlus.name, EVENT_ADD_ON_LOADED, AutoLootPlus.OnAddOnLoaded)
