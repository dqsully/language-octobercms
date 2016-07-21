# !NOT FINISHED YET!

_ = require 'underscore-plus'
{CompositeDisposable} = require 'atom'

module.exports =
class TwigMatcher
  pairs:
    '{': [
        canwrap: true
        requires: #       {|} -> {{ | }}
          before: '{'
          after:  '}'
        insert:
          before: '{ '
          after:  ' }'
          markers: [1, 2]
    ]
    '}': [
        requires: #       | }} ->  }|}
          after: ' }}'
          markers: [1]
        do:
          rmmarkers: [1, 2]
          mvcursor: 2
    ]
    '%': [
        canwrap: true
        requires: #       {|} -> {% | %}
          before: '{'
          after:  '}'
        insert:
          before: '% '
          after:  ' %'
          markers: [1, 2]
      ,
        requires: #       | %} ->  %|}
          after:  ' %}'
          markers: [1]
        do:
          rmmarkers: [1, 2]
          mvcursor: 2
      ,
        requires: #       |%} -> %|}
          after:  '%}'
          markers: [1]
        do:
          rmmarkers: [1]
          mvcursor: 1
    ]
    '#': [
        canwrap: true
        requires: #       {|} -> {#|#}
          before: '{'
          after:  '}'
        insert:
          before: '#'
          after:  '#'
          markers: [1]
      ,
        requires: #       | #} ->  #|}
          after:  ' #}'
          markers: [1]
        do:
          rmmarkers: [1, 2]
          mvcursor: 2
      ,
        requires: #       |#} -> #|}
          after: '#}'
          markers: [1]
        do:
          rmmarkers: [1]
          mvcursor: 1
    ]
    ' ': [
        canwrap: true
        requires: #       {#|#} -> {# | #}
          before: '{#'
          after:  '#}'
        insert:
          before: ' '
          after:  ' '
          markers: [1]
      ,
        requires: #       | }} ->  |}}
          after:  '| }}'
          markers: [1]
        do:
          rmmarkers: [1]
          mvcursor: 1
      ,
        requires: #       | %} ->  |%}
          after:  '| %}'
          markers: [1]
        do:
          rmmarkers: [1]
          mvcursor: 1
      ,
        requires: #       | #} ->  |#}
          after:  '| #}'
          markers: [1]
        do:
          rmmarkers: [1]
          mvcursor: 1
    ]
  bspace: [
      requires:
        before: '{{ '
        after:  ' }}'
      delete:
        before: 2
        after:  2
    ,
      requires:
        before: '{%'
        after:  '%}'
      delete:
        before: 1
        after:  1
    ,
      requires:
        before: '{% '
        after:  ' %}'
      delete:
        before: 2
        after:  2
    ,
      requires:
        before: '{#'
        after:  '#}'
      delete:
        before: 1
        after:  1
    ,
      requires:
        before: '{# '
        after:  ' #}'
      delete:
        before: 2
        after:  2
  ]

  constructor: (@editor, editorElement) ->
    @subscriptions = new CompositeDisposable

    @origEditorInsertText = @editor.insertText.bind @editor
    _.adviseBefore(@editor, 'insertText', @insertText)
    _.adviseBefore(@editor, 'insertNewline', @insertNewline)
    _.adviseBefore(@editor, 'backspace', @backspace)

    @subscriptions.add atom.commands.add editorElement, 'twig-matcher:remove-brackets-from-selection', (event) =>
      event.abortKeyBinding() unless @removeBrackets()

    @subscriptions.add @editor.onDidDestroy => @unsubscribe()

    @buffer = @editor.getBuffer()
    @markers = []

  insertText: (text, options) =>
    # TODO: make sure you are in correct grammar first!
    return true unless text
    return true if options?.select or options?.undo is 'skip'

    return false if @wrapSelectionInBrackets(text)
    return true if @editor.hasMultipleCursors()

    cPosition = @editor.getCursorBufferPosition()
    brackets = getBrackets cPosition, cPosition, text



  # oldwrapSelectionInBrackets: (bracket) ->
  #   return false unless @getScopedSetting('bracket-matcher.wrapSelectionsInBrackets')
  #
  #   return false unless @isOpeningBracket(bracket)
  #   pair = @pairedCharacters[bracket]
  #
  #   selectionWrapped = false
  #   @editor.mutateSelectedText (selection) ->
  #     return if selection.isEmpty()
  #
  #     selectionWrapped = true
  #     range = selection.getBufferRange()
  #     options = reversed: selection.isReversed()
  #     # TODO: Fix this:
  #     selection.insertText("#{bracket}#{selection.getText()}#{pair}")
  #     selectionStart = range.start.traverse([0, bracket.length]);
  #     if range.start.row is range.end.row
  #       selectionEnd = range.end.traverse([0, bracket.length])
  #     else
  #       selectionEnd = range.end
  #     selection.setBufferRange([selectionStart, selectionEnd], options)
  #
  #   selectionWrapped

  wrapSelectionInBrackets: (bracket) ->
    return false unless @isOpeningBracket(bracket)

    selectionWraped = false
    pair = @pairs[bracket]

    @editor.mutateSelectedText (selection) ->
      return if selection.isEmpty()
      range = selection.getBufferRange()
      return unless @getScopedSetting('bracket-matcher.wrapSelectionsInBrackets', range.start) and @getScopedSetting('bracket-matcher.wrapSelectionsInBrackets', range.end)

      options = reversed: selection.isReversed()
      brackets = getBrackets range.start, range.end, bracket, true
      return unless brackets?
      selectionWrapped = true

      before = brackets.insert.before or ''
      after = brackets.insert.after or ''
      selection.insertText "#{before}#{selection.getText()}#{after}"
      # Don't insert markers

      selectionStart = range.start.traverse([0, before.length])
      if range.start.row is range.end.row
        selectionEnd = range.end.traverse([0, after.length])
      else
        selectionEnd = range.end
      selection.setBufferRange([selectionStart, selectionEnd], options)

    selectionWrapped

  getBrackets: (rangeStart, rangeEnd, key, wrap) ->
    textBefore = reverseText @editor.getTextInBufferRange(rangeStart.traverse([0, -3]), rangeStart)
    textAfter = @editor.getTextInBufferRange(rangeEnd, rangeEnd.traverse([0, 3]))

    for obj in pairs[key]
      if (wrap and obj.canwrap is true) or not wrap
        satisfiesNeeds = true

        if obj.requires?
          if obj.requires.before?
            rb = reverseText obj.requires.before
            if textBefore.substr(0, rb.length) isnt rb
              satisfiesNeeds = false

          if obj.requires.after?
            ra = obj.requires.after
            if textAfter.substr(0, ra.length) isnt ra
              satisfiesNeeds = false

          if obj.requires.markers?
            if wrap?
              satisfiesNeeds = false
            else
              for o in obj.requires.markers
                if not _.find(@markers, (m) -> m.isValid() and m.getBufferRange().end.isEqual(rangeEnd.traverse([0, o])))
                  satisfiesNeeds = false

        if satisfiesNeeds
          return obj

    null

  reverseText: (string) ->
    out = ""
    out[i] = c for c, i in string
    out

  isOpeningBracket: (string) ->
    ['{', '%', '#', ' '].indexOf(string) isnt -1

  isClosingBracket: (string) ->
    ['}', '%', '#', ' '].indexOf(string) isnt -1

  unsubscribe: ->
    @ssubscriptions.dispose()

  getScopedSetting: (key, point) ->
    atom.config.get(key, scope: @editor.scopeDescriptionForBufferPosition(point))
