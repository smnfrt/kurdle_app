.PHONY: all install fetch unmunch filter merge categorize emit checksum clean verify test deploy-assets

PY ?= python3
VENV := .venv
ACTIVATE := . $(VENV)/bin/activate

# Final artifacts (relative to pipeline dir)
OUT_DIR := build/out
WORDLIST := $(OUT_DIR)/wordlist.txt.gz
ENTRIES := $(OUT_DIR)/ferheng_entries.ndjson
LEGACY := $(OUT_DIR)/legacy_meanings.json
QA := $(OUT_DIR)/ferheng_qa.csv
META := $(OUT_DIR)/meta.json
CHECKSUMS := $(OUT_DIR)/SHA256SUMS

# App asset destinations
APP_ASSETS := ../../assets/ferheng

all: install fetch unmunch filter merge categorize emit checksum

$(VENV):
	$(PY) -m venv $(VENV)
	$(ACTIVATE) && pip install --upgrade pip && pip install -r requirements.txt

install: $(VENV)

fetch:
	$(ACTIVATE) && $(PY) scripts/01_fetch_sources.py

unmunch:
	$(ACTIVATE) && $(PY) scripts/02_unmunch.py

filter:
	$(ACTIVATE) && $(PY) scripts/03_filter_kaikki.py

merge:
	$(ACTIVATE) && $(PY) scripts/04_merge_meanings.py

categorize:
	$(ACTIVATE) && $(PY) scripts/05_categorize.py

emit:
	$(ACTIVATE) && $(PY) scripts/06_emit_artifacts.py

checksum:
	$(ACTIVATE) && $(PY) scripts/07_checksums.py

verify:
	$(ACTIVATE) && cd $(OUT_DIR) && shasum -a 256 -c SHA256SUMS

test:
	$(ACTIVATE) && pytest tests/ -v

deploy-assets: $(WORDLIST) $(LEGACY)
	mkdir -p $(APP_ASSETS)
	cp $(WORDLIST) $(APP_ASSETS)/wordlist.txt.gz
	cp $(LEGACY) $(APP_ASSETS)/legacy_meanings.json
	cp $(OUT_DIR)/entries.ndjson.gz $(APP_ASSETS)/entries.ndjson.gz
	cp LICENSES/ATTRIBUTION.md $(APP_ASSETS)/ATTRIBUTION.md
	cp data/categories.json $(APP_ASSETS)/categories.json
	@echo "Assets deployed to $(APP_ASSETS)"

clean:
	rm -rf raw/* build/*
	@echo "Cleaned raw/ and build/. Run 'make all' to regenerate."

distclean: clean
	rm -rf $(VENV)
