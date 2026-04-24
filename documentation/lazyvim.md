# LazyVim (Neovim)

## Setup

LazyVim wird über `home/neovim.nix` konfiguriert. Die Config-Dateien landen via `xdg.configFile` in `~/.config/nvim/`.

Beim ersten Start von `nvim` bootstrapt LazyVim automatisch `lazy.nvim` und lädt alle Plugins (braucht Internet).

## Dateien

| Datei | Zweck |
|---|---|
| `~/.config/nvim/init.lua` | Einstiegspunkt, ruft `config.lazy` auf |
| `~/.config/nvim/lua/config/lazy.lua` | lazy.nvim Bootstrap + LazyVim-Setup |
| `~/.config/nvim/lua/config/options.lua` | Gemeinsame Optionen (Clipboard, Zeilennummern) |
| `~/.config/nvim/lua/config/keymaps.lua` | Host-spezifische Keymaps (via Nix generiert) |
| `~/.config/nvim/lua/plugins/` | Eigene Plugin-Specs |

## Host-spezifische Keymaps

Das Keyboard-Layout wird per `_module.args.keyboardLayout` in den Host-Configs gesetzt:

```nix
# hosts/leonardn/default.nix
home-manager.users.leonardn = {
  _module.args.keyboardLayout = "neo";
  ...
};

# hosts/laptop/default.nix
home-manager.users.leonardn = {
  _module.args.keyboardLayout = "qwertz";
  ...
};
```

`home/neovim.nix` nimmt `keyboardLayout` als Parameter und generiert `keymaps.lua` entsprechend.

## Neue Plugins hinzufügen

Plugin-Spec in `home/neovim.nix` als neue `xdg.configFile`-Datei unter `nvim/lua/plugins/`:

```nix
xdg.configFile."nvim/lua/plugins/mein-plugin.lua".text = ''
  return {
    "author/plugin-name",
    opts = { ... },
  }
'';
```

## Aktuelle Optionen

- `clipboard = "unnamedplus"` — System-Clipboard für Yank/Paste
- `relativenumber = true` — Relative Zeilennummern
