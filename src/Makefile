LIB = objirc
LIB_MAJOR = 0
LIB_MINOR = 0

SRCS = IRCConnection.m	\
       IRCUser.m

HEADERS = ${SRCS:.m=.h}	\
	  ObjIRC.h

CPPFLAGS += -I.
OBJCFLAGS += -Werror

prefix ?= /usr/local

INSTALL ?= install
OBJFW_CONFIG ?= objfw-config
OBJFW_COMPILE ?= objfw-compile

LIB_PREFIX = `${OBJFW_CONFIG} --lib-prefix`
LIB_SUFFIX = `${OBJFW_CONFIG} --lib-suffix`
LIB_FILE = ${LIB_PREFIX}${LIB}${LIB_SUFFIX}

all:
	@objfw-compile				\
		--lib ${LIB_MAJOR}.${LIB_MINOR}	\
		-o objirc			\
		--builddir build		\
		${CPPFLAGS}			\
		${OBJCFLAGS}			\
		${SRCS}

clean:
	rm -f libobjirc.* *~
	rm -fr build

install:
	mkdir -p ${destdir}${prefix}/include/ObjIRC
	for i in ${HEADERS}; do \
		${INSTALL} -m 644 $$i \
			${destdir}${prefix}/include/ObjIRC/$$i; \
	done
	mkdir -p ${destdir}${prefix}/lib
	export LIB_MAJOR=${LIB_MAJOR}; \
	export LIB_MINOR=${LIB_MINOR}; \
	${INSTALL} -m 755 ${LIB_FILE} ${destdir}${prefix}/lib/${LIB_FILE}
