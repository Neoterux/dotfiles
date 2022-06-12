-- vim: sw=2: foldmethod=marker
require('bufferline').setup( {
  options = {
    numbers = 'buffer_id',
    close_command = 'bdelete! %d',
    right_mouse_command = nil,
    left_mouse_command = 'buffer %d',
    middle_mouse_command = nil,
    indicator_icon = "▎",
    buffer_close_icon = "",
    modified_icon = "●",
    close_icon = "",
    left_trunc_marker = "",
    right_trunc_marker = "",
  }
})
