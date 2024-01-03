BINARY := word-cloud-generator
ver := $(shell git rev-parse --short HEAD)

all: clean test build

lint: vet fmt
	@echo "Linting finished using go vet && go fmt"

vet:
	go vet $$(go list ./...|grep -v vendor)

fmt:
	go fmt $$(go list ./...|grep -v vendor)

test:
	@go test $$(go list ./...|grep -v vendor) -v

integration:
	@curl -H "Content-Type: application/json" -d '{"text":"stars stars stars"}' http://localhost:8888/api | grep 3

run:
	@go run main.go

start-mac: build
	./artifacts/osx/word-cloud-generator

goconvey-install:
	@go install github.com/smartystreets/goconvey

goconvey:
	@goconvey -port=9999

getver: 
	@echo $(ver)

build:
	@echo "Creating compiled builds in ./artifacts"
	@env GOOS=darwin GOARCH=amd64 go build -o ./artifacts/osx/${BINARY} -v .
	@env GOOS=linux GOARCH=amd64 go build -o ./artifacts/linux/${BINARY} -v .
	@env GOOS=windows GOARCH=amd64 go build -o ./artifacts/windows/${BINARY} -v .
	@ls -lR ./artifacts

docker-build: docker-build-mac docker-build-amd

docker-build-mac: build
	@echo "Creating the docker on alpine linux for mac (linux/arm64) host"
	docker build -f ./Dockerfile -t wickett/word-cloud-generator:$(ver)-arm64 -t wickett/word-cloud-generator:latest-arm64 .

docker-build-amd: getver build
	@echo "Creating the docker on alpine linux for linux/amd64 host"
	docker buildx build --load --platform linux/amd64 -f ./Dockerfile -t wickett/word-cloud-generator:$(ver)-amd64 -t wickett/word-cloud-generator:latest-amd64 .

docker-run:
	@echo "Starting new container of word-cloud-generator listening on localhost:8888"
	docker run -it --rm -p 8888:8888 wickett/word-cloud-generator:latest-arm64

docker-push:
	@echo "Pushing docker image to dockerhub"
	docker push wickett/word-cloud-generator:$(ver)-amd64
	docker push wickett/word-cloud-generator:latest-amd64
	docker push wickett/word-cloud-generator:$(ver)-arm64
	docker push wickett/word-cloud-generator:latest-arm64

clean:
	@echo "Cleaning up previous builds"
	@go clean
	@rm -rf ./artifacts/*

install:
	@echo "Installs to $$GOPATH/bin"
	@go build ./main.go
	@go install

uninstall:
	@echo "Removing from $$GOPATH/bin"
	@go clean -i

git-hooks:
	test -d .git/hooks || mkdir -p .git/hooks
	cp -f hooks/git-pre-commit.hook .git/hooks/pre-commit
	chmod a+x .git/hooks/pre-commit

.PHONY: all install uninstall clean
.DEFAULT_GOAL := all
