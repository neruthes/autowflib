# AutoWFLib Documentation: Font Spec Format

This article describes how a font is defined in this repository.





## Path

A font must have a major category and a minor category, which are reflected in the path.
For example, the transitional serif font **C059** (a member of Century Schoolbook series) in this library
owns a directory at `/fonts/sans-trans/c059`.

Its definition directory ("defdir") must only use lowercase alphanumerical characters and hyphen.


## Structure

Inside the defdir of a font, the following files should exist:

| Filename | Description                                                                                 |
| -------- | ------------------------------------------------------------------------------------------- |
| info     | Some metadata of the font identity.                                                         |
| build.sh | (Optional) A script which provides certain functions to be used by the actual build script. |

### info

Example:

```
id="c059"
family="C059"
cat="serif-trans"
about="URW New Century Schoolbook"
license="OFL"

download="https://fontesk.com/download/39316/"
format="zip"
sha256="99f2595b3093f82faf9f054947544d2839a769ef8c8c926883e4e5e8c5fd4b76"

infopage="https://fontesk.com/century-schoolbook-typeface/"

convert_from="otf"
convert_from_prefix=""

weight_map="400:C059-Roman
400i:C059-Italic
600:C059-Bold
600i:C059-BdIta"
```

This file (as a shell script) shall contain these variables:

| Variable Name    | Description                                                                                                      |
| ---------------- | ---------------------------------------------------------------------------------------------------------------- |
| `id`             | The machine-friendly identifier. Must be unique across all categories.                                           |
| `family`         | The human-friendly family name. Must be equal to the one read from OTF/TTF metadata.                             |
| `cat`            | Category identifier, like `serif-trans`.                                                                         |
| `about`          | Short description.                                                                                               |
| `license`        | Must be `GPL` or `OFL`. More to add in future.                                                                   |
| `download`       | Upstream archive file URL.                                                                                       |
| `format`         | Format of the archive file. Can be `zip`. More to add in future.                                                 |
| `sha256`         | Expected SHA-256 hash of the archive file. Encoded hexadecimal.                                                  |
| `infopage`       | The introduction webpage.                                                                                        |
| `convert_from`   | Convert from this format to WOFF2. Can be `otf`, `skip`. Magic `skip`: Zip includes WOFF2.                       |
| `convert_subdir` | (TODO) Only use the files which reside in this sub-directory (relative to the extraction root `$workdir/build`). |
| `weight_map`     | A **weight map**, whose format is documented in a later section.                                                 |





## Categories

A category identifier ("catcode") consists of two required parts: major category ("majcat") and minor category ("mincat").
The values of both majcat and mincat must be chosen from the following lists.

Available major categories:
| Name    | Meaning       |
| ------- | ------------- |
| serif   | Serif         |
| sans    | Sans-serif    |
| mono    | Monospace     |
| display | Display       |
| calli   | Calligraphy   |
| emoji   | Emoji         |
| misc    | Miscellaneous |

Available global minor categories:
| Name  | Meaning                   | Example          |
| ----- | ------------------------- | ---------------- |
| x     | To be decided later       | -                |
| cjk   | Designed for CJK          | Noto Sans CJK SC |
| human | Humanist                  | Frutiger         |
| geo   | Geometric                 | Avenir           |
| trans | Transitional              | Georgia          |
| old   | Old-style                 | EB Garamond      |
| type  | Typewriter                | Courier          |
| other | Can hardly be categorized | -                |

Available local minor categories by allowed range:
- sans
  - `did`: Didone. E.g. Didot.
- sans
  - `grot`: Grotesque and neo-grotesque. E.g. Helvetica.
- mono
  - `code`: Fonts used for software code editors and modern terminal emulators. E.g. JetBrains Mono.
- display
  - `gothic`: Grotesque and neo-grotesque. E.g. Bertholdr Mainzer Fraktur.
  - `magic`: Related feelings of magic. E.g. IM FELL English, Papyrus.
- calli
  - `hand`: Handwritten style.
  - `cursive`: Classical cursive style.
- misc
  - `deco`: Not letters, but symbols. E.g. Webdings, FontAwesome.

The categories defined above may still lack some aspects of real-world typography.
If you have any particular category in mind, please recommend it by opening an issue.




## Weight Map

A weight map is a multi-line piece of text which contains such lines:

```
WeightCode:FilenameMajor
```

Empty lines and leading/trailing LF will not break things.

### WeightCode

The WeightCode consists of two parts:
- WeightNumber (required)
- Italic Indicator (optional)

For example, a variant for `font-weight: 600; font-style: italic;` should have a line `600i` in the weight;

### FilenameMajor

The FilenameMajor is the filename of the font without the extension (`.woff2`).

### Example

Example:

```
400:C059-Roman
400i:C059-Italic
600:C059-Bold
600i:C059-BdIta
```
