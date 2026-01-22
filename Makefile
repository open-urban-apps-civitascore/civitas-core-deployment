.PHONY: validate

# Run pre-commit on all files
validate:
	pre-commit run --all-files;

.PHONY: new-component
new-component:
	cd components && copier copy .. .

.PHONY: update
update:
	copier update --skip-answered -a test/.copier-answers.yaml components

.PHONY: update-components
update-components:
	@for d in components/*; do \
		if [ -d "$$d" ]; then \
			name=$$(basename "$$d"); \
			echo "Updating $$name..."; \
			( cd components && copier update --skip-answered --trust -a "$$name/.copier-answers.yml" ) || echo "copier update failed for $$name"; \
		fi; \
	done;
