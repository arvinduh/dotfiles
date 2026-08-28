# The only tooling in this repo. There is no install script on purpose:
# symlinking is one stow command, and bootstrapping a fresh machine happens
# about once a year — the README block does that better than code would.
#
#   make link       symlink everything into $HOME
#   make unlink     remove those symlinks
#   make packages   install packages.txt via apt
#   make doctor     check that what is linked actually resolves
#   make audit      line counts by language (needs scc)
#   make check      assert the formatters and linters actually work

# The directory layout IS the package list. Adding a tool means adding a
# directory that mirrors its target path; nothing here needs editing.
#
# docs/ is prose. windows/ mirrors %APPDATA% and %LOCALAPPDATA%, not $HOME, so
# stow has nothing to do with it — windows/link.ps1 is its equivalent.
STOW := $(patsubst %/,%,$(filter-out docs/ windows/ tests/,$(wildcard */)))

# $(HOME) at depth 2 already covers ~/.config/*; .local/bin is deeper.
HOME_LINKS := $(HOME) $(HOME)/.local/bin

.PHONY: link unlink packages doctor audit check help

help:
	@sed -n '1,9p' Makefile | sed 's/^# \?//'
	@echo
	@echo "stow packages: $(STOW)"

# --restow is unlink-then-relink, which makes this idempotent and clears stale
# links. Folding stays ON: nvim NEEDS ~/.config/nvim to be a directory symlink
# so lazy-lock.json is written back into this repo. Never add --no-folding.
link:
	stow --restow --target=$(HOME) $(STOW)

unlink:
	stow --delete --target=$(HOME) $(STOW)

packages:
	sed -e 's/#.*//' -e '/^[[:space:]]*$$/d' packages.txt \
	  | xargs sudo apt-get install -y --no-install-recommends

# Two failure modes are worth catching: a symlink into this repo whose target
# was deleted, and a tool the config calls by name that is not installed.
doctor:
	@echo "dangling links into this repo:"
	@out=$$(find $(HOME_LINKS) -maxdepth 2 -type l ! -exec test -e {} \; -print 2>/dev/null | sort -u); \
	  if [ -n "$$out" ]; then echo "$$out" | sed 's|^|  |'; else echo "  none"; fi
	@echo
	@echo "missing commands:"
	@for c in zsh nvim tmux git stow zoxide fzf eza rg atuin node npm \
	          rustc rust-analyzer clangd clang-format shellcheck shfmt; do \
	  command -v $$c >/dev/null 2>&1 || echo "  $$c"; \
	done
	@echo
	@printf 'zsh startup: '
	@zsh -i -c exit >/dev/null 2>&1   # warm the compdump first, or this lies
	@{ time -p zsh -i -c exit ; } 2>&1 | awk '/^real/{print $$2 "s"}'

# scc is not in apt; the README bootstrap installs it from a GitHub release.
# Defaults (including --no-cocomo) come from scc/.config/scc/config.
audit:
	@command -v scc >/dev/null 2>&1 \
	  && scc \
	  || echo "scc not installed — see the bootstrap block in README.md"

# The same Lua suite Windows runs, so there is one implementation rather than a
# shell script and a PowerShell twin that drift apart.
check:
	@nvim --headless -c 'luafile tests/run.lua'
