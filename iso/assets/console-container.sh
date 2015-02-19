#!/bin/sh
set -e

logger -s -p user.info -t "console[$$]" "Waiting for Docker"
while sleep 0.1; do
    if docker ps >/dev/null 2>&1; then
        break
    fi
done

logger -s -p user.info -t "console[$$]" "Setting up network"
if ! docker inspect dhcp >/dev/null 2>&1; then
    docker import - dhcp < /.dhcp.tar
fi
docker run --rm -it --net host --cap-add NET_ADMIN dhcp udhcpc -i eth0

logger -s -p user.info -t "console[$$]" "Starting up Dropbear SSH"
dropbear -s

docker tag -f dhcp console-image:latest

logger -s -p user.info -t "console[$$]" "Starting up console"
while true; do
    if docker inspect console >/dev/null 2>&1; then
        docker start -ai console
    else
        docker run \
            --rm \
            -v /:/root \
            -v /lib/modules:/lib/modules:ro \
            -v /bin/docker:/usr/bin/docker:ro \
            -v /var/run/docker.sock:/var/run/docker.sock:ro \
            --privileged \
            --net host \
            --name console \
            -it \
            console-image:latest sh
    fi
    sleep 1
done
