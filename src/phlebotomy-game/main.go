// -------------------------------------------------------------------------------
// Phlebotomy Game - HTTP Server
//
// Project: Munchbox / Author: Alex Freidah
//
// Web-based flashcard game for studying blood collection tube order of draw,
// colors, names, and contents. Provides multiple game modes including multiple
// choice quiz, drag-and-drop ordering, and matching games.
// -------------------------------------------------------------------------------

package main

import (
	"embed"
	"encoding/json"
	"html/template"
	"log"
	"math/rand"
	"net/http"
	"os"
	"strings"
	"time"
)

//go:embed templates/*
var templateFS embed.FS

//go:embed static/*
var staticFS embed.FS

// -------------------------------------------------------------------------
// TYPES
// -------------------------------------------------------------------------

// QuizQuestion represents a multiple choice question for the quiz mode.
type QuizQuestion struct {
	Question string   `json:"question"`
	Options  []string `json:"options"`
	Answer   string   `json:"answer"`
	Category string   `json:"category"`
}

// -------------------------------------------------------------------------
// MAIN
// -------------------------------------------------------------------------

func main() {
	// Load tube data (from file if available, otherwise defaults)
	LoadTubeData()

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	tmpl := template.Must(template.ParseFS(templateFS, "templates/*.html"))
	mux := http.NewServeMux()

	// --- Static files ---
	mux.Handle("/static/", http.FileServer(http.FS(staticFS)))

	// --- Landing page ---
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			http.NotFound(w, r)
			return
		}
		w.Header().Set("Content-Type", "text/html")
		tmpl.ExecuteTemplate(w, "index.html", nil)
	})

	// --- Game mode pages ---
	mux.HandleFunc("/quiz", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html")
		tmpl.ExecuteTemplate(w, "quiz.html", nil)
	})

	mux.HandleFunc("/order", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html")
		tmpl.ExecuteTemplate(w, "order.html", nil)
	})

	mux.HandleFunc("/matching", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html")
		tmpl.ExecuteTemplate(w, "matching.html", nil)
	})

	// --- API endpoints ---
	mux.HandleFunc("/api/tubes", handleTubes)
	mux.HandleFunc("/api/quiz", handleQuiz)

	// --- Health check ---
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	})

	log.Printf("Starting phlebotomy-game on :%s", port)
	log.Fatal(http.ListenAndServe(":"+port, mux))
}

// -------------------------------------------------------------------------
// API HANDLERS
// -------------------------------------------------------------------------

// handleTubes returns all tube data as JSON.
func handleTubes(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(Tubes)
}

// handleQuiz generates a set of quiz questions.
func handleQuiz(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	questions := generateQuizQuestions(10)
	json.NewEncoder(w).Encode(questions)
}

// -------------------------------------------------------------------------
// QUIZ GENERATION
// -------------------------------------------------------------------------

// generateQuizQuestions creates a set of randomized quiz questions.
func generateQuizQuestions(count int) []QuizQuestion {
	questions := []QuizQuestion{}
	questionTypes := []func() QuizQuestion{
		generateColorToNameQuestion,
		generateNameToContentsQuestion,
		generateContentsToColorQuestion,
		generateOrderToTubeQuestion,
	}

	rng := rand.New(rand.NewSource(time.Now().UnixNano()))

	for i := 0; i < count; i++ {
		genFunc := questionTypes[rng.Intn(len(questionTypes))]
		questions = append(questions, genFunc())
	}

	return questions
}

// generateColorToNameQuestion creates a "given color, identify name" question.
func generateColorToNameQuestion() QuizQuestion {
	rng := rand.New(rand.NewSource(time.Now().UnixNano()))
	tube := Tubes[rng.Intn(len(Tubes))]

	options := []string{tube.Name}
	for len(options) < 4 {
		other := Tubes[rng.Intn(len(Tubes))]
		if !contains(options, other.Name) {
			options = append(options, other.Name)
		}
	}
	shuffle(options)

	return QuizQuestion{
		Question: "What is the name of the " + tube.Color + " tube?",
		Options:  options,
		Answer:   tube.Name,
		Category: "color-to-name",
	}
}

// generateNameToContentsQuestion creates a "given name, identify contents" question.
func generateNameToContentsQuestion() QuizQuestion {
	rng := rand.New(rand.NewSource(time.Now().UnixNano()))
	tube := Tubes[rng.Intn(len(Tubes))]

	options := []string{tube.Contents}
	for len(options) < 4 {
		other := Tubes[rng.Intn(len(Tubes))]
		if !contains(options, other.Contents) {
			options = append(options, other.Contents)
		}
	}
	shuffle(options)

	return QuizQuestion{
		Question: "What does the " + tube.Name + " contain?",
		Options:  options,
		Answer:   tube.Contents,
		Category: "name-to-contents",
	}
}

// generateContentsToColorQuestion creates a "given contents, identify color" question.
func generateContentsToColorQuestion() QuizQuestion {
	rng := rand.New(rand.NewSource(time.Now().UnixNano()))
	tube := Tubes[rng.Intn(len(Tubes))]

	options := []string{tube.Color}
	for len(options) < 4 {
		other := Tubes[rng.Intn(len(Tubes))]
		if !contains(options, other.Color) {
			options = append(options, other.Color)
		}
	}
	shuffle(options)

	return QuizQuestion{
		Question: "Which tube contains " + tube.Contents + "?",
		Options:  options,
		Answer:   tube.Color,
		Category: "contents-to-color",
	}
}

// generateOrderToTubeQuestion creates a "given order number, identify tube" question.
func generateOrderToTubeQuestion() QuizQuestion {
	rng := rand.New(rand.NewSource(time.Now().UnixNano()))
	tube := Tubes[rng.Intn(len(Tubes))]

	orderSuffix := getOrdinalSuffix(tube.Order)
	options := []string{tube.Color + " (" + tube.Name + ")"}

	for len(options) < 4 {
		other := Tubes[rng.Intn(len(Tubes))]
		optStr := other.Color + " (" + other.Name + ")"
		if !contains(options, optStr) {
			options = append(options, optStr)
		}
	}
	shuffle(options)

	return QuizQuestion{
		Question: "Which tube is drawn " + orderSuffix + " in the order of draw?",
		Options:  options,
		Answer:   tube.Color + " (" + tube.Name + ")",
		Category: "order-to-tube",
	}
}

// -------------------------------------------------------------------------
// HELPERS
// -------------------------------------------------------------------------

// contains checks if a slice contains a string.
func contains(slice []string, item string) bool {
	for _, s := range slice {
		if strings.EqualFold(s, item) {
			return true
		}
	}
	return false
}

// shuffle randomizes a string slice in place.
func shuffle(slice []string) {
	rng := rand.New(rand.NewSource(time.Now().UnixNano()))
	for i := len(slice) - 1; i > 0; i-- {
		j := rng.Intn(i + 1)
		slice[i], slice[j] = slice[j], slice[i]
	}
}

// getOrdinalSuffix returns the ordinal representation (1st, 2nd, etc.)
func getOrdinalSuffix(n int) string {
	switch n {
	case 1:
		return "1st"
	case 2:
		return "2nd"
	case 3:
		return "3rd"
	default:
		return string(rune('0'+n)) + "th"
	}
}
