zig build-exe src/organic.zig -O ReleaseSmall -fsingle-threaded -fstrip -fno-lto

sudo mv organic /usr/local/bin/o