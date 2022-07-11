# hive repo mirror | hiveos

A simple docker container to take advantage of the hive repo mirror utility provided by [hiveos](https://hiveon.com/os/). The repo will update every hour from crontab and make sure that the files are in sync.

## building and running

hiverepo is meant to be ran in a container. I have provided the dockerfile that I personally use to build the repo. You will be saving the hive repository packages to the container, so it is advised that you use bind mounts.

### building docker container

Don't forget to put in the registry url for the `$REGISTRY` variable.

```bash
cd ~
git clone https://gitlab.com/burningsunrise/hiverepo.git && cd hiverepo
docker buildx build --platform linux/amd64 -t $REGISTRY/hiverepo:latest --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') --push .
```

### docker-compose example:

This compose file is also available in the repo.

```yaml
version: '3.9'
services:
  hiverepo:
    image: $REGISTRY/hiverepo:latest
    container_name: hiverepo
    restart: unless-stopped
    ports:
      - 80:80 # Optional; if you have a reverse proxy may want to use that
    volumes:
      - /home/$USER/hiverepo/repo:/var/www/html/repomirror/repo # Wherever you want to save packages to on your disk
```

After that, run `docker-compose up -d`  and this will start the container. Note that in this compose file the packages will save to disk so they are more permanent than using a volume mount. You will need about ~23gb to save all the packages to disk.

## usage

The repo should be pretty much self-sufficient, it will automatically download new files every hour and make sure that the repo is in sync with the hiverepo, just like the original script does. 

If you wish to download the stable image file of their operating system to the repo, either inside the container run: `download_os` or from your docker host run `docker exec -it hiverepo /usr/bin/download_os`. This will download the latest stable image of their software an put it in the `/var/www/html/repomirror/repo` directory.

If you want to update manually, similarly you can use `update` inside the container or `docker exec -it hiverepo /usr/bin/update`. This will sync the repo to the offical hive repository. 