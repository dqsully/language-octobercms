# coffeelint: disable=max_line_length
{CompositeDisposable} = require 'atom'

TwigMatcher = require './twig-matcher'


module.exports =
  activate: ->
    @subscriptions = new CompositeDisposable
    subs = @subscriptions

    @subscriptions.add atom.packages.onDidActivatePackage (pkg) ->
      if pkg.name is 'bracket-matcher'
        # Make sure that the bracket-matcher package gets first-dibs
        subs.add atom.workspace.observeTextEditors (editor) ->
          editorElement = atom.views.getView(editor)

          new TwigMatcher(editor, editorElement)
      else if pkg.name is 'emmet'
        document.documentElement.classList.add 'emmet'

    if atom.packages.getActivePackage 'bracket-matcher'
      # Make sure that the bracket-matcher package gets first-dibs
      subs.add atom.workspace.observeTextEditors (editor) ->
        editorElement = atom.views.getView(editor)

        new TwigMatcher(editor, editorElement)

    @subscriptions.add atom.packages.onDidDeactivatePackage (pkg) ->
      if pkg.name is 'emmet'
        document.documentElement.classList.remove 'emmet'

  deactivate: ->
    @subscriptions.dispose()
