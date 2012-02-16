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
@synthesize server, port, nickname, username, realname, delegate, sock;

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
		       port: port];

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

- (void)sendLineWithFormat: (OFConstantString*)format, ...
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

- (void)sendMessage: (OFString*)msg
	  toChannel: (IRCChannel*)channel
{
	[self sendLineWithFormat: @"PRIVMSG %@ :%@", channel.name, msg];
}

- (void)sendMessage: (OFString*)msg
	     toUser: (OFString*)user
{
	[self sendLineWithFormat: @"PRIVMSG %@ :%@", user, msg];
}

- (void)sendNotice: (OFString*)notice
	    toUser: (OFString*)user
{
	[self sendLineWithFormat: @"NOTICE %@ :%@", user, notice];
}

- (void)sendNotice: (OFString*)notice
	 toChannel: (IRCChannel*)channel
{
	[self sendLineWithFormat: @"NOTICE %@ :%@", channel.name, notice];
}

- (void)kickUser: (OFString*)user
     fromChannel: (IRCChannel*)channel
      withReason: (OFString*)reason
{
	[self sendLineWithFormat: @"KICK %@ %@ :%@",
				  channel.name, user, reason];
}

- (void)changeNicknameTo: (OFString*)nickname_
{
	[self sendLineWithFormat: @"NICK %@", nickname_];
}

- (void)process
{
	OFAutoreleasePool *pool = [[OFAutoreleasePool alloc] init];
	OFString *line;
	OFArray *split;
	OFString *action = nil;

	if (sock.atEndOfStream) {
		if ([delegate respondsToSelector:
		    @selector(connectionWasClosed:)])
			[delegate connectionWasClosed: self];

		return;
	}

	@try {
		line = [sock tryReadLine];
	} @catch (OFInvalidEncodingException *e) {
		line = [sock tryReadLineWithEncoding:
		    OF_STRING_ENCODING_WINDOWS_1252];
	}

	if (line == nil)
		return;

	if ([delegate respondsToSelector:
	    @selector(connection:didReceiveLine:)])
		[delegate connection: self
		      didReceiveLine: line];

	split = [line componentsSeparatedByString: @" "];

	/* PING */
	if (split.count == 2 && [split.firstObject isEqual: @"PING"]) {
		OFMutableString *s = [[line mutableCopy] autorelease];
		[s replaceOccurrencesOfString: @"PING"
				   withString: @"PONG"];
		[self sendLine: s];

		return;
	}

	action = [[split objectAtIndex: 1] uppercaseString];

	/* Connected */
	if ([action isEqual: @"001"] && split.count >= 4) {
		if ([delegate respondsToSelector:
		    @selector(connectionWasEstablished:)])
			[delegate connectionWasEstablished: self];

		[pool release];
		return;
	}

	/* JOIN */
	if ([action isEqual: @"JOIN"] && split.count == 3) {
		OFString *who = [split objectAtIndex: 0];
		OFString *where = [split objectAtIndex: 2];
		IRCUser *user;
		IRCChannel *channel;

		who = [who substringWithRange: of_range(1, who.length - 1)];
		user = [IRCUser IRCUserWithString: who];

		if ([who hasPrefix: [nickname stringByAppendingString: @"!"]]) {
			channel = [IRCChannel channelWithName: where];
			[channels setObject: channel
				     forKey: where];
		} else
			channel = [channels objectForKey: where];

		[channel IRC_addUser: user.nickname];

		if ([delegate respondsToSelector:
		    @selector(connection:didSeeUser:joinChannel:)])
			[delegate connection: self
				  didSeeUser: user
				 joinChannel: channel];

		[pool release];
		return;
	}

	/* NAMES reply */
	if ([action isEqual: @"353"] && split.count >= 6) {
		IRCChannel *channel;
		OFArray *users;
		size_t pos;

		channel = [channels objectForKey: [split objectAtIndex: 4]];
		if (channel == nil) {
			/* We did not request that */
			[pool release];
			return;
		}

		pos = [[split objectAtIndex: 0] length] +
		    [[split objectAtIndex: 1] length] +
		    [[split objectAtIndex: 2] length] +
		    [[split objectAtIndex: 3] length] +
		    [[split objectAtIndex: 4] length] + 6;

		users = [[line substringWithRange:
		    of_range(pos, line.length - pos)]
		    componentsSeparatedByString: @" "];

		for (OFString *user in users) {
			if ([user hasPrefix: @"@"] || [user hasPrefix: @"+"] ||
			    [user hasPrefix: @"%"] || [user hasPrefix: @"*"])
				user = [user substringWithRange:
				    of_range(1, user.length - 1)];

			[channel IRC_addUser: user];
		}

		if ([delegate respondsToSelector: @selector(connection:
		    didReceiveNamesForChannel:)])
			[delegate	   connection: self
			    didReceiveNamesForChannel: channel];

		[pool release];
		return;
	}

	/* PART */
	if ([action isEqual: @"PART"] && split.count >= 3) {
		OFString *who = [split objectAtIndex: 0];
		OFString *where = [split objectAtIndex: 2];
		IRCUser *user;
		IRCChannel *channel;
		OFString *reason = nil;
		size_t pos = who.length + 1 +
		    [[split objectAtIndex: 1] length] + 1 + where.length;

		who = [who substringWithRange: of_range(1, who.length - 1)];
		user = [IRCUser IRCUserWithString: who];
		channel = [channels objectForKey: where];

		if (split.count > 3)
			reason = [line substringWithRange:
			    of_range(pos + 2, line.length - pos - 2)];

		[channel IRC_removeUser: user.nickname];

		if ([delegate respondsToSelector:
		    @selector(connection:didSeeUser:leaveChannel:
		    withReason:)])
			[delegate connection: self
				  didSeeUser: user
				leaveChannel: channel
				  withReason: reason];

		[pool release];
		return;
	}

	/* KICK */
	if ([action isEqual: @"KICK"] && split.count >= 4) {
		OFString *who = [split objectAtIndex: 0];
		OFString *where = [split objectAtIndex: 2];
		OFString *whom = [split objectAtIndex: 3];
		IRCUser *user;
		IRCChannel *channel;
		OFString *reason = nil;
		size_t pos = who.length + 1 +
		    [[split objectAtIndex: 1] length] + 1 + where.length + 1 +
		    whom.length;

		who = [who substringWithRange: of_range(1, who.length - 1)];
		user = [IRCUser IRCUserWithString: who];
		channel = [channels objectForKey: where];

		if (split.count > 4)
			reason = [line substringWithRange:
			    of_range(pos + 2, line.length - pos - 2)];

		[channel IRC_removeUser: user.nickname];

		if ([delegate respondsToSelector:
		    @selector(connection:didSeeUser:kickUser:
		    fromChannel:withReason:)])
			[delegate connection: self
				  didSeeUser: user
				    kickUser: whom
				 fromChannel: channel
				  withReason: reason];

		[pool release];
		return;
	}

	/* QUIT */
	if ([action isEqual: @"QUIT"] && split.count >= 2) {
		OFString *who = [split objectAtIndex: 0];
		IRCUser *user;
		OFString *reason = nil;
		size_t pos = who.length + 1 + [[split objectAtIndex: 1] length];

		who = [who substringWithRange: of_range(1, who.length - 1)];
		user = [IRCUser IRCUserWithString: who];

		if (split.count > 2)
			reason = [line substringWithRange:
			    of_range(pos + 2, line.length - pos - 2)];

		for (IRCChannel *channel in channels)
			[channel IRC_removeUser: user.nickname];

		if ([delegate respondsToSelector:
		    @selector(connection:didSeeUserQuit:withReason:)])
			[delegate connection: self
			      didSeeUserQuit: user
				  withReason: reason];

		[pool release];
		return;
	}

	/* NICK */
	if ([action isEqual: @"NICK"] && split.count == 3) {
		OFString *who = [split objectAtIndex: 0];
		OFString *newNickname = [split objectAtIndex: 2];
		IRCUser *user;

		who = [who substringWithRange: of_range(1, who.length - 1)];
		newNickname = [newNickname substringWithRange:
		    of_range(1, newNickname.length - 1)];

		user = [IRCUser IRCUserWithString: who];

		if ([user.nickname isEqual: nickname]) {
			[nickname release];
			nickname = [user.nickname copy];
		}

		for (IRCChannel *channel in channels) {
			if ([channel.users containsObject: user.nickname]) {
				[channel IRC_removeUser: user.nickname];
				[channel IRC_addUser: newNickname];
			}
		}

		if ([delegate respondsToSelector:
		    @selector(connection:didSeeUser:changeNicknameTo:)])
			[delegate connection: self
				  didSeeUser: user
			    changeNicknameTo: newNickname];

		[pool release];
		return;
	}

	/* PRIVMSG */
	if ([action isEqual: @"PRIVMSG"] && split.count >= 4) {
		OFString *from = [split objectAtIndex: 0];
		OFString *to = [split objectAtIndex: 2];
		IRCUser *user;
		OFString *msg;
		size_t pos = from.length + 1 +
		    [[split objectAtIndex: 1] length] + 1 + to.length;

		from = [from substringWithRange: of_range(1, from.length - 1)];
		msg = [line substringWithRange:
		    of_range(pos + 2, line.length - pos - 2)];
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

		[pool release];
		return;
	}

	/* NOTICE */
	if ([action isEqual: @"NOTICE"] && split.count >= 4) {
		OFString *from = [split objectAtIndex: 0];
		OFString *to = [split objectAtIndex: 2];
		IRCUser *user = nil;
		OFString *notice;
		size_t pos = from.length + 1 +
		    [[split objectAtIndex: 1] length] + 1 + to.length;

		from = [from substringWithRange: of_range(1, from.length - 1)];
		notice = [line substringWithRange:
		    of_range(pos + 2, line.length - pos - 2)];

		if (![from containsString: @"!"] || [to isEqual: @"*"]) {
			/* System message - ignore for now */
			[pool release];
			return;
		}

		user = [IRCUser IRCUserWithString: from];

		if (![to isEqual: nickname]) {
			IRCChannel *channel;

			channel = [channels objectForKey: to];

			if ([delegate respondsToSelector:
			    @selector(connection:didReceiveNotice:
			    fromUser:inChannel:)])
				[delegate connection: self
				    didReceiveNotice: notice
					    fromUser: user
					   inChannel: channel];
		} else {
			if ([delegate respondsToSelector:
			    @selector(connection:didReceiveNotice:
			    fromUser:)])
				[delegate connection: self
				    didReceiveNotice: notice
					    fromUser: user];
		}

		[pool release];
		return;
	}
}

- (void)handleConnection
{
	while (![sock isAtEndOfStream])
		[self process];
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
