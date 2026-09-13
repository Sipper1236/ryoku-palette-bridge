package main

import (
	"bufio"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

const paletteOne = `{"primary":"#112233","surface":"#010203","onSurface":"#fefefe"}`
const paletteTwo = `{"primary":"#aabbcc","surface":"#101112","onSurface":"#eeeeee"}`

func TestSlowClientReceivesLatestPalette(t *testing.T) {
	hub := newPaletteHub()
	updates := make(chan snapshot, 1)
	hub.clients[updates] = struct{}{}
	for _, data := range []string{paletteOne, paletteTwo} {
		if err := hub.publish([]byte(data)); err != nil {
			t.Fatal(err)
		}
	}
	if got := string((<-updates).data); got != paletteTwo {
		t.Fatalf("client stuck on stale palette: %s", got)
	}
}

func BenchmarkPalettePublish(b *testing.B) {
	hub := newPaletteHub()
	for i := 0; i < 3; i++ {
		hub.clients[make(chan snapshot, 1)] = struct{}{}
	}
	palettes := [][]byte{[]byte(paletteOne), []byte(paletteTwo)}
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		if err := hub.publish(palettes[i%2]); err != nil {
			b.Fatal(err)
		}
	}
}

func TestPaletteEndpoint(t *testing.T) {
	hub := newPaletteHub()
	if err := hub.publish([]byte(paletteOne)); err != nil {
		t.Fatal(err)
	}
	recorder := httptest.NewRecorder()
	hub.paletteHandler(recorder, httptest.NewRequest(http.MethodGet, "/v1/palette", nil))
	if recorder.Code != http.StatusOK || strings.TrimSpace(recorder.Body.String()) != paletteOne {
		t.Fatalf("unexpected response: %d %q", recorder.Code, recorder.Body.String())
	}
}

func TestInvalidPaletteDoesNotReplaceCurrent(t *testing.T) {
	hub := newPaletteHub()
	if err := hub.publish([]byte(paletteOne)); err != nil {
		t.Fatal(err)
	}
	if err := hub.publish([]byte(`{"primary":"nope"}`)); err == nil {
		t.Fatal("invalid palette was accepted")
	}
	if got := string(hub.snapshot().data); got != paletteOne {
		t.Fatalf("palette changed to %q", got)
	}
}

func TestInvalidHexInAnyRoleIsRejected(t *testing.T) {
	hub := newPaletteHub()
	invalid := `{"primary":"#112233","surface":"#010203","onSurface":"#fefefe","tertiary":"#zzzzzz"}`
	if err := hub.publish([]byte(invalid)); err == nil {
		t.Fatal("invalid optional palette role was accepted")
	}
}

func TestEventStreamRejectsNonGet(t *testing.T) {
	hub := newPaletteHub()
	recorder := httptest.NewRecorder()
	hub.eventsHandler(recorder, httptest.NewRequest(http.MethodPost, "/v1/events", nil))
	if recorder.Code != http.StatusMethodNotAllowed {
		t.Fatalf("unexpected response: %d", recorder.Code)
	}
}

func TestEventStreamPublishesChanges(t *testing.T) {
	hub := newPaletteHub()
	if err := hub.publish([]byte(paletteOne)); err != nil {
		t.Fatal(err)
	}
	server := httptest.NewServer(http.HandlerFunc(hub.eventsHandler))
	defer server.Close()

	response, err := http.Get(server.URL)
	if err != nil {
		t.Fatal(err)
	}
	defer response.Body.Close()
	lines := make(chan string, 8)
	go func() {
		scanner := bufio.NewScanner(response.Body)
		for scanner.Scan() {
			lines <- scanner.Text()
		}
		close(lines)
	}()

	waitFor := func(want string) {
		t.Helper()
		timer := time.NewTimer(time.Second)
		defer timer.Stop()
		for {
			select {
			case line := <-lines:
				if line == "data: "+want {
					return
				}
			case <-timer.C:
				t.Fatalf("did not receive %s", want)
			}
		}
	}
	waitFor(paletteOne)
	if err := hub.publish([]byte(paletteTwo)); err != nil {
		t.Fatal(err)
	}
	waitFor(paletteTwo)
}
