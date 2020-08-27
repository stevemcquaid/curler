SOURCE_FILES?=$$(go list ./... | grep -v /vendor/)
TEST_PATTERN?=.
TEST_OPTIONS?=

.PHONY: build test
.DEFAULT_GOAL := build

## Build docker container
docker-build:
	@docker build --target final -t stevemcquaid/curler:latest .

## Run docker container
docker-run: docker-build
	@docker run -it -p 8080:8080 stevemcquaid/curler:latest .

## Build the binary
build:
	@go build -o bin/app ./
	@chmod u+x bin/app

## Build the binary, cross-compiled for linux
build-linux:
	@GOOS=linux GOARCH=amd64 go build -o bin/app.linux.amd64.bin ./
	@chmod u+x bin/app.linux.amd64.bin

## Build the binary, cross-compiled for windows
build-windows:
	@GOOS=windows GOARCH=386 go build -o bin/app.windows.386.bin ./
	@chmod u+x bin/app.windows.386.exe

## Run the binary
run:
	@go run main.go

## Install all the build and lint dependencies
setup:
	GO111MODULE=on go get github.com/golangci/golangci-lint/cmd/golangci-lint@v1.26.0
	GO111MODULE=on go get honnef.co/go/tools/cmd/staticcheck@2020.1.4
	go get -u github.com/pierrre/gotestcover
	go get -u golang.org/x/tools/cmd/cover
	go get -u golang.org/x/tools/cmd/goimports
	mkdir -p build

## Run all the tests
test: test-unit

test-unit: ## Run all unit tests
	go test -cover $(TEST_OPTIONS) -covermode=atomic -coverprofile=build/unit.out $(SOURCE_FILES) -run $(TEST_PATTERN) -timeout=2m

test-integration: ## Run all integration tests
	go test -cover $(TEST_OPTIONS) -tags=integration -covermode=atomic -coverprofile=build/integration.out ./... -run $(TEST_PATTERN) -timeout=2m

## Run all the tests and opens the coverage report
cover: test
	# gocovmerge build/unit.out build/integration.out > build/all.out
	gocovmerge build/unit.out > build/all.out
	go tool cover -html=build/all.out


## gofmt and goimports all go files
fmt:
	find . -name '*.go' -not -wholename './vendor/*' | while read -r file; do gofmt -w -s "$$file"; goimports -w "$$file"; done

## Run all the linters
lint: staticcheck
	golangci-lint run  \
    		--deadline=30m \
    		--disable-all  \
    		--no-config  \
    		--issues-exit-code=0  \
    		--enable=bodyclose \
    		--enable=deadcode  \
    		--enable=dupl  \
    		--enable=errcheck  \
    		--enable=gocognit \
    		--enable=goconst  \
    		--enable=gocyclo \
    		--enable=gofmt \
    		--enable=goimports \
    		--enable=golint \
    		--enable=gomodguard \
    		--enable=gosec  \
    		--enable=govet \
    		--enable=ineffassign \
    		--enable=interfacer  \
    		--enable=megacheck \
    		--enable=misspell \
    		--enable=nakedret \
    		--enable=prealloc \
    		--enable=rowserrcheck \
    		--enable=staticcheck \
    		--enable=structcheck  \
    		--enable=stylecheck \
    		--enable=typecheck \
    		--enable=unconvert  \
    		--enable=unparam \
    		--enable=varcheck \
    		--enable=whitespace

staticcheck:
	staticcheck -fail -tests -checks="all,-ST1000,-ST1021,-ST1020" ./...

## Download deps & Runs `go mod tidy`
deps:
	@go mod tidy
	@go mod download
	@go mod vendor

## Verifies `go vet` passes
vet:
	@go vet $(shell go list ./... | grep -v vendor) | grep -v '.pb.go:' | tee /dev/stderr

## Prep for commit - run make fmt, vendor, tidy
clean: fmt deps vet

## Run all the tests and code checks
ci: fmt lint deps vet test

# Absolutely awesome: http://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
#help:
#	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

## This help menu
help:
	@printf "Available targets:\n\n"
	@awk '/^[a-zA-Z\-\_0-9%:\\]+:/ { \
	  helpMessage = match(lastLine, /^## (.*)/); \
	  if (helpMessage) { \
	    helpCommand = $$1; \
	    helpMessage = substr(lastLine, RSTART + 3, RLENGTH); \
      gsub("\\\\", "", helpCommand); \
      gsub(":+$$", "", helpCommand); \
	    printf "  \x1b[32;01m%-35s\x1b[0m %s\n", helpCommand, helpMessage; \
	  } \
	} \
	{ lastLine = $$0 }' $(MAKEFILE_LIST) | sort -u
	@printf "\n"

