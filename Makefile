.PHONY: validate

# Run pre-commit on all files
validate:
	pre-commit run --all-files;

.PHONY: new-component
new-component:
	copier copy /home/julian/projects/civitas/civitas-2/template-component components/ --trust

.PHONY: update-components
update-components:
	@for d in components/*; do \
		if [ -d "$$d" ]; then \
			name=$$(basename "$$d"); \
			echo "Updating $$name..."; \
			( cd components && copier update --skip-answered --trust -a "$$name/.copier-answers.yml" ) || echo "copier update failed for $$name"; \
		fi; \
	done;
