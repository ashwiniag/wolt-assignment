## Context   
This document outlines the architecture setup of Alice Temas' project which deploys the instrumented code, discusses the emitted custom metrics to understand meaningful events of users. Provides the tech stack to provision and sending metrics of application and cluster to metrics storage.  All keeping in mind the scope of the application. It also delves into the idea of what could be improved, since this is the first draft.   
    
## Goals 

The goal of the project is to instrument the project A from Alice team to capture insightful events of the application
- Deploys the project in a Kubernetes environment.   
- Provision a AWS cloud-based architecture and providing metrics storage Terraform. 
- Identify key metrics to be observed and Instruments the applications. 
- Share ideas on what could be observed.  
- Provides simple bash scripts to deploy the stack. 
    
## Non-goals    

- Doesn't change the scope of the application.   
- Doesn't instrument traces.  
- Doesn't do any Integration tests  
    
## Background 

- Share some knowledge on what metrics are, logs are. How can they be useful . what are counts and gauge basically metrics unit    
- For the fun of it I took liberty to explore prometheus operator and implemented it. 
    
## Glossary

 - Directory structure:
├── alice-team
│   ├── infra // tf. files for basic aws infra like vpc, subnets etc
│   ├── resources // .tf files for nodes, ssm for being curious whats happening.
│   ├── services_k8s // .tf files for backend, db etc
│   └── setup_metrics // For sending cluster and application metrics 
│       ├── kube-state-metrics-configs
│       └── prometheus-operator
├── nginx-golang-mysql // Application that serves
│   ├── backend
│   ├── db
│   └── proxy
├── templates // .tf files which will be applied using Makefile 
└── tfstate_setup // Configures s3 backend to store terraform statefiles  
    
## Details     
  
### API 

#### Scope of the application written in Go  

Implements simple GET API that retrieves blog titles from MySQL and returns them as JSON.  
  
#### Endpoints 

- `/backend`: Serves the main application content.  

- `/backend_metrics`: Provides metrics for monitoring the performance and health of the application.  
  
Both endpoints are accessible on port `8000`  
  
### Storage 

The storage for the application consists of a deployed VictoriaMetrics pod. Metrics are stored by writing to the VictoriaMetrics API at `http://<localhost:port>/api/v1/write`.  

### Artefacts

Docker image is build locally and upload in ECR. 
  
### Architecture diagram 
![Diagram](https://github.com/ashwiniag/wolt-assignment/blob/main/Alice-architecture.png?raw=true)  
  
  
### Provisioning: How to use the scripts to implement. 

`provisioning_script.sh`: A simple bash scripts that build docker image and uploads on ECR, provisions necessary aws resources like VPC, subnets and managed eks cluster, and deploys k8s services.   
  
  
### Metrics & Logging 
  
The Go application is instrumented with [Prometheus](https://prometheus.io/docs/guides/go-application/), emitting various metrics including following custom metrics:   
  
  For metrics and its labels check  `metrics.go` or hit on `http://<host:port>/backend_metrics`
  
1. `wolt_http_requests_total`: Tracks the total number of HTTP requests processed.  
2. `wolt_http_response_time_seconds`: Measures the time taken to process an HTTP request, labeled by method and endpoint.  
3. `wolt_db_connect_time`: Records the time taken to connect to the database.  
4. `wolt_db_connect_success`: Indicates the success or failure of connecting to the database.  
5. `wolt_db_query_success`: Indicates the success or failure of retrieving blog post titles from the database.  
6. `wolt_db_query_time`: Measures the time taken to retrieve blog post titles from the database.  
7. `wolt_json_encode_time`: Records the time taken to encode the blog post titles into JSON.  
8. `wolt_blog_count`: Counts the number of blog posts stored in the database.  
  
Instruction on running Grafana and add the endpoint to query from.  
Note: For now logs are printed at stdout    
     
    
### Discussion notes  
- `wolt_db_connect_success`:  Lets say it's value is `false` more than 3 times in last 5min window, then alert it. This can give the patterns in the connection's stability, which will effect application performance leading to not good user experience. We can further investigate if db reached its resource crunch, what is the max connection / concurrent connection a db can handle etc to improve the performance.
- `wolt_db_connect_time:` it  indicate that the average connection time is consistent and within acceptable connection window time set.  If a large number of connections are falling into a high time bucket [ lets say more than 2 secs], it could indicate that the average connection time is much higher than desired and that the performance of the database connection is not up to the mark. User will be experiencing a slow application. //* where can we look should be written?
- `wolt_db_query_success`:  Allows to track the success or failure of query, which can help to identify and troubleshoot issues with  database interactions more effectively, here we have just one query, as of now may be with feature this can be optimised to measure performance of queries .Let’s say if the success rate of this query in last 5 min fails below 3 then, one could hop early and debug - in the lines of” Performance issues (If the database is experiencing high load or resource constraints. Then hop onto kubernetes metrics of pods - CPU, men etc), Incorrect data type ( If the query is trying to access data that does not match the specified data type, in this case check for **ERROR** logs .)
- `wolt_db_query_time`: Helps to observe the performance of the database query by measuring the time taken to retrieve blog post titles. This information is useful in understanding query performance or helping in decision like could it be further optimised? By checking logs of which query ois taking time. The metric can also be used for monitoring of the performance of the database over time, and for tracking changes in response times for queries, here status  label could be used to find other type of queries in context to this. But the scope of application here is defined to one query. dbQueryTime metric, can even set as SLO total good metrics it should be able to serve in given time.This can help us to catch  any degradation issues early.
- `wolt_json_encode_time`: This help in understanding the performance of the JSON encoding process in the application. It provides the distribution(bucket) of the time taken to encode blog post titles into JSON. Because it first converts the post to JSON it means, it takes some time and how much time is that? Depends on the data? Which indirectly will effect user experience.
- `wolt_blog_count`: This metric is a gauge which means it will display the current value in that point in time. This tracks the current number of blog posts stored in the database. It is helpful in monitoring the size/growth of the database over time, and detecting any changes in the number of blog posts, which could be used in detecting issues with data ingestion perhaps. When monitoring the growth one can also set the trigger when blog post reached beyond the value we want. May be on this one can take an active approach in upgrading db storage.
These are few custom metrics to begin with in understanding user experience and how it is impacting them to take an action based on priority. 
- `wolt_http_requests_total`: The total number of HTTP requests processed.  A counter value meaning it will work in incremented value. 
- `wolt_http_response_time_seconds`: The time it takes to process an HTTP request in seconds. Can be used to observe what endpoints are taking two much time to serve?

###  Room for improvements  
There is scope of improvements as this the first draft. 
Something to think of:
1. Metric label value for db's: dbQuerySuccess("host": "db", "status": "failure"). We can further optimised to retrieve the "host" value as the IP where the db is running. It will be in fact give better insights on system resources and how much it needs and where the application is running in determining to scale that node or pods etc.
2. Could add a metric to measure how much time it take to prepare a DB? Since the application seems to prepare db first and then proceed with server calls. A early detection of DB failure. 
3. One can improve this application further, like traking the request information or maintaining the can help understanding who are our users. Having a different endpoint for metrics listening at different port to avoid congestion (thought of this bit late. ).
4. Better handling of status codes(2XX,5XX,3XX) and emitting as metrics. This can significantly help in understanding the availability of there service by tracking number_of_bad_requests/total_requests in X time window. Can help in grabbing in quick attention to look at performance or issues, and deciding the priorities of what work on. 

...to be continued in thinking brain encountered 5xx

 