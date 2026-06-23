-- Provider registry. A provider is a table implementing:
--   name                          string
--   matches(remote_url)           -> boolean
--   parse(remote_url)             -> parsed | nil, err
--   token()                       -> token | nil, err
--   build_request(ctx)            -> { url, headers = {..}, body = {..} }
--   parse_response(decoded_json)  -> ok:boolean, message:string, url:string?
--
-- `ctx` passed to build_request: { branch, target, title, description, token, parsed }
--
-- To add a new provider (e.g. gitlab), drop a module under providers/ and
-- register it below — nothing else in the plugin needs to change.
local M = {}

local registry = {}

function M.register(provider)
  table.insert(registry, provider)
end

function M.detect(remote_url)
  for _, p in ipairs(registry) do
    if p.matches(remote_url) then
      return p
    end
  end
  return nil
end

M.register(require("gitgen.providers.github"))
M.register(require("gitgen.providers.azure"))

return M
