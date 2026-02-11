local _, NS = ...
HARFDB = HARFDB or {}
NS.Data = {}
NS.Util = {}
NS.Core = {}
NS.Opt = {}

--Version-specific handling of saved vars
if not HARFDB.version then
    HARFDB = {}
    HARFDB.version = "1.0.1"
end

print('AdvancedRaidFrames v.' .. HARFDB.version)