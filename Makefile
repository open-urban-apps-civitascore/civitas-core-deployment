.PHONY: validate

# Run pre-commit on all files
validate:
	pre-commit run --all-files;

.PHONY: new-component
new-component:
	copier copy /home/julian/projects/civitas/civitas-2/template-component components/
