## Perl dependencies

```shell
cpanm Dist::Zilla
dzil authordeps | cpanm
dzil listdeps | cpanm
```

## Run tests

Run the tests using the `prove` test harness:

```shell
# run tests on both the t/ and xt/ directories
prove -lvr t xt
```

Run tests using Dist::Zilla:
```shell
dzil test --all
```

## Coverage on a branch

Requirements:

```shell
cpanm Devel::Cover Pod::Coverage
```

```shell
. $PATH_TO_DEVOPS/ENV.sh  # source the environment
renard_run_cover_on_branch [branch-name]
```
