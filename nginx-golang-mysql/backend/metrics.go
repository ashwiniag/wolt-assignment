package main

import (
	"github.com/prometheus/client_golang/prometheus"

	)

// Defines the metrics we want to expose.
var (
	dbConnectSuccess = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "wolt_db_connect_success",
			Help: "Indicates whether connecting to the database was successful either true or false",
		},
		[]string{"host", "status"},
	)

	dbConnectTime = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "wolt_db_connect_time",
			Help:    "Time taken to connect to the database",
			Buckets: prometheus.ExponentialBuckets(0.01, 2, 4),
		}, []string{"host"},
	)

	dbQuerySuccess = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "wolt_db_query_success",
			Help: "Indicates whether retrieving blog post titles from the database was successful",
		}, []string{"host", "status"},
	)

	dbQueryTime = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "wolt_db_query_time",
			Help:    "Time taken to retrieve blog post titles from the database",
			Buckets: prometheus.ExponentialBuckets(0.01, 2, 4),
		}, []string{"host", "status"},
	)

	httpRequestsTotal = prometheus.NewCounter(
		prometheus.CounterOpts{
			Name: "wolt_http_requests_total",
			Help: "The total number of HTTP requests processed.",
		},
	)
	httpResponseTime = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "wolt_http_response_time_seconds",
			Help:    "The time it takes to process an HTTP request in seconds.",
			Buckets: prometheus.ExponentialBuckets(0.05, 2, 4),
		},
		[]string{"method", "endpoint"},
	)

	jsonEncodeTime = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "wolt_json_encode_time",
			Help:    "Time taken to encode the blog post titles into JSON",
			Buckets: prometheus.ExponentialBuckets(0.01, 2, 4),
		}, []string{"status"},
	)

	BlogCount = prometheus.NewGauge(
		prometheus.GaugeOpts{
			Name: "wolt_blog_count",
			Help: "Count of all blog posts stored in the database.",
		},
	)
)


// Registers the metrics
func init() {
	prometheus.MustRegister(httpRequestsTotal)
	prometheus.MustRegister(httpResponseTime)
	prometheus.MustRegister(dbConnectSuccess)
	prometheus.MustRegister(dbConnectTime)
	prometheus.MustRegister(dbQuerySuccess)
	prometheus.MustRegister(dbQueryTime)
	prometheus.MustRegister(jsonEncodeTime)
	prometheus.MustRegister(BlogCount)

}

