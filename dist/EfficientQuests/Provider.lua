-- Public QuestieDB adapter. A provider is usable only when it explicitly
-- accepts the contract and exposes the entity accessors we depend on.
function EfficientQuests.GetProvider()
    local provider = _G.LibQuestieDB
    if not provider then return nil, "missing" end
    if type(provider.RequireContract) ~= "function" then return nil, "incompatible" end
    local called, ok = pcall(provider.RequireContract, 1)
    if not called or not ok then return nil, "incompatible" end
    for _, name in ipairs({"Quest", "Npc", "Item", "Object"}) do
        if type(provider[name]) ~= "table" or type(provider[name].Get) ~= "function" then
            return nil, "incompatible"
        end
    end
    return provider
end
