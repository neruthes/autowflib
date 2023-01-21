# AutoWFLib Documentation: Font Spec Format

This article collects tips and thoughts on the security implications of this repository.


## Shell Script

The fetching and building processes are largely powered by shell scripts,
which are inherently capable of doing a lot of actions without good ways to restrict.

You should consider doing the fetching and building processes under a special account,
which has no access to your $HOME.


