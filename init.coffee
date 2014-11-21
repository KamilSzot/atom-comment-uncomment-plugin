# Your init script
#
# Atom will evaluate this file each time a new window is opened. It is run
# after packages are loaded/activated and after the previous editor state
# has been restored.
#
# An example hack to log to the console when each text editor is saved.
#
# atom.workspace.observeTextEditors (editor) ->
#   editor.onDidSave ->
#     console.log "Saved! #{editor.getPath()}"

path = require 'path'

node_modules  = (name) -> path.join atom.config.resourcePath, 'node_modules', name
src           = (name) -> path.join atom.config.resourcePath, 'src', name

TextEditor = require src 'text-editor'
Selection = require src 'selection'
LanguageMode = require src 'language-mode'

_ = require node_modules 'underscore-plus'
{OnigRegExp} = require node_modules 'oniguruma'

atom.commands.add 'atom-text-editor:not(.mini)', stopEventPropagationAndGroupUndo
  'editor:comment-buffer-rows': -> @commentSelection()
  'editor:uncomment-buffer-rows': -> @uncommentSelection()

TextEditor::commentSelection = ->
  @mutateSelectedText (selection) ->
    selection.comment()

TextEditor::uncommentSelection = ->
  @mutateSelectedText (selection) ->
    selection.uncomment()

Selection::comment = ->
  @editor.languageMode.commentBufferRows @getBufferRowRange()...

Selection::uncomment = ->
  @editor.languageMode.uncommentBufferRows @getBufferRowRange()...

LanguageMode::commentBufferRows = (start, end) ->
  scopeDescriptor = @editor.scopeDescriptorForBufferPosition([start, 0])
  properties = atom.config.settingsForScopeDescriptor(scopeDescriptor, 'editor.commentStart')[0]
  return unless properties

  commentStartString = _.valueForKeyPath(properties, 'editor.commentStart')
  commentEndString = _.valueForKeyPath(properties, 'editor.commentEnd')

  return unless commentStartString

  buffer = @editor.buffer

  if commentEndString
    buffer.transact ->
      indentLength = buffer.lineForRow(start).match(/^\s*/)?[0].length ? 0
      buffer.insert([start, indentLength], commentStartString)
      buffer.insert([end, buffer.lineLengthForRow(end)], commentEndString)
  else
    if start is end
      indent = @editor.indentationForBufferRow(start)
    else
      indent = @minIndentLevelForRowRange(start, end)
    indentString = @editor.buildIndentString(indent)
    tabLength = @editor.getTabLength()
    indentRegex = new RegExp("(\t|[ ]{#{tabLength}}){#{Math.floor(indent)}}")
    for row in [start..end]
      line = buffer.lineForRow(row)
      if indentLength = line.match(indentRegex)?[0].length
        buffer.insert([row, indentLength], commentStartString)
      else
        buffer.setTextInRange([[row, 0], [row, indentString.length]], indentString + commentStartString)

LanguageMode::uncommentBufferRows = (start, end) ->
    scopeDescriptor = @editor.scopeDescriptorForBufferPosition([start, 0])
    properties = atom.config.settingsForScopeDescriptor(scopeDescriptor, 'editor.commentStart')[0]
    return unless properties

    commentStartString = _.valueForKeyPath(properties, 'editor.commentStart')
    commentEndString = _.valueForKeyPath(properties, 'editor.commentEnd')

    return unless commentStartString

    buffer = @editor.buffer
    commentStartRegexString = _.escapeRegExp(commentStartString).replace(/(\s+)$/, '(?:$1)?')
    commentStartRegex = new OnigRegExp("^(\\s*)(#{commentStartRegexString})")

    if commentEndString
      shouldUncomment = commentStartRegex.testSync(buffer.lineForRow(start))
      if shouldUncomment
        commentEndRegexString = _.escapeRegExp(commentEndString).replace(/^(\s+)/, '(?:$1)?')
        commentEndRegex = new OnigRegExp("(#{commentEndRegexString})(\\s*)$")
        startMatch =  commentStartRegex.searchSync(buffer.lineForRow(start))
        endMatch = commentEndRegex.searchSync(buffer.lineForRow(end))
        if startMatch and endMatch
          buffer.transact ->
            columnStart = startMatch[1].length
            columnEnd = columnStart + startMatch[2].length
            buffer.setTextInRange([[start, columnStart], [start, columnEnd]], "")

            endLength = buffer.lineLengthForRow(end) - endMatch[2].length
            endColumn = endLength - endMatch[1].length
            buffer.setTextInRange([[end, endColumn], [end, endLength]], "")
    else
      allBlank = true
      allBlankOrCommented = true

      for row in [start..end]
        line = buffer.lineForRow(row)
        blank = line?.match(/^\s*$/)

        allBlank = false unless blank
        allBlankOrCommented = false unless blank or commentStartRegex.testSync(line)

      shouldUncomment = allBlankOrCommented and not allBlank

      if shouldUncomment
        for row in [start..end]
          if match = commentStartRegex.searchSync(buffer.lineForRow(row))
            columnStart = match[1].length
            columnEnd = columnStart + match[2].length
            buffer.setTextInRange([[row, columnStart], [row, columnEnd]], "")



`
function stopEventPropagationAndGroupUndo(commandListeners) {
  var commandListener, commandName, newCommandListeners, _fn;
  newCommandListeners = {};
  _fn = function(commandListener) {
    return newCommandListeners[commandName] = function(event) {
      var model;
      event.stopPropagation();
      model = this.getModel();
      return model.transact(atom.config.get('editor.undoGroupingInterval'), function() {
        return commandListener.call(model, event);
      });
    };
  };
  for (commandName in commandListeners) {
    commandListener = commandListeners[commandName];
    _fn(commandListener);
  }
  return newCommandListeners;
};
`
