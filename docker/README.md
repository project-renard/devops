# Docker setup 

1. Install [docker](https://www.docker.com/). For some windows machines you will need to install the docker-toolbox, which uses `Oracle VM VirtualBox` to run.
2. Create a docker machine (only if you have not got one)

```shell
docker-machine create  default
```

3. Get the ENV vars which the docker client needs in order to connect to the docker machine (server) [This you will need to do every time or set in your ENV vars]

```
docker-machine.exe env default
```

4. You can either install them manually or run one of the following depending on your shell environment (cmd, bash, power-shell)

```shell
docker-machine env --shell=cmd # you need to run it manually
docker-machine env --shell=bash > env-var-commands-tmp && . env-var-commands-tmp && rm env-var-commands-tmp
docker-machine env --shell=powershell | Invoke-Expression
```

5. Pull the docker image you would like to work with

```shell
docker pull debian
```
