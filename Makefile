libh2o.a: src-h2o/libh2o.a
	cp $< $@

src-h2o/.git:
	git submodule update --init

src-h2o/libh2o.a: | src-h2o/.git
	sh build.sh

