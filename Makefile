.PHONY: app run test clean icon

app:
	./scripts/build-app.sh release

run: app
	-pkill -x Breather
	open build/Breather.app

test:
	swift test

clean:
	rm -rf .build build

icon:
	swift scripts/make-icon.swift Resources/AppIcon.icns
