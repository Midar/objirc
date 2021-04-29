/*
 * Copyright (c) 2010, 2011, 2012, 2013, 2016
 *   Jonathan Schleifer <js@heap.zone>
 *
 * https://heap.zone/git/?p=objirc.git
 *
 * Permission to use, copy, modify, and/or distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice is present in all copies.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#include <stdlib.h>
#include <string.h>

#import <ObjFW/OFString.h>

#import <ObjFW/OFInvalidFormatException.h>
#import <ObjFW/OFOutOfMemoryException.h>

#import <ObjFW/macros.h>

#import "IRCUser.h"

@implementation IRCUser
@synthesize username = _username, nickname = _nickname, hostname = _hostname;

+ (instancetype)IRCUserWithString: (OFString *)string
{
	return [[[self alloc] initWithString: string] autorelease];
}

- (instancetype)initWithString: (OFString *)string
{
	char *tmp2 = NULL;

	self = [super init];

	@try {
		char *tmp;

		tmp2 = OFStrDup(string.UTF8String);

		if ((tmp = strchr(tmp2, '@')) == NULL)
			@throw [OFInvalidFormatException exception];

		*tmp = '\0';
		_hostname = [[OFString alloc] initWithUTF8String: tmp + 1];

		if ((tmp = strchr(tmp2, '!')) == NULL)
			@throw [OFInvalidFormatException exception];

		*tmp = '\0';
		_username = [[OFString alloc] initWithUTF8String: tmp + 1];

		_nickname = [[OFString alloc] initWithUTF8String: tmp2];
	} @catch (id e) {
		[self release];
		@throw e;
	} @finally {
		if (tmp2 != NULL)
			free(tmp2);
	}

	return self;
}

- (void)dealloc
{
	[_nickname release];
	[_username release];
	[_hostname release];

	[super dealloc];
}

- (id)copy
{
	return [self retain];
}

- (OFString *)description
{
	return [OFString stringWithFormat: @"%@!%@@%@",
					   _nickname, _username, _hostname];
}
@end
