{ ... }:

{
  programs.zed-editor = {
    enable = true;

    # Nur die initiale Extension-Liste ist deklarativ; weitere kannst du jederzeit
    # über die GUI nachinstallieren.
    extensions = [
      "nix"
      "toml"
      "catppuccin"
    ];

    userSettings = {
      # --- Vim ---
      vim_mode = true;
      vim = {
        # wie in vscode (vim.useSystemClipboard): yank/paste übers System-Clipboard
        use_system_clipboard = "always";
      };

      # --- Optik (passend zu catppuccin-sddm) ---
      theme = {
        mode = "system";
        dark = "Catppuccin Mocha";
        light = "Catppuccin Latte";
      };
      ui_font_size = 16;
      buffer_font_size = 15;
      # buffer_font_family = "JetBrains Mono";   # bei Bedarf einkommentieren (Font muss installiert sein)

      # --- Editor-Komfort ---
      relative_line_numbers = true;        # wie deine vscode-Einstellung
      cursor_blink = false;
      format_on_save = "on";
      tab_size = 2;
      soft_wrap = "editor_width";
      show_whitespaces = "selection";
      scrollbar = { show = "auto"; };
      indent_guides = {
        enabled = true;
        coloring = "indent_aware";
      };
      inlay_hints = { enabled = true; };

      # --- Git ---
      git = {
        git_gutter = "tracked_files";
        inline_blame = { enabled = true; };
      };

      # --- Terminal ---
      terminal = {
        copy_on_select = true;
      };

      # --- Privatsphäre (kein Telemetrie-Versand) ---
      telemetry = {
        diagnostics = false;
        metrics = false;
      };

      # Auto-Update aus – Updates laufen über home-manager/Nix
      auto_update = false;
    };

    # Standard-Zwischenablage trotz Vim-Mode:
    # - Strg+C / Strg+X nur im Visual-Mode (also wenn etwas markiert ist, z. B. per Maus)
    #   → so bleibt Strg+C im Insert/Normal-Mode weiterhin "Escape zurück zu Normal".
    # - Strg+V überall als Einfügen.
    userKeymaps = [
      {
        context = "Editor && vim_mode == visual";
        bindings = {
          "ctrl-c" = "editor::Copy";
          "ctrl-x" = "editor::Cut";
        };
      }
      {
        context = "Editor";
        bindings = {
          "ctrl-v" = "editor::Paste";
        };
      }
    ];
  };
}
