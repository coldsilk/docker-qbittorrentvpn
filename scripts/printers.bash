#!/bin/bash

function vprint() {
  printf "%s\n" "$(date +"%Y-%m-%d_%H:%M:%S.%4N"): $*";
}
function vprintf() {
  printf "%s" "$(date +"%Y-%m-%d_%H:%M:%S.%4N"): $*";
}

function iprint() {
  printf "%s\n" "$(date +"%Y-%m-%d_%H:%M:%S.%4N"): [_info]: $*";
}
function iprintf() {
  printf "%s" "$(date +"%Y-%m-%d_%H:%M:%S.%4N"): [_info]: $*";
}

function eprint() {
  >&2 printf "%s\n" "$(date +"%Y-%m-%d_%H:%M:%S.%4N"): [ERROR]: $*";
}
function eprintf() {
  >&2 printf "%s" "$(date +"%Y-%m-%d_%H:%M:%S.%4N"): [ERROR]: $*";
}

function wprint() {
  printf "%s\n" "$(date +"%Y-%m-%d_%H:%M:%S.%4N"): [_warn]: $*";
}
function wprintf() {
  printf "%s" "$(date +"%Y-%m-%d_%H:%M:%S.%4N"): [_warn]: $*";
}
