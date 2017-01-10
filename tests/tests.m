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

#import <ObjFW/OFString.h>
#import <ObjFW/OFApplication.h>
#import <ObjFW/OFFile.h>

#import "IRCConnection.h"
#import "IRCUser.h"

@interface TestApp: OFObject <OFApplicationDelegate, IRCConnectionDelegate>
@end

OF_APPLICATION_DELEGATE(TestApp)

@implementation TestApp
- (void)applicationDidFinishLaunching
{
	IRCConnection *connection = [[IRCConnection alloc] init];

	[connection setServer: @"irc.freenode.net"];
	[connection setNickname: @"ObjIRC"];
	[connection setUsername: @"ObjIRC"];
	[connection setRealname: @"ObjIRC"];
	[connection setDelegate: self];

	[connection connect];
	[connection handleConnection];
}

- (void)connection: (IRCConnection*)connection
    didReceiveLine: (OFString*)line
{
	[of_stderr writeFormat: @"> %@\n", line];
}

- (void)connection: (IRCConnection*)connection
       didSendLine: (OFString*)line
{
	[of_stderr writeFormat: @"< %@\n", line];
}

- (void)connectionWasEstablished: (IRCConnection*)connection
{
	[connection joinChannel: @"#objfw"];
}

- (void)connection: (IRCConnection*)connection
	didSeeUser: (IRCUser*)user
       joinChannel: (OFString*)channel
{
	of_log(@"%@ joined %@.", user, channel);
}

- (void)connection: (IRCConnection*)connection
	didSeeUser: (IRCUser*)user
      leaveChannel: (OFString*)channel
	    reason: (OFString*)reason
{
	of_log(@"%@ left %@ (%@).", user, channel, reason);
}

-    (void)connection: (IRCConnection*)connection
	   didSeeUser: (IRCUser*)user
	     kickUser: (OFString*)kickedUser
	      channel: (OFString*)channel
	       reason: (OFString*)reason
{
	of_log(@"%@ kicked %@ from %@: %@", user, kickedUser, channel, reason);
}

- (void)connection: (IRCConnection*)connection
    didSeeUserQuit: (IRCUser*)user
	    reason: (OFString*)reason
{
	of_log(@"%@ quit (%@).", user, reason);
}

- (void)connection: (IRCConnection*)connection
	didSeeUser: (IRCUser*)user
  changeNicknameTo: (OFString *)nickname
{
	of_log(@"%@ changed nick to %@.", user, nickname);
}

-  (void)connection: (IRCConnection*)connection
  didReceiveMessage: (OFString*)msg
	    channel: (OFString*)channel
	       user: (IRCUser*)user
{
	of_log(@"[%@] %@: %@", channel, [user nickname], msg);
}

-	  (void)connection: (IRCConnection*)connection
  didReceivePrivateMessage: (OFString*)msg
		      user: (IRCUser*)user
{
	of_log(@"(%@): %@", user, msg);
}

- (void)connection: (IRCConnection*)connection
  didReceiveNotice: (OFString*)notice
	   channel: (OFString*)channel
	      user: (IRCUser*)user
{
	of_log(@"NOTICE: [%@] %@: %@", channel, [user nickname], notice);
}

- (void)connection: (IRCConnection*)connection
  didReceiveNotice: (OFString*)notice
	      user: (IRCUser*)user
{
	of_log(@"NOTICE: (%@): %@", user, notice);
}

-	   (void)connection: (IRCConnection*)connection
  didReceiveNamesForChannel: (OFString*)channel
{
	of_log(@"Users in %@: %@", channel,
	    [connection usersInChannel: channel]);
}
@end