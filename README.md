# JBrowse2 Containerized Service

This project provides the capability to build a [JBrowse 2](https://jbrowse.org/jb2) docker image which can be run using `docker run` or `docker compose`.

**Building Locally**

```
> git clone git@github.com:VEuPathDB/jbrowse2.git
> cd jbrowse2
> docker build -t jbrowse2 .
```

**Building in Jenkins**

The repo includes a Jenkinsfile that uses [pipelib](https://github.com/VEuPathDB/pipelib) to build the image and upload it to DockerHub

**Configuration**

The image depends on two environment variables to configure it.  See sample.env for sample values.

- JBROWSE2_SERVER_PORT: port on which service should run
- MACHINE_FILES_DIR: data directory on the parent system where track files and a JBrowse2 `config.json` file are located (see [JBrowse documentation](https://jbrowse.org/jb2/docs/))

This repo contains a set of sample data files and a config.json file that points at them.

**Starting the Container**

The container can be run with either `docker run` or `docker compose`.

To run with `docker run`:
```
> cp env.sample .env  # then edit .env to set appropriate values
> set -a; . .env; set +a
> docker run --rm jbrowse2:latest
```

