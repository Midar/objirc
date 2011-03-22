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

#import <ObjFW/ObjFW.h>

#import "IRCConnection.h"
#import "IRCUser.h"
#import "IRCChannel.h"

@interface TestApp: OFObject <OFApplicationDelegate, IRCConnectionDelegate>
@end

OF_APPLICATION_DELEGATE(TestApp)

@implementation TestApp
- (void)applicationDidFinishLaunching
{
	IRCConnection *conn = [[IRCConnection alloc] init];

	conn.server = @"leguin.freenode.net";
	conn.nickname = @"ObjIRC";
	conn.username = @"ObjIRC";
	conn.realname = @"ObjIRC";
	conn.delegate = self;

	[conn connect];
	[conn handleConnection];
}

- (void)connection: (IRCConnection*)conn
    didReceiveLine: (OFString*)line
{
	[of_stderr writeFormat: @"> %@\n", line];
}

- (void)connection: (IRCConnection*)conn
       didSendLine: (OFString*)line
{
	[of_stderr writeFormat: @"< %@\n", line];
}

- (void)connectionWasEstablished: (IRCConnection*)conn
{
	[conn joinChannel: @"#objfw"];
}

- (void)connection: (IRCConnection*)conn
	didSeeUser: (IRCUser*)user
       joinChannel: (IRCChannel*)channel
{
	of_log(@"%@ joined %@.", user, channel.name);
}

-  (void)connection: (IRCConnection*)conn
  didReceiveMessage: (OFString*)msg
	   fromUser: (IRCUser*)user
	  inChannel: (IRCChannel*)channel
{
	of_log(@"[%@] %@: %@", channel.name, user, msg);
}

-	  (void)connection: (IRCConnection*)conn
  didReceivePrivateMessage: (OFString*)msg
		  fromUser: (IRCUser*)user
{
	of_log(@"(%@): %@", user, msg);
}
@end
