This repo contains all the files needed to create a containerised Apache Git HTTP server from scratch on a Linux host machine.

### Steps to setup Git server:
1. Prepare host machine by running the host setup file
    ``` bash
        sudo ./initial-host-setup.sh
    ```
2. Copy all of the below files to host machine's directory path: `/var/www/setup-scripts`:
    - Dockerfile
    - docker-compose.yaml
    - git-http.conf
    - apache-performance.conf
    - mirror-aosp.sh
3. Start the docker compose stack (and build image)
    ``` bash
        sudo docker compose up --build
    ```
4. Start AOSP mirror process by running the `mirror-aosp.sh` script inside the container: `sdv-mirror-git-server` (or whatever name you have chosen for git server container) by
    ``` bash
        sudo docker exec -it sdv-mirror-git-server bash -c "/var/www/setup-scripts/mirror-aosp.sh > /var/www/setup-scripts/mirror-aosp.log 2>&1"
    ```