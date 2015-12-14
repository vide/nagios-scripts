nagios-scripts
==============

Collection of various Nagios scripts and plugins

### check_wp.sh

Frontend to wp-cli (http://wp-cli.org) to check through Nagios if your wordpress 
installation (core, plugins) is updated to the latest version, so you can upgrade
as soos as a new fix is available. 
It supports multisite installs as well and obviously relies on PHP.

### check_kafka_lag.sh

Used to check the lag between to Kafka instances, one used as a "producer" and
the other as a "consumer". Don't know if it's really useful outside my company 
but anyway, here it is

### check_graphite.sh

I know that there are at least two other projects here on GitHub for the same
purpose but they are both written in Ruby and I've developed an idiosincrasy
towards that language, as a sysadmin (I won't rant here :P).
Moreover, both of them are not flexible enough, cause I need dates range 
support and different calculation modes (they just return the last valid 
value). So here it is this simple bash script to check if a Graphite series
is within two given thresholds.
Check the program help for the options available

This script has a dependency on JSON.sh, you can find this great bash script 
here: https://github.com/dominictarr/JSON.sh

Nagios integration examples

checkcommands.cfg:

    define command {
        command_name    check_graphite
        command_line    $USER1$/check_graphite.sh -g 'http://graphite.server/' -w $ARG1$ -c $ARG2$ -m "$ARG3$" -t $ARG4$ -s "$ARG5$" -e "$ARG6$" -a $ARG7$
    }

!!! Pay attention to the double quotes !!!

Service definition

    define service {
            check_command                  check_graphite!10!30!integral\(path.to.your.metric.\)!My_tag!30 min ago!now!avg
            host_name                      my.host.tld 
            use                            generic-service
            service_description            My description
            action_url                     /pnp/index.php?host=$HOSTNAME$&srv=$SERVICEDESC$
    }

Optionally if you are using Puppet, this is the service definition to generate the above example

    nagios_service { "graphite check 1":
            tag                 => "nagios-service",
            host_name           => $::hostname,
            service_description => "My description"
            use                 => "generic-service",
            check_command       => "check_graphite!10!30!integral\(path.to.your.metric.\)!My_tag!30 min ago!now!avg",
            action_url          => "/pnp/index.php?host=\$HOSTNAME\$&srv=\$SERVICEDESC\$"
    }

!!! Remember to escape the parenthesis !!!

### check_ndb 

Previously in a separate repo, it is a scripts to monitor MySQL NDB Cluster from 
Nagios. It connects to the NDB Manager and check the memory used by the cluster
for the specified node

