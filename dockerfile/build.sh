#! /bin/bash
set -x
set -o nounset
set -o errexit

readonly SELF_DIR=$(cd $(dirname $0) && pwd)

LIBEVENT_URL=https://github.com/libevent/libevent/releases/download/release-2.0.22-stable/libevent-2.0.22-stable.tar.gz
GFLAGS_URL=https://github.com/gflags/gflags/archive/v2.1.2.tar.gz
GLOG_URL=https://github.com/google/glog/archive/v0.3.4.tar.gz
THRIFT_URL=https://github.com/apache/thrift/archive/0.9.3.tar.gz
HIREDIS_URL=https://github.com/redis/hiredis/archive/v0.13.3.tar.gz
PROTOBUF_URL=https://github.com/google/protobuf/releases/download/v3.1.0/protobuf-cpp-3.1.0.tar.gz

function download
{
    local url=${1:?}
    local pkg=${2:-$(basename "$url")}
    ! grep $pkg packages.md5sum | md5sum --check || return 0
    curl -fsSL "$url" > $pkg && grep $pkg packages.md5sum | md5sum --check
    echo "Extracting $pkg into $SELF_DIR"
    tar -C $SELF_DIR -xzf $pkg
}

function prepare
{
    download $LIBEVENT_URL libevent.tar.gz
    download $GFLAGS_URL gflags.tar.gz
    download $GLOG_URL glog.tar.gz
    download $THRIFT_URL thrift.tar.gz
    download $HIREDIS_URL hiredis.tar.gz
    download $PROTOBUF_URL protobuf.tar.gz
}

function get_build_dir
{
    local pkg=${1?}
    echo $(dirname $pkg)/$(tar tzf $pkg | head -1)
}

function build
{
    local pkg=${1?}  # /tmp/abc-1.0.tar.gz
    shift 1  # other args are passed to configure
    
    local build_dir=$(get_build_dir)
    local -a configure_opts=()
    if (( $# >= 1 )); then
        configure_opts+=("$@")
    fi
    echo "Building in $build_dir with configure options: ${configure_opts[@]}"

    # Build in subdir
    (
        set -o errexit
        cd $build_dir || exit 1

        autoreconf_cmd="autoreconf --verbose --install --force"
        [[ ! -f autogen.sh ]] || $autoreconf_cmd
        [[ ! -f bootstrap.sh ]] || ./bootstrap.sh

        ./configure "${configure_opts[@]}"
        make
        make install
    )
}

function build_with_cmake
{
    local pkg=${1?}  # /tmp/abc-1.0.tar.gz
    shift 1  # other args are passed to configure

    local build_dir=$(get_build_dir)
    local -a cmake_opts=()
    if (( $# >= 1 )); then
        cmake_opts+=("$@")
    fi
    echo "Building in $build_dir with cmake options: ${cmake_opts[@]}"

    # Build in subdir
    (
        set -o errexit
        mkdir -p $build_dir/build
        cd $build_dir/build
        cmake .. "${cmake_opts[@]}"
        make
        make install
    )
}

function build_with_make
{
    local pkg=${1?}  # /tmp/abc-1.0.tar.gz
    shift 1  # other args are passed to configure

    local build_dir=$(get_build_dir)
    echo "Building in $build_dir with make"

    # Build in subdir
    (
        set -o errexit
        cd $build_dir
        make
        make install
    )
}

function build_all
{
    local TARGET_DIR=/usr/local
    build libevent.tar.gz --prefix $TARGET_DIR/libevent
    build_with_cmake gflags.tar.gz -DCMAKE_INSTALL_PREFIX=$TARGET_DIR/gflags
    build glog.tar.gz --prefix $TARGET_DIR/glog
    build thrift.tar.gz --prefix $TARGET_DIR/thrift CPPFLAGS="-I$TARGET_DIR/libevent/include" LDFLAGS="-L$TARGET_DIR/libevent/lib"
    (PREFIX=$TARGET_DIR/hiredis build_with_make hiredis.tar.gz)
    build protobuf.tar.gz --prefix $TARGET_DIR/protobuf
}

function main
{
    yum install -y cmake make gcc-c++ libtool byacc flex unzip
    yum install -y boost-static boost-devel openssl-static openssl-devel
    prepare
    build_all
}

main
