# msrtsimul in a Docker

First make sure you complete `docker login ghcr.io/fmassin/msrtsimuld`

1. Start the docker (only once or when updating docker image)
    ```bash
    docker stop msrtsimuld && docker rm msrtsimuld  
    docker run -d \
            --add-host=host.docker.internal:host-gateway  \
            -p 18000:18000 \
            --name msrtsimuld \
            ghcr.io/fmassin/msrtsimuld:main
    ```
2. Allow container `msrtsimuld` to copy from your computer (once per image run)
    ```bash
    docker exec -u 0  -it msrtsimuld ssh-keygen 
    docker exec -u 0  -it msrtsimuld ssh-copy-id $USER@host.docker.internal 
    ```
3. Define a shortcut function (once per host session)
    ```bash
    msrtsimuld () {docker exec -u 0  -it msrtsimuld main $@ ; } 
    ```
4. Playback your data (e.i., `$(pwd)/data.mseed`) using your metadata and its format (e.i., `$(pwd)/inv.xml,sc3` for an `sc3` format, include level station for best efficiency)... Note the IP at the begining of stdout
    ```bash
    msrtsimuld $USER@host.docker.internal:$(pwd)/data.mseed $USER@host.docker.internal:$(pwd)/inv.xml,sc3
    ```

Once data are being played back and given container IP is 172.17.0.4: 
```
slinktool -Q 172.17.0.4
```