set -ex
[ "$EUID" -eq 0 ] && exit "this script must be run with non-root user!"
sudo apt-get update -y

DEBIAN_FRONTEND=noninteractive sudo apt-get install -y build-essential autoconf automake libtool cmake zlib1g-dev pkg-config libssl-dev libsasl2-dev

# install openjdk-8-jdk
sudo apt-get install openjdk-8-jdk -y
export JAVA_HOME=`dirname $(dirname $(update-alternatives --list javac |grep java-8))`

# install maven-3.6.2
[ -d "/opt/apache-maven-3.6.2/" ] || wget -O - "https://www.apache.org/dist/maven/maven-3/3.6.2/binaries/apache-maven-3.6.2-bin.tar.gz" | tar xz -C /opt/
export PATH=/opt/apache-maven-3.6.2/bin:$PATH

javac -version
mvn --version

# Need to keep the localhost in the 1st line
grep "127.0.0.1 $(hostname)" /etc/hosts || sudo sed  -i '2i\127.0.0.1 '$(hostname)'' /etc/hosts
# fix tests in org.apache.hadoop.yarn.server.resourcemanager.recovery.TestFSRMStateStore
grep "127.0.0.1 $(hostname)." /etc/hosts || sudo sed  -i '3i\127.0.0.1 '$(hostname).'' /etc/hosts

# Install Docker
type docker || curl -sSL https://get.docker.com/ | sh -

if [ ! -d "/opt/protobuf-3.7.1" ]; then
    wget -O - https://github.com/protocolbuffers/protobuf/releases/download/v3.7.1/protobuf-java-3.7.1.tar.gz | tar zx -C ~/
    pushd ~/protobuf-3.7.1
    ./configure --prefix=/opt/protobuf-3.7.1
    sudo make install
    popd
    sudo rm -fr ~/protobuf-3.7.1
fi
export PROTOBUF_HOME=/opt/protobuf-3.7.1
export PATH="${PATH}:/opt/protobuf-3.7.1/bin"

# phantomjs 2.1.1 require libicu55 which only in ubuntu xenial
sudo echo "deb http://ports.ubuntu.com/ubuntu-ports xenial main" >> /etc/apt/sources.list
sudo apt-get update
sudo apt-get install -y libicu55

if ! type phantomjs; then
    readonly phant_dir="$(mktemp -d --tmpdir phantomjs.XXXXXX)"
    wget -O - "https://github.com/liusheng/phantomjs/releases/download/2.1.1/phantomjs-2.1.1-linux-aarch64.tar.bz2" | sudo tar xj -C "$phant_dir"
    sudo cp "$phant_dir"/phantomjs-2.1.1-linux-aarch64/bin/phantomjs /usr/bin/
fi

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
sudo chmod go-w ~/ -R
[[ "$(umask)" =~ "022" ]] || echo "umask 022" >> ~/.profile
. ~/.profile
umask

mkdir -p ~/src/
[ -d ~/src/hadoop ] || git clone http://github.com/apache/hadoop ~/src/hadoop
cd ~/src/hadoop

# Install manually compiled netty-all package
wget -O netty-all-4.1.27-linux-aarch64.jar https://git.io/Je8K3
mvn install:install-file -DgroupId=io.netty -Dfile=netty-all-4.1.27-linux-aarch64.jar -DartifactId=netty-all -Dversion=4.1.27.Final -Dpackaging=jar
rm netty-all-4.1.27-linux-aarch64.jar

mkdir -p ~/hadoop-logs/
# Install hadoop in Maven local repo -Pdist,native,aarch64
mvn clean install -e -B -Pdist,native -Dtar -DskipTests -Dmaven.javadoc.skip 2>&1 | tee ~/hadoop-logs/hadoop_build.log

# Compile hadoop
sudo cp -r hadoop-dist/target/hadoop-3.3.0-SNAPSHOT /opt/
export PATH=/opt/hadoop-3.3.0-SNAPSHOT/bin:$PATH
hadoop version
# hadoop checknative -a

pushd hadoop-yarn-project/
mvn test -B -e -fn | tee ~/hadoop-logs/hadoop_yarn_test.log
popd