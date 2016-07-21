# language-octobercms package

Provides language support for [October CMS's](http://octobercms.com) template file syntax.
**NOTE:** Because of the limitations of the Atom grammar system, ``{##}`` must be at the beginning of your Twig/HTML script.

## Dependencies:
**NONE!** (check the update notes)

## Recent Update:
* Eliminates need for dependencies
* Eliminates need for ";;" at the beginning of the document (however ";;" still tells Atom to automatically use this language)
* Fixes bug where text indentation in the Twig section would not work properly
* Fixes bug where Twig did not have priority over HTML in strings

## Soon to come:
* Custom bracket autocompletion in the Twig portion of your files
* Custom snippets
* Customized Twig for OctoberCMS

![A screenshot of your package](https://github.com/dqsully/language-octobercms/blob/master/screenshot.png?raw=true)
