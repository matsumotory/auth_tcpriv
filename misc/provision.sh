#/bin/bash

MYHOST=`hostname`
SRC_DIR=~/auth_remote_client_uid
BUILD_DIR=$SRC_DIR/build
TEST_DIR=$SRC_DIR/test
MYSQL_BUILD_DIR=$SRC_DIR/mysql_build
REPO=https://github.com/matsumotory/auth_remote_client_uid.git

# use ccache
HOSTCXX=g++
CC=gcc
THREAD=2

# download tcpriv
if [ -d $SRC_DIR ]; then
  rm -rf $SRC_DIR
fi
git clone $REPO $SRC_DIR

# setup build enviroment
sudo apt-get update
sudo apt-get -y install build-essential rake bison git gperf automake m4 \
                autoconf libtool cmake pkg-config libcunit1-dev ragel \
                libpcre3-dev clang-format-6.0
sudo apt-get -y remove nano
sudo apt-get -y install gawk chrpath socat libsdl1.2-dev xterm libncurses5-dev lzop flex libelf-dev kmod

sudo update-alternatives --install /usr/bin/clang-format clang-format /usr/bin/clang-format-6.0 1000
sudo sed -i s/#\ deb-src/deb-src/ /etc/apt/sources.list
sudo apt update
sudo apt install -y dpkg-dev

if [ -d $BUILD_DIR ]; then
  rm -rf $BUILD_DIR
fi
mkdir $BUILD_DIR

if [ -d $MYSQL_BUILD_DIR ]; then
  rm -rf $MYSQL_BUILD_DIR
fi
mkdir $MYSQL_BUILD_DIR

if [ $MYHOST = "server" ]; then
  # Build MySQL
  cd $MYSQL_BUILD_DIR
  apt source mysql-server
  cd $MYSQL_BUILD_DIR/mysql-8.0-8.0.21
  wget https://dl.bintray.com/boostorg/release/1.72.0/source/boost_1_72_0.tar.gz
  cmake . -DFORCE_INSOURCE_BUILD=1 -DWITH_BOOST=./boost \
        -DCMAKE_INSTALL_PREFIX=/usr/local/mysql_tcpriv \
        -DDEFAULT_CHARSET=utf8 -DDEFAULT_COLLATION=utf8_general_ci \
        -DWITH_EXTRA_CHARSETS=all \
        -DWITH_ZLIB=bundled -DWITH_SSL=bundled -DWITH_READLINE=1 \
        -DWITH_PIC=ON -DWITH_FAST_MUTEXES=ON \
        -DWITH_DEBUG=OFF \
        -DCOMPILATION_COMMENT="tcpvir" -DMYSQL_SERVER_SUFFIX="-tcpriv" \
        -DMYSQL_USER=nobody -DMYSQL_UNIX_ADDR="/tmp/mysql_tcpriv.sock" \
        -DMYSQL_TCP_PORT=13306 \
        -DWITH_DEFAULT_FEATURE_SET=xsmall \
        -DWITH_PARTITION_STORAGE_ENGINE=1 \
        -DWITHOUT_DAEMON_EXAMPLE_STORAGE_ENGINE=1 \
        -DWITHOUT_FTEXAMPLE_STORAGE_ENGINE=1 \
        -DWITHOUT_EXAMPLE_STORAGE_ENGINE=1 \
        -DWITHOUT_ARCHIVE_STORAGE_ENGINE=1 \
        -DWITHOUT_BLACKHOLE_STORAGE_ENGINE=1 \
        -DWITHOUT_FEDERATED_STORAGE_ENGINE=1 \
        -DWITHOUT_INNOBASE_STORAGE_ENGINE=1 \
        -DWITHOUT_PERFSCHEMA_STORAGE_ENGINE=1 \
        -DWITHOUT_NDBCLUSTER_STORAGE_ENGINE=1 \
        -DWITH_INNODB_MEMCACHED=OFF \
        -DWITH_EMBEDDED_SERVER=OFF \
        -DWITH_UNIT_TESTS=OFF
  make

  cd $TEST_DIR
  make clean
  make
  exit $?
fi
