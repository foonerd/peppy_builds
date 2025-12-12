#!/bin/bash
# peppy-python-builds clean-all.sh
# Clean all build outputs

set -e

echo "Cleaning Python packages build outputs..."

rm -rf out/armv6/*
rm -rf out/armhf/*
rm -rf out/arm64/*
rm -rf out/amd64/*

echo "Done"
