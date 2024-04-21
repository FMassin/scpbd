# SeisComP playback in a docker

> Miniseed data playback in SeisComP requires [configuring a dedicated seedlink server appropriately for msrtsimul](https://www.seiscomp.de/doc/base/tutorials/waveformplayback.html) and the related metadata. Using **SeisComP playback in a docker** (`scpbd`), all of this is done automatically via SeisComP tools leaving your system config untouched. The only dependencies are [docker](https://docs.docker.com/engine/install/) and ssh ([OSX](https://support.apple.com/en-gb/guide/mac-help/mchlp1066/mac)).  

> This is based on https://github.com/yannikbehr/sc3-playback developed by @yannikbehr.

1. First, make sure that [you complete `docker login ghcr.io/fmassin/scpbd`](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry#authenticating-to-the-container-registry)
2. Start the docker (only once or when updating docker image, old docker version: replace `host-gateway` by `$(ip addr show docker0 | grep -Po 'inet \K[\d.]+')`)
    ```bash
    docker stop scpbd && docker rm scpbd # That is in case you update an existing one 
    docker run -d \
            --add-host=host.docker.internal:host-gateway  \
            -p 18000:18000 \
            -p 222:22 \
            --name scpbd \
            ghcr.io/fmassin/scpbd:main
    ```
3. Allow container `scpbd` to copy from your computer (once per image run)
    ```bash
    docker exec -u 0  -it scpbd ssh-keygen -t rsa -N '' 
    docker exec -u 0  -it scpbd ssh-copy-id $USER@host.docker.internal 
    ```
4. Define a shortcut function (once per host session)
    ```bash
    scpbd () { docker exec -u 0  -it scpbd main $@ ; } 
    ```
5. Playback your data (e.i., `$(pwd)/data.mseed`) using your metadata and its format (e.i., `$(pwd)/inv.xml,sc3` for an `sc3` format, include station level for best efficiency)... Note the IP at the beginning of stdout
    ```bash
    scpbd $USER@host.docker.internal:$(pwd)/data.mseed $USER@host.docker.internal:$(pwd)/inv.xml,sc3
    ```
6. Reprocess the data within a real-time simulation respecting data timestamps by adding a sqlite3 database as 3rd argument:
    ```bash
    docker exec -u sysop  -it scpbd /home/sysop/seiscomp/bin/seiscomp enable scautopick scamp  scautoloc scevent sceewenv scvsmag

    scpbd $USER@host.docker.internal:$(pwd)/test/data.mseed $USER@host.docker.internal:$(pwd)/test/inv.xml,sc3 
    ```

> Point 6 requires SeisComP automatic processing modules to be enabled and configured, e.g., with `ssh -p 222 sysop@localhost scconfig`

Once data are being played back: 
```
slinktool -Q localhost
```

# Build locally and test 
For developing purpose
```bash
docker build -f "Dockerfile" -t scpbd:latest "."
docker stop scpbd && docker rm scpbd 
docker run -d \
        --add-host=host.docker.internal:host-gateway  \
        -p 18000:18000 \
        -p 222:22 \
        --name scpbd \
        scpbd:latest

docker exec -u 0  -it scpbd ssh-keygen -t rsa -N '' 
docker exec -u 0  -it scpbd ssh-copy-id $USER@host.docker.internal 

scpbd () { docker exec -u 0  -it scpbd main $@ ; } 

docker exec -u sysop  -it scpbd /home/sysop/seiscomp/bin/seiscomp enable scautopick scamp  scautoloc scevent sceewenv scvsmag

scpbd $USER@host.docker.internal:$(pwd)/test/data.mseed $USER@host.docker.internal:$(pwd)/test/inv.xml,sc3 
```