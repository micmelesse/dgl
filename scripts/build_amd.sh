rm -rf build
mkdir build
cd build
cmake -DUSE_ROCM=ON ..
make -j4