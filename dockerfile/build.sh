#! /bin/bash
set -x
set -o nounset
set -o errexit

readonly SELF_DIR=$(cd $(dirname $0) && pwd)

BOOST_URL=https://sourceforge.net/projects/boost/files/boost/1.62.0/boost_1_62_0.tar.gz
LIBEVENT_URL=https://github.com/libevent/libevent/releases/download/release-2.0.22-stable/libevent-2.0.22-stable.tar.gz
GFLAGS_URL=https://github.com/gflags/gflags/archive/v2.1.2.tar.gz
GLOG_URL=https://github.com/google/glog/archive/v0.3.4.tar.gz
THRIFT_URL=https://github.com/apache/thrift/archive/0.9.3.tar.gz
HIREDIS_URL=https://github.com/redis/hiredis/archive/v0.13.3.tar.gz
PROTOBUF_URL=https://github.com/google/protobuf/releases/download/v3.1.0/protobuf-cpp-3.1.0.tar.gz
SNAPPY_URL=https://github.com/google/snappy/archive/1.1.3.tar.gz
LOG4CPP_URL=https://github.com/orocos-toolchain/log4cpp/archive/v2.7.0-rc1.tar.gz
MAVEN_URL=https://archive.apache.org/dist/maven/maven-3/3.2.5/binaries/apache-maven-3.2.5-bin.tar.gz

HADOOP_URL=http://ftp.cuhk.edu.hk/pub/packages/apache.org/hadoop/common/hadoop-2.7.7/hadoop-2.7.7.tar.gz
JRE_URL="https://javadl.oracle.com/webapps/download/AutoDL?BundleId=235717_2787e4a523244c269598db4e85c51e0c"

function download
{
    local url=${1:?}
    local pkg=${2:-$(basename "$url")}
    ! grep $pkg packages.md5sum | md5sum --check || return 0
    curl -fsSL "$url" > $pkg && grep $pkg packages.md5sum | md5sum --check
}

function tar_file
{
    local src=${1}
    local dst=${2}

    tar -xvzf $src -C $dst
}

function prepare
{
    download $HADOOP_URL hadoop.tar.gz
    download $JRE_URL jre.tar.gz
    download $BOOST_URL boost.tar.gz
    download $LIBEVENT_URL libevent.tar.gz
    download $GFLAGS_URL gflags.tar.gz
    download $GLOG_URL glog.tar.gz
    download $THRIFT_URL thrift.tar.gz
    download $HIREDIS_URL hiredis.tar.gz
    download $PROTOBUF_URL protobuf.tar.gz
    download $SNAPPY_URL snappy.tar.gz
    download $LOG4CPP_URL log4cpp.tar.gz
    download $MAVEN_URL apache-maven-bin.tar.gz
}

function get_build_dir
{
    local pkg=${1?}
    tar -C $SELF_DIR -xzf $pkg
    echo $(dirname $pkg)/$(tar tzf $pkg | head -1)
}

function build
{
    local pkg=${1?}  # /tmp/abc-1.0.tar.gz
    shift 1  # other args are passed to configure
    
    local build_dir=$(get_build_dir $pkg)
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

    local build_dir=$(get_build_dir $pkg)
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

    local build_dir=$(get_build_dir $pkg)
    echo "Building in $build_dir with make"

    # Build in subdir
    (
        set -o errexit
        cd $build_dir
        make
        make install
    )
}

function build_with_b2
{
    local pkg=${1?}  # /tmp/abc-1.0.tar.gz
    shift 1  # other args are passed to configure

    local build_dir=$(get_build_dir $pkg)
    local -a b2_opts=()
    if (( $# >= 1 )); then
        b2_opts+=("$@")
    fi
    echo "Building in $build_dir with b2 options: ${b2_opts[@]}"

    # Build in subdir
    (
        set -o errexit
        cd $build_dir
        ./bootstrap.sh "${b2_opts[@]}"
        ./b2 install
    )
}

function build_all
{
    local TARGET_DIR=/usr/local
    build_with_b2 boost.tar.gz --prefix=$TARGET_DIR/boost --with-libraries=system,thread,regex,test
    build libevent.tar.gz --prefix $TARGET_DIR/libevent
    build_with_cmake gflags.tar.gz -DCMAKE_INSTALL_PREFIX=$TARGET_DIR/gflags
    build glog.tar.gz --prefix $TARGET_DIR/glog
    build thrift.tar.gz --prefix $TARGET_DIR/thrift --with-boost=$TARGET_DIR/boost CPPFLAGS="-I$TARGET_DIR/libevent/include" LDFLAGS="-L$TARGET_DIR/libevent/lib"
    build protobuf.tar.gz --prefix $TARGET_DIR/protobuf
    build snappy.tar.gz --prefix $TARGET_DIR/snappy
    build log4cpp.tar.gz --prefix $TARGET_DIR/log4cpp
    (PREFIX=$TARGET_DIR/hiredis build_with_make hiredis.tar.gz)

    tar_file apache-maven-bin.tar.gz $TARGET_DIR && ln -s $TARGET_DIR/apache-maven-* $TARGET_DIR/maven
    tar_file hadoop.tar.gz $TARGET_DIR && ln -s $TARGET_DIR/hadoop-* $TARGET_DIR/hadoop
    tar_file jre.tar.gz $TARGET_DIR && ln -s $TARGET_DIR/jre1* $TARGET_DIR/jre
}

function main
{
    yum install -y cmake make gcc-c++ libtool byacc flex unzip patch which
    yum install -y openssl-static openssl-devel
    yum install -y java-1.6.0-openjdk-devel
    prepare
    build_all
}

main
