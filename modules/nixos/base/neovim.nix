{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;

    configure.customRC = ''
      set number relativenumber
      autocmd FileType markdown setlocal shiftwidth=2

      imap <F3> <C-R>=strftime("%Y-%m-%d")<CR>
      imap <F4> <C-R>=strftime("%-H:%M")<CR>
      noremap ZR :write<CR>
    '';
  };
}
