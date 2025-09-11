# Friction in my workflow
- Close all buffers except active buffer

- Pressing Escape then o to create a new line and enter insert mode
 - I do this all the time

- Center page when using <C-d> and <C-u>

- Yank the current file buffer full path into the default register
    - `:let @" = expand("%")`
    - Remap to keystroke
    - `:nmap cp :let @" = expand("%")<cr>`
