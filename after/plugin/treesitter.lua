require 'nvim-treesitter.configs'.setup {
  -- A list of parser names, or "all"
  ensure_installed = { "vimdoc", "javascript", "typescript", "tsx", "c", "lua", "rust", "hurl" },

  -- Install parsers synchronously (only applied to `ensure_installed`)
  sync_install = false,

  -- Automatically install missing parsers when entering buffer
  -- Recommendation: set to false if you don't have `tree-sitter` CLI installed locally
  auto_install = true,

  highlight = {
    -- `false` will disable the whole extension
    enable = true,

    -- Setting this to true will run `:h syntax` and tree-sitter at the same time.
    -- Set this to `true` if you depend on 'syntax' being enabled (like for indentation).
    -- Using this option may slow down your editor, and you may see some duplicate highlights.
    -- Instead of true it can also be a list of languages
    additional_vim_regex_highlighting = false,
  },
}

-- nvim-treesitter master registers its predicates/directives with `all = false`,
-- which Neovim 0.12 no longer honours: `match[id]` is now always a list of nodes.
-- Re-register them through an adapter that hands each handler a single node.
if vim.fn.has "nvim-0.12" == 1 then
  local query = require "vim.treesitter.query"
  local add_predicate, add_directive = query.add_predicate, query.add_directive

  local function single_node(handler)
    return function(match, ...)
      local m = {}
      for id, nodes in pairs(match) do
        m[id] = type(nodes) == "table" and nodes[#nodes] or nodes
      end
      return handler(m, ...)
    end
  end

  query.add_predicate = function(name, handler, opts) add_predicate(name, single_node(handler), opts) end
  query.add_directive = function(name, handler, opts) add_directive(name, single_node(handler), opts) end
  package.loaded["nvim-treesitter.query_predicates"] = nil
  require "nvim-treesitter.query_predicates"
  query.add_predicate, query.add_directive = add_predicate, add_directive
end
