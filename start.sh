#!/bin/bash

mkdir -p /app/streams

nginx
bash /app/worker.sh
