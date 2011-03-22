/*
 * Copyright (c) 2010, 2011, Jonathan Schleifer <js@webkeks.org>
 *
 * https://webkeks.org/hg/objirc/
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

#include <string.h>

#import "IRCUser.h"

@implementation IRCUser
@synthesize username, nickname, hostname;
+ IRCUserWithString: (OFString*)str
{
	return [[[self alloc] initWithString: str] autorelease];
}

- initWithString: (OFString*)str
{
	char *tmp2 = NULL;

	self = [super init];

	@try {
		char *tmp;

		if ((tmp2 = strdup(str.cString)) == NULL)
			@throw [OFOutOfMemoryException
			     newWithClass: isa
			    requestedSize: str.cStringLength];

		if ((tmp = strchr(tmp2, '@')) == NULL)
			@throw [OFInvalidFormatException newWithClass: isa];

		*tmp = '\0';
		hostname = [[OFString alloc] initWithCString: tmp + 1];

		if ((tmp = strchr(tmp2, '!')) == NULL)
			@throw [OFInvalidFormatException newWithClass: isa];

		*tmp = '\0';
		username = [[OFString alloc] initWithCString: tmp + 1];

		nickname = [[OFString alloc] initWithCString: tmp2];
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
	[nickname release];
	[username release];
	[hostname release];

	[super dealloc];
}

- copy
{
	return [self retain];
}

- (OFString*)description
{
	return [OFString stringWithFormat: @"%@!%@@%@",
					   nickname, username, hostname];
}
@end
