#!/bin/bash

# Time measurement
start=$(date +%s)

sudo apt-get update
sudo apt-get install -y libx11-dev

cd /vagrant/provision
tar xzf HTK-3.4.1.tar.gz

cd ./htk
./configure
make all
sudo make install

# Time measurement
end=$(date +%s)

diff=$(( $end - $start ))

echo ":::::::::::::::::::::::::::::::::"
echo "::: Elapsed Time: $diff seconds!!"
echo ":::::::::::::::::::::::::::::::::"
