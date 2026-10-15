# Bundled mathematics renderer

`tex-mml-svg.js` is the unmodified MathJax 3.2.2 combined TeX/MathML-to-SVG component.

- Source: https://cdn.jsdelivr.net/npm/mathjax@3.2.2/es5/tex-mml-svg.js
- License: Apache-2.0; full license is in `LICENSE`.
- Documentation: https://docs.mathjax.org/en/v3.2/web/components/combined.html

The reading view loads this asset locally, so equation rendering does not require
an internet connection. YouTube streams and remote lesson images still require
network access. Arbitrary scripts from lesson HTML are removed before display.
