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
5. Enable (and configure) the required SeisComP automatic processing modules, e.g.:
    ```bash
    docker exec -u sysop  -it scpbd /opt/seiscomp/bin/seiscomp enable scautopick scamp  scautoloc scevent sceewenv scvsmag

    # Check or edit the config
    ssh -p 222 sysop@localhost scconfig
    ```
6. Reprocess your data (e.i., `$(pwd)/data.mseed`) using your metadata and its format (e.i., `$(pwd)/inv.xml,sc3` for an `sc3` format, include station level for best efficiency) within a real-time simulation respecting data timestamps (an optional  sqlite3 database can be provided as 3rd argument). Note the IP at the beginning of stdout. The data from the ETHZ-SED EEW unit-test dataset can be found at https://zenodo.org/doi/10.5281/zenodo.11192289:
    ```bash
    scpbd $USER@host.docker.internal:$(pwd)/test/data.mseed $USER@host.docker.internal:$(pwd)/test/inv.xml,sc3 

    # Check the data during playback (in another terminal window or tab): 
    slinktool -Q localhost
    ```
7. And see the results
    ```bash
    ssh -p 222 sysop@localhost /opt/seiscomp/bin/seiscomp exec scolv -d sqlite3:///home/sysop/event_db.sqlite --offline 
    ```

# Build locally and test 
For developing purpose
```bash
# Build fresh image
docker build -f "Dockerfile" -t scpbd:latest "."

# Stop & remove container
docker stop scpbd && docker rm scpbd 

# Run fresh container
docker run -d \
        --add-host=host.docker.internal:host-gateway  \
        -p 18000:18000 \
        -p 222:22 \
        --name scpbd \
        scpbd:latest

# Allow container `scpbd` to copy from your computer (once per image run)
docker exec -u 0  -it scpbd ssh-keygen -t rsa -N '' 
docker exec -u 0  -it scpbd ssh-copy-id $USER@host.docker.internal 

# Define an `scpbd` shortcut function (once per host session)
scpbd () { docker exec -u 0  -it scpbd main $@ ; } 

# Enable automatic processing modules in `scpbd` container (once per container run)
docker exec -u sysop  -it scpbd /opt/seiscomp/bin/seiscomp enable scautopick scamp  scautoloc scevent sceewenv scvsmag

# Run playback
scpbd $USER@host.docker.internal:$(pwd)/test/data.mseed $USER@host.docker.internal:$(pwd)/test/inv.xml,sc3 

# See results
ssh -p 222 sysop@localhost /opt/seiscomp/bin/seiscomp exec scolv -d sqlite3:///home/sysop/event_db.sqlite --offline 
```