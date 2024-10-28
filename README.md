# metacopy
A macOS command-line tool for backing up and restoring only the metadata of files/directories but not their contents.

* Can also be used recursively to maintain directory structure (for backup/archive purposes for example)
* Copying works in both directions:
  * Backup: If a target file doesn't exist, a new empty file (zero bytes) will be created but with the same metadata as the source file
  * Restore: If a target file already exists, only the metadata of that file will be updated and the contents remain unchanged
* Symlinks and aliases are copied as is (not as empty files and not resolved to their targets)
* Extended Attributes (xattrs) are copied additively, i.e. only xattrs with the same name will be overwritten, other source xattrs added and other target xattrs left unchanged.
* Can copy the following metadata:
  * **Dates:** creation, modification and access dates
  * **Permissions:** POSIX permissions, owner and group IDs/names (Access Control Lists are not yet supported!)
  * **Extended Attributes:** e.g. color labels
  * **File flags:** hidden and immutable (aka. "locked") flags

Overall behaviour is similar to GNU's `cp -a --attributes-only` with the important exception that the `cp` command will truncate the the target files to zero bytes if they already exist.  
So you can't use the `cp` command for example when you want to restore metadata from a previous backup to existing files (that you want to keep the contents of)!

## Usage

```
USAGE:  metacopy [OPTIONS ...] <input file> <output file>

ARGUMENTS:
  <input file>      The path to the input file or directory.
  <output file>     The path to the output file or directory.

RECURSIVE MODE OPTIONS:
  -r                Recursively copy contents of directory. Input and output need to be
                    directories.
  -s                Skip files when encountering errors instead of canceling.
                    An error message is still printed to STDERR. Recursive mode only.
  -v                Print relative paths of successfully copied files to STDOUT.
                    Recursive mode only.

METADATA OPTIONS:
  --no-dates        Don't copy creation and modification dates.
  --no-perms        Don't copy permissions, owner and group.
  --no-xattrs       Don't copy extended attributes.
  --no-flags        Don't copy "hidden" and "immutable" flags.
  --no-hfs          Don't copy HFS type and creator codes.

GENERAL OPTIONS:
  -h, --help        Show help information.
```

## Download compiled binary

Instead of building the tool yourself, you can download a compiled binary for macOS from the [**latest&nbsp;release**](https://github.com/YourMJK/metacopy/releases/latest).

## Build prerequisites

To build the package, the Swift toolchain version 5.7 or higher needs to be installed.
- For macOS either [download Xcode from the AppStore](https://apps.apple.com/us/app/xcode/id497799835) or run `xcode-select --install` to just get the Command Line Tools.  
Swift 5.7 requires at least Xcode 14 and macOS 12.5 Monterey.

## Build

Build the Swift Package and copy executable to `bin/`:
```
$ make
```
Automatically install executable into `/usr/local/bin/`:
```
$ make install
```
