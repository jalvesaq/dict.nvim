# Dict.nvim

  - Display in a floating window the result of `dict` for the word under the cursor.

  - Special highlighting for _WordNet_, _The Collaborative International
    Dictionary of English_, and _FreeDict Dictionary_.

  - Replace the word under the cursor with one chosen from `dict` results.

  - Use [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) to show the list of words in installed dictionaries
    if the word under cursor is not found by `dict`.

## Installation

  - Install `dict.nvim` as any other Neovim plugin.

  - Install [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim).

  - Install `dict`, `dictd` and at least one dictionary.
    On Debian/Ubuntu systems, you can use `apt` to install them. Example:

    ```
    sudo apt install dict dictd dict-wn dict-gcide dict-freedict-por-eng
    ```

## Configuration

### Mandatory

You have to create a key binding to run `dict.nvim`. Example for `init.lua`:

```lua
vim.keymap.set('n', '<Leader>d', '<Cmd>lua require("dict").lookup()<CR>')
```

### Optional

By default, `dict.nvim` will run `dict` without any argument other than the word
being looked up. It will read dictionary indexes from `/usr/share/dictd`,
and will cache the compiled list of words at `~/.cach/dict.nvim`. Instead,
you can tell `dict` to search a single dictionary and can also tell
`dict.nvim` where to read the indexes, and where to store its own compiled
list of words. Example:

```lua
require'dict'.setup({
    dict = 'wn',
    dict_dir = '/usr/share/dictd',
    cache_dir = os.getenv('HOME') .. '/.cache/dict.nvim',
})
```

On Debian, Ubuntu and other Linux distributions derived from them, to change
the order the dictionaries are searched, edit the file
`/etc/dictd/dictd.order`, and run:

```sh
sudo dictdconfig -w
```

and, finally, restart the `dictd` daemon.

## Usage

- Put the cursor over the word whose definition you want to lookup. Then,
  press the key binding that you have configured to open a float window with
  `dict` results.

- On the float window, you can:

  - press the same key binding to replace the displayed word definition;

  - press `<Enter>` to replace the word that was under the cursor in the
    editor with the current word under the cursor in the float window;

  - press either `<Esc>` or `q` to quit the float window.
