package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"time"

	_ "github.com/go-sql-driver/mysql"
	"github.com/gorilla/handlers"
	"github.com/gorilla/mux"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

func connect() (*sql.DB, error) {
	start := time.Now()
	defer func() {
		dbConnectTime.With(prometheus.Labels{"host": "db"}).Observe(time.Since(start).Seconds())
	}()

	bin, err := ioutil.ReadFile("/run/secrets/db-password")
	if err != nil {
		return nil, err
	}
	db, err := sql.Open("mysql", fmt.Sprintf("root:%s@tcp(db:3306)/example", string(bin)))
	if err != nil {
		dbConnectSuccess.With(prometheus.Labels{"host": "db", "status": "failure"}).Set(0)
		return nil, err
	}
	dbConnectSuccess.With(prometheus.Labels{"host": "db", "status": "success"}).Set(1)
	return db, nil
}

func blogHandler(w http.ResponseWriter, r *http.Request) {
	httpRequestsTotal.Inc()

	// Time it takes to complete the request
	start := time.Now()
	defer func() {
		httpResponseTime.With(prometheus.Labels{
			"method": r.Method,
			"endpoint": r.URL.Path,
		}).Observe(time.Since(start).Seconds())
	}()

	db, err := connect()
	if err != nil {
		w.WriteHeader(500)
		return
	}
	defer db.Close()

	queryStart := time.Now()
	rows, err := db.Query("SELECT title FROM blog")
	if err != nil {
		dbQuerySuccess.With(prometheus.Labels{"host": "db", "status": "failure"}).Set(0)
		w.WriteHeader(500)
		return
	}
	dbQuerySuccess.With(prometheus.Labels{"host": "db", "status": "success"}).Set(1)
	dbQueryTime.With(prometheus.Labels{"host": "db", "status": "success"}).Observe(time.Since(queryStart).Seconds())

	var titles []string
	for rows.Next() {
		var title string
		err = rows.Scan(&title)
		titles = append(titles, title)
	}
	BlogCount.Set(float64(len(titles)))
	// Start timing the JSON encoding
	encodeStart := time.Now()
	err = json.NewEncoder(w).Encode(titles)
	jsonEncodeTime.With(prometheus.Labels{"status": "success"}).Observe(time.Since(encodeStart).Seconds())
	if err != nil {
		jsonEncodeTime.With(prometheus.Labels{"status": "failure"}).Observe(time.Since(encodeStart).Seconds())
		w.WriteHeader(500)
		return
	}
}

func main() {
	log.Print("Prepare db...")
	if err := prepare(); err != nil {
		log.Fatal(err)
	}

	log.Print("Listening 8000")
	r := mux.NewRouter()
	r.HandleFunc("/", blogHandler)
	r.Handle("/metrics", promhttp.Handler())
	log.Fatal(http.ListenAndServe(":8000", handlers.LoggingHandler(os.Stdout, r)))
}

func prepare() error {
	db, err := connect()
	if err != nil {
		return err
	}
	defer db.Close()

	for i := 0; i < 60; i++ {
		if err := db.Ping(); err == nil {
			break
		}
		time.Sleep(time.Second)
	}

	if _, err := db.Exec("DROP TABLE IF EXISTS blog"); err != nil {
		return err
	}

	if _, err := db.Exec("CREATE TABLE IF NOT EXISTS blog (id int NOT NULL AUTO_INCREMENT, title varchar(255), PRIMARY KEY (id))"); err != nil {
		return err
	}

	for i := 0; i < 5; i++ {
		if _, err := db.Exec("INSERT INTO blog (title) VALUES (?);", fmt.Sprintf("Blog post #%d", i)); err != nil {
			return err
		}
	}
	return nil
}
