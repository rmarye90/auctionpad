-- Minimal localization: English strings, with translations looked up by client locale.
-- Unknown keys fall through to the key itself so a missing string is visible, not blank.

if not Auctionpad then Auctionpad = {} end
if not Auctionpad.Utils then Auctionpad.Utils = {} end

local Locale = {}
Auctionpad.Utils.Locale = Locale

Locale.translations = {
    frFR = {
        ["Auctionpad"] = "Auctionpad",
        ["Groups"] = "Groupes",
        ["New group"] = "Nouveau groupe",
        ["Group name"] = "Nom du groupe",
        ["Delete group"] = "Supprimer le groupe",
        ["No group yet. Create one to get started."] = "Aucun groupe. Crée-en un pour commencer.",
        ["Drag an item here, or paste an item link."] = "Glisse un objet ici, ou colle un lien d'objet.",
        ["Item"] = "Objet",
        ["Stock"] = "Stock",
        ["On sale"] = "En vente",
        ["Target"] = "Cible",
        ["To post"] = "À poster",
        ["To recraft"] = "À recraft",
        ["Recraft only"] = "À recraft seulement",
        ["Refresh"] = "Rafraîchir",
        ["Add"] = "Ajouter",
        ["Remove"] = "Retirer",
        ["Open the auction house to refresh what is on sale."] =
            "Ouvre l'hôtel des ventes pour actualiser ce qui est en vente.",
        ["On sale: unknown (never seen at the auction house)."] =
            "En vente : inconnu (jamais vu à l'hôtel des ventes).",
        ["On sale as of %s ago."] = "En vente, relevé il y a %s.",
        ["Ready"] = "Complet",
        ["In bank"] = "En banque",
        ["Post"] = "À poster",
        ["Craft"] = "À craft",
        ["Unknown"] = "Inconnu",
        ["%d item"] = "%d objet",
        ["%d items"] = "%d objets",
        ["less than a minute"] = "moins d'une minute",
        ["%d min"] = "%d min",
        ["%d h"] = "%d h",
    },
}

function Locale.get(key)
    local locale = GetLocale and GetLocale() or "enUS"
    local table_for_locale = Locale.translations[locale]
    if table_for_locale and table_for_locale[key] then
        return table_for_locale[key]
    end
    return key
end

-- "less than a minute" / "12 min" / "3 h"
function Locale.format_age(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))

    if seconds < 60 then
        return Locale.get("less than a minute")
    end
    if seconds < 3600 then
        return string.format(Locale.get("%d min"), math.floor(seconds / 60))
    end
    return string.format(Locale.get("%d h"), math.floor(seconds / 3600))
end
