#!/bin/bash

# Компилируем программу
zig build-exe src/organic.zig -O ReleaseSmall -fsingle-threaded -fstrip -fno-lto

# Проверяем, успешно ли создался файл organic
if [ -f "organic" ]; then
   sudo mv organic /usr/local/bin/o
   echo "Successfully installed organic as 'o'"
else
   echo "Error: Failed to build organic executable"
   exit 1
fi