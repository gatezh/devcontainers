#!/usr/bin/dumb-init /bin/sh

# Entrypoint for ralphex-fe container.
# Adapted from umputun/baseimage (base.alpine/files/init.sh) for Debian.
# Changes: gosu instead of su-exec, groupadd/groupdel instead of addgroup/delgroup,
#          dumb-init path adjusted for Debian.
# Source: https://github.com/umputun/baseimage/blob/master/base.alpine/files/init.sh

uid=$(id -u)

if [ "${uid}" -eq 0 ]; then
    [ "${INIT_QUIET}" != "1" ] && echo "init container"

    # set container's time zone
    if [ -f "/usr/share/zoneinfo/${TIME_ZONE}" ]; then
        cp "/usr/share/zoneinfo/${TIME_ZONE}" /etc/localtime
        echo "${TIME_ZONE}" >/etc/timezone
        [ "${INIT_QUIET}" != "1" ] && echo "set timezone ${TIME_ZONE} ($(date))"
    fi

    # set UID for user app
    if [ "${APP_UID}" != "1001" ]; then
        [ "${INIT_QUIET}" != "1" ] && echo "set custom APP_UID=${APP_UID}"
        sed -i "s/:1001:1001:/:${APP_UID}:${APP_UID}:/g" /etc/passwd
        sed -i "s/:1001:/:${APP_UID}:/g" /etc/group
    else
        [ "${INIT_QUIET}" != "1" ] && echo "custom APP_UID not defined, using default uid=1001"
    fi

    # set GID for docker group
    if [ "${DOCKER_GID}" != "999" ]; then
        [ "${INIT_QUIET}" != "1" ] && echo "set custom DOCKER_GID=${DOCKER_GID}"
        existing_group=$(getent group "${DOCKER_GID}" | cut -d: -f1)
        if [ -n "${existing_group}" ] && [ "${existing_group}" != "docker" ]; then
            [ "${INIT_QUIET}" != "1" ] && echo "GID ${DOCKER_GID} used by '${existing_group}', adding app to it"
            usermod -aG "${existing_group}" app || { echo "error: failed to add app to group '${existing_group}'"; exit 1; }
        else
            groupdel docker 2>/dev/null || true
            groupadd -g "${DOCKER_GID}" docker || { echo "error: failed to create docker group with GID=${DOCKER_GID}"; exit 1; }
            usermod -aG docker app || { echo "error: failed to add app to docker group"; exit 1; }
        fi
    else
        [ "${INIT_QUIET}" != "1" ] && echo "custom DOCKER_GID not defined, using default gid=999"
    fi

    chown -R app:app /srv
    if [ "${SKIP_HOME_CHOWN}" != "1" ]; then
        chown -R app:app /home/app
    fi
fi

if [ -f "/srv/init.sh" ]; then
    [ "${INIT_QUIET}" != "1" ] && echo "execute /srv/init.sh"
    chmod +x /srv/init.sh
    /srv/init.sh
    if [ "$?" -ne "0" ]; then
      echo "/srv/init.sh failed"
      exit 1
    fi
fi

[ "${INIT_QUIET}" != "1" ] && echo "execute $*"
if [ "${uid}" -eq 0 ]; then
   exec gosu app "$@"
else
   exec "$@"
fi
