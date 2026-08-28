-- Animated cursor trail. Purely cosmetic, pure Lua, no dependencies.
--
-- Colours are left unset so the smear derives from the active colorscheme's
-- cursor highlight rather than a hardcoded value.

return {
  {
    "sphamba/smear-cursor.nvim",
    event = "VeryLazy",
    opts = {
      stiffness = 0.8,
      trailing_stiffness = 0.5,
      distance_stop_animating = 0.5,
      -- Terminals that do not report their background cannot draw the smear
      -- correctly; this keeps it to solid blocks, which works everywhere.
      legacy_computing_symbols_support = false,
    },
  },
}
