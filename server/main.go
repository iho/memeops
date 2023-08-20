package main

import (
    "database/sql"
    "fmt"
    "log"
	"os"
    "net/http"
    "encoding/json"
    _ "github.com/lib/pq"
)

type Todo struct {
    ID        int    `json:"id"`
    Task      string `json:"task"`
    Completed bool   `json:"completed"`
}

var db *sql.DB

func init() {
	var err error
	rdsURL := os.Getenv("RDS_URL")
	if rdsURL == "" {
		log.Println("$RDS_URL must be set")
	}

	rdsURL = os.Getenv("DB_HOST")

	connStr := fmt.Sprintf("host=%s user=username dbname=tododb password=yourpassword sslmode=disable", rdsURL)
	db, err = sql.Open("postgres", connStr)
	if err != nil {
		log.Fatal(err)
	}
}

func getTodos(w http.ResponseWriter, r *http.Request) {
    rows, err := db.Query("SELECT * FROM todos")
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }
    defer rows.Close()

    var todos []Todo
    for rows.Next() {
        var t Todo
        if err := rows.Scan(&t.ID, &t.Task, &t.Completed); err != nil {
            http.Error(w, err.Error(), http.StatusInternalServerError)
            return
        }
        todos = append(todos, t)
    }

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(todos)
}

func main() {
	defer db.Close()
    http.HandleFunc("/todos", getTodos)
    // Add handlers for Create, Update, Delete

    fmt.Println("Server started on :8080")
    http.ListenAndServe(":8080", nil)
}
