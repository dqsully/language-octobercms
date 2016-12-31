# coffeelint: disable=max_line_length
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
    _.adviseBefore(@editor, 'backspace', @backspace)

    @subscriptions.add atom.commands.add editorElement, 'twig-matcher:remove-brackets-from-selection', (event) =>
      event.abortKeyBinding() unless @removeBrackets()

    subs = @subscriptions
    @subscriptions.add @editor.onDidDestroy -> subs.dispose()

    @buffer = @editor.getBuffer()
    @markers = []

  insertText: (text, options) =>
    # TODO: make sure you are in correct grammar first!
    return true unless text
    return true if options?.select or options?.undo is 'skip'

    return false if @wrapSelectionInBrackets(text)
    return true if @editor.hasMultipleCursors()

    scopes = @editor.getLastCursor().getScopeDescriptor().scopes
    return true unless scopes[0] == 'text.html.octobercms' and scopes[1] == 'text.html.twig.octobercms'

    cPosition = @editor.getCursorBufferPosition()
    brackets = @getBrackets cPosition, cPosition, text

    if brackets
      if 'insert' of brackets
        @editor.insertText brackets.insert.before + brackets.insert.after
        for i in [0..brackets.insert.after.length-1]
          @editor.moveLeft()

        cPosition = @editor.getCursorBufferPosition()
        for n in brackets.insert.markers
          range = [cPosition.traverse([0, -n]), cPosition.traverse([0, n])]
          @markers.push @editor.markBufferRange(range)
        return false
      else if 'do' of brackets
        if brackets.do.rmmarkers?
          for o in brackets.do.rmmarkers
            markersToRemove = _.filter @markers, (m) -> m.isValid() and m.getBufferRange().end.isEqual(cPosition.traverse([0, o]))
            _.remove(@markers, m) for m in markersToRemove

        if brackets.do.mvcursor?
          if brackets.do.mvcursor > 0
            @editor.moveRight() for [0..brackets.do.mvcursor-1]

        return false


  wrapSelectionInBrackets: (bracket) =>
    return false unless @isOpeningBracket(bracket)

    selectionWrapped = false
    pair = @pairs[bracket]
    t = this

    @editor.mutateSelectedText (selection) =>
      # TODO: make sure you are in correct grammar first!
      return if selection.isEmpty()
      range = selection.getBufferRange()
      return unless @getScopedSetting('bracket-matcher.wrapSelectionsInBrackets', range.start) and @getScopedSetting('bracket-matcher.wrapSelectionsInBrackets', range.end)

      scopes = @editor.scopeDescriptorForBufferPosition(range.start).scopes
      return unless scopes[0] == 'text.html.octobercms' and scopes[1] == 'text.html.twig.octobercms'
      scopes = @editor.scopeDescriptorForBufferPosition(range.end).scopes
      return unless scopes[0] == 'text.html.octobercms' and scopes[1] == 'text.html.twig.octobercms'

      options = reversed: selection.isReversed()
      brackets = @getBrackets range.start, range.end, bracket, true
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

  getBrackets: (rangeStart, rangeEnd, key, wrap) =>
    textBefore = @reverseText @editor.getTextInBufferRange([rangeStart.traverse([0, -3]), rangeStart])
    textAfter = @editor.getTextInBufferRange([rangeEnd, rangeEnd.traverse([0, 3])])

    return unless key of @pairs

    for obj in @pairs[key]
      if (wrap and obj.canwrap is true) or not wrap
        satisfiesNeeds = true

        if obj.requires?
          if obj.requires.before?
            rb = @reverseText obj.requires.before
            if textBefore.substr(0, rb.length) != rb
              satisfiesNeeds = false

          if obj.requires.after?
            ra = obj.requires.after
            if textAfter.substr(0, ra.length) != ra
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

  backspace: =>
    return if @editor.hasMultipleCursors()
    return unless @editor.getLastSelection().isEmpty()

    rangePoint = @editor.getLastCursor().getBufferPosition()

    cPosition = @editor.getCursorBufferPosition()
    textBefore = @reverseText @editor.getTextInBufferRange([rangePoint.traverse([0, -3]), cPosition])
    textAfter = @editor.getTextInBufferRange([rangePoint, rangePoint.traverse([0, 3])])

    for rule in @bspace
      satisfiesNeeds = true

      if rule.requires.before?
        rb = @reverseText rule.requires.before
        if textBefore.substr(0, rb.length) != rb
          satisfiesNeeds = false

      if rule.requires.after?
        ra = rule.requires.after
        if textAfter.substr(0, ra.length) != ra
          satisfiesNeeds = false

      if satisfiesNeeds and @getScopedSetting('bracket-matcher.wrapSelectionsInBrackets', rangePoint)
        if rule.delete.before?
          db = rule.delete.before
        else
          db = 0

        if rule.delete.after?
          da = rule.delete.after
        else
          da = 0

        @editor.transact =>
          @editor.moveLeft() for [0..db-1]
          @editor.delete() for [0..db+da-1]
        return false

  reverseText: (string) ->
    string.split('').reverse().join('')

  isOpeningBracket: (string) ->
    ['{', '%', '#', ' '].indexOf(string) isnt -1

  isClosingBracket: (string) ->
    ['}', '%', '#', ' '].indexOf(string) isnt -1

  unsubscribe: ->
    @ssubscriptions.dispose()

  getScopedSetting: (key, point) =>
    atom.config.get(key, scope: @editor.scopeDescriptorForBufferPosition(point))
