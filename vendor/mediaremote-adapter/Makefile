.PHONY: all version

all:

version:
	@system_profiler SPSoftwareDataType | sed -En 's/.*System Version: *//p'
	@date

update-readme-badges:
	python3 ./scripts/update-readme-badges.py
