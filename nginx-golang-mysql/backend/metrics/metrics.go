package metrics

import (
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	nothing = prometheus.NewCounter(
		prometheus.CounterOpts{
			Name: "nothing",
			Help: "serving dummy",
		},
	)
)

func init() {
	prometheus.MustRegister(nothing)
}