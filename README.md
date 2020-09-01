[![Build Status](https://api.travis-ci.org/coincar-sim/mrt_cmake_modules_ci.svg?branch=master)](https://travis-ci.org/coincar-sim/mrt_cmake_modules_ci)

# MRT CMAKE MODULES Continous Integration
Inspired by and forked from https://travis-ci.org/ros-planning/moveit_ci

## Usage

Create a ``.travis.yml`` file in the base of you repo similar to:

```
# This config file for Travis CI utilizes https://github.com/coincar-sim/mrt_cmake_modules_ci/ package.
sudo: required
dist: xenial
services:
  - docker
language: cpp
compiler: gcc
cache: ccache

notifications:
  email:
    recipients:
      # - user@email.com

matrix:
  include:
    - env:
      - UBUNTU_VERSION=xenial
      - ROS_DISTRO=kinetic
    - env:
      - UBUNTU_VERSION=bionic
      - ROS_DISTRO=melodic

env:
  global:
    - DEPENDENCIES_ROSINSTALL=dependencies.rosinstall

before_script:
  - git clone -q https://github.com/coincar-sim/mrt_cmake_modules_ci.git .mrt_cmake_modules_ci

script:
  - .mrt_cmake_modules_ci/travis.sh
```

## Configurations

- `ROS_DISTRO`: which version of ROS (kinetic, melodic, ...)
- `UBUNTU_VERSION` (optional): which version of ubuntu (xenial, bionic, ...; default is xenial)
- `DEPENDENCIES_ROSINSTALL` (optional): rosinstall file pointing to source dependencies
- other dependencies are resolved via rosdep and [mrt_cmake_modules](https://github.com/KIT-MRT/mrt_cmake_modules)' AutoDeps
