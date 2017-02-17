PACKAGE=perfsonar-meshconfig
ROOTPATH=/usr/lib/perfsonar
CONFIGPATH=/etc/perfsonar
VERSION=4.0
RELEASE=0.9.rc3

default:
	@echo No need to build the package. Just run \"make install\"

dist:
	mkdir /tmp/$(PACKAGE)-$(VERSION).$(RELEASE)
	tar ch -T MANIFEST | tar x -C /tmp/$(PACKAGE)-$(VERSION).$(RELEASE)
	cd /tmp/$(PACKAGE)-$(VERSION).$(RELEASE) && ln -s doc/LICENSE LICENSE
	cd /tmp/$(PACKAGE)-$(VERSION).$(RELEASE) && ln -s doc/INSTALL INSTALL
	cd /tmp/$(PACKAGE)-$(VERSION).$(RELEASE) && ln -s doc/README README
	tar czf $(PACKAGE)-$(VERSION).$(RELEASE).tar.gz -C /tmp $(PACKAGE)-$(VERSION).$(RELEASE)
	rm -rf /tmp/$(PACKAGE)-$(VERSION).$(RELEASE)


install:
	mkdir -p ${ROOTPATH}
	tar ch --exclude=etc/* --exclude=*spec --exclude=dependencies --exclude=MANIFEST --exclude=Makefile -T MANIFEST | tar x -C ${ROOTPATH}
	sed -i 's:.RealBin/\.\./etc:/etc/perfsonar:g' ${ROOTPATH}/bin/*
	for i in `cat MANIFEST | grep ^etc/ | sed "s/^etc\///"`; do  mkdir -p `dirname $(CONFIGPATH)/$${i}`; if [ -e $(CONFIGPATH)/$${i} ]; then install -m 640 -c etc/$${i} $(CONFIGPATH)/$${i}.new; else install -m 640 -c etc/$${i} $(CONFIGPATH)/$${i}; fi; done
