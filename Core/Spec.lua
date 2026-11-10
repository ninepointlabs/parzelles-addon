-- Spec definitions: names, roles, palette, icons.
local _, ns = ...

ns.SPEC_ORDER = { "Arcane", "Fire", "Frost" }

-- Palette (brief): arcane violet/blue, ember orange/gold, ice blue/white.
-- Icons are the standard Mage spec icons, the same art Blizzard's icon CDN serves.
ns.Specs = {
    Arcane = {
        key = "Arcane", role = "Damage",
        icon = "Interface\\Icons\\Spell_Holy_MagicalSentry",
        accent = { 0.690, 0.533, 1.00 }, accent2 = { 0.502, 0.690, 1.00 },
        tree = "Arcane", weights = "Arcane",
        blurb = "Arcane Blast stacks, free Arcane Missiles from Missile Barrage and Arcane Wrath burst. Strong mana regen; a solid leveler in Forever.",
    },
    Fire = {
        key = "Fire", role = "Damage",
        icon = "Interface\\Icons\\Spell_Fire_FireBolt02",
        accent = { 1.00, 0.549, 0.200 }, accent2 = { 1.00, 0.820, 0.302 },
        tree = "Fire", weights = "Fire",
        blurb = "Crits build Heating Up for fast Pyroblasts, plus Ignite and Fire Blast. Hits hardest, drinks the most.",
    },
    Frost = {
        key = "Frost", role = "Damage",
        icon = "Interface\\Icons\\Spell_Frost_FrostBolt02",
        accent = { 0.494, 0.808, 1.00 }, accent2 = { 0.906, 0.969, 1.00 },
        tree = "Frost", weights = "Frost",
        blurb = "Frostbolt, Fingers of Frost and Ice Lance on frozen targets, Frost Nova to stay safe. The safest way to level.",
    },
}

-- What the research recommends before talents (Parzelle hadn't picked one at level 8):
-- Frost is the safest leveler; Arcane is viable on its own in Forever.
ns.RECOMMENDED_LEVELING_SPEC = "Frost"

-- Neutral palette used before a spec is picked.
ns.NeutralAccent = { 0.80, 0.84, 0.95 }
ns.NEUTRAL_ICON = "Interface\\Icons\\Spell_Holy_MagicalSentry"

function ns.SpecAccent(spec)
    local s = ns.Specs[spec or (ns.DB and ns.DB.char and ns.DB.ActiveSpec())]
    return s and s.accent or ns.NeutralAccent
end

-- Every Mage spec deals damage; kept so shared code reads like Andric's.
function ns.IsHealer() return false end
