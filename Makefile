VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
LDFLAGS := -ldflags "-X main.version=$(VERSION)"

.PHONY: build install clean test lint

build:
	cd tui && go build $(LDFLAGS) -o dots .

install: build
	cp tui/dots /opt/homebrew/bin/dots

clean:
	rm -f tui/dots

test:
	cd tui && go test ./...

lint:
	shellcheck scripts/*.sh
	cd tui && go vet ./...
