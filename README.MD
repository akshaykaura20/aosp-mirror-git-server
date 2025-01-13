This repo contains all the files needed to create a containerised Apache Git HTTP server from scratch on a Linux host machine.

### Steps to setup Git server:
1. Prepare host machine by running the host setup file as root:
    ``` bash
    sudo chmod +x ./initial-host-setup.sh
    sudo ./initial-host-setup.sh
    ```
2. In the file: `apache-server-name.conf`, the property `ServerName` is defined and could either be an IP or a domain. This should ideally be **set to the host machine's IP/ domain.**
3. Copy all of the below files to host machine's directory path: `/var/www/setup-scripts`:
    - Dockerfile
    - docker-compose.yaml
    - git-http.conf
    - apache-performance.conf
    - apache-server-name.conf
    - mirror-aosp.sh
4. Create a `.env` file at the same location: `/var/www/setup-scripts` and populate it with:
    ```.env
    USERNAME=root
    PASSWORD=<your-password>
    ```
5. Start the docker compose stack (and build image) from the directory `/var/www/setup-scripts`:
    ``` bash
    sudo docker compose up --build
    ```
6. Start AOSP mirror process by running the `mirror-aosp.sh` script inside the container: `sdv-mirror-git-server` (or whatever name you have chosen for git server container) by
    ``` bash
    sudo docker exec -it sdv-mirror-git-server bash -c "/var/www/setup-scripts/mirror-aosp.sh > /var/www/setup-scripts/mirror-aosp.log 2>&1"
    ```