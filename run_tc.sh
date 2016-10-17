#!/bin/bash

NAME=run_tc.sh

TC=tc

# Interface
IF=eth0

# Speed Limit
SPED=1000Mbps

# Set up rules
function rules() {
    # Create classes
    $TC qdisc add dev $IF root handle 1: htb
    $TC class add dev $IF parent 1: classid 1:1 htb rate $SPED
    $TC class add dev $IF parent 1: classid 1:2 htb rate $SPED
    $TC class add dev $IF parent 1: classid 1:3 htb rate $SPED

    # A slow network. Delays are from 500ms to 1500ms, follows normal
    # distribution, but no packet lost.
    #
    # It is useful to create a struggler.
    $TC qdisc add dev eth0 parent 1:1 handle 10: netem delay 250ms 750ms distribution normal

    # This causes the random number generator to be less random and can be used
    # to emulate packet burst losses.
    #
    # Link: https://wiki.linuxfoundation.org/networking/netem
    $TC qdisc add dev eth0 parent 1:2 handle 20: netem loss 0.3% 25%

    # A shitty network. Delays are from 500ms to 1500ms, follows normal
    # distribution. 5 percent packet will be randomly dropped.
    $TC qdisc add dev eth0 parent 1:3 handle 30: netem loss 5%

    # Packet Loss in Real Time Services on the Internet
    # packet loss on Internet links where most of the traffic is controlled by
    # TCP but with an essential contribution of real time traffic without flow
    # control.
    #
    # Paper: http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.90.1411&rep=rep1&type=pdf
    # Link: https://www.excentis.com/blog/use-linux-traffic-control-impairment-node-test-environment-part-2
    #
    # It is useful for the feature real-time database.
    #$TC qdisc add dev eth0 parent 1:2 handle 10: netem loss gemodel 1% 10% 70% 0.1%
}

# Filter example
#
# All icmp packets delay 100ms
# icmp: protocol 1 0xff
#  1: icmp code in /etc/protocols
#  0xff: mask, match 1 exactly.
#
#  0                   1                   2                   3
#  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
# |Version|  IHL  |Type of Service|          Total Length         |
# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
# |         Identification        |Flags|      Fragment Offset    |
# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
# |  Time to Live |    Protocol   |         Header Checksum       |
# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
# |                       Source Address                          |
# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
# |                    Destination Address                        |
# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
# |                    Options                    |    Padding    |
# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
function filter_icmp() {
    $TC filter add dev $IF protocol ip prio 1 u32 match ip protocol 1 0xff flowid 1:1
}

# Filter example
#
# Create a struggler, whoever listens port 8081 it becomes a struggler.
function filter_sport() {
    $TC filter add dev $IF protocol ip prio 1 u32 match ip sport 8081 0xffff flowid 1:1
}

function start() {
    rules
    sleep 1
    # An example, now ping should be slow.
    filter_icmp
}

# $1 is the target's port, $2 is the rule.
function add() {
    if [[ !((-n $1)) || !((-n $2)) ]]; then
        echo "  $NAME add usage: add TARGET_PORT RULE_NUM"
        echo "      example: $NAME add 8080 1"
        exit 1
    fi

    $TC filter add dev $IF protocol ip prio 1 u32 match ip sport $1 0xffff flowid 1:$2
    $TC filter add dev $IF protocol ip prio 1 u32 match ip dport $1 0xffff flowid 1:$2
}

# $1 is the target's port, $2 is the rule.
function remove() {
    if [[ !((-n $1)) || !((-n $2)) ]]; then
        echo "  $NAME remove usage: remove TARGET_PORT RULE_NUM"
        echo "      example: $NAME remove 8080 1"
        exit 1
    fi

    $TC filter delete dev $IF protocol ip prio 1 u32 match ip sport $1 0xffff flowid 1:$2
    $TC filter delete dev $IF protocol ip prio 1 u32 match ip dport $1 0xffff flowid 1:$2
}

function stop() {
    $TC qdisc del dev $IF root
}

function restart() {
    stop
    sleep 1
    start
}

function show() {
    $TC -s qdisc ls dev $IF
}

case "$1" in

  start)

    echo -n "Starting traffic control: "
    start
    echo "done"
    ;;

  add)

    echo "Adding target ..."
    add $2 $3
    echo "done"
    ;;

  remove)

    echo "Removing target ..."
    remove $2 $3
    echo "done"
    ;;

  stop)

    echo -n "Stopping traffic control: "
    stop
    echo "done"
    ;;

  restart)

    echo -n "Restarting traffic control: "
    restart
    echo "done"
    ;;

  show)

    echo "traffic control status for $IF:\n"
    show
    echo ""
    ;;

  *)

    pwd=$(pwd)
    echo "Usage: $(/usr/bin/dirname $pwd)/tc.bash {start|add|remove|stop|restart|show}"
    ;;

esac

exit 0
