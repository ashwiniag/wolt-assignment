package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	//"io/ioutil"
	"log"
	"net/http"
	"os"
	"time"

	_ "github.com/go-sql-driver/mysql"
	"github.com/gorilla/handlers"
	"github.com/gorilla/mux"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	_ "k8s.io/client-go/kubernetes"
	_ "k8s.io/client-go/rest"
)

func getEnv(key, defaultValue string) string {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	}
	return value
}

func connect() (*sql.DB, error) {
	start := time.Now()
	defer func() {
		dbConnectTime.With(prometheus.Labels{"host": "db"}).Observe(time.Since(start).Seconds())
	}()

	DB_PASSWORD := getEnv("DB_PASSWORD", "db-q5n2g")
	DB_HOST := getEnv("DB_HOST", "db")
	DB_PORT := getEnv("DB_PORT", "3306")

	if DB_PASSWORD == "" || DB_HOST == "" || DB_PORT == "" {
		log.Println("ERROR: Missing required environment variables: DB_PASSWORD, DB_HOST, DB_PORT")
		return nil, fmt.Errorf("DB_PASSWORD, DB_PORT and DB_HOST variables must be passed")
	}

	//bin, err := ioutil.ReadFile("/run/secrets/db-password")
	//if err != nil {
	//	log.Printf("error reading file: %v", err)
	//	return nil, err
	//}

	db, err := sql.Open("mysql", fmt.Sprintf("root:%s@tcp(%s:%s)/example", DB_PASSWORD, DB_HOST, DB_PORT ))
	if err != nil {
		log.Printf("ERROR: Check connection string, failed to connect to the database: %v", err)
		dbConnectSuccess.With(prometheus.Labels{"host": "db", "status": "failure"}).Set(0)
		return nil, err
	}
	dbConnectSuccess.With(prometheus.Labels{"host": "db", "status": "success"}).Set(1)
	log.Println("INFO: Successfully connected to the database")
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
		log.Printf("ERROR: Failed to query from database,: %v", err)
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
		if err != nil {
			w.WriteHeader(500)
			log.Printf("ERROR: Failed scanning row,: %v", err)
			return
		}
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
	r.HandleFunc("/backend", blogHandler)
	r.Handle("/backend_metrics", promhttp.Handler())
	log.Fatal(http.ListenAndServe(":8000", handlers.LoggingHandler(os.Stdout, r)))
}

func prepare() error {
	db, err := connect()
	if err != nil {
		log.Printf("ERROR: preparing the db, is the connection string fine?,: %v", err)
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
