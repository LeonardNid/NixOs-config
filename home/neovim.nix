{ keyboardLayout ? "qwertz", pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    withRuby = false;
    withPython3 = false;
    extraPackages = with pkgs; [ gcc ];
  };

  xdg.configFile."nvim/init.lua".text = ''
    require("config.lazy")
  '';

  xdg.configFile."nvim/lua/config/lazy.lua".text = ''
    local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
    if not (vim.uv or vim.loop).fs_stat(lazypath) then
      local lazyrepo = "https://github.com/folke/lazy.nvim.git"
      local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
      if vim.v.shell_error ~= 0 then
        vim.api.nvim_echo({
          { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
          { out, "Warn" },
          { "\nPress any key to exit...", "ErrorMsg" },
        }, true, {})
        vim.fn.getchar()
        os.exit(1)
      end
    end
    vim.opt.rtp:prepend(lazypath)

    require("lazy").setup({
      spec = {
        { "LazyVim/LazyVim", import = "lazyvim.plugins" },
        { import = "plugins" },
      },
      defaults = { lazy = false, version = false },
      install = { colorscheme = { "tokyonight", "habamax" } },
      checker = { enabled = true },
    })
  '';

  xdg.configFile."nvim/lua/config/options.lua".text = ''
    vim.opt.clipboard = "unnamedplus"
    vim.opt.relativenumber = true
  '';

  # keyboard layout: ${keyboardLayout}
  # Neo-spezifische Binds werden hier später ergänzt
  xdg.configFile."nvim/lua/config/keymaps.lua".text = ''
    vim.keymap.set("n", "<leader>F", function()
      require("telescope.builtin").find_files({
        attach_mappings = function(prompt_bufnr, _)
          local actions = require("telescope.actions")
          local action_state = require("telescope.actions.state")
          actions.select_default:replace(function()
            local selection = action_state.get_selected_entry()
            actions.close(prompt_bufnr)
            if selection then
              vim.fn.jobstart({ "kitty", "nvim", selection[1] }, { detach = true })
            end
          end)
          return true
        end,
      })
    end, { desc = "Open file in new Kitty window" })
  '';

  xdg.configFile."nvim/lua/plugins/init.lua".text = "return {}";
}
