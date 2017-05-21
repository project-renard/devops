
# Docker [quick-start-guide](https://docs.docker.com/get-started/)

# Docker setup 

1. Install [docker](https://www.docker.com/). For some windows machines you will need to install the docker-toolbox, which uses `Oracle VM VirtualBox` to run.
2. Create a docker machine (only if you have not got one)

    ```shell
    docker-machine create  default
    ```

3. Get the ENV vars which the docker client needs in order to connect to the docker machine (server) [This you will need to do every time or set in your ENV vars]

    ```shell
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
    docker pull debian # docker pull <repository>
    ```
6. Run the machine

    ```shell
    docker run -i -t debian # docker run -i -t <friendly name>
    ```
7. Having amde all your changes, you can now `exit`

    ```shell
    docker ps -a 
    docker diff 516c25bb3b8c # docker diff <the id of the machine eddited>
    docker commit 516c25bb3b8c debian:thechange # docker commit <the id of the machine eddited> <repository>:<name-of-change> #

    docker images # you can see the changes
    ```

# [Custom docker](https://www.youtube.com/watch?v=hnxI-K10auY)

```shell
docker build -t curie-test docker-repository/ # docker build -t <friendly name> <docker repository directory>
# docker run --name curie-test  <docker-id>  # docker run --name curie-test <idproduced by docker build>
docker run curie-test # docker run <friendly name> 
docker rm curie-test # cleanup 
```

# Sending commands to a runnig docker image

```shell
# Start a dettached docker
docker run -d perl # docker run -d <image name> 
# List docker images
docker ps
# Execute a command
docker exec -it 87ae864730 bash -c 'ls /' # docker exec -it <runing docker unique id> bash -c '<bash command>'
# Stop the docker execution
docker stop 87ae864730
```
