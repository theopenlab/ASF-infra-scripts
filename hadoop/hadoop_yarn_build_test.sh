#!/bin/bash

set -ex

export BUILD_TOOLS_DIR=/home/jenkins/build-tools
export DEPS_DIR=/home/jenkins/test-deps/

DEBIAN_FRONTEND=noninteractive sudo apt-get install -y build-essential autoconf automake libtool cmake zlib1g-dev pkg-config libssl-dev libsasl2-dev

# use default openjdk-8-jdk
export JAVA_HOME=`dirname $(dirname $(update-alternatives --list javac |grep java-8))`

# use maven-3.6.2
export PATH=$PATH:/home/jenkins/build-tools/maven/apache-maven-3.6.2/bin

javac -version
mvn --version

# Need to keep the localhost in the 1st line
grep "127.0.0.1 $(hostname)" /etc/hosts || sudo sed  -i '2i\127.0.0.1 '$(hostname)'' /etc/hosts
# fix tests in org.apache.hadoop.yarn.server.resourcemanager.recovery.TestFSRMStateStore
grep "127.0.0.1 $(hostname)." /etc/hosts || sudo sed  -i '3i\127.0.0.1 '$(hostname).'' /etc/hosts

# Install Docker
type docker || curl -sSL https://get.docker.com/ | sh -

export PROTOBUF_HOME=$DEPS_DIR/protobuf/3.7.1/build-bin/
export PATH=${PATH}:$PROTOBUF_HOME/bin/
echo $PATH
protoc --version

# use phantomjs
export PATH=$PATH:$DEPS_DIR/phantomjs/2.1.1/build-bin/bin/

# Install protoc-gen-grpc-java for ARM platform
if [ ! -f ~/.m2/repository/io/grpc/protoc-gen-grpc-java/1.15.1/protoc-gen-grpc-java-1.15.1-linux-aarch_64.exe ]; then
    mkdir -p ~/.m2/repository/io/grpc/protoc-gen-grpc-java/1.15.1/
    pushd ~/.m2/repository/io/grpc/protoc-gen-grpc-java/1.15.1/
    wget http://home.apache.org/~aajisaka/repository/io/grpc/protoc-gen-grpc-java/1.15.1/protoc-gen-grpc-java-1.15.1-linux-aarch_64.exe
    wget http://home.apache.org/~aajisaka/repository/io/grpc/protoc-gen-grpc-java/1.15.1/protoc-gen-grpc-java-1.15.1.pom
    wget http://home.apache.org/~aajisaka/repository/io/grpc/protoc-gen-grpc-java/1.15.1/protoc-gen-grpc-java-1.15.1.pom.sha1
    popd
fi

# NOTE: the tests of TestAuxServices need to create some file and directories which must not have group
# and other permissions, and the files' parents direcotries(must not writable by group or other).
# so we need change all the permissions of directories and the "umask" the umask will effect the new
# created files and directories' permissions e.g. the 077 means the new created permissions: 777 - 077 = 700 (files: 666 - 077 = 600)
chmod go-w . -R
[[ "$(umask)" =~ "022" ]] || echo "umask 022" >> ~/.profile
. ~/.profile
umask

# Install manually compiled netty-all package
wget -O netty-all-4.1.27-linux-aarch64.jar https://git.io/Je8K3
mvn install:install-file -DgroupId=io.netty -Dfile=netty-all-4.1.27-linux-aarch64.jar -DartifactId=netty-all -Dversion=4.1.27.Final -Dpackaging=jar
rm netty-all-4.1.27-linux-aarch64.jar

# Install hadoop in Maven local repo -Pdist,native,aarch64
mvn clean install -e -B -Pdist,native -Dtar -DskipTests -Dmaven.javadoc.skip

# test hadoop yarn
export PATH=$PWD/hadoop-dist/target/hadoop-3.3.0-SNAPSHOT/bin:$PATH
hadoop version
# hadoop checknative -a

pushd hadoop-yarn-project/
mvn test -B -e -fn
popd
