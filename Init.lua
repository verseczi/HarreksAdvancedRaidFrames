--Initialize tables
local _, NS = ...
NS.Data = {}
NS.Ui = {}
NS.Util = {}
NS.Core = {}
NS.Version = '2.0.0'

--Initialize saved variables
HARFDB = HARFDB or {}
if HARFDB.version ~= NS.Version then
    HARFDB = {}
    HARFDB.version = NS.Version
end
if not HARFDB.options then HARFDB.options = {} end
if not HARFDB.savedIndicators then HARFDB.savedIndicators = {} end

print('|cnNORMAL_FONT_COLOR:AdvancedRaidFrames|r v' .. HARFDB.version .. ' by Harrek. use |cnNORMAL_FONT_COLOR:/harf|r to open the settings.')
