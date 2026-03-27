VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
LDFLAGS := -ldflags "-X main.version=$(VERSION)"

.PHONY: build install clean test lint

build:
	cd tui && go build $(LDFLAGS) -o dots .

PREFIX ?= $(shell brew --prefix 2>/dev/null || echo /usr/local)

install: build
	cp tui/dots $(PREFIX)/bin/dots

clean:
	rm -f tui/dots

test:
	cd tui && go test ./...

lint:
	shellcheck scripts/*.sh
	cd tui && go vet ./...
