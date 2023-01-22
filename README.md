# Automated Web Font Library

Some fonts are not available on Google Fonts, and the submission-approval process can destroy patience.
Perhaps this place is an alternative home.

Website: [https://autowflib.pages.dev/](https://autowflib.pages.dev/).

The website shows the complete list of collected fonts and supports searching by font name.

CSS/WOFF2 artifacts are served over Cloudflare CDN and hosted on Cloudflare Pages.







## Contributing

### Font Inclusion

The font being submitted for inclusion in this repository must satisfy the following criteria:

- It is published with GPL, OFL, MIT, or some similar license (permitting unlimited web embedding).
- If it is a fork of another open source font, it is differentiated enough from its upstream, or has at least some basic popularity (e.g. 100 stars on GitHub).
- If the submission to this library is not made by the font creator/maintainer themselves:
  - The font should have some basic popularity.
  - The font is not available on Google Fonts.

### Pull Requests

Our workflow is similar to software packaging in GNU/Linux communities.

Suppose that you are going to submit a font "My First Font" under category "sans-humanist".

Steps for making a good pull request:

- Fork this repo.
- Clone to your machine.
- Create the `/fonts/sans-humanist/my-first-font/info` file according to [FontSpecFormat.md](docs/FontSpecFormat.md). Refer to the definitions of other fonts when in doubt. Also, the `/addfont.sh` interactive script can make the creation of the `info` file more friendly.
- Create a `build.sh` file along with it, only if necessary.
- Run `./make.sh fonts/sans-humanist/my-first-font`.
- Make sure that the command above produces expected WOFF2 files and CSS files in `/distdir/fonts/sans-humanist/my-first-font`.
- Commit, push, and create a pull request.
- Include the generated log file `buildlog.txt` in the pull request as an attachment.






## Copyright

### The AutoWFLib Project

Copyright (c) 2023 Neruthes, and other contributors.

The source code and documentation included in this repository are published with
[GNU AGPL 3.0](https://www.gnu.org/licenses/agpl-3.0.html).
These specifically include: all Markdown documents (`.md`, including this one),
all shell scripts (`.sh`), and the entire `/wwwsrc` directory.

The image assets (`png` and `jpg`) are published with
[CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).

### The Collected Fonts

The collected fonts are copyrighted by their original owners.
We at this project merely make the font files easier for web usage.

The names of the fonts may be trademarks of their respective owners.

For any collected font, our WOFF2 artifacts are released with the same license
which the original font files come with (share-alike).
And our CSS artifacts are released under the MIT license.
