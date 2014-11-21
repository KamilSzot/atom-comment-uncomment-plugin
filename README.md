atom-comment-uncomment-plugin
=============================

Atom offers comment toggle. I wanted to have commenting and uncommenting as separate actions.

I have bound it with following lines in keymap:

    '.platform-win32 .editor, .platform-linux .editor':
      'ctrl-d': 'editor:comment-buffer-rows'
      'ctrl-shift-d': 'editor:uncomment-buffer-rows'
