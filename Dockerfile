# syntax=docker/dockerfile:1.3-labs

# build base that sets up common dependencies of the build
ARG BUILD_BASE_VERSION=alpine
FROM rust:$BUILD_BASE_VERSION as build-base

WORKDIR /

# Install build deps
RUN <<EOF
set -ex

apk add --no-cache \
  clang clang-dev clang-libs pkgconfig bearssl-dev git \
  gcc make g++ linux-headers protobuf protobuf-dev musl-dev
EOF

# Install sccache and mold
RUN <<EOF
set -ex

# Get fetch
mkdir -p /deps/fetch
wget https://github.com/gruntwork-io/fetch/releases/download/v0.4.2/fetch_linux_amd64 -P /deps/fetch
mv /deps/fetch/fetch_linux_amd64 /fetch
chmod +x /fetch

# Install scache
mkdir /deps/sccache
/fetch --repo="https://github.com/mozilla/sccache" --tag="~>0.2.15" --release-asset="^sccache-v[0-9.]*-x86_64-unknown-linux-musl.tar.gz$" /deps/sccache
tar -xvf /deps/sccache/sccache-v*-x86_64-unknown-linux-musl.tar.gz -C /deps/sccache
mv /deps/sccache/sccache-v*-x86_64-unknown-linux-musl/sccache /sccache
chmod +x /sccache

# install mold build deps
apk add --no-cache --virtual .mold-deps xxhash-dev openssl-dev cmake

# Install mold
/fetch --repo="https://github.com/rui314/mold" --tag="~>0.9.6" /deps/mold
cd /deps/mold
make -j$(nproc)
make install
cd /

# Cleanup
rm -rf /deps
rm -rf /fetch
apk del .mold-deps

EOF

WORKDIR /build

ARG RUST_TOOLCHAIN=nightly

RUN <<EOF
rustup install $RUST_TOOLCHAIN
rustup target add wasm32-unknown-unknown --toolchain $RUST_TOOLCHAIN
EOF
