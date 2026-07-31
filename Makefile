.PHONY: build test app package install clean

build:
	swift build

test:
	swift test

app:
	./scripts/build-app.sh

package:
	./scripts/package-release.sh

install:
	./scripts/install.sh

clean:
	swift package clean
	rm -rf dist
