include ../extra.mk

PROG_NOINST = tests${PROG_SUFFIX}
SRCS = tests.m

include ../buildsys.mk

post-all: ${RUN_TESTS}

.PHONY: run
run:
	rm -f libobjirc.so.${OBJIRC_LIB_MAJOR}
	rm -f libobjirc.so.${OBJIRC_LIB_MAJOR_MINOR}
	rm -f libobjirc.dll libobjirc.${OBJIRC_LIB_MAJOR}.dylib
	if test -f ../src/libobjirc.so; then \
		${LN_S} ../src/libobjirc.so libobjirc.so.${OBJIRC_LIB_MAJOR}; \
		${LN_S} ../src/libobjirc.so \
			libobjirc.so.${OBJIRC_LIB_MAJOR_MINOR}; \
	elif test -f ../src/libobjirc.so.${OBJIRC_LIB_MAJOR_MINOR}; then \
		${LN_S} ../src/libobjirc.so.${OBJIRC_LIB_MAJOR_MINOR} \
			libobjirc.so.${OBJIRC_LIB_MAJOR_MINOR}; \
	fi
	if test -f ../src/libobjirc.dll; then \
		${LN_S} ../src/libobjirc.dll libobjirc.dll; \
	fi
	if test -f ../src/libobjirc.dylib; then \
		${LN_S} ../src/libobjirc.dylib \
			libobjirc.${OBJIRC_LIB_MAJOR}.dylib; \
	fi
	LD_LIBRARY_PATH=.$${LD_LIBRARY_PATH+:}$$LD_LIBRARY_PATH \
	DYLD_LIBRARY_PATH=.$${DYLD_LIBRARY_PATH+:}$$DYLD_LIBRARY_PATH \
	LIBRARY_PATH=.$${LIBRARY_PATH+:}$$LIBRARY_PATH \
	${TEST_LAUNCHER} ./${PROG_NOINST}; EXIT=$$?; \
	rm -f libobjirc.so.${OBJIRC_LIB_MAJOR}; \
	rm -f libobjirc.so.${OBJIRC_LIB_MAJOR_MINOR} libobjirc.dll; \
	rm -f libobjirc.${OBJIRC_LIB_MAJOR}.dylib; \
	exit $$EXIT

${PROG_NOINST}: ${LIBOBJIRC_DEP}

CPPFLAGS += -I../src -I../src/exceptions
LIBS += -L../src -lobjirc
LD = ${OBJC}
