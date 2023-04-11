VoiceOver = setmetatable({}, { __index = function(self, key) return getglobal(key) end })
VoiceOver._G = setmetatable({}, {
    __index = function(self, key) return getglobal(key) end,
    __newindex = function(self, key, value) setglobal(key, value) end,
 })