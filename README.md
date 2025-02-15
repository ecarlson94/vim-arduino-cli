# vim-arduino-cli
Vim plugin for compiling, uploading, and debugging arduino sketches. It makes
use of Arduino's [commandline interface tool](https://arduino.github.io/arduino-cli/latest/commands/arduino-cli/) (in alpha).

This project is heavily inspired by Steven Arcangeli's [vim-arduino](https://github.com/stevearc/vim-arduino) which uses the Arduino IDE's command line interface.

I opted for this new approach for two major reasons:
1. It is naturally headless (no need to install Xvfb)
1. Although `arduino-cli` is in alpha, the Arduino team has indicated that they would be replacing the internals of their IDE with it

## Table of Contents
<!-- TOC GFM -->

- [Installation](#installation)
- [Platforms](#platforms)
- [Configuration](#configuration)
  - [Status Line](#status-line)
- [License](#license)

<!-- /TOC -->

## Installation

vim-arduino-cli works with [Pathogen](https://github.com/tpope/vim-pathogen)

```sh
cd ~/.vim/bundle/
git clone https://github.com/ecarlson94/vim-arduino-cli
```

and [vim-plug](https://github.com/junegunn/vim-plug)

```sh
Plug 'ecarlson94/vim-arduino-cli'
```

You also need to install the [arduino-cli](https://arduino.github.io/arduino-cli/latest/installation/)
(version 0.14 or newer) and make sure the `arduino-cli` command is in your PATH.

## Platforms

vim-arduino-cli should work with no special configuration on Linux and Mac. I have
not tested on Windows, but have heard that it works via WSL. See #4 for
discussion.

## Configuration

The docs have detailed information about configuring vim-arduino-cli
[here](https://github.com/ecarlson94/vim-arduino-cli/blob/master/doc/arduino.txt).

The main commands you will want to use are:

* `:ArduinoChooseBoard` - Select the type of board from a list.
* `:ArduinoChooseProgrammer` - Select the programmer from a list.
* `:ArduinoChoosePort` - Select the serial port from a list.
* `:ArduinoLibSearch` - Search for a library to install.
* `:ArduinoLibInstall` - Install a specific library.
* `:ArduinoCompile` - Build the sketch.
* `:ArduinoUpload` - Build and upload the sketch.
* `:ArduinoAttach` - Connect to the board for debugging over a serial port.
* `:ArduinoUploadAndAttach` - Build, upload, and connect for debugging.
* `:ArduinoInfo` - Display internal information. Useful for debugging issues with vim-arduino.

To make easy use of these, you may want to bind them to a key combination. You
can put the following in `.vim/ftplugin/arduino.vim`:

```vim
nnoremap <buffer> <leader>as :ArduinoLibSearch<CR>
nnoremap <buffer> <leader>ai :ArduinoLibInstall<CR>
nnoremap <buffer> <leader>am :ArduinoCompile<CR>
nnoremap <buffer> <leader>au :ArduinoUpload<CR>
nnoremap <buffer> <leader>ad :ArduinoUploadAndAttach<CR>
nnoremap <buffer> <leader>ab :ArduinoChooseBoard<CR>
nnoremap <buffer> <leader>ap :ArduinoChooseProgrammer<CR>
```

If you wish to run these commands in tmux/screen/some other location, you can
make use of [vim-slime](https://github.com/jpalardy/vim-slime):

```vim
let g:arduino_use_slime = 1
```

### Status Line

If you want to add the board type to your status line, it's easy with the
following:

```vim
" my_file.ino [arduino:avr:uno]
function! MyStatusLine()
  return '%f [' . g:arduino_board . ']'
endfunction
setl statusline=%!MyStatusLine()
```

Or if you want something a bit fancier that includes serial port info:

```vim
" my_file.ino [arduino:avr:uno] [arduino:usbtinyisp] (/dev/ttyACM0:9600)
function! MyStatusLine()
  let port = arduino#GetPort()
  let line = '%f [' . g:arduino_board . '] [' . g:arduino_programmer . ']'
  if !empty(port)
    let line = line . ' (' . port . ')'
  endif
  return line
endfunction
setl statusline=%!MyStatusLine()
```
Note: if you are using the 'airline' plugin for the status line, you can display
this custom status part instead of the filename extension with:

```vim
autocmd BufNewFile,BufRead *.ino let g:airline_section_x='%{MyStatusLine()}'
```

## License
Everything is under the [MIT
License](https://github.com/ecarlson/vim-arduino-cli/blob/master/LICENSE) except for
the wonderful syntax file, which was created by Johannes Hoff and copied from
[vim.org](http://www.vim.org/scripts/script.php?script_id=2654) and is under the
[Vim License](http://vimdoc.sourceforge.net/htmldoc/uganda.html).
