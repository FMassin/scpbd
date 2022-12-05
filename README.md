# msrtsimul in a Docker

> Miniseed data playback in SeisComP requires [configuring a dedicated seedlink server appropriately for msrtsimul](https://www.seiscomp.de/doc/base/tutorials/waveformplayback.html) and the related metadata. Using **msrtsimul in a docker** (*msrtsimuld*), all of this is done automatically via SeisComP tools leaving your system config untouched. The only dependencies are [docker](https://docs.docker.com/engine/install/) and ssh ([OSX](https://support.apple.com/en-gb/guide/mac-help/mchlp1066/mac)).  

1. First make sure that [you complete `docker login ghcr.io/fmassin/msrtsimuld`](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry#authenticating-to-the-container-registry)
2. Start the docker (only once or when updating docker image)
    ```bash
    docker stop msrtsimuld && docker rm msrtsimuld # That is in case you update an existing one 
    docker run -d \
            --add-host=host.docker.internal:host-gateway  \
            -p 18000:18000 \
            --name msrtsimuld \
            ghcr.io/fmassin/msrtsimuld:main
    ```
3. Allow container `msrtsimuld` to copy from your computer (once per image run)
    ```bash
    docker exec -u 0  -it msrtsimuld ssh-keygen 
    docker exec -u 0  -it msrtsimuld ssh-copy-id $USER@host.docker.internal 
    ```
4. Define a shortcut function (once per host session)
    ```bash
    msrtsimuld () {docker exec -u 0  -it msrtsimuld main $@ ; } 
    ```
5. Playback your data (e.i., `$(pwd)/data.mseed`) using your metadata and its format (e.i., `$(pwd)/inv.xml,sc3` for an `sc3` format, include level station for best efficiency)... Note the IP at the begining of stdout
    ```bash
    msrtsimuld $USER@host.docker.internal:$(pwd)/data.mseed $USER@host.docker.internal:$(pwd)/inv.xml,sc3
    ```

Once data are being played back and given container IP is 172.17.0.4: 
```
slinktool -Q 172.17.0.4
```