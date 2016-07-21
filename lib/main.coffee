{CompositeDisposable} = require 'atom'

TwigMatcher = null

module.exports =
  activate: ->
    @subscriptions = new CompositeDisposable

    @subscriptions.add atom.workspace.observeTextEditors (editor) ->
      editorElement = atom.views.getView(editor)

      # TwigMatcher ?= require './twig-matcher'
      # new TwigMatcher(editor, editorElement)

    @subscriptions.add atom.packages.onDidActivatePackage(@test)
    @subscriptions.add atom.packages.onDidDeactivatePackage(@test)

  deactivate: ->
    @subscriptions.dispose()

  test: ->
    document.documentElement.classList[if atom.packages.isPackageActive('emmet') then 'add' else 'remove'] 'emmet'
