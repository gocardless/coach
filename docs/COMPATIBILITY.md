# Compatibility

Our goal as Coach maintainers is for the library to be compatible with all supported versions of Ruby and Rails.

Specifically, any CRuby/MRI version that has not reached [End of Life](https://endoflife.date/ruby) is supported. Similarly, any version of Rails listed as currently supported on [this page](https://endoflife.date/rails) is one we aim to support in Coach.

To that end, [our build matrix](../.github/tests.yml) includes all these versions.

Any time Coach doesn't work on a supported combination of Ruby and Rails, it's a bug, and can be reported [here](https://github.com/gocardless/coach/issues).

# Deprecation

Whenever a version of Ruby or Rails falls out of support, we will mirror that change in Coach by updating the build matrix and releasing a new major version.

At that point, we will close any issues that only affect the unsupported version, and may choose to remove any workarounds from the code that are only necessary for the unsupported version.

We will then bump the major version of Coach, to indicate the break in compatibility. Even if the new version of Coach happens to work on the unsupported version of Ruby or Rails, we consider compatibility to be broken at this point.
