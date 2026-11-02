build:
	./build-app.sh

install: build
	rm -rf /Applications/UVCMirror.app
	mv UVCMirror.app /Applications

default: build
