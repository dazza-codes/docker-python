# docker-python

This project is motivated by trying to use docker-in-docker
for gitlab-CI that runs python test suites where something
needs a docker container/service.

THIS IS NOT AN OFFICIAL DOCKER or PYTHON repository and
NO SUPPORT will be provided and issues might not get any
attention.  See the links below for official projects.
Feel free to use this repository to push changes upstream
to official projects - it's all Apache-2.0; if the
approaches in this repository are pushed upstream, it
should die a natural deprecation.  If you need changes,
review the links below and fork it to do it yourself;
PRs are welcome but don't expect anything to change in
a timely manner.

## Approach

- use https://github.com/docker-library/docker as a
  base image to build python versions
- adapt https://github.com/docker-library/python/
  - focus on the alpine builds
  - use docker base image, which is based on alpine
  - add bash and default to CMD ["/bin/bash"]

## Docker Images

- https://hub.docker.com/r/dazzacodes/docker-python
  - warning: could be obsolete or abandoned at any time

## Use

```text
make update
PY_VER=3.6 make build
PY_VER=3.7 make build
PY_VER=3.8 make build
```

Each build will run python tests.  If they build, they should be OK, but
check each build with something like:

```text
PY_VER=3.6 make shell
# python --version
# python
>>> import random
>>> random.uniform(1,10)
```

If it looks OK, it could get pushed to DockerHub (requires a manual login):

```text
PY_VER=3.6 make push
```

## License

```text

   Copyright 2020 Darren Weber

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.

```
