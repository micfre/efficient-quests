-- Shared addon loader for the Lua suites: run every file the addon's TOC
-- ships, in TOC order, the way the game would load it. Each suite loads
-- this once with its own substituted game services in place, and every
-- suite stays individually runnable from the repository root.
return function()
  for line in io.lines('EfficientQuests/EfficientQuests.toc') do
    if line:match('%.lua$') then assert(loadfile('EfficientQuests/' .. line))('EfficientQuests', {}) end
  end
end
