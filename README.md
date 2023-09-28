# JBrowse2 Containerized Service

This project provides the capability to build a [JBrowse 2](https://jbrowse.org/jb2) docker image which can be run using `docker compose`.

## Building Locally ##

Note this will overwrite the latest 

```
> git clone git@github.com:VEuPathDB/jbrowse2.git
> cd jbrowse2
> docker build -t jbrowse2 .
```

## Building in Jenkins ##

The repo includes a Jenkinsfile that uses [pipelib](https://github.com/VEuPathDB/pipelib) to build the image and upload it to DockerHub

## Configuration ##

The image depends on the following environment variables to configure it.  See sample.env for sample values.

- JBROWSE2_IMAGE_NAME: compose dependency deciding which image to use; defaults to `veupathdb/jbrowse2` but set to `jbrowse2` if developing this container locally
- JBROWSE2_SERVER_PORT: port on which service should run (defaults to 8080 if this value is not present)
- MACHINE_FILES_DIR: data directory on the parent system where track files and a JBrowse2 `config.json` file are located

The track files and config.json must be generated in advance.  See [JBrowse documentation](https://jbrowse.org/jb2/docs/)) for what file types are supported and the format of the config.json file.

## Starting the Container with Docker Compose ##

A docker-compose.yml file is included to support compose stack deployment.

To run with `docker compose`:
```
> cp env.sample .env  # then edit .env to set appropriate values
> docker compose up
```

If successful, you should be able to use JBrowse 2 in a web browser at http://localhost:8080

If you are running docker-traefik, you should also be able to use JBrowse 2 at https://jbrowse2-dev.local.apidb.org
