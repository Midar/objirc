/*
 * Copyright (c) 2010, 2011, Jonathan Schleifer <js@webkeks.org>
 *
 * https://webkeks.org/git/?p=objirc.git
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

#define IRC_CONNECTION_M

#include <stdarg.h>

#import <ObjFW/OFString.h>
#import <ObjFW/OFArray.h>
#import <ObjFW/OFMutableDictionary.h>
#import <ObjFW/OFTCPSocket.h>
#import <ObjFW/OFAutoreleasePool.h>

#import <ObjFW/OFInvalidEncodingException.h>

#import <ObjFW/macros.h>

#import "IRCConnection.h"
#import "IRCUser.h"

@implementation IRCConnection
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

- (void)setServer: (OFString*)server_
{
	OF_SETTER(server, server_, YES, YES)
}

- (OFString*)server
{
	OF_GETTER(server, YES)
}

- (void)setPort: (uint16_t)port_
{
	port = port_;
}

- (uint16_t)port
{
	return port;
}

- (void)setNickname: (OFString*)nickname_
{
	OF_SETTER(nickname, nickname_, YES, YES)
}

- (OFString*)nickname
{
	OF_GETTER(nickname, YES)
}

- (void)setUsername: (OFString*)username_
{
	OF_SETTER(username, username_, YES, YES)
}

- (OFString*)username
{
	OF_GETTER(username, YES)
}

- (void)setRealname: (OFString*)realname_
{
	OF_SETTER(realname, realname_, YES, YES)
}

- (OFString*)realname
{
	OF_GETTER(realname, YES)
}

- (void)setDelegate: (id <IRCConnectionDelegate>)delegate_
{
	delegate = delegate_;
}

- (id <IRCConnectionDelegate>)delegate
{
	return delegate;
}

- (OFTCPSocket*)socket
{
	OF_GETTER(sock, YES)
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
	reason = [[reason componentsSeparatedByString: @"\n"] firstObject];

	if (reason == nil)
		[self sendLine: @"QUIT"];
	else
		[self sendLineWithFormat: @"QUIT :%@", reason];
}

- (void)joinChannel: (OFString*)channel
{
	channel = [[channel componentsSeparatedByString: @"\n"] firstObject];

	[self sendLineWithFormat: @"JOIN %@", channel];
}

- (void)leaveChannel: (OFString*)channel
{
	[self leaveChannel: channel
		    reason: nil];
}

- (void)leaveChannel: (OFString*)channel
	      reason: (OFString*)reason
{
	channel = [[channel componentsSeparatedByString: @"\n"] firstObject];
	reason = [[reason componentsSeparatedByString: @"\n"] firstObject];

	if (reason == nil)
		[self sendLineWithFormat: @"PART %@", channel];
	else
		[self sendLineWithFormat: @"PART %@ :%@", channel, reason];

	[channels removeObjectForKey: channel];
}

- (void)sendLine: (OFString*)line
{
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
		 to: (OFString*)to
{
	OFArray *lines = [msg componentsSeparatedByString: @"\n"];
	OFEnumerator *enumerator = [lines objectEnumerator];
	OFString *line;

	while ((line = [enumerator nextObject]) != nil)
		[self sendLineWithFormat: @"PRIVMSG %@ :%@", to, line];
}

- (void)sendNotice: (OFString*)notice
		to: (OFString*)to
{
	OFArray *lines = [notice componentsSeparatedByString: @"\n"];
	OFEnumerator *enumerator = [lines objectEnumerator];
	OFString *line;

	while ((line = [enumerator nextObject]) != nil)
		[self sendLineWithFormat: @"NOTICE %@ :%@", to, line];
}

- (void)kickUser: (OFString*)user
	 channel: (OFString*)channel
	  reason: (OFString*)reason
{
	reason = [[reason componentsSeparatedByString: @"\n"] firstObject];

	[self sendLineWithFormat: @"KICK %@ %@ :%@", channel, user, reason];
}

- (void)changeNicknameTo: (OFString*)nickname_
{
	nickname_ = [[nickname_ componentsSeparatedByString: @"\n"]
	    firstObject];

	[self sendLineWithFormat: @"NICK %@", nickname_];
}

- (void)IRC_processLine: (OFString*)line
{
	OFArray *components;
	OFString *action = nil;

	[delegate connection: self
	      didReceiveLine: line];

	components = [line componentsSeparatedByString: @" "];

	/* PING */
	if ([components count] == 2 &&
	    [[components firstObject] isEqual: @"PING"]) {
		OFMutableString *s = [[line mutableCopy] autorelease];
		[s replaceOccurrencesOfString: @"PING"
				   withString: @"PONG"];
		[self sendLine: s];

		return;
	}

	action = [[components objectAtIndex: 1] uppercaseString];

	/* Connected */
	if ([action isEqual: @"001"] && [components count] >= 4) {
		[delegate connectionWasEstablished: self];
		return;
	}

	/* JOIN */
	if ([action isEqual: @"JOIN"] && [components count] == 3) {
		OFString *who = [components objectAtIndex: 0];
		OFString *where = [components objectAtIndex: 2];
		IRCUser *user;
		OFMutableSet *channel;

		who = [who substringWithRange: of_range(1, [who length] - 1)];
		user = [IRCUser IRCUserWithString: who];

		if ([who hasPrefix: [nickname stringByAppendingString: @"!"]]) {
			channel = [OFMutableSet set];
			[channels setObject: channel
				     forKey: where];
		} else
			channel = [channels objectForKey: where];

		[channel addObject: [user nickname]];

		[delegate connection: self
			  didSeeUser: user
			 joinChannel: where];

		return;
	}

	/* NAMES reply */
	if ([action isEqual: @"353"] && [components count] >= 6) {
		OFString *where;
		OFMutableSet *channel;
		OFArray *users;
		size_t pos;
		OFEnumerator *enumerator;
		OFString *user;

		where = [components objectAtIndex: 4];

		if ((channel = [channels objectForKey: where]) == nil) {
			/* We did not request that */
			return;
		}

		pos = [[components objectAtIndex: 0] length] +
		    [[components objectAtIndex: 1] length] +
		    [[components objectAtIndex: 2] length] +
		    [[components objectAtIndex: 3] length] +
		    [[components objectAtIndex: 4] length] + 6;

		users = [[line substringWithRange:
		    of_range(pos, [line length] - pos)]
		    componentsSeparatedByString: @" "];

		enumerator = [users objectEnumerator];
		while ((user = [enumerator nextObject]) != nil) {
			if ([user hasPrefix: @"@"] || [user hasPrefix: @"+"] ||
			    [user hasPrefix: @"%"] || [user hasPrefix: @"*"])
				user = [user substringWithRange:
				    of_range(1, [user length] - 1)];

			[channel addObject: user];
		}

		[delegate	   connection: self
		    didReceiveNamesForChannel: where];

		return;
	}

	/* PART */
	if ([action isEqual: @"PART"] && [components count] >= 3) {
		OFString *who = [components objectAtIndex: 0];
		OFString *where = [components objectAtIndex: 2];
		IRCUser *user;
		OFMutableSet *channel;
		OFString *reason = nil;
		size_t pos = [who length] + 1 +
		    [[components objectAtIndex: 1] length] + 1 + [where length];

		who = [who substringWithRange: of_range(1, [who length] - 1)];
		user = [IRCUser IRCUserWithString: who];
		channel = [channels objectForKey: where];

		if ([components count] > 3)
			reason = [line substringWithRange:
			    of_range(pos + 2, [line length] - pos - 2)];

		[channel removeObject: [user nickname]];

		[delegate connection: self
			  didSeeUser: user
			leaveChannel: where
			      reason: reason];

		return;
	}

	/* KICK */
	if ([action isEqual: @"KICK"] && [components count] >= 4) {
		OFString *who = [components objectAtIndex: 0];
		OFString *where = [components objectAtIndex: 2];
		OFString *whom = [components objectAtIndex: 3];
		IRCUser *user;
		OFMutableSet *channel;
		OFString *reason = nil;
		size_t pos = [who length] + 1 +
		    [[components objectAtIndex: 1] length] + 1 +
		    [where length] + 1 + [whom length];

		who = [who substringWithRange: of_range(1, [who length] - 1)];
		user = [IRCUser IRCUserWithString: who];
		channel = [channels objectForKey: where];

		if ([components count] > 4)
			reason = [line substringWithRange:
			    of_range(pos + 2, [line length] - pos - 2)];

		[channel removeObject: [user nickname]];

		[delegate connection: self
			  didSeeUser: user
			    kickUser: whom
			     channel: where
			      reason: reason];

		return;
	}

	/* QUIT */
	if ([action isEqual: @"QUIT"] && [components count] >= 2) {
		OFString *who = [components objectAtIndex: 0];
		IRCUser *user;
		OFString *reason = nil;
		size_t pos = [who length] + 1 +
		    [[components objectAtIndex: 1] length];
		OFEnumerator *enumerator;
		OFMutableSet *channel;

		who = [who substringWithRange: of_range(1, [who length] - 1)];
		user = [IRCUser IRCUserWithString: who];

		if ([components count] > 2)
			reason = [line substringWithRange:
			    of_range(pos + 2, [line length] - pos - 2)];

		enumerator = [channels objectEnumerator];
		while ((channel = [enumerator nextObject]) != nil)
			[channel removeObject: [user nickname]];

		[delegate connection: self
		      didSeeUserQuit: user
			      reason: reason];

		return;
	}

	/* NICK */
	if ([action isEqual: @"NICK"] && [components count] == 3) {
		OFString *who = [components objectAtIndex: 0];
		OFString *newNickname = [components objectAtIndex: 2];
		IRCUser *user;
		OFEnumerator *enumerator;
		OFMutableSet *channel;

		who = [who substringWithRange: of_range(1, [who length] - 1)];
		newNickname = [newNickname substringWithRange:
		    of_range(1, [newNickname length] - 1)];

		user = [IRCUser IRCUserWithString: who];

		if ([[user nickname] isEqual: nickname]) {
			[nickname release];
			nickname = [[user nickname] copy];
		}

		enumerator = [channels keyEnumerator];
		while ((channel = [enumerator nextObject]) != nil) {
			if ([channel containsObject: [user nickname]]) {
				[channel removeObject: [user nickname]];
				[channel addObject: newNickname];
			}
		}

		[delegate connection: self
			  didSeeUser: user
		    changeNicknameTo: newNickname];

		return;
	}

	/* PRIVMSG */
	if ([action isEqual: @"PRIVMSG"] && [components count] >= 4) {
		OFString *from = [components objectAtIndex: 0];
		OFString *to = [components objectAtIndex: 2];
		IRCUser *user;
		OFString *msg;
		size_t pos = [from length] + 1 +
		    [[components objectAtIndex: 1] length] + 1 + [to length];

		from = [from substringWithRange:
		    of_range(1, [from length] - 1)];
		msg = [line substringWithRange:
		    of_range(pos + 2, [line length] - pos - 2)];
		user = [IRCUser IRCUserWithString: from];

		if (![to isEqual: nickname])
			[delegate connection: self
			   didReceiveMessage: msg
				     channel: to
					user: user];
		else
			[delegate	  connection: self
			    didReceivePrivateMessage: msg
						user: user];

		return;
	}

	/* NOTICE */
	if ([action isEqual: @"NOTICE"] && [components count] >= 4) {
		OFString *from = [components objectAtIndex: 0];
		OFString *to = [components objectAtIndex: 2];
		IRCUser *user = nil;
		OFString *notice;
		size_t pos = [from length] + 1 +
		    [[components objectAtIndex: 1] length] + 1 + [to length];

		from = [from substringWithRange:
		    of_range(1, [from length] - 1)];
		notice = [line substringWithRange:
		    of_range(pos + 2, [line length] - pos - 2)];

		if (![from containsString: @"!"] || [to isEqual: @"*"]) {
			/* System message - ignore for now */
			return;
		}

		user = [IRCUser IRCUserWithString: from];

		if (![to isEqual: nickname])
			[delegate connection: self
			    didReceiveNotice: notice
				     channel: to
					user: user];
		else
			[delegate connection: self
			    didReceiveNotice: notice
					user: user];

		return;
	}
}

- (void)processLine: (OFString*)line
{
	OFAutoreleasePool *pool = [[OFAutoreleasePool alloc] init];

	[self IRC_processLine: line];

	[pool release];
}

-	  (BOOL)connection: (OFTCPSocket*)connection
    didReceiveISO88591Line: (OFString*)line
		 exception: (OFException*)exception
{
	if (line != nil) {
		[self IRC_processLine: line];
		[sock asyncReadLineWithTarget: self
				     selector: @selector(connection:
						   didReceiveLine:
						   exception:)];
	}

	return NO;
}

- (BOOL)connection: (OFTCPSocket*)connection
    didReceiveLine: (OFString*)line
	 exception: (OFException*)exception
{
	if (line != nil) {
		[self IRC_processLine: line];
		return YES;
	}

	if ([exception isKindOfClass: [OFInvalidEncodingException class]])
		[sock asyncReadLineWithEncoding: OF_STRING_ENCODING_ISO_8859_1
					 target: self
				       selector: @selector(connection:
						     didReceiveISO88591Line:
						     exception:)];

	return NO;
}

- (void)handleConnection
{
	[sock asyncReadLineWithTarget: self
			     selector: @selector(connection:didReceiveLine:
					   exception:)];
}

- (OFSet*)usersInChannel: (OFString*)channel
{
	return [[[channels objectForKey: channel] copy] autorelease];
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

@implementation OFObject (IRCConnectionDelegate)
- (void)connection: (IRCConnection*)connection
    didReceiveLine: (OFString*)line
{
}

- (void)connection: (IRCConnection*)connection
       didSendLine: (OFString*)line
{
}

- (void)connectionWasEstablished: (IRCConnection*)connection
{
}

- (void)connection: (IRCConnection*)connection
	didSeeUser: (IRCUser*)user
       joinChannel: (OFString*)channel
{
}

- (void)connection: (IRCConnection*)connection
	didSeeUser: (IRCUser*)user
      leaveChannel: (OFString*)channel
	    reason: (OFString*)reason
{
}

- (void)connection: (IRCConnection*)connection
        didSeeUser: (IRCUser*)user
  changeNicknameTo: (OFString*)nickname
{
}

- (void)connection: (IRCConnection*)connection
	didSeeUser: (IRCUser*)user
	  kickUser: (OFString*)kickedUser
	   channel: (OFString*)channel
	    reason: (OFString*)reason
{
}

- (void)connection: (IRCConnection*)connection
    didSeeUserQuit: (IRCUser*)user
	    reason: (OFString*)reason
{
}

-  (void)connection: (IRCConnection*)connection
  didReceiveMessage: (OFString*)msg
	    channel: (OFString*)channel
	       user: (IRCUser*)user
{
}

-	  (void)connection: (IRCConnection*)connection
  didReceivePrivateMessage: (OFString*)msg
		      user: (IRCUser*)user
{
}

- (void)connection: (IRCConnection*)connection
  didReceiveNotice: (OFString*)notice
	   channel: (OFString*)channel
	      user: (IRCUser*)user
{
}

- (void)connection: (IRCConnection*)connection
  didReceiveNotice: (OFString*)notice
	      user: (IRCUser*)user
{
}

-	   (void)connection: (IRCConnection*)connection
  didReceiveNamesForChannel: (OFString*)channel
{
}

- (void)connectionWasClosed: (IRCConnection*)connection
{
}
@end
