#! /bin/bash
# Copyright 2020 Mavenir
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


#Usage: ./svc-discovery.sh [kafka topic list]
#kafka topic list: This is optional param which if present must be declared like "kafka_topic1 kafka_topic2 ...".

KAFKATOPIC_LIST=""
if [[ -n $1 ]] ; then
    KAFKATOPIC_LIST=$1
fi

#progress-bar() {
#    wait=$1
#    msg=$2
#    for i in `seq 1 $wait`; do
#        z=$((i * 100))
#        z=$(($z / $wait))
#        #echo -ne "\rProgress[$z%]"
#        echo -ne "\r$msg[$z%]"
#        sleep 1
#    done
#    echo ""
#}

get_etcd_cluster_status() {
    etcd_cluster_endpoints=http://etcd-0.$ETCD_SVC_FQDN,http://etcd-1.$ETCD_SVC_FQDN,http://etcd-2.$ETCD_SVC_FQDN
    retval=$(ETCDAPI=3; ./etcdctl -C $etcd_cluster_endpoints cluster-health | awk '/^cluster is healthy|^cluster is degraded/{print}')
    echo "$retval"
    if [[ "$retval" == "cluster is healthy" ]] || [[ "$retval" == "cluster is degraded" ]]; then
      echo $(date): Healthy etcd Cluster
      return 1
    else
      echo $(date): Un-Healthy etcd Cluster
      return 0
    fi
}

check_etcd_cluster_availibility() {
    curr_retry_index=0
    max_retry_attempt=$1
    retry_timer=$2
    echo "checking etcd cluster availibility"
    etcd_cluster_healthy=$?
    while [[ $etcd_cluster_healthy -eq 0 ]] && [[ $curr_retry_index -lt $max_retry_attempt ]]
    do
       curr_retry_index=`expr $curr_retry_index + 1`
       #progress-bar $retry_timer "Retrying dependency resolution..."
       #echo "[$curr_retry_index/$max_retry_attempt] Retrying dependency resolution..."
       echo "Retrying ..."
       sleep $retry_timer
       get_etcd_cluster_status
       etcd_cluster_healthy=$?
       #Resetting the counter, so that it can wait indefinately till cluster is healthy
       curr_retry_index=0
    done
}


get_kafka_cluster_status() {
    tp=$1
    kafka_cluster_endpoints=kafka-0.$KAFKA_SVC_FQDN,kafka-1.$KAFKA_SVC_FQDN,kafka-2.$KAFKA_SVC_FQDN
    retval=$(kafkacat -L -b kafka-0.$KAFKA_SVC_FQDN,kafka-1.$KAFKA_SVC_FQDN,kafka-2.$KAFKA_SVC_FQDN | awk "/topic \"$tp\" with.*partitions:/{print}" | tr -s \ | cut -d ' ' -f 5)

    if [[ -n "$retval" ]] && [[ $retval -ne "" ]] && [[ "$retval" -ne "0" ]] ; then
      echo $(date): $tp kafka topic created with $retval partitions
      return 1
    else
      echo $(date): Un-Healthy kafka Cluster or Topic $tp not ready
      return 0
    fi
}

check_kafka_cluster_availibility() {
    curr_retry_index=0
    max_retry_attempt=$1
    retry_timer=$2
    topic_list=$3

    echo "checking kafka cluster and topic availibility"
    echo "Topic List: [$topic_list]"
    if [[ -z $topic_list ]]; then
       echo "kafka dependency check not required"
       return
    fi
    for topic in $topic_list
    do
         kafka_cluster_healthy=0
         while [[ $kafka_cluster_healthy -eq 0 ]] && [[ $curr_retry_index -lt $max_retry_attempt ]]
         do
            curr_retry_index=`expr $curr_retry_index + 1`
            #progress-bar $retry_timer "Retrying dependency resolution..."
            #echo "[$curr_retry_index/$max_retry_attempt] Retrying dependency resolution..."
            echo "Retrying ..."
            sleep $retry_timer
            echo "checking etcd cluster availibility"
            get_kafka_cluster_status $topic
            kafka_cluster_healthy=$?
            #Resetting the counter, so that it can wait indefinately till cluster is healthy
            curr_retry_index=0
         done
    done
}


check_zk_cluster_availibility() {
    zk_cluster_status=0
    zk_cluster_endpoints1=zk-0.$ZK_SVC_FQDN
    zk_cluster_endpoints2=zk-1.$ZK_SVC_FQDN
    zk_cluster_endpoints3=zk-2.$ZK_SVC_FQDN
    ZK_COUNT=$(echo $KAFKA_ZOOKEEPER_CONNECT | tr ',' ' ' | wc -w)
    echo "ZK_COUNT: $ZK_COUNT"
    while [[ $zk_cluster_status -eq 0 ]]
    do
      if [[ "$ZK_COUNT" -eq "3" ]]; then
        zk_cluster1=$(echo stat | nc $(echo $KAFKA_ZOOKEEPER_CONNECT|cut -d "," -f 1|cut -d ":" -f1) 2181 |awk '/Mode: follower|Mode: leader/' |wc -l )
        zk_cluster2=$(echo stat | nc $(echo $KAFKA_ZOOKEEPER_CONNECT|cut -d "," -f 2|cut -d ":" -f1) 2181 |awk '/Mode: follower|Mode: leader/' |wc -l )
        zk_cluster3=$(echo stat | nc $(echo $KAFKA_ZOOKEEPER_CONNECT|cut -d "," -f 3|cut -d ":" -f1) 2181 |awk '/Mode: follower|Mode: leader/' |wc -l )
        zk_cluster=$(( $zk_cluster1 + $zk_cluster2 + $zk_cluster3 ))
        if [[ "$zk_cluster" -gt "1" ]] ; then
          echo $(date): Healthy zk Cluster
          return 0
        else
          echo $(date): Un-Healthy zk Cluster
          zk_cluster_status=0
        sleep 5
        fi
      else
        zk_cluster1=$(echo stat | nc $(echo $KAFKA_ZOOKEEPER_CONNECT|cut -d "," -f 1|cut -d ":" -f1) 2181 |awk '/Mode: standalone/' |wc -l )
        if [[ "$zk_cluster1" -eq "1" ]] ; then
          echo $(date): Healthy zk instance
          return 0
        else
          echo $(date): Un-Healthy zk instance
          zk_cluster_status=0
        sleep 5
        fi
      fi
    done
}


KAFKA_SVC_FQDN="${KAFKA_SVC_FQDN}"
echo "Kafka FQDN: $KAFKA_SVC_FQDN"

ETCD_SVC_FQDN="${ETCD_SVC_FQDN}"
echo "Etcd FQDN: $ETCD_SVC_FQDN"

ZK_SVC_FQDN="${ZK_SVC_FQDN}"
echo "ZK FQDN: $ZK_SVC_FQDN"


if [[ "kafka" == "${service}" ]]; then
   echo "service type is ${service}. Hence skiping etcd/kafka check..."
   check_zk_cluster_availibility
else
   echo "Validating etcd/kafka cluster status...."
   check_etcd_cluster_availibility 600 5
   check_kafka_cluster_availibility 600 5 "$KAFKATOPIC_LIST"
fi
