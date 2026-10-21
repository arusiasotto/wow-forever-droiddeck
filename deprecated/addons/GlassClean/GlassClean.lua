local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")

local function hide(name)
    local frame = _G[name]
    if frame and frame.Hide then
        frame:Hide()
        if frame.SetScript then
            pcall(frame.SetScript, frame, "OnShow", frame.Hide)
        end
    end
end

local function apply()
    local ns = _G.GodMacro
    if ns and ns.HUD then
        local c = ns.HUD.Config()
        c.palette = "glass"
        c.enabled = true
        if ns.HUD.ApplyPreset then
            ns.HUD.ApplyPreset("minimal")
        end
        if c.modules.swings then c.modules.swings.enabled = false end
        if c.modules.player then c.modules.player.showDetails = false end
        if c.modules.target then c.modules.target.showDetails = false end
        if ns.HUD.UI then
            ns.HUD.UI.ApplyLayout()
            if ns.HUD.UI.Refresh then ns.HUD.UI.Refresh() end
            if ns.HUD.UI.Render then ns.HUD.UI.Render(1) end
        end
    end
    if ns and ns.db and ns.db.global and ns.db.global.bar then
        ns.db.global.bar.enabled = false
        if ns.BarUI and ns.BarUI.Refresh then ns.BarUI.Refresh() end
    end
    if ns and ns.Overlay and ns.Overlay.Hide then ns.Overlay.Hide() end
    if ns and ns.UI and ns.UI.Hide then ns.UI.Hide(true) end
    for _, name in ipairs({
        "PlayerFrame", "TargetFrame", "FocusFrame", "PetFrame", "BuffFrame",
        "TemporaryEnchantFrame", "CastingBarFrame", "GodMacroBar",
    }) do
        hide(name)
    end
end

f:SetScript("OnEvent", function()
    apply()
    if C_Timer and C_Timer.After then
        C_Timer.After(1, apply)
        C_Timer.After(3, apply)
    end
end)
