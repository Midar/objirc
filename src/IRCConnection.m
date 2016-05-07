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

#import <ObjFW/OFInvalidEncodingException.h>

#import <ObjFW/macros.h>

#import "IRCConnection.h"
#import "IRCUser.h"

@implementation IRCConnection
@synthesize server = _server, port = _port;
@synthesize nickname = _nickname, username = _username, realname = _realname;
@synthesize delegate = _delegate, socket = _socket;

+ (instancetype)connection
{
	return [[[self alloc] init] autorelease];
}

- init
{
	self = [super init];

	@try {
		_channels = [[OFMutableDictionary alloc] init];
		_port = 6667;
	} @catch (id e) {
		[self release];
		@throw e;
	}

	return self;
}

- (void)dealloc
{
	[_socket release];
	[_server release];
	[_nickname release];
	[_username release];
	[_realname release];
	[_channels release];

	[super dealloc];
}

- (void)connect
{
	void *pool = objc_autoreleasePoolPush();

	if (_socket != nil)
		@throw [OFAlreadyConnectedException exception];

	_socket = [[OFTCPSocket alloc] init];
	[_socket connectToHost: _server
			  port: _port];

	[self sendLineWithFormat: @"NICK %@", _nickname];
	[self sendLineWithFormat: @"USER %@ * 0 :%@", _username, _realname];

	objc_autoreleasePoolPop(pool);
}

- (void)disconnect
{
	[self disconnectWithReason: nil];
}

- (void)disconnectWithReason: (OFString*)reason
{
	void *pool = objc_autoreleasePoolPush();

	reason = [[reason componentsSeparatedByString: @"\n"] firstObject];

	if (reason == nil)
		[self sendLine: @"QUIT"];
	else
		[self sendLineWithFormat: @"QUIT :%@", reason];

	objc_autoreleasePoolPop(pool);
}

- (void)joinChannel: (OFString*)channel
{
	void *pool = objc_autoreleasePoolPush();

	channel = [[channel componentsSeparatedByString: @"\n"] firstObject];

	[self sendLineWithFormat: @"JOIN %@", channel];

	objc_autoreleasePoolPop(pool);
}

- (void)leaveChannel: (OFString*)channel
{
	[self leaveChannel: channel
		    reason: nil];
}

- (void)leaveChannel: (OFString*)channel
	      reason: (OFString*)reason
{
	void *pool = objc_autoreleasePoolPush();

	channel = [[channel componentsSeparatedByString: @"\n"] firstObject];
	reason = [[reason componentsSeparatedByString: @"\n"] firstObject];

	if (reason == nil)
		[self sendLineWithFormat: @"PART %@", channel];
	else
		[self sendLineWithFormat: @"PART %@ :%@", channel, reason];

	[_channels removeObjectForKey: channel];

	objc_autoreleasePoolPop(pool);
}

- (void)sendLine: (OFString*)line
{
	if ([_delegate respondsToSelector: @selector(connection:didSendLine:)])
		[_delegate connection: self
			  didSendLine: line];

	[_socket writeLine: line];
}

- (void)sendLineWithFormat: (OFConstantString*)format, ...
{
	void *pool = objc_autoreleasePoolPush();
	OFString *line;
	va_list args;

	va_start(args, format);
	line = [[[OFString alloc] initWithFormat: format
				       arguments: args] autorelease];
	va_end(args);

	[self sendLine: line];

	objc_autoreleasePoolPop(pool);
}

- (void)sendMessage: (OFString*)msg
		 to: (OFString*)to
{
	void *pool = objc_autoreleasePoolPush();

	for (OFString *line in [msg componentsSeparatedByString: @"\n"])
		[self sendLineWithFormat: @"PRIVMSG %@ :%@", to, line];

	objc_autoreleasePoolPop(pool);
}

- (void)sendNotice: (OFString*)notice
		to: (OFString*)to
{
	void *pool = objc_autoreleasePoolPush();

	for (OFString *line in [notice componentsSeparatedByString: @"\n"])
		[self sendLineWithFormat: @"NOTICE %@ :%@", to, line];

	objc_autoreleasePoolPop(pool);
}

- (void)kickUser: (OFString*)user
	 channel: (OFString*)channel
	  reason: (OFString*)reason
{
	void *pool = objc_autoreleasePoolPush();

	reason = [[reason componentsSeparatedByString: @"\n"] firstObject];

	[self sendLineWithFormat: @"KICK %@ %@ :%@", channel, user, reason];

	objc_autoreleasePoolPop(pool);
}

- (void)changeNicknameTo: (OFString*)nickname
{
	void *pool = objc_autoreleasePoolPush();

	nickname = [[nickname componentsSeparatedByString: @"\n"]
	    firstObject];

	[self sendLineWithFormat: @"NICK %@", nickname];

	objc_autoreleasePoolPop(pool);
}

- (void)IRC_processLine: (OFString*)line
{
	OFArray *components;
	OFString *action = nil;

	if ([_delegate respondsToSelector:
	    @selector(connection:didReceiveLine:)])
		[_delegate connection: self
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
		if ([_delegate respondsToSelector:
		    @selector(connectionWasEstablished:)])
			[_delegate connectionWasEstablished: self];

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

		if ([who hasPrefix:
		    [_nickname stringByAppendingString: @"!"]]) {
			channel = [OFMutableSet set];
			[_channels setObject: channel
				      forKey: where];
		} else
			channel = [_channels objectForKey: where];

		[channel addObject: [user nickname]];

		if ([_delegate respondsToSelector:
		    @selector(connection:didSeeUser:joinChannel:)])
			[_delegate connection: self
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

		where = [components objectAtIndex: 4];

		if ((channel = [_channels objectForKey: where]) == nil) {
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

		for (OFString *user in users) {
			if ([user hasPrefix: @"@"] || [user hasPrefix: @"+"] ||
			    [user hasPrefix: @"%"] || [user hasPrefix: @"*"])
				user = [user substringWithRange:
				    of_range(1, [user length] - 1)];

			[channel addObject: user];
		}

		if ([_delegate respondsToSelector:
		    @selector(connection:didReceiveNamesForChannel:)])
			[_delegate	   connection: self
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
		channel = [_channels objectForKey: where];

		if ([components count] > 3)
			reason = [line substringWithRange:
			    of_range(pos + 2, [line length] - pos - 2)];

		[channel removeObject: [user nickname]];

		if ([_delegate respondsToSelector:
		    @selector(connection:didSeeUser:leaveChannel:reason:)])
			[_delegate connection: self
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
		channel = [_channels objectForKey: where];

		if ([components count] > 4)
			reason = [line substringWithRange:
			    of_range(pos + 2, [line length] - pos - 2)];

		[channel removeObject: [user nickname]];

		if ([_delegate respondsToSelector:
		    @selector(connection:didSeeUser:kickUser:channel:reason:)])
			[_delegate connection: self
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

		who = [who substringWithRange: of_range(1, [who length] - 1)];
		user = [IRCUser IRCUserWithString: who];

		if ([components count] > 2)
			reason = [line substringWithRange:
			    of_range(pos + 2, [line length] - pos - 2)];

		for (OFMutableSet *channel in _channels)
			[channel removeObject: [user nickname]];

		if ([_delegate respondsToSelector:
		    @selector(connection:didSeeUserQuit:reason:)])
			[_delegate connection: self
			       didSeeUserQuit: user
				       reason: reason];

		return;
	}

	/* NICK */
	if ([action isEqual: @"NICK"] && [components count] == 3) {
		OFString *who = [components objectAtIndex: 0];
		OFString *nickname = [components objectAtIndex: 2];
		IRCUser *user;

		who = [who substringWithRange: of_range(1, [who length] - 1)];
		nickname = [nickname substringWithRange:
		    of_range(1, [nickname length] - 1)];

		user = [IRCUser IRCUserWithString: who];

		if ([[user nickname] isEqual: _nickname]) {
			[_nickname release];
			_nickname = [nickname copy];
		}

		for (OFMutableSet *channel in _channels) {
			if ([channel containsObject: [user nickname]]) {
				[channel removeObject: [user nickname]];
				[channel addObject: nickname];
			}
		}

		if ([_delegate respondsToSelector:
		    @selector(connection:didSeeUser:changeNicknameTo:)])
			[_delegate connection: self
				   didSeeUser: user
			     changeNicknameTo: nickname];

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

		if (![to isEqual: _nickname]) {
			if ([_delegate respondsToSelector: @selector(connection:
			    didReceiveMessage:channel:user:)])
				[_delegate connection: self
				    didReceiveMessage: msg
					      channel: to
						 user: user];
		} else {
			if ([_delegate respondsToSelector: @selector(connection:
			    didReceivePrivateMessage:user:)])
				[_delegate	  connection: self
				    didReceivePrivateMessage: msg
							user: user];
		}

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

		if (![to isEqual: _nickname]) {
			if ([_delegate respondsToSelector: @selector(connection:
			    didReceiveNotice:channel:user:)])
				[_delegate connection: self
				     didReceiveNotice: notice
					      channel: to
						 user: user];
		} else {
			if ([_delegate respondsToSelector:
			    @selector(connection:didReceiveNotice:user:)])
				[_delegate connection: self
				     didReceiveNotice: notice
						 user: user];
		}

		return;
	}
}

- (void)processLine: (OFString*)line
{
	void *pool = objc_autoreleasePoolPush();

	[self IRC_processLine: line];

	objc_autoreleasePoolPop(pool);
}

-	    (bool)socket: (OFTCPSocket*)socket
  didReceiveISO88591Line: (OFString*)line
	       exception: (OFException*)exception
{
	if (line != nil) {
		[self IRC_processLine: line];
		[socket asyncReadLineWithTarget: self
				       selector: @selector(socket:
						     didReceiveLine:
						     exception:)];
	}

	return false;
}

-   (bool)socket: (OFTCPSocket*)socket
  didReceiveLine: (OFString*)line
       exception: (OFException*)exception
{
	if (line != nil) {
		[self IRC_processLine: line];
		return true;
	}

	if ([exception isKindOfClass: [OFInvalidEncodingException class]]) {
		[socket asyncReadLineWithEncoding: OF_STRING_ENCODING_ISO_8859_1
					   target: self
					 selector: @selector(socket:
						       didReceiveISO88591Line:
						       exception:)];
		return false;
	}

	if ([_delegate respondsToSelector: @selector(connectionWasClosed:)]) {
		[_delegate connectionWasClosed: self];
		[_socket release];
		_socket = nil;
	}

	return false;
}

- (void)handleConnection
{
	[_socket asyncReadLineWithTarget: self
				selector: @selector(socket:didReceiveLine:
					      exception:)];
}

- (OFSet*)usersInChannel: (OFString*)channel
{
	return [[[_channels objectForKey: channel] copy] autorelease];
}
@end
