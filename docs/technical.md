---
title: Technical documentation
description: How the COSMIC Desktop Extras tools work, which files they install, their settings, patch maintenance and tests.
---

{%- comment -%}
  Links in README.md point to the .md pages; on the site they are .html. Links to README.md files
  stay: those are outside docs/ and the layout sends them to GitHub.
{%- endcomment -%}
{%- capture readme -%}{% include_relative README.md %}{%- endcapture -%}
{{ readme | replace: ".md)", ".html)" | replace: "README.html)", "README.md)" }}
