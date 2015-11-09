{CompositeDisposable} = require "atom"

module.exports =

  activate: ->
    atom.packages.onDidActivatePackage(@test)
    atom.packages.onDidDeactivatePackage(@test)

  deactivate: ->
    @subscriptions.dispose();

  test: ->
    if atom.packages.isPackageActive('emmet')
      document.documentElement.classList.add('emmet')
    else
      document.documentElement.classList.remove('emmet');
