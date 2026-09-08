# Makefile to apply the Nix flake configuration to the system

BUILDER_OPTS := \
		--option builders-use-substitutes true \
		--option always-allow-substitutes true

BUILDERS_HB := \
		ssh://builder@miniberry aarch64-darwin - 16 4 ; \
		ssh://builder@publicproxy aarch64-linux - 4 1 ; \
		ssh://builder@weirdfi.sh aarch64-linux - 4 1

BUILDERS := \
		ssh://builder@hyperberry x86_64-linux - 16 2 ; \
		ssh://builder@miniberry aarch64-darwin - 16 4 ;

BUILDERS_WIFI_OUT := \
		ssh://builder@publicproxy aarch64-linux - 4 1 ; \
		ssh://builder@weirdfi.sh aarch64-linux - 4 1 ;

HOME_MANAGER := home-manager --extra-experimental-features "nix-command flakes"

NIX := nix --extra-experimental-features "nix-command flakes" --extra-deprecated-features url-literals
NOM := --log-format internal-json -v 2>&1 | nom --json

HOSTNAME := $(shell cat /etc/hostname)

.PHONY: hyperberry piberry airberry update

update-index:
	git add -A

# weird Nix bug where local relative flake inputs are broken when they are
# garbage collected from the nix store
update-local-inputs:
	nix flake update mandoc-forked
	nix flake update neoforge-1-21-1
	nix flake update nix-time
	nix flake update weirdfish-server
	nix flake update agenix-secrets

# Build host-specific configurations
hyperberry: update-local-inputs update-index
	sudo nixos-rebuild switch --no-reexec --flake .#hyperberry $(NOM) ; \

blueberry: update-local-inputs update-index
	# Go!
	sudo nixos-rebuild switch --flake .#blueberry \
		$(BUILDER_OPTS) \
		--builders '$(BUILDERS)' \
		$(NOM)

piberry: update-local-inputs update-index
	sudo nixos-rebuild --max-jobs 0 switch --flake .#piberry \
		$(BUILDER_OPTS) \
		--builders '$(BUILDERS)' 

piberry-sdcard: update-local-inputs update-index
	sudo $(NIX) build .#nixosConfigurations.piberry.config.system.build.images.sd-card

tauberry: update-local-inputs update-index
	sudo nixos-rebuild --max-jobs 0 switch --flake .#tauberry \
		$(BUILDER_OPTS) \
		--builders '$(BUILDERS)' \
		$(NOM)

tauberry-sdcard: update-local-inputs update-index
	sudo $(NIX) build .#nixosConfigurations.tauberry.config.system.build.images.sd-card

airberry: update-local-inputs update-index
	sudo darwin-rebuild switch \
		$(BUILDER_OPTS) \
		--flake .#airberry 

miniberry: update-local-inputs update-index
	sudo darwin-rebuild switch \
		--flake .#miniberry \
		--option builders '$(BUILDERS)'
		--option builders-use-substitutes true \
		--option always-allow-substitutes true

bootstrap-weirdfi.sh: update-local-inputs update-index
	$(NIX) run github:nix-community/nixos-anywhere -- --generate-hardware-config nixos-generate-config ./systems/weirdfi.sh-cax11-4gb/hardware-configuration.nix --flake .#weirdfish-cax11-4gb --target-host "root@weirdfi.sh"

bootstrap-publicproxy: update-local-inputs update-index
	$(NIX) run github:nix-community/nixos-anywhere -- --generate-hardware-config nixos-generate-config ./systems/publicproxy-cax11-4gb/hardware-configuration.nix --flake .#publicproxy-cax11-4gb --target-host "root@publicproxy"

deploy: update-index
ifeq ($(HOSTNAME),hyperberry)
	# build locally
	deploy $(HOST) \
		--skip-checks \
		--skip-offline \
		--fast-connection true \
		--rollback-succeeded false \
		-- \
		$(BUILDER_OPTS) \
		--max-jobs 16 \
		--builders '$(BUILDERS_HB)' \
		--show-trace
else
	# build remotely
	deploy $(HOST) \
		--skip-checks \
		--skip-offline \
		--fast-connection false \
		--rollback-succeeded false \
		-- \
		$(BUILDER_OPTS) \
		--builders '$(BUILDERS_WIFI_OUT)' \
		--max-jobs 0 \
		$(NOM) 
endif

weirdfi.sh:
	HOST=.#weirdfish-cax11-4gb make deploy 

publicproxy:
	HOST=.#publicproxy-cax11-4gb make deploy 

midnight:
	nix build .#robotnixConfigurations.midnight.img $(NOM)

midnight-generate-keys:
	nix build .#robotnixConfigurations.midnight.generateKeysScript --out-link generate-keys.sh $(NOM)

midnight-release:
	nix build .#robotnixConfigurations.midnight.releaseScript --out-link make-release.sh $(NOM)

# Update flake inputs and lock file
update:
	$(NIX) flake update

render-flakegraph:
	nix build .#packages.x86_64-linux.flakegraph || true

show-flakegraph: render-flakegraph
	qiv ./result/hosts.png

setup-remotes:
	git remote add github git@github.com:jaspinegz/d1.git || true
	git remote add srv jaspine@weirdfi.sh:/data/git/d1.git || true
	git fetch srv
	git branch -u srv/master

push:
	git push github master
	git push srv master

force-push:
	git push github master -f
	git push srv master -f
