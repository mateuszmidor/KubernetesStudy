#!/usr/bin/env bash

trap tearDown SIGINT

HOST1="linux1"
HOST2="linux2"
USER="user"
SSH_PORT=2222

function stage() {
    COLOR="\e[95m"
    RESET="\e[0m"
    msg="$1"
    
    echo
    echo -e "$COLOR$msg$RESET"
}

function checkPrerequsites() {
    stage "Checking prerequisites"

    [[ ! -f $HOME/.ssh/id_rsa.pub ]] && echo "You need to first generate ssh keys under $HOME/.ssh/id_rsa.pub" && exit 1

    command docker --version > /dev/null 2>&1
    [[ $? != 0 ]] && echo "You need to install docker to run this example" && exit 1

    command ansible --version > /dev/null 2>&1
    [[ $? != 0 ]] && echo "You need to install ansible to run this example" && exit 1

    echo "OK"
}

function runContainers() {
    stage "Running containers $HOST1, $HOST2 as daemons"
 
    docker run \
        --name $HOST1 \
        --rm -d \
        --hostname=$HOST1\
        -e USER_NAME=$USER \
        -e SUDO_ACCESS=true \
        -e PUBLIC_KEY="`cat $HOME/.ssh/id_rsa.pub`" \
        linuxserver/openssh-server

    docker run \
        --name $HOST2 \
        --rm -d \
        --hostname=$HOST2\
        -e USER_NAME=$USER \
        -e SUDO_ACCESS=true \
        -e PUBLIC_KEY="`cat $HOME/.ssh/id_rsa.pub`" \
        linuxserver/openssh-server
}

function waitSshReady() {
    stage "Waiting containers ssh is ready"

    sleep 3

    IP=`docker inspect -f {{.NetworkSettings.IPAddress}} $HOST1`
    while true; do
        ssh $USER@$IP -p $SSH_PORT -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null 'whoami'
        [[ $? == 0 ]] && break
        sleep 3
    done;

    IP=`docker inspect -f {{.NetworkSettings.IPAddress}} $HOST2`
    while true; do
        ssh $USER@$IP -p $SSH_PORT -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null 'whoami'
        [[ $? == 0 ]] && break
        sleep 3
    done;
}

function runAnsible() {
    stage "Running ansible"

    IP1=`docker inspect -f {{.NetworkSettings.IPAddress}} $HOST1`
    IP2=`docker inspect -f {{.NetworkSettings.IPAddress}} $HOST2`
    ansible-playbook \
        run.yml \
        --extra-vars "HOST1_IP=$IP1 HOST2_IP=$IP2 USER=$USER PORT=$SSH_PORT" \
        --ssh-extra-args "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" #-vvvv
}

function sshIntoContainer1() {
    stage "SSH into container $HOST1"

    IP=`docker inspect -f {{.NetworkSettings.IPAddress}} $HOST1`
    ssh $USER@$IP -p $SSH_PORT -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
}

function tearDown() {
    stage "Destroying containers"

    docker kill $HOST1
    docker kill $HOST2
    exit 0
}

checkPrerequsites
runContainers
waitSshReady
runAnsible
sshIntoContainer1
tearDown