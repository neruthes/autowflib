# AutoWFLib Documentation: Font Spec Format

This article describes how a font is defined in this repository.


## Path

A font must have a major category and a minor category, which are reflected in the path.
For example, if we ever adopt a digitalization of the classic **Frutiger** in this library,
it should own a directory at `/fonts/sans-humanist/frutiger`.

Its definition directory ("defdir") must only use lowercase alphanumerical characters and hyphen.


## Structure

Inside the defdir of a font, the following files should exist:

| Filename | Description                                                                      |
| -------- | -------------------------------------------------------------------------------- |
| info     | Some metadata of the font identity.                                              |
| build.sh | A script which provides certain functions to be used by the actual build script. |
