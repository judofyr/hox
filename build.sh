cd src-h2o

# Compile without libuv
if grep -q libh2o.*LIBUV CMakeLists.txt; then
  echo 'SET_TARGET_PROPERTIES(libh2o PROPERTIES COMPILE_FLAGS "-DH2O_USE_LIBUV=0")' >> CMakeLists.txt
fi

cmake .
make libh2o

