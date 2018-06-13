#!/bin/bash

# Software License Agreement - BSD License
#
# Inspired by MoveIt! travis https://github.com/ros-planning/moveit_core/blob/09bbc196dd4388ac8d81171620c239673b624cc4/.travis.yml
# Inspired by JSK travis https://github.com/jsk-ros-pkg/jsk_travis
# Inspired by ROS Industrial https://github.com/ros-industrial/industrial_ci
# Inspired by and forked from MoveIt CI https://travis-ci.org/ros-planning/moveit_ci
#
# Author:  Maximilian Naumann

echo "--- begin of travis.sh ---"
export CI_SOURCE_PATH=$(pwd) # The repository code in this pull request that we are testing
export CI_PARENT_DIR=.mrt_cmake_modules_ci  # This is the folder name that is used in downstream repositories in order to point to this repo.
export CI_DESKTOP="xenial"
export HIT_ENDOFSCRIPT=false
export REPOSITORY_NAME=${PWD##*/}
export CATKIN_WS=/root/catkin_ws
export PYTHONPATH=$PYTHONPATH:/usr/lib/python2.7/dist-packages:/usr/local/lib/python2.7/dist-packages

# Helper functions
source ${CI_SOURCE_PATH}/$CI_PARENT_DIR/util.sh

# Run all CI in a Docker container -> start docker if not yet inside
if ! [ -f /.dockerenv ]; then

    # Choose the correct CI container to use
    . /etc/os-release
    export DOCKER_IMAGE=ubuntu:xenial

    # Pull first to allow us to hide console output
    docker pull $DOCKER_IMAGE > /dev/null

    # Start Docker container
    echo "Starting docker \"$DOCKER_IMAGE\" from a travis machine running \"$PRETTY_NAME\" and run travis.sh inside the docker."
    docker run \
        -e ROS_DISTRO \
        -e BEFORE_SCRIPT \
        -e CI_PARENT_DIR \
        -e CI_SOURCE_PATH \
        -e DEPENDENCIES_ROSINSTALL \
        -e TRAVIS_BRANCH \
        -v $(pwd):/root/$REPOSITORY_NAME \
        -v $HOME/.ccache:/root/.ccache \
        $DOCKER_IMAGE \
        /bin/bash -c "cd /root/$REPOSITORY_NAME; source .mrt_cmake_modules_ci/travis.sh;"
    return_value=$?

    if [ $return_value -eq 0 ]; then
        echo "Docker \"$DOCKER_IMAGE\" finished successfully"
        HIT_ENDOFSCRIPT=true;
        exit 0
    fi
    echo "Docker \"$DOCKER_IMAGE\" finished with errors"
    exit 1 # error
fi

# If we are here, we can assume we are inside a Docker container
. /etc/os-release
echo "Inside docker container, running \"$PRETTY_NAME\""
echo "Testing branch '$TRAVIS_BRANCH' of '$REPOSITORY_NAME' on ROS '$ROS_DISTRO'"

# Adding ros repo
echo "Adding ros repo to apt sources"
sh -c "echo \"deb http://packages.ros.org/ros/ubuntu $CI_DESKTOP main\" > /etc/apt/sources.list.d/ros-latest.list"
travis_run apt-key adv --keyserver hkp://ha.pool.sks-keyservers.net:80 --recv-key 421C365BD9FF1F717815A3895523BAEEB01FA116

# Update the sources
travis_run apt-get -qq update

# Install the required apt packages
travis_run apt-get install -y build-essential
travis_run apt-get install -y python-catkin-pkg
travis_run apt-get install -y python-rosdep
travis_run apt-get install -y python-wstool
travis_run apt-get install -y ros-$ROS_DISTRO-catkin
travis_run apt-get install -y python-catkin-tools

# Enable ccache
travis_run apt-get -qq install ccache
export PATH=/usr/lib/ccache:$PATH

# Install and run xvfb to allow for X11-based unittests on DISPLAY :99
travis_run apt-get -qq install xvfb mesa-utils
Xvfb -screen 0 640x480x24 :99 &
export DISPLAY=:99.0
travis_run_true glxinfo

# Setup rosdep and add rosdep-definitions from mrt_cmake_modules
travis_run rosdep init
travis_run echo "Adding rosdep-definitions from mrt_cmake_modules"
echo "yaml https://raw.githubusercontent.com/KIT-MRT/mrt_cmake_modules/master/yaml/base.yaml" | tee --append /etc/ros/rosdep/sources.list.d/20-default.list
travis_run rosdep update

# Source ROS
travis_run source /opt/ros/$ROS_DISTRO/setup.bash

# Create workspace
travis_run mkdir -p $CATKIN_WS
travis_run cd $CATKIN_WS
travis_run wstool init src
travis_run catkin init
# Configure catkin to build in debug mode
travis_run catkin config --cmake-args -DCMAKE_BUILD_TYPE=Debug
# Add the package under integration to the workspace using a symlink.
travis_run cd ~/catkin_ws/src
travis_run ln -s $CI_SOURCE_PATH .

# Install all dependencies
# Source dependencies: install using wstool.
travis_run cd ~/catkin_ws
if [[ -f "$CI_SOURCE_PATH/$DEPENDENCIES_ROSINSTALL" ]] ; then
    travis_run wstool merge -t src "$CI_SOURCE_PATH/$DEPENDENCIES_ROSINSTALL"
    travis_run wstool update -t src ;
else
    echo "No rosinstall file provided, was looking for $CI_SOURCE_PATH/$DEPENDENCIES_ROSINSTALL" ;
fi

# Package depdencies: install using rosdep.
travis_run rosdep install -y -r --from-paths src --ignore-src --rosdistro $ROS_DISTRO

# Build and test
travis_run cd ~/catkin_ws
travis_run catkin build --no-status --continue-on-failure
# Run the tests and check the results. (But do not test this (mrt_cmake_modules_ci) package as it would fail.)
if [[ $REPOSITORY_NAME != mrt_cmake_modules_ci ]] ; then
    travis_run catkin run_tests --no-status $REPOSITORY_NAME --no-deps
    travis_run catkin_test_results --verbose build/$REPOSITORY_NAME ;
else
    echo "Not testing this ci-package (mrt_cmake_modules_ci) as it is not a catkin package itself" ;
fi
