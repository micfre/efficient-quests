-- Shared addon loader for the Lua suites: run every file the addon's TOC
-- ships, in TOC order, the way the game would load it. The game hands
-- every file of one addon the same private table as the second vararg, so
-- the loader keeps one shared namespace for them all: the generated data
-- files fill that namespace, and the addon code reads it. Each suite loads
-- this once with its own substituted game services in place, and every
-- suite stays individually runnable from the repository root.
return function()
  local namespace = {}
  for line in io.lines('dist/EfficientQuests/EfficientQuests.toc') do
    if line:match('%.lua$') then
      assert(loadfile('dist/EfficientQuests/' .. line))('EfficientQuests', namespace)
    end
  end
end
