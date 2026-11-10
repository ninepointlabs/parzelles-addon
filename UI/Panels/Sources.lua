-- Settings › About the data: client info, research gaps, conflicts, assumptions, sources.
local _, ns = ...
local UI = ns.UI

UI.SettingsSections = UI.SettingsSections or {}

UI.SettingsSections["About the data"] = function(L, c)
    local meta = ns.Data.Meta
    L:Label("Client")
    L:Row({ title = ("Built for %s · Interface %s · project %s"):format(meta.game, tostring(meta.toc_interface), meta.wow_project_id),
        sub = ("Research build %s\nYour client %s (WOW_PROJECT_ID %s)"):format(meta.latest_build_seen,
            table.concat({ GetBuildInfo() }, " / "), tostring(WOW_PROJECT_ID)) })
    L:Note(meta.api_note)

    L:Label("Research gaps (the addon doesn't guess these)")
    for _, g in ipairs(ns.Data.Gaps) do
        L:Row({ chip = { text = "Gap", kind = "warn" }, title = g.gap })
        L:Source(g)
    end
    L:Label("Conflicts between sources")
    for _, cf in ipairs(ns.Data.Conflicts or {}) do
        L:Row({ chip = { text = "Conflict", kind = "info" }, title = cf.topic or "?", sub = cf.detail })
        L:Source(cf)
    end
    L:Label("Addon assumptions")
    L:Row({ title = "Gear scores use rank-derived weights from each spec's stat priority, not simulations." })
    L:Row({ title = "Hit/crit % are scaled by " .. ns.db.global.percentScale .. " points per 1% (Tooltips & bags tab)." })
    L:Row({ title = "Spell damage counts for your spec's school (Arcane, Fire or Frost) plus all-school damage; other schools are shown but not weighted." })
    L:Row({ title = "Conjured items are recognised from their tooltip text, since Forever's conjured food/water names aren't sourced." })
    L:Row({ title = "Tooltip stat parsing reads English item text." })

    L:Label("Sources")
    local keys = {}
    for k in pairs(ns.Data.Sources) do table.insert(keys, k) end
    table.sort(keys)
    for _, k in ipairs(keys) do L:Link(k, ns.Data.Sources[k]) end
end
