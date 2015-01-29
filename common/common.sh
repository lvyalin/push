#!/bin/bash

export LANGUAGE="utf-8"
#export LANGUAGE="gbk"

this_file=`pwd`"/"$0
PROJECT=$1
shift 1

TAG_DIR="./tag/"
LOG_DIR="./log/"