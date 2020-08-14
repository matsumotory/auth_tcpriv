#/bin/bash

MYHOST=`hostname`
SRC_DIR=~/auth_tcpriv
BUILD_DIR=$SRC_DIR/build
TEST_DIR=$SRC_DIR/test
MYSQL_BUILD_DIR=$SRC_DIR/mysql_build
MYSQL_SRC_DIR=$MYSQL_BUILD_DIR/mysql-8.0-8.0.21
MYSQL_PLUGIN_DIR=$MYSQL_SRC_DIR/plugin
REPO=https://github.com/matsumotory/auth_tcpriv.git

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

  # Deploy tcpriv module
  cd $MYSQL_PLUGIN_DIR
  git clone $REPO

  # Build mysql
  cd $MYSQL_SRC_DIR
  cmake . -DFORCE_INSOURCE_BUILD=1 -DWITH_BOOST=./boost \
        -DCMAKE_INSTALL_PREFIX=/usr/local/mysql_tcpriv \
        -DWITH_DEBUG=OFF \
        -DCOMPILATION_COMMENT="tcpriv" \
        -DMYSQL_SERVER_SUFFIX="-tcpriv" \
        -DMYSQL_UNIX_ADDR="/tmp/mysql_tcpriv.sock" \
        -DMYSQL_TCP_PORT=13306 \
        -DWITH_DEFAULT_FEATURE_SET=xsmall \
        -DWITH_UNIT_TESTS=OFF .
  make
  make install
  sudo chown -R vagrant:vagrant /usr/local/mysql_tcpriv

  # Start mysqld
  /usr/local/mysql_tcpriv/bin/mysqld --user=vagrant \
          --basedir=/usr/local/mysql_tcpriv \
          --datadir=/usr/local/mysql_tcpriv/data \
          --log-error-verbosity=3 \
          --initialize-insecure
  /usr/local/mysql_tcpriv/bin/mysqld --user=vagrant \
          --basedir=/usr/local/mysql_tcpriv \
          --datadir=/usr/local/mysql_tcpriv/data \
          --log-error-verbosity=3 &

  cd $TEST_DIR
  make clean
  make
  exit $?
fi
