# Git Signatures #

This repo includes extensions and workflow examples for being able to attach
an arbitrary number of GPG signatures to a given commit or tag.

Git already supports commit signing. These tools are intended to complement
that support by allowing a code reviewer and/or release engineer attach
their signatures as well.

A CI or build system that enforces m-of-n signature verification on git tags
to be released offers strong protection against tampering of the repository
by a single bad actor or compromised system.

This approach builds entirely on the git-notes interface which allows the
attachment of arbitrary data to an existing commit.

## Requirements ##

  * Git 2.1+
  * GnuPG 2.2+

### Mac OS X ###

Since the built in getopt and date binaries are not compatible with this script, you must install some GNU compatible binaries (homebrew recommended).

  * gnu-getopt
    * `brew install gnu-getopt`
    * `ln -s $(brew --prefix gnu-getopt)/bin/getopt /usr/local/bin/gnu-getopt`
  * coreutils
    * `brew install coreutils`

Make sure that the `gnu-getopt`, `gdate`, and `gshuf` binaries are in your $PATH.

## Install ##

You need only place bin/git-signatures anywhere in your $PATH.

By default you can install it to $HOME/.local/bin with:

```
make install
```

## Usage ##

### Pull and merge signatures from origin

```
git signatures pull
```

### Sign a tag

```
git signatures add v1.0.0
```

### Push new signatures to origin

```
git signatures push
```

### Pull/merge/sign/push against origin as single step

```
git signatures add --push v1.0.0
```

### Verify signatures

Will return the public key IDs of verified signers:

```
git signatures verify v1.0.0
```

### Verify m-of-n signatures

Verify m-of-n requirement met against default gpg trustdb.
Will return 0 only if conditions met.

```
git signatures verify --min-count 2 v1.0.0
```


### Verify against m-of-n signatures from multiple GPG trustdbs

```
git signatures verify --trustdb dev-team.db --min-count 2 v1.0.0
git signatures verify --trustdb release-team.db --min-count 1 v1.0.0
```

## Implementation ##

git-signatures is only a very simple set of wrappers to offer a shorthand
for git/gpg manipulations.

Signatures are just base64 encoded results of GPG signing a given git hash.
They are appended in the git-notes interface at refs/signatures.

These methods were chosen to make this setup easy to reason about and review.

A manual signing could be performed as:

```
  git rev-parse HEAD | gpg --sign | base64 -w0 | \
    git notes --ref refs/signatures append --file=-
  git push origin refs/signatures
```

A manual verification could be performed as:

```
git fetch origin refs/signatures
git notes merge -s cat_sort_uniq origin/refs/signatures
git notes --ref refs/signatures show | \
  xargs -L1 -I {} sh -c "echo {} | base64 -d | gpg -d"
```

## Notes ##

  Use at your own risk. You may be eaten by a grue.

  Questions/Comments?

  - IRC: [lrvick@irc.freenode.net/6697]()
  - Matrix: [@lrvick:matrix.org]()
  - Email: [lance@lrvick.net](mailto://lance@lrvick.net)
