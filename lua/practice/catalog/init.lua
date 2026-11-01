local data = require('practice.core.data')
local metadata = require('practice.catalog.metadata')
local lesson_schema = require('practice.core.catalog')
local Catalog = {}
Catalog.__index = Catalog
function Catalog.new(providers, collections)
    assert(data.array(providers), 'providers must be an array')
    assert(data.array(collections or {}), 'collections must be an array')
    local self = setmetatable({ providers = {}, ordered = {}, entries = {}, owners = {}, loaded = {}, collections = {} }, Catalog)
    for _, provider in ipairs(providers) do
        metadata.id(provider.id, 'provider id')
        assert(provider.prefix == nil or provider.prefix == provider.id .. '.', 'provider prefix must match its namespace')
        assert(not self.providers[provider.id], 'duplicate provider: ' .. provider.id)
        assert(type(provider.list) == 'function' and type(provider.get) == 'function', 'provider requires list() and get()')
        self.providers[provider.id] = provider
        self.ordered[#self.ordered + 1] = provider.id
    end
    for _, collection in ipairs(collections or {}) do
        assert(data.plain(collection), 'collection must be plain data')
        for key in pairs(collection) do
            assert(key == 'id' or key == 'title' or key == 'items' or key == 'provider', 'unknown collection field: ' .. tostring(key))
        end
        metadata.id(collection.id, 'collection id')
        assert(collection.id ~= 'catalog.all', 'catalog.all is a reserved collection')
        assert(type(collection.title) == 'string' and collection.title ~= '', 'collection requires a title')
        assert(not self.collections[collection.id], 'duplicate collection: ' .. collection.id)
        assert((collection.items ~= nil) ~= (collection.provider ~= nil), 'collection needs either items or provider')
        if collection.provider then
            assert(self.providers[collection.provider], 'unknown collection provider: ' .. collection.provider)
        else
            assert(data.array(collection.items), 'collection.items must be an array')
            local seen = {}
            for _, ref in ipairs(collection.items) do
                assert(type(ref) == 'table', 'collection reference must be a table')
                for key in pairs(ref) do assert(key == 'id' or key == 'order', 'unknown collection reference field') end
                metadata.id(ref.id)
                assert(not seen[ref.id], 'duplicate collection reference: ' .. ref.id)
                assert(type(ref.order) == 'number' and ref.order % 1 == 0, 'reference order must be an integer')
                seen[ref.id] = true
            end
        end
        self.collections[collection.id] = data.copy(collection)
    end
    return self
end
function Catalog:load(provider_id)
    if self.loaded[provider_id] then return end
    local provider = assert(self.providers[provider_id], 'unknown provider: ' .. tostring(provider_id))
    local rows = provider.list()
    assert(data.array(rows), 'provider.list() must return an array')
    local pending, seen = {}, {}
    for _, row in ipairs(rows) do
        local entry = metadata.entry(row)
        assert(not self.entries[entry.id] and not seen[entry.id], 'duplicate tutorial: ' .. entry.id)
        if provider.prefix then assert(entry.id:sub(1, #provider.prefix) == provider.prefix, 'tutorial outside provider namespace: ' .. entry.id) end
        pending[#pending + 1], seen[entry.id] = entry, true
    end
    -- Publish only after the whole metadata snapshot validates.
    for _, entry in ipairs(pending) do self.entries[entry.id], self.owners[entry.id] = entry, provider_id end
    self.loaded[provider_id] = true
end
function Catalog:metadata(id)
    metadata.id(id)
    if not self.entries[id] then
        for _, provider_id in ipairs(self.ordered) do
            local provider = self.providers[provider_id]
            if not provider.prefix or id:sub(1, #provider.prefix) == provider.prefix then self:load(provider_id) end
        end
    end
    return data.copy(self.entries[id])
end
function Catalog:get(id)
    local entry = self:metadata(id)
    if not entry then return nil end
    local lesson = self.providers[self.owners[id]].get(id)
    assert(lesson, 'missing tutorial body: ' .. id)
    lesson = lesson_schema.new({ lesson }).get(id)
    assert(lesson, 'tutorial body has a different id: ' .. id)
    for _, key in ipairs({ 'title', 'tool', 'category' }) do
        assert(lesson[key] == entry[key], 'tutorial body/index mismatch: ' .. id .. '.' .. key)
    end
    return lesson
end
function Catalog:list(collection_id)
    local result = {}
    if collection_id and collection_id ~= 'catalog.all' then
        local collection = assert(self.collections[collection_id], 'unknown collection: ' .. collection_id)
        if collection.items then
            local refs = metadata.sort(data.copy(collection.items))
            for _, ref in ipairs(refs) do
                result[#result + 1] = assert(self:metadata(ref.id), 'missing collection tutorial: ' .. ref.id)
            end
            return result
        end
        self:load(collection.provider)
        for id, entry in pairs(self.entries) do
            if self.owners[id] == collection.provider then result[#result + 1] = data.copy(entry) end
        end
        return metadata.sort(result)
    end
    for row in self:iterate() do result[#result + 1] = row end
    return result
end
-- Consumers may stop before reaching optional providers later in catalog order.
function Catalog:iterate()
    return coroutine.wrap(function()
        for _, provider_id in ipairs(self.ordered) do
            self:load(provider_id)
            local rows = {}
            for id, entry in pairs(self.entries) do
                if self.owners[id] == provider_id then rows[#rows + 1] = data.copy(entry) end
            end
            for _, row in ipairs(metadata.sort(rows)) do coroutine.yield(row) end
        end
    end)
end
function Catalog:has_collection(id) return id == 'catalog.all' or self.collections[id] ~= nil end
function Catalog:validate()
    for _, collection in pairs(self.collections) do
        if collection.items then self:list(collection.id) end
    end
end
function Catalog:search(query, collection_id)
    assert(type(query) == 'string', 'query must be a string')
    local result, needle = {}, query:lower()
    for _, entry in ipairs(self:list(collection_id)) do
        local haystack = table.concat({ entry.id, entry.title, entry.tool, entry.category,
            entry.description or '', table.concat(entry.tags or {}, ' ') }, ' '):lower()
        if haystack:find(needle, 1, true) then result[#result + 1] = entry end
    end
    return result
end
return Catalog
