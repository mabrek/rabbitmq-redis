GIT_UPSTREAM=https://github.com/cstar/erldis.git
REVISION=bb812a27eff43d6c00041a61bb0af5f49aa787aa

EBIN_DIR=ebin
INCLUDE_DIR=include

LIB_PACKAGE=erldis
LIB_PACKAGE_DIR=$(LIB_PACKAGE)
LIB_PACKAGE_NAME=$(LIB_PACKAGE).ez

CHECKOUT_DIR=$(LIB_PACKAGE_DIR)-git

TARGETS=$(LIB_PACKAGE_NAME)

all: $(TARGETS)

clean:
	rm -rf $(EBIN_DIR)
	rm -rf $(INCLUDE_DIR)
	rm -rf $(TARGETS)
	make -C $(LIB_PACKAGE_DIR) clean

distclean: clean
	rm -rf $(CHECKOUT_DIR) $(LIB_PACKAGE_DIR)

$(LIB_PACKAGE_DIR): $(CHECKOUT_DIR)
	cp -r $< $@

$(CHECKOUT_DIR):
	git clone $(GIT_UPSTREAM) $@-tmp
	(cd $@-tmp; git checkout $(REVISION))
	cd $@-tmp && patch -p1 < ../rm-gen-server2.patch && cd .. && mv $@-tmp $@

%.ez: $(LIB_PACKAGE_DIR)
	$(MAKE) -C $(LIB_PACKAGE_DIR) clean all
	rm -rf ebin include
	cp -r $(LIB_PACKAGE_DIR)/ebin $(EBIN_DIR)
	cp -r $(LIB_PACKAGE_DIR)/include $(INCLUDE_DIR)
	zip $(LIB_PACKAGE_NAME) $(LIB_PACKAGE_DIR)/
	zip -r $(LIB_PACKAGE_NAME) $(LIB_PACKAGE_DIR)/$(EBIN_DIR)/
