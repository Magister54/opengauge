echo "Fetching last updates..."
git pull
cmake ..
make clean
make -j4
nohup ./dashboard &
sleep 10
