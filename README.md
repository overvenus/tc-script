## TC is enough

### What can TC do

 1. Sharping Traffic
 2. Delay packets
 3. Drop packets

### Commands

 - Running TC in a docker container

   Create a container with the flag `--cap-add NET_ADMIN`

   ```
   docker run --cap-add NET_ADMIN --name sandbox -t -i ubuntu:14.04 /bin/bash
   ```

 - Show status of qdisc

   ```
   tc -s qdisc
   ```


 - Restore

   ```
   sudo tc qdisc del dev eth0 root
   ```

#### Simple Classless Usage

 - Random delay

   ```
   sudo tc qdisc add dev eth0 root netem delay 50ms 10ms distribution normal
   ```


#### Classful Usage

 - Create classes

   ```
   # root of class tree
   sudo tc qdisc add dev eth0 root handle 1: htb
   # create three classes
   sudo tc class add dev eth0 parent 1: classid 1:1 htb rate 1000Mbps
   sudo tc class add dev eth0 parent 1: classid 1:2 htb rate 1000Mbps
   sudo tc class add dev eth0 parent 1: classid 1:3 htb rate 1000Mbps
   ```

 - Bind qdisc

   ```
   # bind delay to class 1:1
   sudo tc qdisc add dev eth0 parent 1:1 handle 10: netem delay 100ms

   # bind delay to class 1:2
   sudo tc qdisc add dev eth0 parent 1:2 handle 20: netem delay 300ms
   ```

 - Filters

   ```
   # filter all icmp traffic to class 1:1, in this case, delay 100ms
   #   `protocol 1`: icmp, see more `cat /etc/protocols`
   sudo tc filter add dev eth0 protocol ip prio 1 u32 match ip protocol 1 0xff flowid 1:1
   ```

## Reference

1. [Manualtc Packet Filtering and netem](http://tcn.hypert.net/tcmanual.pdf)
2. [loopback-latency.sh](https://gist.github.com/keturn/541339)
3. [NetEM examples of rules](https://omf.mytestbed.net/projects/omf/wiki/NetEM_examples_of_rules)
4. [Linux Advanced Routing & Traffic Control HOWTO](http://lartc.org/howto/)
5. [Traffic Shaping, Bandwidth Shaping, Packet Shaping with Linux tc htb](https://www.iplocation.net/traffic-control)
