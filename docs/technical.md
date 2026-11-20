---
title: Technical documentation
description: How the Desktop Extras for COSMIC™ tools work, which files they install, their settings, patch maintenance and tests.
---

{%- comment -%}
  Links in README.md point to the .md pages; on the site they are .html. Links to README.md files
  stay: those are outside docs/ and the layout sends them to GitHub. The README.md of a docs/
  subfolder is that folder's index page on the site.
{%- endcomment -%}
{%- capture readme -%}{% include_relative README.md %}{%- endcapture -%}
{{ readme | replace: ".md)", ".html)" | replace: "README.html)", "README.md)" | replace: "](text-editor/README.md)", "](text-editor/)" }}
