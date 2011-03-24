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

#include <stdarg.h>

#import <ObjFW/OFString.h>
#import <ObjFW/OFArray.h>
#import <ObjFW/OFMutableDictionary.h>
#import <ObjFW/OFTCPSocket.h>
#import <ObjFW/OFAutoreleasePool.h>

#import <ObjFW/OFInvalidEncodingException.h>

#import "IRCConnection.h"
#import "IRCUser.h"
#import "IRCChannel.h"

@implementation IRCConnection
@synthesize server, port, nickname, username, realname, delegate;

- init
{
	self = [super init];

	@try {
		channels = [[OFMutableDictionary alloc] init];
		port = 6667;
	} @catch (id e) {
		[self release];
		@throw e;
	}

	return self;
}

- (void)connect
{
	OFAutoreleasePool *pool = [[OFAutoreleasePool alloc] init];

	sock = [[OFTCPSocket alloc] init];
	[sock connectToHost: server
		     onPort: port];

	[self sendLineWithFormat: @"NICK %@", nickname];
	[self sendLineWithFormat: @"USER %@ * 0 :%@", username, realname];

	[pool release];
}

- (void)disconnect
{
	[self disconnectWithReason: nil];
}

- (void)disconnectWithReason: (OFString*)reason
{
	if (reason == nil)
		[self sendLine: @"QUIT"];
	else
		[self sendLineWithFormat: @"QUIT :%@", reason];
}

- (void)joinChannel: (OFString*)channelName
{
	[self sendLineWithFormat: @"JOIN %@", channelName];
}

- (void)leaveChannel: (IRCChannel*)channel
{
	[self leaveChannel: channel
		withReason: nil];
}

- (void)leaveChannel: (IRCChannel*)channel
          withReason: (OFString*)reason
{
	if (reason == nil)
		[self sendLineWithFormat: @"PART %@", channel.name];
	else
		[self sendLineWithFormat: @"PART %@ :%@", channel.name, reason];

	[channels removeObjectForKey: channel.name];
}

- (void)sendLine: (OFString*)line
{
	if ([delegate respondsToSelector: @selector(connection:didSendLine:)])
		[delegate connection: self
			 didSendLine: line];

	[sock writeLine: line];
}

- (void)sendLineWithFormat: (OFString*)format, ...
{
	OFAutoreleasePool *pool = [[OFAutoreleasePool alloc] init];
	OFString *line;
	va_list args;

	va_start(args, format);
	line = [[[OFString alloc] initWithFormat: format
				       arguments: args] autorelease];
	va_end(args);

	[self sendLine: line];

	[pool release];
}

- (void)handleConnection
{
	OFAutoreleasePool *pool = [[OFAutoreleasePool alloc] init];
	OFString *line;
	OFArray *splitted;

	for (;;) {
		@try {
			line = [sock readLine];
		} @catch (OFInvalidEncodingException *e) {
			[e dealloc];
			line = [sock readLineWithEncoding:
			    OF_STRING_ENCODING_WINDOWS_1252];
		}

		if (line == nil)
			break;

		if ([delegate respondsToSelector:
		    @selector(connection:didReceiveLine:)])
			[delegate connection: self
			      didReceiveLine: line];

		splitted = [line componentsSeparatedByString: @" "];

		/* PING */
		if (splitted.count == 2 &&
		    [splitted.firstObject isEqual: @"PING"]) {
			OFMutableString *s = [[line mutableCopy] autorelease];
			[s replaceOccurrencesOfString: @"PING"
					   withString: @"PONG"];
			[self sendLine: s];

			continue;
		}

		/* Connected */
		if (splitted.count >= 4 &&
		    [[splitted objectAtIndex: 1] isEqual: @"001"]) {
			if ([delegate respondsToSelector:
			    @selector(connectionWasEstablished:)])
				[delegate connectionWasEstablished: self];

			continue;
		}

		/* JOIN */
		if (splitted.count == 3 &&
		    [[splitted objectAtIndex: 1] isEqual: @"JOIN"]) {
			OFString *who = [splitted objectAtIndex: 0];
			OFString *where = [splitted objectAtIndex: 2];
			IRCUser *user;
			IRCChannel *channel;

			who = [who substringFromIndex: 1
					      toIndex: who.length];
			where = [where substringFromIndex: 1
						  toIndex: where.length];

			user = [IRCUser IRCUserWithString: who];

			if ([who hasPrefix:
			    [nickname stringByAppendingString: @"!"]]) {
				channel = [IRCChannel channelWithName: where];
				[channels setObject: channel
					     forKey: where];
			} else
				channel = [channels objectForKey: where];

			if ([delegate respondsToSelector:
			    @selector(connection:didSeeUser:joinChannel:)])
				[delegate connection: self
					  didSeeUser: user
					 joinChannel: channel];

			continue;
		}

		/* PRIVMSG */
		if (splitted.count >= 4 &&
		    [[splitted objectAtIndex: 1] isEqual: @"PRIVMSG"]) {
			OFString *from = [splitted objectAtIndex: 0];
			OFString *to = [splitted objectAtIndex: 2];
			IRCUser *user;
			OFString *msg;
			size_t pos = from.length + 1 +
			    [[splitted objectAtIndex: 1] length] + 1 +
			    to.length;

			from = [from substringFromIndex: 1
						toIndex: from.length];
			msg = [line substringFromIndex: pos + 2
					       toIndex: line.length];

			user = [IRCUser IRCUserWithString: from];

			if (![to isEqual: nickname]) {
				IRCChannel *channel;

				channel = [channels objectForKey: to];

				if ([delegate respondsToSelector:
				    @selector(connection:didReceiveMessage:
				    fromUser:inChannel:)])
					[delegate connection: self
					   didReceiveMessage: msg
						    fromUser: user
						   inChannel: channel];
			} else {
				if ([delegate respondsToSelector:
				     @selector(connection:
				     didReceivePrivateMessage:fromUser:)])
					[delegate
					    connection: self
					    didReceivePrivateMessage: msg
					    fromUser: user];
			}

			continue;
		}

		[pool releaseObjects];
	}

	[pool release];
}

- (void)dealloc
{
	[sock release];
	[server release];
	[nickname release];
	[username release];
	[realname release];
	[channels release];

	[super dealloc];
}
@end
