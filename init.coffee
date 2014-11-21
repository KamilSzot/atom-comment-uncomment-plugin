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

`
LanguageMode.prototype.commentBufferRows2 = function(start, end) {
  var allBlank, allBlankOrCommented, blank, buffer, columnEnd, columnStart, commentEndRegex, commentEndRegexString, commentEndString, commentStartRegex, commentStartRegexString, commentStartString, endMatch, indent, indentLength, indentRegex, indentString, line, match, properties, row, scopeDescriptor, shouldUncomment, startMatch, tabLength, _i, _j, _k, _ref1, _results, _results1;
  scopeDescriptor = this.editor.scopeDescriptorForBufferPosition([start, 0]);
  properties = atom.config.settingsForScopeDescriptor(scopeDescriptor, 'editor.commentStart')[0];
  if (!properties) {
    return;
  }
  commentStartString = _.valueForKeyPath(properties, 'editor.commentStart');
  commentEndString = _.valueForKeyPath(properties, 'editor.commentEnd');
  if (!commentStartString) {
    return;
  }
  buffer = this.editor.buffer;
  commentStartRegexString = _.escapeRegExp(commentStartString).replace(/(\s+)$/, '(?:$1)?');
  commentStartRegex = new OnigRegExp("^(\\s*)(" + commentStartRegexString + ")");
  if (commentEndString) {
    shouldUncomment = commentStartRegex.testSync(buffer.lineForRow(start));
    if (shouldUncomment) {
      commentEndRegexString = _.escapeRegExp(commentEndString).replace(/^(\s+)/, '(?:$1)?');
      commentEndRegex = new OnigRegExp("(" + commentEndRegexString + ")(\\s*)$");
      startMatch = commentStartRegex.searchSync(buffer.lineForRow(start));
      endMatch = commentEndRegex.searchSync(buffer.lineForRow(end));
      if (startMatch && endMatch) {
        return buffer.transact(function() {
          var columnEnd, columnStart, endColumn, endLength;
          columnStart = startMatch[1].length;
          columnEnd = columnStart + startMatch[2].length;
          buffer.setTextInRange([[start, columnStart], [start, columnEnd]], "");
          endLength = buffer.lineLengthForRow(end) - endMatch[2].length;
          endColumn = endLength - endMatch[1].length;
          return buffer.setTextInRange([[end, endColumn], [end, endLength]], "");
        });
      }
    } else {
      return buffer.transact(function() {
        var indentLength, _ref1, _ref2;
        indentLength = (_ref1 = (_ref2 = buffer.lineForRow(start).match(/^\s*/)) != null ? _ref2[0].length : void 0) != null ? _ref1 : 0;
        buffer.insert([start, indentLength], commentStartString);
        return buffer.insert([end, buffer.lineLengthForRow(end)], commentEndString);
      });
    }
  } else {
    allBlank = true;
    allBlankOrCommented = true;
    for (row = _i = start; start <= end ? _i <= end : _i >= end; row = start <= end ? ++_i : --_i) {
      line = buffer.lineForRow(row);
      blank = line != null ? line.match(/^\s*$/) : void 0;
      if (!blank) {
        allBlank = false;
      }
      if (!(blank || commentStartRegex.testSync(line))) {
        allBlankOrCommented = false;
      }
    }
    shouldUncomment = allBlankOrCommented && !allBlank;
    if (shouldUncomment) {
      _results = [];
      for (row = _j = start; start <= end ? _j <= end : _j >= end; row = start <= end ? ++_j : --_j) {
        if (match = commentStartRegex.searchSync(buffer.lineForRow(row))) {
          columnStart = match[1].length;
          columnEnd = columnStart + match[2].length;
          _results.push(buffer.setTextInRange([[row, columnStart], [row, columnEnd]], ""));
        } else {
          _results.push(void 0);
        }
      }
      return _results;
    } else {
      if (start === end) {
        indent = this.editor.indentationForBufferRow(start);
      } else {
        indent = this.minIndentLevelForRowRange(start, end);
      }
      indentString = this.editor.buildIndentString(indent);
      tabLength = this.editor.getTabLength();
      indentRegex = new RegExp("(\t|[ ]{" + tabLength + "}){" + (Math.floor(indent)) + "}");
      _results1 = [];
      for (row = _k = start; start <= end ? _k <= end : _k >= end; row = start <= end ? ++_k : --_k) {
        line = buffer.lineForRow(row);
        if (indentLength = (_ref1 = line.match(indentRegex)) != null ? _ref1[0].length : void 0) {
          _results1.push(buffer.insert([row, indentLength], commentStartString));
        } else {
          _results1.push(buffer.setTextInRange([[row, 0], [row, indentString.length]], indentString + commentStartString));
        }
      }
      return _results1;
    }
  }
};


`
