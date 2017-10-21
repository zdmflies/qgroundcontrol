#! /bin/bash

# otherwise default to nuttx
if [ -z ${QGC_DOCKER_REPO+x} ]; then
	QGC_DOCKER_REPO="mavlink/qgc-build-linux:2017-10-21"
fi

if [ -z ${QGC_CONFIG+x} ]; then
	QGC_CONFIG="Release"
fi

if [ -z ${QT_SPEC+x} ]; then
	QT_SPEC="linux-g++"
fi


# docker hygiene

#Delete all stopped containers (including data-only containers)
#docker rm $(docker ps -a -q)

#Delete all 'untagged/dangling' (<none>) images
#docker rmi $(docker images -q -f dangling=true)

echo "QGC_DOCKER_REPO: $QGC_DOCKER_REPO";
echo "QGC_CONFIG: $QGC_CONFIG";
echo "QT_SPEC: $QT_SPEC";

PWD=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
SRC_DIR=$PWD/../

CCACHE_DIR=${HOME}/.ccache
mkdir -p "${CCACHE_DIR}"

SHADOW_BUILD_DIR=${SHADOW_BUILD_DIR:=/tmp/qgc_build_dir}
mkdir -p ${SHADOW_BUILD_DIR}

docker run -it --rm \
	--env=CCACHE_DIR="${CCACHE_DIR}" \
	--env=LOCAL_USER_ID="$(id -u)" \
	--env=QGC_CONFIG \
	--env=QT_FATAL_WARNINGS \
	--env=QT_SPEC \
	--env=TRAVIS_BUILD_DIR \
	--volume=${CCACHE_DIR}:${CCACHE_DIR}:rw \
	--volume=${SHADOW_BUILD_DIR}:${SHADOW_BUILD_DIR}:rw \
	--volume=${SRC_DIR}:${SRC_DIR}:rw \
	--workdir ${SRC_DIR} \
	${QGC_DOCKER_REPO} \
	/bin/bash -c $1 $2 $3
