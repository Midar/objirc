include ../extra.mk

SHARED_LIB = ${OBJIRC_SHARED_LIB}
STATIC_LIB = ${OBJIRC_STATIC_LIB}
LIB_MAJOR = ${OBJIRC_LIB_MAJOR}
LIB_MINOR = ${OBJIRC_LIB_MINOR}

SRCS = IRCConnection.m \
       IRCUser.m

INCLUDES = ${SRCS:.m=.h}	\
	   ObjIRC.h

include ../buildsys.mk

LD = ${OBJC}
