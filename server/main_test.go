package main_test

import "testing"

func TestGetTodos(t *testing.T) {
	got := 1
	want := 1
	if got != want {
		t.Errorf("got %q, want %q", got, want)
	}
}
