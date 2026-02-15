# calendar.nvim

A minimal calendar widget for Neovim that embeds below the [Snacks.nvim](https://github.com/folke/snacks.nvim) explorer sidebar, showing a monthly calendar with today highlighted and a live clock with blinking colon.

## Requirements

- Neovim >= 0.10
- [folke/snacks.nvim](https://github.com/folke/snacks.nvim) with explorer enabled

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "vulcanshen/calendar.nvim",
  dependencies = { "folke/snacks.nvim" },
  lazy = false,
  opts = {},
  keys = {
    { "<leader>uC", "<cmd>CalendarToggle<cr>", desc = "Toggle Calendar" },
  },
}
```

## Configuration

Default options:

```lua
{
  time_format = "%H:%M:%S",
  highlights = {
    CalendarTitle  = { default = true, link = "Title" },
    CalendarHeader = { default = true, link = "Keyword" },
    CalendarDay    = { default = true, link = "Normal" },
    CalendarToday  = { default = true, reverse = true, bold = true },
    CalendarSep    = { default = true, link = "FloatBorder" },
    CalendarTime   = { default = true, bold = true },
  },
}
```

### Highlights

| Group | Default | Description |
|---|---|---|
| `CalendarTitle` | `Title` | Month and year title |
| `CalendarHeader` | `Keyword` | Weekday header (Su Mo Tu ...) |
| `CalendarDay` | `Normal` | Day numbers |
| `CalendarToday` | reverse + bold | Today's date |
| `CalendarSep` | `FloatBorder` | Separator lines |
| `CalendarTime` | bold | Clock display |

Override any highlight group to customize colors:

```lua
opts = {
  highlights = {
    CalendarTime = { fg = "#ff9900", bold = true },
    CalendarDay = { fg = "#888888" },
  },
}
```

## Commands

| Command | Description |
|---|---|
| `:CalendarToggle` | Toggle the calendar widget |
| `:CalendarOpen` | Open the calendar |
| `:CalendarClose` | Close the calendar |

## Behavior

- Auto-opens when the Snacks explorer sidebar is visible
- Auto-closes when the explorer is closed
- Automatically hides when other floating windows (pickers, search) are focused
- Adapts to colorscheme changes
- Clock colon blinks every second
