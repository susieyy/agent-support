PREFIX ?= /usr/local
BIN    := agent-support

.DEFAULT_GOAL := help

.PHONY: help build install uninstall test run sync check status clean

help:  ## このヘルプを表示
	@printf "Usage: make <target> [PREFIX=...]\n\n"
	@printf "Targets:\n"
	@awk 'BEGIN{FS=":.*## "} /^[a-zA-Z_-]+:.*## / {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@printf "\nVariables:\n"
	@printf "  \033[36m%-12s\033[0m %s\n" "PREFIX" "install 先プレフィックス (default: /usr/local)"
	@printf "  \033[36m%-12s\033[0m %s\n" "BIN"    "バイナリ名 (default: agent-support)"

build:  ## release ビルド (.build/release/agent-support)
	swift build -c release

install: build  ## $(PREFIX)/bin に agent-support をインストール
	install -d "$(PREFIX)/bin"
	install -m 0755 .build/release/$(BIN) "$(PREFIX)/bin/$(BIN)"

uninstall:  ## $(PREFIX)/bin から agent-support を削除
	rm -f "$(PREFIX)/bin/$(BIN)"

test:  ## swift test を実行
	swift test

run:  ## swift run agent-support (引数なし = status 表示)
	swift run $(BIN)

sync:  ## このリポジトリに対して sync を実行
	swift run $(BIN) sync

check:  ## このリポジトリに対して check を実行 (CI 用)
	swift run $(BIN) check

status:  ## このリポジトリに対して status を表示
	swift run $(BIN) status

clean:  ## ビルド成果物をすべて削除
	swift package clean
	rm -rf .build
