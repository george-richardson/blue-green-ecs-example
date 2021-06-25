package main

import (
  "fmt"
  "net/http"
  "html/template"
)

const helloTemplate = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>{{.}}</title>
  <style>
    body {
      background-color: #14DB95;
      color: #FFFFFF;
      font-family: Sans-Serif;
      text-align: center;
      font-size: 6vw
    }
  </style>
</head>
<body>
  <h1>{{.}}</h1>
</body>
</html>`

func formatReponse(r *http.Request) string {
  r.ParseForm()
  name := r.Form.Get("name")
  if name == "" {
    name = "World"
  }
  return "Hello " + name + "!"
}

func htmlResponse(w http.ResponseWriter, r *http.Request) {
  name := formatReponse(r)
  t, _ := template.New("webpage").Parse(helloTemplate)
  t.Execute(w, name)
}

func apiResponse(w http.ResponseWriter, r *http.Request) {
  fmt.Fprintf(w, formatReponse(r))
}

func main() {
  http.HandleFunc("/", htmlResponse)
  http.HandleFunc("/api", apiResponse)
  http.ListenAndServe(":80", nil)
}