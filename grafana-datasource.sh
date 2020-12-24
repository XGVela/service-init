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


# This script is to make sure the grafana has required datasource to ensure the all the metrics,events,alarms,TCA can be visuaized on grafana through multiple dashboards(FMAAS,PaaS Resource Usage etc)

M3DB_DATASOURCE_URL=$(printenv M3DB_URL)
DASHBOARD_URL=$(printenv GRAFANA_URL)
PROM_DATASOURCE_NAME=$(printenv PROM_DATASOURCE)
ES_ALARMS_DATASOURCE_NAME=$(printenv ES_ALARMS_DATASOURCE)
ES_EVENTS_DATASOURCE_NAME=$(printenv ES_EVENTS_DATASOURCE)

#Checking the acceesibiltiy of grafana Dashbaord using k8s svc dns.
status_code=$(curl --write-out "%{http_code}\n" --silent --output /dev/null $DASHBOARD_URL)
if  [[ "$status_code" -ne 200 ]] ; then
    printf "Unable to connect to grafana dashbaord\n"
    exit 1
fi

#Checking Prometheus Datasource if exists then validating it has correct URL pointing to M3DB. Otherwise it wil create Prometheus Datasource.
status_code=$(curl --write-out "%{http_code}\n" --silent --output /dev/null $DASHBOARD_URL/api/datasources/name/$PROM_DATASOURCE_NAME)
if [[ "$status_code" -eq 200 ]] ; then
   data=$(curl -XGET --silent -k $DASHBOARD_URL/api/datasources/name/$PROM_DATASOURCE_NAME)
   URL=$(curl -XGET --silent -k $DASHBOARD_URL/api/datasources/name/$PROM_DATASOURCE_NAME | jq -r '.url'  )
   ID=$(curl -XGET --silent -k $DASHBOARD_URL/api/datasources/name/$PROM_DATASOURCE_NAME | jq -r '.id'  )
   if [[ "$URL" == "$M3DB_DATASOURCE_URL" ]] ; then
      printf "\nDatasource is already updated\n"
   else
       printf "\nUpdating Datasource\n"
       updatedData=$(echo $data | sed "s,$URL,$M3DB_DATASOURCE_URL,g")
       newResp=$(curl -X PUT --silent -H "Content-Type: application/json" -d $updatedData $DASHBOARD_URL/api/datasources/$ID )
       printf "\nNew response is: $newResp\n"
   fi

else
  printf "\n*******Creating Prometheus Datasource**********\n"
  curl -X POST -s -H "Content-Type: application/json" -d '{
    "name": "'$PROM_DATASOURCE_NAME'",
    "type": "prometheus",
    "access": "proxy",
    "url": "http://m3coordinator.xgvela-xgvela1-infra-xgvela-xgvela1.svc.cluster.local:7201",
    "basicAuth": false,
    "basicAuthUser": "",
    "basicAuthPassword": "",
    "withCredentials": false,
    "isDefault": true,
    "jsonData": {
      "timeInterval": "5s"
    },
    "secureJsonFields": {},
    "readOnly": false
  }' $DASHBOARD_URL/api/datasources/
fi


#Checking ES_Alarms Dashboard is available if not then it will be created.
es_alarm_status_code=$(curl --write-out "%{http_code}\n" --silent --output /dev/null $DASHBOARD_URL/api/datasources/name/$ES_ALARMS_DATASOURCE_NAME)
if [[ "$es_alarm_status_code" -eq 200 ]] ; then
   printf "\nES_Alarms Data Source Exists\n"
else
  printf "\n**********Creating ES_Alarms Datasource************\n"
  curl -X POST -s -H "Content-Type: application/json" -d '{
    "name": "'$ES_ALARMS_DATASOURCE_NAME'",
    "type": "elasticsearch",
    "typeLogoUrl": "public/app/plugins/datasource/elasticsearch/img/elasticsearch.svg",
    "access": "proxy",
    "url": "http://elasticsearch:9200",
    "password": "",
    "user": "",
    "database": "[alarms-]YYYY-MM-DD",
    "basicAuth": false,
    "isDefault": false,
    "jsonData": {
      "esVersion": 60,
      "interval": "Daily",
      "timeField": "commonEventHeader.startEpochMillis"
    },
    "readOnly": false

  }' $DASHBOARD_URL/api/datasources/
fi

#Checking ES_Events Dashboard is available if not then it will be created.
es_events_status_code=$(curl --write-out "%{http_code}\n" --silent --output /dev/null $DASHBOARD_URL/api/datasources/name/$ES_EVENTS_DATASOURCE_NAME)
if [[ "$es_events_status_code" -eq 200 ]] ; then
   printf "\nES_Events Data Source Exists\n"
else
   printf "\n***************creating ES_Events Datasource*********\n"
  curl -X POST -s -H "Content-Type: application/json" -d '{
    "name": "'$ES_EVENTS_DATASOURCE_NAME'",
    "type": "elasticsearch",
    "typeLogoUrl": "public/app/plugins/datasource/elasticsearch/img/elasticsearch.svg",
    "access": "proxy",
    "url": "http://elasticsearch:9200",
    "password": "",
    "user": "",
    "database": "[events-]YYYY-MM-DD",
    "basicAuth": false,
    "isDefault": false,
    "jsonData": {
      "esVersion": 60,
      "interval": "Daily",
      "timeField": "commonEventHeader.startEpochMillis"
    },
    "readOnly": false
  }' $DASHBOARD_URL/api/datasources/
fi
