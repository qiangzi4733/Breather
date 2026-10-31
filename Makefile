.PHONY: app run install release test clean icon

app:
	./scripts/build-app.sh release

run: app
	-pkill -x Breather
	open build/Breather.app

# 安装到「应用程序」文件夹，长期自用
install: app
	-pkill -x Breather
	rm -rf /Applications/Breather.app
	ditto build/Breather.app /Applications/Breather.app
	open /Applications/Breather.app

# 打包可分发的 dist/Breather-<版本>.zip
release:
	./scripts/release.sh

test:
	swift test

clean:
	rm -rf .build build dist

icon:
	swift scripts/make-icon.swift Resources/AppIcon.icns
