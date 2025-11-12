.PHONY: validate

# Run pre-commit on all files
validate:
	pre-commit run --all-files;
