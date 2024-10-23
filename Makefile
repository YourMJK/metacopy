DIR = bin
SWIFTBUILD = swift build -c release --product
BINARIES = .build/release

.PHONY: metacopy all clean distclean
.DEFAULT_GOAL := all


$(DIR):
	mkdir $(DIR)

metacopy:
	$(SWIFTBUILD) metacopy


all: $(DIR) metacopy
	@cp -v $(BINARIES)/metacopy $(DIR)/

clean:
	swift package clean
	rm -f $(DIR)/metacopy

distclean: clean
	rm -f Package.resolved
