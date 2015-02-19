#!/bin/sh
set -e

echo "$(date): Waiting for Docker" >> /var/log/init.log
while sleep 0.1; do
    if docker ps >/dev/null 2>&1; then
        break
    fi
done

echo "$(date): Setting up network" >> /var/log/init.log
echo Setting up network
if ! docker inspect dhcp >/dev/null 2>&1; then
    docker import - dhcp < /.dhcp.tar
fi
docker run --rm -it --net host --cap-add NET_ADMIN dhcp udhcpc -i eth0

docker tag -f dhcp console-image:latest

echo "$(date): Starting up console" >> /var/log/init.log
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
